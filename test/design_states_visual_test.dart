// Production error/pending components on isolated, synthetic responses.
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
import 'package:mtaxi/auth/login/login_widget.dart';
import 'package:mtaxi/component/select_balance/select_balance_widget.dart';
import 'package:mtaxi/custom_code/widgets/delivery_taxi_map.dart';
import 'package:mtaxi/design/mtaxi_theme.dart';
import 'package:mtaxi/design/offer_card.dart';
import 'package:mtaxi/trips/order_offers.dart';
import 'package:mtaxi/trips/wallet_page.dart';
import 'design_flow_test.dart' show wrap;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Noto Sans')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    PackageInfo.setMockInitialValues(
        appName: 'MTaxi',
        packageName: 'test.mtaxi',
        version: '1',
        buildNumber: '1',
        buildSignature: '');
  });
  for (var id = 1; id <= 8; id++) {
    testWidgets('state E0$id at 390x844', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/geolocator'),
          (call) async =>
              call.method == 'isLocationServiceEnabled' ? false : 1);
      SharedPreferences.setMockInitialValues({});
      FFAppState.reset();
      await FFAppState().initializePersistedState();
      activateBackendUser(null);
      final offer = {
        'id': 'state-offer',
        'driverName': 'Арман',
        'price': 1500,
        'expiresAt': '2030-01-01T00:00:00Z'
      };
      var retries = 0;
      await http.runWithClient(() async {
        final Widget page = switch (id) {
          1 => const Scaffold(
              body: DeliveryTaxiMap(
                  enableAutoLocation: true,
                  enableTileLayer: false,
                  enableRemoteGeocoding: false)),
          2 || 3 => const Scaffold(
              body: Center(
                  child: Padding(
                      padding: EdgeInsets.all(22),
                      child: PassengerOffers(
                          orderDocPath: 'order/state-fixture')))),
          4 => Scaffold(
              body: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: DriverOfferCard(offer: {
                        ...offer,
                        'expiresAt': '2000-01-01T00:00:00Z'
                      }, onAccept: () => fail('Expired offer accepted'))))),
          5 => const Scaffold(body: SelectBalanceWidget(passenger: true)),
          6 => Scaffold(
              body: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: MTaxiUploadError(
                          message:
                              'Фото не загрузилось. Проверьте интернет и попробуйте ещё раз.',
                          onRetry: () => retries++)))),
          7 => const LoginWidget(),
          _ => const WalletPage(),
        };
        await tester.pumpWidget(wrap(page));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (id == 3) {
          await tester.tap(find.text('Принять предложение'));
        }
        if (id == 5) {
          await tester.enterText(find.byType(TextField).at(0), '+77019990011');
          await tester.enterText(find.byType(TextField).at(1), '1000');
          await tester.tap(find.text('Запросить счёт Kaspi'));
        }
        if (id == 7) {
          await tester.enterText(
              find.byKey(const ValueKey('login-phone')), '+77019990011');
          await tester.enterText(find.byKey(const ValueKey('login-password')),
              'wrong-test-password');
          await tester.ensureVisible(find.text('Войти'));
          await tester.tap(find.text('Войти'));
        }
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (id == 3)
          expect(find.text('Недостаточно средств на счёте'), findsOneWidget);
        if (id == 5) {
          expect(find.textContaining('Заявка отправлена.'), findsOneWidget);
          expect(find.textContaining('Деньги зачислены'), findsNothing);
        }
        if (id == 7)
          expect(find.text('Проверьте номер и пароль'), findsOneWidget);
        if (id == 8) expect(find.text('Счёт недоступен'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
            find.byType(MaterialApp), matchesGoldenFile('goldens/E0$id.png'));
        if (id == 6) {
          await tester.tap(find.text('Повторить загрузку'));
          expect(retries, 1);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 10));
      },
          () => MockClient((request) async {
                final name = request.url.pathSegments.last;
                final response = switch (name) {
                  'listOrderOffers' => {
                      'success': true,
                      'offers': id == 3 ? [offer] : []
                    },
                  'respondOrderOffer' => {
                      'success': false,
                      'code': 'PASSENGER_BALANCE_INSUFFICIENT',
                      'error': 'Недостаточно средств на счёте'
                    },
                  'createPassengerTopUpPayment' => {
                      'success': true,
                      'paymentId': 'state-payment',
                      'paymentStatus': 'pending'
                    },
                  'passwordLogin' => {
                      'success': false,
                      'error': 'Проверьте номер и пароль'
                    },
                  'getSessionBootstrap' => {
                      'success': false,
                      'error': 'Нет соединения'
                    },
                  _ => {'success': true, 'settings': {}},
                };
                return http.Response(jsonEncode(response), 200, headers: {
                  'content-type': 'application/json; charset=utf-8'
                });
              }));
    });
  }
}
