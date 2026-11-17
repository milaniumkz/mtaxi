import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mtaxi/flutter_flow/internationalization.dart';
import 'package:mtaxi/backend/backend_session.dart';
import 'package:mtaxi/design/offer_card.dart';
import 'package:mtaxi/trips/order_offers.dart';

void main() {
  for (var pass = 0; pass < 30; pass++) {
    testWidgets('stale offer response cannot cross into next order, pass $pass',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {mtaxiBackendAccessTokenPrefsKey: 'synthetic-token'});
      PackageInfo.setMockInitialValues(
          appName: 'MTaxi',
          packageName: 'audit',
          version: '1',
          buildNumber: '1',
          buildSignature: '');
      final old = Completer<http.Response>();
      final path = ValueNotifier<String>('order/old');
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
            localizationsDelegates: const [
              FFLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate
            ],
            supportedLocales: const [
              Locale('ru'),
              Locale('kk')
            ],
            locale: const Locale('ru'),
            home: Scaffold(
                body: ValueListenableBuilder<String>(
                    valueListenable: path,
                    builder: (_, value, __) =>
                        PassengerOffers(orderDocPath: value)))));
        await tester.pump(const Duration(milliseconds: 50));
        path.value = 'order/new';
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('New driver'), findsOneWidget);
        old.complete(http.Response(
            jsonEncode({
              'success': true,
              'offers': [
                {'id': 'old', 'driverName': 'Old driver', 'price': 700}
              ]
            }),
            200));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('New driver'), findsOneWidget);
        expect(find.text('Old driver'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
          () => MockClient((req) async {
                final body = jsonDecode(req.body) as Map;
                if (body['orderDocPath'] == 'order/old') return old.future;
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'offers': [
                        {'id': 'new', 'driverName': 'New driver', 'price': 800}
                      ]
                    }),
                    200);
              }));
      path.dispose();
    });
  }
  for (final secondAccept in [true, false]) {
    testWidgets(
        'rapid offer decisions preserve passenger route, second accept: $secondAccept',
        (tester) async {
      PackageInfo.setMockInitialValues(
          appName: 'MTaxi',
          packageName: 'audit',
          version: '1',
          buildNumber: '1',
          buildSignature: '');
      SharedPreferences.setMockInitialValues(
          {mtaxiBackendAccessTokenPrefsKey: 'synthetic-token'});
      var responses = 0;
      await http.runWithClient(() async {
        final router = GoRouter(initialLocation: '/trip', routes: [
          GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Text('Главная'))),
          GoRoute(
              path: '/trip',
              builder: (_, __) => const Scaffold(
                      body: Column(children: [
                    Text('Экран поездки'),
                    PassengerOffers(orderDocPath: 'order/audit')
                  ])))
        ]);
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(
            routerConfig: router,
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
            ]));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(DriverOfferCard), findsNWidgets(5));
        expect(tester.getSize(find.byType(DriverOfferCard).first).height,
            greaterThanOrEqualTo(90));
        await tester
            .ensureVisible(find.widgetWithText(FilledButton, 'Принять').last);
        await tester.pump();
        expect(find.widgetWithText(FilledButton, 'Принять').last.hitTestable(),
            findsOneWidget);
        final card =
            tester.widget<DriverOfferCard>(find.byType(DriverOfferCard).first);
        card.onAccept!();
        await tester.pump(const Duration(milliseconds: 30));
        if (secondAccept) {
          card.onAccept!();
        } else {
          card.onDecline!();
        }
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(find.text('Экран поездки'), findsOneWidget);
        expect(responses, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
          () => MockClient((request) async {
                final name = request.url.pathSegments.last;
                if (name == 'respondOrderOffer') responses++;
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'offers': responses > 0
                          ? []
                          : [
                              for (var n = 0; n < 5; n++)
                                {
                                  'id': 'audit-offer-$n',
                                  'driverName': 'Synthetic $n',
                                  'price': 700,
                                  'expiresAt': DateTime.now()
                                      .add(const Duration(minutes: 1))
                                      .toIso8601String()
                                }
                            ]
                    }),
                    200);
              }));
    });
  }
}
