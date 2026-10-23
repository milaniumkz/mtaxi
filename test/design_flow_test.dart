import 'package:mtaxi/backend/backend_session.dart';
import 'package:mtaxi/auth/backend_auth/backend_user_provider.dart';
import 'package:mtaxi/passenger/me_order/me_order_widget.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtaxi/app_state.dart';
import 'package:mtaxi/auth/login/login_widget.dart';
import 'package:mtaxi/component/select_balance/select_balance_widget.dart';
import 'package:mtaxi/custom_code/widgets/delivery_taxi_map.dart';
import 'package:mtaxi/design/bonus_progress.dart';
import 'package:mtaxi/design/bottom_navigation.dart';
import 'package:mtaxi/design/fare_composer.dart';
import 'package:mtaxi/design/mtaxi_theme.dart';
import 'package:mtaxi/design/offer_card.dart';
import 'package:mtaxi/design/trip_panel.dart';
import 'package:mtaxi/flutter_flow/internationalization.dart';
import 'package:mtaxi/trips/passenger_wallet.dart';
import 'package:mtaxi/trips/wallet_page.dart';
import 'package:mtaxi/trips/trip_receipt.dart';
import 'package:mtaxi/driver/set_profile_driver/set_profile_driver_widget.dart';

Widget wrap(Widget child, {double scale = 1, String locale = 'ru'}) =>
    ChangeNotifierProvider<FFAppState>.value(
        value: FFAppState(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MTaxiDesign.theme(Brightness.light),
          locale: Locale(locale),
          supportedLocales: const [Locale('ru'), Locale('kk')],
          localizationsDelegates: const [
            FFLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate
          ],
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: child,
        ));
