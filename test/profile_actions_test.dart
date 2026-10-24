import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtaxi/app_state.dart';
import 'package:mtaxi/auth/backend_auth/auth_util.dart';
import 'package:mtaxi/auth/backend_auth/backend_user_provider.dart';
import 'package:mtaxi/backend/backend_session.dart';
import 'package:mtaxi/design/mtaxi_theme.dart';
import 'package:mtaxi/design/bottom_navigation.dart';
import 'package:mtaxi/flutter_flow/internationalization.dart';
import 'package:mtaxi/passenger/profile/profile_widget.dart';

Widget app(GoRouter router) => ChangeNotifierProvider<FFAppState>.value(
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
        ]));

void main() {
  for (final target in [
    'driver',
    'passenger',
    'logout',
    'approved-after-review'
  ]) {
    testWidgets('profile action $target updates the session before navigating',
        (tester) async {
      PackageInfo.setMockInitialValues(
          appName: 'MTaxi',
          packageName: 'mtaxi',
          version: '1.2.0',
          buildNumber: '58',
          buildSignature: 'test');
      final initiallyDriver = target == 'passenger';
      final user = <String, dynamic>{
        'id': 'profile-actions',
        'displayName': 'Тест',
        'phone': '+77019990011',
        'hasPassword': true,
        'profileCompleted': true,
        'city': 'Железинка',
        'isDriver': true,
        'statusDriver': 'approved',
        'driverRegistrationStatus': 'approved',
        'roleState': initiallyDriver ? 'DRIVER_ONLINE' : 'PASSENGER',
        'preferredClientMode': initiallyDriver ? 'driver' : 'passenger',
        'activeMode': initiallyDriver ? 'driver' : 'passenger',
        'balance': 1000,
      };
      SharedPreferences.setMockInitialValues(
          {mtaxiBackendAccessTokenPrefsKey: 'test-only-token'});
      FFAppState.reset();
      await FFAppState().initializePersistedState();
      UserModeResolver.clearTransientRoleState();
      activateBackendUser(target == 'approved-after-review'
          ? {
              ...user,
              'statusDriver': 'pending_review',
              'driverRegistrationStatus': 'pending_review'
            }
          : user);
      if (target == 'approved-after-review') {
        expect(isDriverRegistrationPendingReview(), isTrue);
      }
      final gate = Completer<Map<String, dynamic>>();
      final activeTab = ValueNotifier(true);
      final router = GoRouter(initialLocation: '/profile', routes: [
        GoRoute(
            path: '/profile',
            builder: (_, __) => ValueListenableBuilder<bool>(
                valueListenable: activeTab,
                builder: (_, active, __) => MTaxiTabActivity(
                    active: active, child: const ProfileWidget()))),
        GoRoute(
            path: '/homeDriver',
            builder: (_, __) => const Scaffold(body: Text('Экран водителя'))),
        GoRoute(
            path: '/homePage',
            builder: (_, __) => const Scaffold(body: Text('Экран пассажира'))),
        GoRoute(
            path: '/login',
            builder: (_, __) => const Scaffold(body: Text('Вход'))),
      ]);
      await http.runWithClient(() async {
        await tester.pumpWidget(app(router));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        if (target == 'approved-after-review') {
          expect(find.text('Анкета на проверке'), findsNothing);
          expect(currentUserDocument?.snapshotData['statusDriver'], 'approved');
          activateBackendUser({
            ...user,
            'statusDriver': 'pending_review',
            'driverRegistrationStatus': 'pending_review'
          });
          activeTab.value = false;
          await tester.pump();
          activeTab.value = true;
          for (var i = 0; i < 3; i++) {
            await tester.pump(const Duration(seconds: 1));
            await tester.pump();
          }
          expect(find.text('Анкета на проверке'), findsNothing);
          expect(currentUserDocument?.snapshotData['statusDriver'], 'approved');
        } else if (target == 'logout') {
          await tester.ensureVisible(find.text('Выйти из аккаунта'));
          await tester.tap(find.text('Выйти из аккаунта'));
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(seconds: 1));
            await tester.pump();
          }
          expect(find.text('Вход'), findsOneWidget);
          expect(await getStoredBackendAccessToken(), isEmpty);
          expect(currentUserDocument, isNull);
        } else {
          await tester.ensureVisible(
              find.text(target == 'driver' ? 'Водитель' : 'Пассажир'));
          await tester
              .tap(find.text(target == 'driver' ? 'Водитель' : 'Пассажир'));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
          expect(router.routeInformationProvider.value.uri.path, '/profile',
              reason: 'A delayed response must not open the wrong role UI');
          gate.complete({
            'success': true,
            'user': {
              ...user,
              'roleState': target == 'driver' ? 'DRIVER_ONLINE' : 'PASSENGER',
              'preferredClientMode': target,
              'activeMode': target
            }
          });
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(seconds: 1));
            await tester.pump();
          }
          expect(
              find.text(
                  target == 'driver' ? 'Экран водителя' : 'Экран пассажира'),
              findsOneWidget);
          expect(
              currentUserDocument?.snapshotData['preferredClientMode'], target);
          expect(UserModeResolver.resolveActiveMode(), target);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 10));
      },
          () => MockClient((request) async {
                final name = request.url.pathSegments.last;
                final result =
                    name == 'updateUserPreferences' && target != 'logout'
                        ? await gate.future
                        : {
                            'success': true,
                            'user': user,
                            'chats': [],
                            'messages': []
                          };
                return http.Response(jsonEncode(result), 200, headers: {
                  'content-type': 'application/json; charset=utf-8'
                });
              }));
      router.dispose();
      activeTab.dispose();
      activateBackendUser(null);
      UserModeResolver.clearTransientRoleState();
    });
  }
}
