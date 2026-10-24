import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:mtaxi/design/fare_composer.dart';
import 'package:mtaxi/trips/order_offers.dart';
import 'design_flow_test.dart' show wrap;

void main() {
  test('counteroffers grow proportionally and never exceed the backend ceiling',
      () {
    expect(driverOfferIncrements(500), [100, 200, 300]);
    expect(driverOfferIncrements(1000), [200, 400, 600]);
    expect(driverOfferIncrements(2500), [500, 1000, 1500]);
    expect(driverOfferIncrements(750), [150, 300, 450]);
    for (final base in [
      500,
      501,
      999,
      100000,
      9000000,
      9999997,
      9999999,
      10000000
    ]) {
      final values = driverOfferIncrements(base);
      expect(values.toSet().length, values.length);
      expect(values.every((x) => x > 0 && base + x <= 10000000), isTrue);
    }
    expect(driverOfferIncrements(10000000), isEmpty);
  });
  testWidgets(
      'driver selects one surcharge and sends exactly one total after confirmation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'MTaxi',
        packageName: 'test.mtaxi',
        version: '1',
        buildNumber: '1',
        buildSignature: '');
    final calls = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap(Scaffold(
          body: Builder(
              builder: (context) => FilledButton(
                  onPressed: () => proposeDriverPrice(context, 'order/audit',
                      initialPrice: 1000),
                  child: const Text('Открыть'))))));
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(
          find.byKey(const ValueKey('driver-offer-plus-200')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('driver-offer-plus-400')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('driver-offer-plus-600')), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Предложить'))
              .onPressed,
          isNull);
      await tester.tap(find.byKey(const ValueKey('driver-offer-plus-600')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('driver-offer-plus-200')));
      await tester.pump();
      expect(calls, isEmpty);
      await tester.tap(find.text('Предложить за 1 200 ₸'));
      await tester.pumpAndSettle();
      expect(calls.length, 1);
      expect(calls.single['price'], 1200);
    },
        () => MockClient((req) async {
              if (req.url.path.endsWith('/submitOrderOffer'))
                calls.add(
                    Map<String, dynamic>.from(jsonDecode(req.body) as Map));
              return http.Response(
                  jsonEncode({'success': false, 'error': 'fixture response'}),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
  });
  testWidgets('repeated cancel preserves the driver feed route',
      (tester) async {
    await tester.pumpWidget(wrap(Scaffold(
        body: Builder(
            builder: (context) => FilledButton(
                onPressed: () => proposeDriverPrice(context, 'order/audit'),
                child: const Text('Открыть'))))));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    final cancel =
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Отмена'));
    cancel.onPressed!();
    await tester.pump(const Duration(milliseconds: 30));
    cancel.onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Открыть'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('fare balances use grouped tenge amounts', (tester) async {
    await tester.pumpWidget(wrap(const Scaffold(
        body: FareComposer(
            user: {'balance': 1000000},
            bonus: {'balance': 1000, 'maxSpendPercent': 100}))));
    expect(find.text('1 000 000 ₸'), findsOneWidget);
    expect(find.textContaining('1 000 ₸'), findsOneWidget);
  });
}
