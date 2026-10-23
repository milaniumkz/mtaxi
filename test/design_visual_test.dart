// Visual fixtures only: all HTTP, GPS and balances are synthetic and isolated.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart' as geo;
import 'package:mtaxi/app_state.dart';
import 'package:mtaxi/auth/backend_auth/backend_user_provider.dart';
import 'package:mtaxi/auth/login/login_widget.dart';
import 'package:mtaxi/backend/backend.dart' show BackendRefs;
import 'package:mtaxi/backend/backend_session.dart';
import 'package:mtaxi/component/select_balance/select_balance_widget.dart';
import 'package:mtaxi/component/set_role/set_role_widget.dart';
import 'package:mtaxi/custom_code/widgets/delivery_taxi_map.dart';
import 'package:mtaxi/design/bottom_navigation.dart';
import 'package:mtaxi/design/driver_approval.dart';
import 'package:mtaxi/design/fare_composer.dart';
import 'package:mtaxi/design/order_preview.dart';
import 'package:mtaxi/driver/home_driver/driver_bonus_card.dart';
import 'package:mtaxi/driver/home_driver/home_driver_widget.dart';
import 'package:mtaxi/driver/home_driver_order/home_driver_order_widget.dart';
import 'package:mtaxi/driver/set_profile_driver/set_profile_driver_widget.dart';
import 'package:mtaxi/passenger/me_order/me_order_widget.dart';
import 'package:mtaxi/passenger/profile/profile_widget.dart';
import 'package:mtaxi/passenger/seach_driver/seach_driver_widget.dart';
import 'package:mtaxi/passenger/support_chat/support_chat_widget.dart';
import 'package:mtaxi/trips/trip_receipt.dart';
import 'package:mtaxi/trips/wallet_page.dart';
import 'design_flow_test.dart' show wrap, order;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Noto Sans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    await fonts.load();
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
  const adaptive = bool.fromEnvironment('MTAXI_ADAPTIVE_REVIEW');
  final variants = adaptive
      ? [(320.0, 1.3, 'ru'), (360.0, 2.0, 'kk'), (430.0, 2.0, 'ru')]
      : [(390.0, 1.0, 'ru')];
  for (final (width, scale, locale) in variants) {
    for (var id = 1; id <= 32; id++) {
      testWidgets(
          'visual ${id.toString().padLeft(2, '0')} at ${width}x844 scale $scale $locale',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/permissions/methods'),
            (_) async => 1);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/geolocator'),
            (call) async => call.method == 'isLocationServiceEnabled'
                ? true
                : call.method == 'checkPermission'
                    ? 3
                    : {
                        'latitude': 53.538,
                        'longitude': 75.313,
                        'accuracy': 10.0,
                        'altitude': 0.0,
                        'heading': 0.0,
                        'speed': 0.0,
                        'speed_accuracy': 0.0,
                        'timestamp': DateTime.now().millisecondsSinceEpoch
                      });
        final driver = id >= 23 && id <= 31;
        final status = switch (id) {
          9 || 26 => 2,
          10 || 27 => 3,
          11 || 28 => 4,
          12 || 29 => 5,
          _ => 0
        };
        final active = [7, 8, 9, 10, 11, 26, 27, 28].contains(id);
        final user = <String, dynamic>{
          'id': driver ? 'driver-fixture' : 'passenger-fixture',
          'displayName': driver ? 'Арман' : 'Марина',
          'phone': '+77019990011',
          'balance': 2850,
          'bonusBalance': 1000,
          'passengerBonusBalance': 350,
          'hasPassword': true,
          'profileCompleted': true,
          'city': 'Железинка',
          'isDriver': driver,
          'statusDriver': driver ? 'approved' : '',
          'driverRegistrationStatus': driver ? 'approved' : '',
          'roleState': driver
              ? active
                  ? 'DRIVER_ON_TRIP'
                  : 'DRIVER_ONLINE'
              : 'PASSENGER',
          'preferredClientMode': driver ? 'driver' : 'passenger',
          'coords': {'latitude': 53.538, 'longitude': 75.313},
          'gosNomer': '123ABC14',
          'color': 'Белый',
          if (active)
            driver ? 'activeDriverOrderId' : 'activePassengerOrderId':
                'visual-order'
        };
        final fixture = <String, dynamic>{
          ...order,
          'id': 'visual-order',
          'orderDocPath': 'order/visual-order',
          'status': status,
          'type': 'taxi',
          'createdAt': id == 24
              ? DateTime.now()
                  .subtract(const Duration(seconds: 30))
                  .toIso8601String()
              : '2026-10-23T12:00:00Z',
          'passengerId': 'passenger-fixture',
          'driverId': status > 0 ? 'driver-fixture' : '',
          'driverPhone': '+77019990022',
          'customerPhone': '+77019990011',
          'fromPoint': {'lat': 53.538, 'lng': 75.313},
          'toPoint': {'lat': 53.542, 'lng': 75.318}
        };
        final bonus = {
          'balance': 1000,
          'enabled': true,
          'completedOrders': 8,
          'targetOrders': 10,
          'reward': 1000,
          'awarded': false
        };
        SharedPreferences.setMockInitialValues({
          mtaxiBackendAccessTokenPrefsKey: 'visual-fixture-token',
          'ff_soundEnabled': false
        });
        FFAppState.reset();
        await FFAppState().initializePersistedState();
        activateBackendUser(user);
        if (active)
          FFAppState().syncLegacyOrderRefs(
              passengerOrderRef: driver
                  ? null
                  : BackendRefs.instance.doc('order/visual-order'),
              driverOrderRef: driver
                  ? BackendRefs.instance.doc('order/visual-order')
                  : null);
        await http.runWithClient(() async {
          Widget page;
          if (id <= 2) {
            page = const LoginWidget();
          } else if (id <= 5) {
            page = const Scaffold(
                body: DeliveryTaxiMap(
                    enableAutoLocation: false,
                    enableRemoteGeocoding: false,
                    enableTileLayer: false,
                    initialFromAddress: 'Железинка, улица Абая, 14',
                    initialFromCoords: geo.LatLng(53.538, 75.313)));
          } else if (id == 6) {
            page = const Scaffold(
                body: FareComposer(
                    user: {'balance': 2850},
                    bonus: {'balance': 350, 'maxSpendPercent': 100},
                    from: 'Железинка, улица Абая, 14',
                    to: 'Центральная районная больница'));
          } else if (id == 7 || id == 8 || (id >= 9 && id <= 11)) {
            page = const SeachDriverWidget(orderDocPath: 'order/visual-order');
          } else if (id == 12 || id == 29) {
            page = Scaffold(
                body: Builder(
                    builder: (context) => FilledButton(
                        onPressed: () => showTripReceipt(
                            context, 'order/visual-order',
                            driver: driver),
                        child: const Text('Итог'))));
          } else if (id == 13 || id == 30) {
            page = WalletPage(driver: driver);
          } else if (id == 14) {
            page = const Scaffold(body: SelectBalanceWidget(passenger: true));
          } else if (id == 15) {
            page = const PassengerBonusPage(
                bonus: {'balance': 350, 'percent': 2, 'maxSpendPercent': 100});
          } else if (id == 16 || id == 17) {
            page = const MeOrderWidget();
          } else if (id == 18) {
            page = const SupportChatWidget();
          } else if (id == 19) {
            page = const ProfileWidget();
          } else if (id == 20 || id == 21) {
            page = const SetProfileDriverWidget();
          } else if (id == 22) {
            page = DriverApproval(onProfile: () {}, onSupport: () {});
          } else if (id == 23 || id == 24) {
            page = const HomeDriverWidget();
          } else if (id == 25) {
            page = Scaffold(
                body: OrderPreview(
                    order: fixture, onAccept: () {}, onOffer: () {}));
          } else if (id >= 26 && id <= 28) {
            page =
                const HomeDriverOrderWidget(orderDocPath: 'order/visual-order');
          } else if (id == 31) {
            page = const Scaffold(
                body: SingleChildScrollView(
                    padding: EdgeInsets.all(22),
                    child: DriverBonusCard(detailed: true)));
          } else {
            page = const SetRoleWidget();
          }
          // The same production navigation; no demo app is shipped.
          if ([3, 7, 8, 9, 10, 11, 13, 16, 19, 23, 24, 26, 27, 28, 30]
              .contains(id))
            page = Scaffold(
                body: page,
                bottomNavigationBar: MTaxiBottomNavigation(
                    index: [13, 30].contains(id)
                        ? 1
                        : id == 16
                            ? 2
                            : id == 19
                                ? 3
                                : 0,
                    driver: driver,
                    onTap: (_) {}));
          await tester.pumpWidget(wrap(
              RepaintBoundary(
                  key: const ValueKey('visual-screen'), child: page),
              scale: scale,
              locale: locale));
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          if (id == 2) {
            await tester.ensureVisible(
                find.text(locale == 'kk' ? 'Аккаунт құру' : 'Создать аккаунт'));
            await tester.tap(
                find.text(locale == 'kk' ? 'Аккаунт құру' : 'Создать аккаунт'));
          }
          if (id == 4 || id == 5) {
            await tester.tap(find
                .text(id == 5
                    ? 'Железинка, улица Абая, 14'
                    : locale == 'kk'
                        ? 'Қайда барамыз?'
                        : 'Куда едем?')
                .last);
          }
          if (id == 12 || id == 29) {
            await tester.tap(find.text('Итог'));
          }
          if (id == 17) {
            await tester.tap(find.text('Железинка, улица Абая, 14').first);
          }
          if (id == 21) {
            await tester.ensureVisible(
                find.text(locale == 'kk' ? 'Жалғастыру' : 'Продолжить'));
            await tester
                .tap(find.text(locale == 'kk' ? 'Жалғастыру' : 'Продолжить'));
          }
          if (id == 24) {
            await tester.ensureVisible(find.text(
                locale == 'kk' ? 'Тапсырыстарды қарау' : 'Смотреть заказы'));
            await tester.tap(find.text(
                locale == 'kk' ? 'Тапсырыстарды қарау' : 'Смотреть заказы'));
          }
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(tester.takeException(), isNull);
          if ([26, 27, 28].contains(id))
            expect(
                find
                    .text(id == 26
                        ? (locale == 'kk' ? 'Мен келдім' : 'Я на месте')
                        : id == 27
                            ? (locale == 'kk'
                                ? 'Сапарды бастау'
                                : 'Начать поездку')
                            : (locale == 'kk'
                                ? 'Сапарды аяқтау'
                                : 'Завершить поездку'))
                    .hitTestable(),
                findsOneWidget);

          if (!adaptive)
            await expectLater(
                find.byType(MaterialApp),
                matchesGoldenFile(
                    'goldens/${id.toString().padLeft(2, '0')}.png'));
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 10));
        },
            () => MockClient((request) async {
                  if (request.url.host == 'tile.openstreetmap.org')
                    return http.Response.bytes(
                        base64Decode(
                            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGN4+/EFAAWVAscBqbtSAAAAAElFTkSuQmCC'),
                        200,
                        headers: {'content-type': 'image/png'});
                  final name = request.url.pathSegments.last;
                  final result = switch (name) {
                    'getSessionBootstrap' => {
                        'success': true,
                        'user': user,
                        'driverBonus': bonus,
                        'passengerBonus': {
                          'balance': 350,
                          'percent': 2,
                          'maxSpendPercent': 100
                        },
                        if (active)
                          driver
                              ? 'activeDriverOrderRef'
                              : 'activePassengerOrderRef': 'order/visual-order'
                      },
                    'getOrderDetails' => {'success': true, 'order': fixture},
                    'listAvailableDriverOrders' || 'listMyOrders' => {
                        'success': true,
                        'orders': [fixture]
                      },
                    'listOrderOffers' => {
                        'success': true,
                        'offers': id == 8
                            ? [
                                {
                                  'id': 'offer-fixture',
                                  'driverName': 'Арман',
                                  'price': 1200,
                                  'etaMinutes': 4,
                                  'rating': 4.9,
                                  'ratingCount': 248,
                                  'completedTrips': 248,
                                  'driverCar': 'Toyota Camry',
                                  'driverPlate': '123 ABC 14',
                                  'expiresAt': '2030-01-01T00:00:00Z'
                                }
                              ]
                            : []
                      },
                    'getTripTracking' => {
                        'success': true,
                        'status': status,
                        'from': fixture['fromPoint'],
                        'to': fixture['toPoint'],
                        'driverPosition': fixture['fromPoint']
                      },
                    'routeLookup' => {
                        'success': true,
                        'coordinates': [
                          [75.313, 53.538],
                          [75.318, 53.542]
                        ],
                        'durationSeconds': 240,
                        'steps': []
                      },
                    'listCityTariffs' => {
                        'success': true,
                        'tariffs': [
                          {'title': 'Железинка', 'priceCity': 500}
                        ]
                      },
                    'getSupportChatMessages' => {
                        'success': true,
                        'messages': [
                          {
                            'id': 'support-message-1',
                            'chatPath': 'chats/support-fixture',
                            'userId': 'admin-fixture',
                            'text': 'Здравствуйте! Чем можем помочь?',
                            'createdAt': '2026-10-23T12:00:00Z'
                          },
                          {
                            'id': 'support-message-2',
                            'chatPath': 'chats/support-fixture',
                            'userId': 'passenger-fixture',
                            'text': 'Подскажите, как пополнить счёт?',
                            'createdAt': '2026-10-23T12:01:00Z'
                          },
                        ]
                      },
                    'ensureSupportChat' || 'getMySupportChat' => {
                        'success': true,
                        'chatPath': 'chats/support-fixture',
                        'chat': {
                          'id': 'support-fixture',
                          'chatPath': 'chats/support-fixture',
                          'userId': 'passenger-fixture'
                        },
                        'supportChatKey': 'support-fixture'
                      },
                    _ => {
                        'success': true,
                        'user': user,
                        'messages': [],
                        'chats': [],
                        'settings': {}
                      },
                  };
                  return http.Response(jsonEncode(result), 200,
                      headers: {'content-type': 'application/json'});
                }));
      });
    }
  }
}
