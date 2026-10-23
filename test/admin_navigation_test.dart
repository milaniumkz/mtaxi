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
import 'package:mtaxi/admin/admin_home/admin_home_widget.dart';
import 'package:mtaxi/app_state.dart';
import 'package:mtaxi/auth/backend_auth/backend_user_provider.dart';
import 'package:mtaxi/backend/backend_session.dart';
import 'package:mtaxi/design/mtaxi_theme.dart';
import 'package:mtaxi/flutter_flow/internationalization.dart';

void main() {
  testWidgets('admin sidebar opens collections, support and driver moderation',
      (tester) async {
    tester.view.physicalSize = const Size(1365, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PackageInfo.setMockInitialValues(
        appName: 'MTaxi',
        packageName: 'mtaxi',
        version: '1.2.0',
        buildNumber: '58',
        buildSignature: 'test');
    SharedPreferences.setMockInitialValues(
        {mtaxiBackendAccessTokenPrefsKey: 'test-only-token'});
    FFAppState.reset();
    await FFAppState().initializePersistedState();
    activateBackendUser({
      'id': 'admin-navigation',
      'phone': '+70000000000',
      'role': 'admin',
      'roleState': 'ADMIN',
      'displayName': 'Администратор'
    });
    final router = GoRouter(initialLocation: '/admin', routes: [
      GoRoute(path: '/admin', builder: (_, __) => const AdminHomeWidget()),
      GoRoute(
          name: 'adminCollection',
          path: '/admin/collection',
          builder: (_, state) => Scaffold(
              body: Text('Раздел ${state.uri.queryParameters['collection']}'))),
      GoRoute(
          name: 'adminSupportChats',
          path: '/admin/support',
          builder: (_, __) => const Scaffold(body: Text('Очередь поддержки'))),
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
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      for (final entry in {
        'Пользователи': 'users',
        'Заказы': 'order',
        'Платежи': 'payments',
        'Настройки': 'appSettings'
      }.entries) {
        await tester.tap(find.text(entry.key).first);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(find.text('Раздел ${entry.value}'), findsOneWidget);
        router.pop();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      }
      await tester.tap(find.text('Поддержка').first);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Очередь поддержки'), findsOneWidget);
      router.pop();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.tap(find.text('Модерация водителей'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Dialog), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(Dialog),
              matching: find.text('Проверка водителей')),
          findsOneWidget);
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    },
        () => MockClient((_) async => http.Response(
            jsonEncode({
              'success': true,
              'users': [],
              'chats': [],
              'payments': [],
              'orders': [],
              'totals': {},
              'store': {'ok': true, 'type': 'json'},
              'architecture': 'backend-only',
              'firebaseAllowedOnlyFor': 'FCM transport',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
    router.dispose();
    activateBackendUser(null);
  });
}
