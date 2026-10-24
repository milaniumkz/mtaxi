import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtaxi/app_state.dart';
import 'package:mtaxi/auth/backend_auth/backend_user_provider.dart';
import 'package:mtaxi/backend/backend_session.dart';
import 'package:mtaxi/design/mtaxi_theme.dart';
import 'package:mtaxi/driver/home_driver/home_driver_widget.dart';
import 'package:mtaxi/flutter_flow/internationalization.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
        appName: 'MTaxi',
        packageName: 'com.milanium.mtaxi',
        version: '1.2.0',
        buildNumber: '58',
        buildSignature: 'test');
  });
  for (final keepPreviewOpen in [true, false]) {
    testWidgets(
        'passenger accepting an offer opens assigned driver trip, preview open: $keepPreviewOpen',
        (tester) async {
      final user = <String, dynamic>{
        'id': 'offer-driver',
        'displayName': 'Тест',
        'phone': '+77019990011',
        'balance': 5000,
        'coords': {'latitude': 53.538, 'longitude': 75.313},
        'hasPassword': true,
        'profileCompleted': true,
        'city': 'Железинка',
        'isDriver': true,
        'statusDriver': 'approved',
        'driverRegistrationStatus': 'approved',
        'roleState': 'DRIVER_ONLINE',
        'preferredClientMode': 'driver',
      };
      var assigned = false;
      Map<String, dynamic> order() => {
            'id': 'offer-order',
            'orderDocPath': 'order/offer-order',
            'passengerId': 'offer-passenger',
            'driverId': assigned ? 'offer-driver' : '',
            'status': assigned ? 2 : 0,
            'city': 'Железинка',
            'type': 'taxi',
            'ot': 'Улица Абая, 14',
            'kuda': 'Больница',
            'price': assigned ? 700 : 500,
            'createdAt': DateTime.now()
                .subtract(const Duration(minutes: 1))
                .toUtc()
                .toIso8601String(),
          };
      SharedPreferences.setMockInitialValues({
        mtaxiBackendAccessTokenPrefsKey: 'test-only-token',
        'ff_soundEnabled': false,
      });
      FFAppState.reset();
      await FFAppState().initializePersistedState();
      activateBackendUser(user);
      final calls = <String>[];
      final router = GoRouter(initialLocation: '/homeDriver', routes: [
        GoRoute(
            path: '/homeDriver', builder: (_, __) => const HomeDriverWidget()),
        GoRoute(
            name: 'homeDriverOrder',
            path: '/homeDriverOrder',
            builder: (_, state) => Scaffold(
                body: Text(
                    'Назначен ${state.uri.queryParameters['orderDocPath']}'))),
      ]);
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
                  GlobalCupertinoLocalizations.delegate,
                ])));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(find.text('Смотреть заказы'), findsNothing);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        await tester.tap(find.text('Посмотреть'));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Детали заказа'), findsOneWidget);
        if (!keepPreviewOpen) {
          await tester.tap(find.byTooltip('Закрыть'));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text('Детали заказа'), findsNothing);
        }
        assigned = true;
        if (!keepPreviewOpen) {
          await tester.pump(const Duration(seconds: 2));
          await tester.pump();
          // The feed deliberately holds its last non-empty result for 3 real seconds.
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 3200)));
        }
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
        }
        expect(find.text('Назначен order/offer-order'), findsOneWidget);
        expect(calls.where((c) => c == 'acceptOrder'), isEmpty,
            reason:
                'An already accepted offer must not charge commission again');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 10));
      },
          () => MockClient((request) async {
                final name = request.url.pathSegments.last;
                calls.add(name);
                if (request.url.host.contains('openstreetmap')) {
                  return http.Response.bytes(
                      base64Decode(
                          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGN4+/EFAAWVAscBqbtSAAAAAElFTkSuQmCC'),
                      200,
                      headers: {'content-type': 'image/png'});
                }
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'user': user,
                      'order': order(),
                      'orders': assigned ? [] : [order()],
                      'driverBonus': {'enabled': false, 'balance': 0},
                      'settings': {'driverOrderMaxDelaySec': 0},
                    }),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8'
                    });
              }));
      router.dispose();
      activateBackendUser(null);
    });
  }
}
