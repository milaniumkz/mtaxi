import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:mtaxi/app_state.dart';
import 'package:mtaxi/auth/backend_auth/backend_user_provider.dart';
import 'package:mtaxi/backend/backend_session.dart';
import 'package:mtaxi/main.dart';
import 'package:mtaxi/passenger/profile/profile_widget.dart';
import 'package:mtaxi/passenger/me_order/me_order_widget.dart';
import 'package:mtaxi/trips/wallet_page.dart';
import 'design_flow_test.dart' show wrap;

void main() {
  for (final driver in [true, false])
    for (final tab in ['wallet', 'history', 'profile']) {
      testWidgets('role $driver preserves deep-linked $tab tab',
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
          'id': 'audit-tab',
          'phone': '+70010000001',
          'displayName': 'Synthetic tab',
          'city': 'Железинка',
          'roleState': driver ? 'DRIVER_ONLINE' : 'PASSENGER',
          'preferredClientMode': driver ? 'driver' : 'passenger',
          'isDriver': driver,
          'statusDriver': driver ? 'approved' : '',
          'profileCompleted': true,
          'hasPassword': true,
          'balance': 1000
        };
        activateBackendUser(user);
        final initial = driver
            ? tab
            : {
                'profile': 'driverProfile',
                'wallet': 'driverWallet',
                'history': 'driverHistory'
              }[tab]!;
        await http.runWithClient(() async {
          final router = GoRouter(initialLocation: '/probe', routes: [
            GoRoute(
                path: '/probe',
                builder: (_, __) => NavBarPage(initialPage: initial))
          ]);
          addTearDown(router.dispose);
          await tester.pumpWidget(wrap(Builder(
              builder: (context) => Router.withConfig(config: router))));
          for (var i = 0; i < 8; i++)
            await tester.pump(const Duration(milliseconds: 100));
          expect(
              find.byType(tab == 'profile'
                  ? ProfileWidget
                  : tab == 'wallet'
                      ? WalletPage
                      : MeOrderWidget),
              findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 9));
        },
            () => MockClient((_) async => http.Response(
                jsonEncode({
                  'success': true,
                  'user': user,
                  'orders': [],
                  'settings': {},
                  'driverBonus': {'enabled': false},
                  'passengerBonus': {'balance': 0}
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'})));
      });
    }
}
