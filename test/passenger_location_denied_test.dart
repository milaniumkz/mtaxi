import 'dart:convert' show base64Decode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mtaxi/auth/backend_auth/backend_user_provider.dart';
import 'package:mtaxi/backend/backend_session.dart';
import 'package:mtaxi/custom_code/widgets/delivery_taxi_map.dart';
import 'package:mtaxi/flutter_flow/flutter_flow_util.dart';
import 'package:mtaxi/passenger/home_page/home_page_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_flow_test.dart' show wrap;

void main() {
  testWidgets('denied GPS never selects a cached or fallback passenger pickup',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {mtaxiBackendAccessTokenPrefsKey: 'isolated-test-token'});
    FFAppState.reset();
    await FFAppState().initializePersistedState();
    final user = <String, dynamic>{
      'id': 'isolated-location-test',
      'city': 'Железинка',
      'profileCompleted': true,
      'hasPassword': true,
    };
    activateBackendUser(user);
    cachedUserLocation = const LatLng(52.3231, 77.1282);
    const channel = MethodChannel('flutter.baseflow.com/geolocator');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async => call.method == 'isLocationServiceEnabled' ? true : 1);
    addTearDown(() {
      cachedUserLocation = null;
      activateBackendUser(null);
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap(const HomePageWidget()));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(
          tester
              .widget<DeliveryTaxiMap>(find.byType(DeliveryTaxiMap))
              .initialFromCoords,
          isNull);
      expect(fields.length, greaterThanOrEqualTo(2));
      expect(fields.first.controller!.text, isEmpty);
      expect(find.text('Недопустимая резервная точка'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 16));
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/getSessionBootstrap')) {
                await Future<void>.delayed(const Duration(seconds: 2));
              }
              if (request.url.path.endsWith('.png')) {
                return http.Response.bytes(
                    base64Decode(
                        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGP6zwAAAgcBApocMXEAAAAASUVORK5CYII='),
                    200,
                    headers: {'content-type': 'image/png'});
              }
              final payload = request.url.path.contains('reverse')
                  ? {'display_name': 'Недопустимая резервная точка'}
                  : {
                      'success': true,
                      'user': user,
                      'settings': {'intercityEnabled': false},
                      'orders': [],
                      'routes': [],
                    };
              return http.Response(jsonEncode(payload), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
}
