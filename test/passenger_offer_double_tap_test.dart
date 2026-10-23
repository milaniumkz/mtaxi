import 'dart:convert';
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
        final card =
            tester.widget<DriverOfferCard>(find.byType(DriverOfferCard));
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
                              {
                                'id': 'audit-offer',
                                'driverName': 'Synthetic',
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