const order = <String, dynamic>{
  'ot': 'Железинка, улица Абая, 14',
  'kuda': 'Центральная районная больница',
  'price': 1200,
  'driverName': 'Арман',
  'driverCar': 'Toyota Camry',
  'driverPlate': '123 ABC 14',
  'customerName': 'Марина',
  'cashToDriver': 700,
  'passengerWalletUsed': 300,
  'passengerBonusUsed': 200,
  'paymentMode': 'cash'
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Noto Sans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    await loader.load();
    PackageInfo.setMockInitialValues(
        appName: 'MTaxi',
        packageName: 'test.mtaxi',
        version: '1',
        buildNumber: '1',
        buildSignature: '');
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('login and registration stay scrollable at 320 and 200% text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrap(const LoginWidget(), scale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Создать аккаунт'));
    await tester.tap(find.text('Создать аккаунт'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login-repeat-password')), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'fare rejects below minimum and returns editable price with payment selection',
      (tester) async {
    FareChoice? result;
    await tester.pumpWidget(wrap(Scaffold(
        body: Builder(
            builder: (context) => FilledButton(
                onPressed: () async {
                  result = await showModalBottomSheet<FareChoice>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const FareComposer(
                          user: {'balance': 5000},
                          bonus: {'balance': 200, 'maxSpendPercent': 100}));
                },
                child: const Text('Открыть'))))));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('fare-price')), '499');
    await tester.ensureVisible(find.byKey(const ValueKey('fare-submit')));
    await tester.tap(find.byKey(const ValueKey('fare-submit')));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.textContaining('Целая цена'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('fare-price')), '1700');
    await tester.ensureVisible(find.text('Со счёта приложения'));
    await tester.tap(find.text('Со счёта приложения'));
    await tester.ensureVisible(find.text('Использовать бонусы'));
    await tester.tap(find.text('Использовать бонусы'));
    await tester.ensureVisible(find.byKey(const ValueKey('fare-submit')));
    await tester.tap(find.byKey(const ValueKey('fare-submit')));
    await tester.pumpAndSettle();
    expect(result?.price, 1700);
    expect(result?.wallet, isTrue);
    expect(result?.bonuses, isTrue);
  });

  testWidgets(
      'started trips never expose cancellation; driver action waits when busy',
      (tester) async {
    var actions = 0;
    await tester.pumpWidget(wrap(Scaffold(
        body: SingleChildScrollView(
            child: TripPanel(
                order: order,
                status: 4,
                driver: false,
                contacts: const SizedBox(),
                onCancel: () => actions++)))));
    expect(find.text('Отменить заказ'), findsNothing);
    expect(
        find.text('После начала поездки отмена недоступна.'), findsOneWidget);
    await tester.pumpWidget(wrap(Scaffold(
        body: SingleChildScrollView(
            child: TripPanel(
                order: order,
                status: 4,
                driver: true,
                contacts: const SizedBox(),
                busy: true,
                onAdvance: () => actions++)))));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(actions, 0);
    expect(find.text('На денежный счёт'), findsOneWidget);
  });

  testWidgets('expired offer cannot be accepted', (tester) async {
    await tester.pumpWidget(wrap(Scaffold(
        body: SingleChildScrollView(
            child: DriverOfferCard(offer: {
      'driverName': 'Арман',
      'price': 1700,
      'expiresAt': '2000-01-01T00:00:00Z'
    }, onAccept: () => fail('Expired offer accepted'))))));
    expect(find.text('Предложение истекло'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(find.text('Пока нет оценок'), findsOneWidget);
  });

  testWidgets(
      'disabled campaign retains real bonus balance without progress reward',
      (tester) async {
    await tester.pumpWidget(wrap(const Scaffold(
        body: SingleChildScrollView(
            child: BonusProgress(detailed: true, data: {
      'balance': 1500,
      'enabled': false,
      'targetOrders': 10,
      'reward': 1000,
      'completedOrders': 3
    })))));
    expect(find.text('Акция отключена'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Награда:'), findsNothing);
    expect(
        find.textContaining('Накопленные бонусы сохраняются'), findsOneWidget);
  });

  for (final driver in [false, true]) {
    testWidgets(
        'four tabs fit 320 at 200% (${driver ? 'driver' : 'passenger'})',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = -1;
      await tester.pumpWidget(wrap(
          Scaffold(
              bottomNavigationBar: MTaxiBottomNavigation(
                  index: 0,
                  driver: driver,
                  onTap: (index) => selected = index)),
          scale: 2,
          locale: 'kk'));
      expect(find.byType(InkWell), findsNWidgets(4));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Тарих'));
      expect(selected, 2);
    });
  }

  testWidgets(
      'manual pickup survives denied/unavailable GPS with no fake user marker',
      (tester) async {
    await tester.pumpWidget(wrap(const Scaffold(
        body: DeliveryTaxiMap(
            enableAutoLocation: false,
            enableTileLayer: false,
            enableRemoteGeocoding: false))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Указать место посадки'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.byIcon(Icons.my_location), findsNothing);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offer expires while its sheet stays open', (tester) async {
    await tester.pumpWidget(wrap(Scaffold(
        body: SingleChildScrollView(
            child: DriverOfferCard(offer: {
      'driverName': 'Арман',
      'price': 1700,
      'expiresAt':
          DateTime.now().add(const Duration(seconds: 1)).toIso8601String()
    }, onAccept: () {})))));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
  });

  testWidgets(
      'history separates passenger and driver trips for the same account',
      (tester) async {
    activateBackendUser({'id': 'dual-role-fixture'});
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap(const MeOrderWidget(driver: true)));
      await tester.pumpAndSettle();
      expect(find.text('Посадка водителя'), findsOneWidget);
      expect(find.text('Посадка пассажира'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(wrap(const MeOrderWidget(driver: false)));
      await tester.pumpAndSettle();
      expect(find.text('Посадка пассажира'), findsOneWidget);
      expect(find.text('Посадка водителя'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async => http.Response(
            jsonEncode({
              'success': true,
              'orders': [
                {
                  'driverId': 'dual-role-fixture',
                  'passengerId': 'other',
                  'ot': 'Посадка водителя',
                  'kuda': 'Назначение',
                  'price': 500,
                  'status': 5
                },
                {
                  'driverId': 'other',
                  'passengerId': 'dual-role-fixture',
                  'ot': 'Посадка пассажира',
                  'kuda': 'Назначение',
                  'price': 500,
                  'status': 5
                },
              ]
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
    activateBackendUser(null);
  });

  testWidgets(
      'driver registration restores a scoped draft without persisting passwords',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (_) async => 1);
    final user = {
      'id': 'draft-test',
      'phone': '+77019990011',
      'hasPassword': true,
      'roleState': 'PASSENGER',
      'profileCompleted': false,
      'isDriver': false
    };
    SharedPreferences.setMockInitialValues({
      mtaxiBackendAccessTokenPrefsKey: 'test-only-token',
      'mtaxi_driver_registration_draft_draft-test': jsonEncode({
        'name': 'Черновик Водителя',
        'plate': '123 ABC 14',
        'color': 'Белый',
        'city': 'Железинка',
        'birthDate': '2000-01-01',
        'step': 1,
        'avtoImage': '',
        'techImage': '',
        'password': 'must-not-be-resaved',
      }),
    });
    activateBackendUser(user);
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap(const SetProfileDriverWidget()));
      await tester.pumpAndSettle();
      expect(find.text('Шаг 2 из 2'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Черновик Водителя'), findsOneWidget);
      await tester.ensureVisible(find.text('Продолжить'));
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(
          prefs.getString('mtaxi_driver_registration_draft_draft-test')!);
      expect(saved['name'], 'Черновик Водителя');
      expect(saved.containsKey('password'), isFalse);
      await tester.pumpWidget(const SizedBox());
      activateBackendUser({...user, 'id': 'another-draft-user'});
      await tester.pumpWidget(wrap(const SetProfileDriverWidget()));
      await tester.pumpAndSettle();
      expect(find.text('Шаг 1 из 2'), findsOneWidget);
      expect(find.text('Черновик Водителя'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((_) async => http.Response(
            jsonEncode({
              'success': true,
              'user': user,
              'tariffs': [
                {'title': 'Железинка'}
              ],
              'cities': ['Железинка'],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
    activateBackendUser(null);
  });

  testWidgets('wallet refreshes when revisited and supports explicit refresh',
      (tester) async {
    var balance = 500;
    var active = true;
    late StateSetter update;
    final calls = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap(StatefulBuilder(builder: (_, setState) {
        update = setState;
        return MTaxiTabActivity(active: active, child: const WalletPage());
      })));
      await tester.pumpAndSettle();
      expect(find.text('500 ₸'), findsOneWidget);
      update(() => active = false);
      await tester.pump();
      balance = 1500;
      update(() => active = true);
      await tester.pumpAndSettle();
      expect(find.text('1 500 ₸'), findsOneWidget);
      balance = 2500;
      await tester.tap(find.byTooltip('Обновить баланс'));
      await tester.pumpAndSettle();
      expect(find.text('2 500 ₸'), findsOneWidget);
      expect(calls.every((name) => name == 'getSessionBootstrap'), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              calls.add(request.url.pathSegments.last);
              return http.Response(
                  jsonEncode({
                    'success': true,
                    'user': {'balance': balance},
                    'passengerBonus': {
                      'balance': 14,
                      'percent': 2,
                      'maxSpendPercent': 100
                    }
                  }),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });

  testWidgets('history retry recovers from a failed response', (tester) async {
    var ready = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap(const MeOrderWidget(driver: false)));
      await tester.pumpAndSettle();
      expect(find.text('Повторить'), findsOneWidget);
      ready = true;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Здесь пока нет поездок'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((_) async => http.Response(
            jsonEncode({'success': ready, 'orders': []}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });

  testWidgets('receipt retry only reloads the confirmed receipt',
      (tester) async {
    var ready = false;
    final calls = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap(Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => showTripReceipt(context, 'order/retry'),
                  child: const Text('Итог'))))));
      await tester.tap(find.text('Итог'));
      await tester.pumpAndSettle();
      expect(find.text('Итог пока недоступен'), findsOneWidget);
      ready = true;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Спасибо за поездку!'), findsOneWidget);
      expect(calls.every((name) => name == 'getOrderDetails'), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              calls.add(request.url.pathSegments.last);
              return http.Response(
                  jsonEncode({
                    'success': ready,
                    'order': {...order, 'status': 5}
                  }),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });

  testWidgets('wallet failure never masquerades as zero balance',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap(const WalletPage()));
      await tester.pumpAndSettle();
      expect(find.text('Счёт недоступен'), findsOneWidget);
      expect(find.text('0 ₸'), findsNothing);
      expect(find.text('Повторить'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient(
            (_) async => throw http.ClientException('offline fixture')));
  });

  testWidgets('Kaspi retry reuses payment key and pending is not credited',
      (tester) async {
    final keys = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(
          wrap(const Scaffold(body: SelectBalanceWidget(passenger: true))));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '+77019990011');
      await tester.enterText(find.byType(TextField).at(1), '1000');
      await tester.tap(find.text('Запросить счёт Kaspi'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
          wrap(const Scaffold(body: SelectBalanceWidget(passenger: true))));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextField>(find.byType(TextField).at(1))
              .controller!
              .text,
          '1000');
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).enabled,
          isFalse);
      await tester.tap(find.text('Повторить проверку заявки'));
      await tester.pumpAndSettle();
      expect(keys, hasLength(2));
      expect(keys[0], keys[1]);
      expect(find.textContaining('Заявка отправлена.'), findsOneWidget);
      expect(find.textContaining('Деньги зачислены'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('createPassengerTopUpPayment')) {
                keys.add((jsonDecode(request.body) as Map)['idempotencyKey']
                    as String);
                if (keys.length == 1)
                  throw http.ClientException('response lost fixture');
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'paymentId': 'test-payment',
                      'paymentStatus': 'pending'
                    }),
                    200);
              }
              return http.Response('{"success":true}', 200);
            }));
  });
}
