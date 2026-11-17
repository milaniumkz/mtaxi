import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtaxi/app_state.dart';
import 'package:mtaxi/auth/backend_auth/backend_user_provider.dart';
import 'package:mtaxi/backend/backend_session.dart';
import 'package:mtaxi/driver/home_driver_order/home_driver_order_widget.dart';
import 'design_flow_test.dart' show wrap;

void main() {
  testWidgets(
      'thirty state updates keep the same active-trip subscription and screen',
      (tester) async {
    PackageInfo.setMockInitialValues(
        appName: 'MTaxi',
        packageName: 'audit',
        version: '1',
        buildNumber: '1',
        buildSignature: '');
    SharedPreferences.setMockInitialValues({
      mtaxiBackendAccessTokenPrefsKey: 'synthetic',
      'ff_soundEnabled': false
    });
    FFAppState.reset();
    await FFAppState().initializePersistedState();
    final user = {
      'id': 'stable-driver',
      'displayName': 'Водитель',
      'phone': '+77010000001',
      'isDriver': true,
      'statusDriver': 'approved',
      'driverRegistrationStatus': 'approved',
      'roleState': 'DRIVER_ON_TRIP',
      'preferredClientMode': 'driver',
      'activeDriverOrderId': 'stable-trip',
      'hasActiveDriverOrder': true,
      'profileCompleted': true,
      'hasPassword': true,
      'city': 'Железинка',
      'balance': 1000
    };
    final order = {
      'id': 'stable-trip',
      'orderDocPath': 'order/stable-trip',
      'passengerId': 'passenger',
      'driverId': 'stable-driver',
      'status': 2,
      'type': 'taxi',
      'city': 'Железинка',
      'ot': 'Абая 1',
      'kuda': 'Абая 10',
      'price': 500,
      'createdAt': DateTime.now().toIso8601String()
    };
    activateBackendUser(user);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/geolocator'),
        (call) async => call.method == 'isLocationServiceEnabled' ? false : 1);
    var reads = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(
          wrap(const HomeDriverOrderWidget(orderDocPath: 'order/stable-trip')));
      for (var i = 0; i < 16; i++)
        await tester.pump(const Duration(milliseconds: 100));
      final before = reads;
      expect(find.text('Я на месте'), findsOneWidget);
      for (var i = 0; i < 30; i++) {
        FFAppState().update(() {});
        await tester.pump(const Duration(milliseconds: 10));
        await tester.pump();
        expect(find.text('Я на месте'), findsOneWidget);
      }
      expect(reads, before,
          reason: 'Rebuilds must not start thirty new HTTP subscriptions');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    },
        () => MockClient((request) async {
              if (!request.url.path.contains('/call/'))
                return http.Response.bytes(
                    base64Decode(
                        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII='),
                    200,
                    headers: {'content-type': 'image/png'});
              if (request.url.path.endsWith('getOrderDetails')) reads++;
              return http.Response(
                  jsonEncode({
                    'success': true,
                    'user': user,
                    'order': order,
                    'activeDriverOrderRef': 'order/stable-trip',
                    'hasActiveDriverOrder': true,
                    'roleState': 'DRIVER_ON_TRIP',
                    'settings': {},
                    'status': 2,
                    'driverPosition': null
                  }),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
  });
}
