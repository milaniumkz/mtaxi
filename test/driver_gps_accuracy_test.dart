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
import 'package:mtaxi/driver/home_driver/home_driver_widget.dart';
import 'design_flow_test.dart' show wrap;

void main() {
  testWidgets('driver landing publishes measured GPS accuracy', (tester) async {
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
      'id': 'audit-gps',
      'phone': '+70010000999',
      'displayName': 'Synthetic',
      'roleState': 'DRIVER_ONLINE',
      'preferredClientMode': 'driver',
      'isDriver': true,
      'statusDriver': 'approved',
      'city': 'Железинка',
      'balance': 1000,
      'profileCompleted': true,
      'hasPassword': true
    };
    activateBackendUser(user);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/geolocator'),
        (call) async => call.method == 'isLocationServiceEnabled'
            ? true
            : call.method == 'checkPermission'
                ? 3
                : {
                    'latitude': 53.53,
                    'longitude': 76.68,
                    'accuracy': 7.0,
                    'altitude': 0.0,
                    'heading': 0.0,
                    'speed': 0.0,
                    'speed_accuracy': 0.0,
                    'timestamp': DateTime.now().millisecondsSinceEpoch
                  });
    final samples = <Map>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap(const HomeDriverWidget()));
      for (var i = 0; i < 20; i++)
        await tester.pump(const Duration(milliseconds: 200));
      expect(samples, isNotEmpty);
      expect(samples.every((sample) => sample['accuracy'] == 7.0), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
        () => MockClient((request) async {
              if (!request.url.path.contains('/call/')) {
                return http.Response.bytes(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII='), 200, headers: {'content-type':'image/png'});
              }
              if (request.url.path.endsWith('updateUserPreferences')) {
                final data = jsonDecode(request.body) as Map;
                if (data['coords'] is Map) samples.add(data['coords'] as Map);
              }
              return http.Response(
                  jsonEncode({
                    'success': true,
                    'user': user,
                    'orders': [],
                    'settings': {'driverCoordsUpdateSec': 2},
                    'driverBonus': {'enabled': false}
                  }),
              200, headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
}
