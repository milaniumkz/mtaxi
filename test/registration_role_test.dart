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
import 'package:mtaxi/auth/login/login_widget.dart';
import 'package:mtaxi/design/mtaxi_theme.dart';
import 'package:mtaxi/flutter_flow/internationalization.dart';

void main() {
  for (final role in ['passenger', 'driver', 'missing']) {
    testWidgets(
        'signup routes explicit $role choice without silently defaulting',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      FFAppState.reset();
      await FFAppState().initializePersistedState();
      PackageInfo.setMockInitialValues(
          appName: 'MTaxi',
          packageName: 'test.mtaxi',
          version: '1',
          buildNumber: '1',
          buildSignature: '');
      var registrations = 0;
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const LoginWidget()),
        GoRoute(
            path: '/passenger-form',
            name: 'setProfile',
            builder: (_, __) => const Scaffold(body: Text('passenger form'))),
        GoRoute(
            path: '/driver-form',
            name: 'setProfileDriver',
            builder: (_, __) => const Scaffold(body: Text('driver form'))),
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
                  GlobalCupertinoLocalizations.delegate
                ])));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Создать аккаунт'));
        await tester.tap(find.text('Создать аккаунт'));
        await tester.pumpAndSettle();
        final passenger =
            find.byKey(const ValueKey('registration-role-passenger'));
        final driver = find.byKey(const ValueKey('registration-role-driver'));
        expect(tester.widget<ChoiceChip>(passenger).selected, isFalse);
        expect(tester.widget<ChoiceChip>(driver).selected, isFalse);
        if (role != 'missing') {
          await tester.ensureVisible(role == 'driver' ? driver : passenger);
          await tester.tap(role == 'driver' ? driver : passenger);
          await tester.pump();
        }
        await tester.enterText(
            find.byKey(const ValueKey('login-phone')), '+77019990011');
        await tester.enterText(
            find.byKey(const ValueKey('login-password')), 'test-only-password');
        await tester.enterText(
            find.byKey(const ValueKey('login-repeat-password')),
            'test-only-password');
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.ensureVisible(find.text('Зарегистрироваться'));
        await tester.tap(find.text('Зарегистрироваться'));
        await tester.pumpAndSettle();
        if (role == 'missing') {
          expect(registrations, 0);
          expect(find.text('Выберите: пассажир или водитель'), findsOneWidget);
          expect(router.routeInformationProvider.value.uri.path, '/');
        } else {
          expect(registrations, 1);
          expect(find.text('$role form'), findsOneWidget);
          expect(FFAppState().pendingRegistrationRole, role);
        }
        await tester.pumpWidget(const SizedBox());
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/registerWithPassword'))
                  registrations++;
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'token': 'isolated-signup-token',
                      'user': {
                        'id': 'signup-$role',
                        'phone': '+77019990011',
                        'role': 'passenger',
                        'roleState': 'PASSENGER',
                        'profileCompleted': false,
                        'hasPassword': true,
                        'isDriver': false
                      }
                    }),
                    200,
                    headers: {'content-type': 'application/json'});
              }));
      router.dispose();
    });
  }
}
