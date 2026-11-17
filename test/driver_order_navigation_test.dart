import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mtaxi/trips/driver_order_navigation.dart';

void main() {
  testWidgets(
      'thirty repeated assignment updates navigate to the same trip once',
      (tester) async {
    var tripBuilds = 0;
    late BuildContext entryContext;
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, state) {
            entryContext = context;
            return const Scaffold(body: Text('Лента'));
          }),
      GoRoute(
          name: 'homeDriverOrder',
          path: '/homeDriverOrder',
          builder: (context, state) {
            tripBuilds++;
            return const Scaffold(body: Text('Активная поездка'));
          }),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(openDriverOrderOnce(entryContext, 'order/current'), isTrue);
    for (var i = 0; i < 30; i++)
      expect(openDriverOrderOnce(entryContext, 'order/current'), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Активная поездка'), findsOneWidget);
    expect(tripBuilds, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}
