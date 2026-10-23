import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtaxi/app_state.dart';
import 'package:mtaxi/auth/backend_auth/backend_user_provider.dart';
import 'package:mtaxi/auth/backend_auth/auth_util.dart';
import 'package:mtaxi/backend/backend.dart';
import 'package:mtaxi/backend/backend_session.dart';
import 'package:mtaxi/design/mtaxi_theme.dart';
import 'package:mtaxi/driver/home_driver_order/home_driver_order_widget.dart';
import 'package:mtaxi/passenger/seach_driver/seach_driver_widget.dart';
import 'package:mtaxi/flutter_flow/internationalization.dart';

void main() {
  for (final driver in [false, true]) {
    testWidgets(
        'completion receipt remains open through repeated polls ($driver)',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PackageInfo.setMockInitialValues(
          appName: 'MTaxi',
          packageName: 'mtaxi',
          version: '1.2.0',
          buildNumber: '58',
          buildSignature: 'test');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/geolocator'),
          (call) async => switch (call.method) {
                'isLocationServiceEnabled' => true,
                'checkPermission' => 3,
                _ => {
                    'latitude': 53.538,
                    'longitude': 75.313,
                    'accuracy': 10.0,
                    'altitude': 0.0,
                    'heading': 0.0,
                    'speed': 0.0,
                    'speed_accuracy': 0.0,
                    'timestamp': DateTime.now().millisecondsSinceEpoch
                  },
              });
      var complete = false;
      final user = <String, dynamic>{
        'id': driver ? 'completion-driver' : 'completion-passenger',
        'displayName': 'Тест',
        'phone': '+77019990011',
        'balance': 5000,
        'hasPassword': true,
        'profileCompleted': true,
        'city': 'Железинка',
        'isDriver': driver,
        'statusDriver': driver ? 'approved' : '',
        'driverRegistrationStatus': driver ? 'approved' : '',
        'roleState': driver ? 'DRIVER_ON_TRIP' : 'PASSENGER',
        'preferredClientMode': driver ? 'driver' : 'passenger',
        'coords': {'latitude': 53.538, 'longitude': 75.313},
        driver ? 'activeDriverOrderId' : 'activePassengerOrderId': 'completion',
      };
      Map<String, dynamic> order() => {
            'id': 'completion',
            'orderDocPath': 'order/completion',
            'passengerId': 'completion-passenger',
            'driverId': 'completion-driver',
            'status': complete ? 5 : 4,
            'price': 700,
            'paymentMode': 'cash',
            'cashToDriver': 700,
            'passengerWalletUsed': 0,
            'passengerBonusUsed': 0,
            'ot': 'Посадка',
            'kuda': 'Назначение',
            'fromPoint': {'latitude': 53.538, 'longitude': 75.313},
            'toPoint': {'latitude': 53.54, 'longitude': 75.315},
            'customerName': 'Пассажир',
            'driverName': 'Водитель',
          };
      SharedPreferences.setMockInitialValues({
        mtaxiBackendAccessTokenPrefsKey: 'test-only-token',
        'ff_soundEnabled': false,
      });
      FFAppState.reset();
      await FFAppState().initializePersistedState();
      UserModeResolver.clearTransientRoleState();
      activateBackendUser(user);
      final ref = BackendRefs.instance.doc('order/completion');
      FFAppState().syncLegacyOrderRefs(
          passengerOrderRef: driver ? null : ref,
          driverOrderRef: driver ? ref : null);
      final router = GoRouter(initialLocation: '/trip', routes: [
        GoRoute(
            path: '/trip',
            builder: (_, __) => driver
                ? const HomeDriverOrderWidget(orderDocPath: 'order/completion')
                : const SeachDriverWidget(orderDocPath: 'order/completion')),
        GoRoute(
            name: 'homeDriver',
            path: '/driver-home',
            builder: (_, __) => const Scaffold(body: Text('Главная водителя'))),
        GoRoute(
            name: 'HomePage',
            path: '/passenger-home',
            builder: (_, __) =>
                const Scaffold(body: Text('Главная пассажира'))),
      ]);
      final calls = <String>[];
      await http.runWithClient(() async {
        await tester.pumpWidget(ChangeNotifierProvider<FFAppState>.value(
            value: FFAppState(),
            child: MaterialApp.router(
                routerConfig: router,
                theme: MTaxiDesign.theme(Brightness.light),
                locale: const Locale('ru'),
                supportedLocales: const [
                  Locale('ru'),
                  Locale('kk')
                ],
                localizationsDelegates: const [
                  FFLocalizationsDelegate(),
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate
                ])));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
        }
        complete = true;
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
        }
        expect(find.text('Поездка завершена'), findsOneWidget);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
        }
        expect(find.text('Поездка завершена'), findsOneWidget,
            reason: 'Background status polling must not dismiss the receipt');
        await tester.tap(find.text(driver ? 'К заказам' : 'Позже'));
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
        }
        expect(find.text(driver ? 'Главная водителя' : 'Главная пассажира'),
            findsOneWidget);
        expect(
            calls.where((c) =>
                c == 'advanceDriverOrderStatus' || c == 'cancelPassengerOrder'),
            isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 10));
      },
          () => MockClient((request) async {
                if (request.url.host.contains('openstreetmap'))
                  return http.Response.bytes(
                      base64Decode(
                          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGN4+/EFAAWVAscBqbtSAAAAAElFTkSuQmCC'),
                      200,
                      headers: {'content-type': 'image/png'});
                final name = request.url.pathSegments.last;
                calls.add(name);
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'user': user,
                      'order': order(),
                      'activeDriverOrderRef':
                          driver && !complete ? 'order/completion' : null,
                      'activePassengerOrderRef':
                          !driver && !complete ? 'order/completion' : null,
                      'settings': {},
                      'driverBonus': {'enabled': false, 'balance': 0},
                      'status': complete ? 5 : 4,
                      'driver': {},
                      'from': order()['fromPoint'],
                      'to': order()['toPoint'],
                      'coordinates': [],
                      'offers': [],
                      'orders': [],
                    }),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8'
                    });
              }));
      router.dispose();
      activateBackendUser(null);
      UserModeResolver.clearTransientRoleState();
    });
  }
}
