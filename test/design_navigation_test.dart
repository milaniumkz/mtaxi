import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtaxi/app_state.dart';
import 'package:mtaxi/auth/backend_auth/backend_user_provider.dart';
import 'package:mtaxi/backend/backend_session.dart';
import 'package:mtaxi/design/bottom_navigation.dart';
import 'package:mtaxi/design/mtaxi_theme.dart';
import 'package:mtaxi/flutter_flow/internationalization.dart';
import 'package:mtaxi/main.dart';

class _Probe extends StatefulWidget {
  const _Probe({required this.onInit, required this.activity});
  final VoidCallback onInit;
  final List<bool> activity;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int count = 0;
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.activity.add(MTaxiTabActivity.isActive(context));
  }

  @override
  Widget build(BuildContext context) => Center(
      child: TextButton(
          onPressed: () => setState(() => count++),
          child: Text('Состояние $count')));
}

void main() {
  for (final driver in [false, true]) {
    testWidgets(
        'tabs retain active page and URL, Back returns to trip (${driver ? 'driver' : 'passenger'})',
        (tester) async {
      final user = {
        'id': 'navigation-fixture',
        'displayName': 'Тест',
        'phone': '+77019990011',
        'balance': 1000,
        'hasPassword': true,
        'profileCompleted': true,
        'city': 'Железинка',
        'isDriver': driver,
        'statusDriver': driver ? 'approved' : '',
        'driverRegistrationStatus': driver ? 'approved' : '',
        'roleState': driver ? 'DRIVER_ONLINE' : 'PASSENGER',
        'preferredClientMode': driver ? 'driver' : 'passenger'
      };
      SharedPreferences.setMockInitialValues(
          {mtaxiBackendAccessTokenPrefsKey: 'test-only-token'});
      FFAppState.reset();
      await FFAppState().initializePersistedState();
      activateBackendUser(user);
      var initializations = 0;
      final activity = <bool>[];
      final path = driver ? '/homeDriverOrder' : '/seachDriver';
      late final GoRouter router;
      final calls = <String>[];
      await http.runWithClient(() async {
        router =
            GoRouter(initialLocation: '$path?orderDocPath=order/test', routes: [
          GoRoute(
              path: path,
              builder: (_, __) => NavBarPage(
                  initialPage: driver ? 'driverOrders' : 'HomePage',
                  page: _Probe(
                      onInit: () => initializations++, activity: activity)))
        ]);
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
        await tester.tap(find.text('Состояние 0'));
        await tester.pump();
        Finder tab(String text) => find.descendant(
            of: find.byType(MTaxiBottomNavigation), matching: find.text(text));
        await tester.tap(tab(driver ? 'Счёт' : 'Кошелёк'));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(activity.last, isFalse);
        await tester.tap(tab('История'));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(find.text('Состояние 1'), findsOneWidget);
        expect(initializations, 1);
        expect(activity.last, isTrue);
        expect(router.routeInformationProvider.value.uri.path, path);
        expect(
            router.routeInformationProvider.value.uri
                .queryParameters['orderDocPath'],
            'order/test');
        expect(
            calls.any((name) =>
                name.contains('cancel') ||
                name.contains('advance') ||
                name.contains('createPassengerOrder')),
            isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 10));
      },
          () => MockClient((request) async {
                final name = request.url.pathSegments.last;
                calls.add(name);
                return http.Response(
                    jsonEncode({
                      'success': true,
                      'user': user,
                      'orders': [],
                      'passengerBonus': {
                        'balance': 200,
                        'percent': 2,
                        'maxSpendPercent': 100
                      },
                      'driverBonus': {'balance': 1000, 'enabled': false},
                      'settings': {}
                    }),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8'
                    });
              }));
      router.dispose();
    });
  }
}
