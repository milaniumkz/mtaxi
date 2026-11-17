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
      'driver sends the selected total immediately without a price dialog',
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
                  onPressed: () =>
                      proposeDriverPrice(context, 'order/audit', price: 1200),
                  child: const Text('Отправить +200'))))));
      await tester.tap(find.text('Отправить +200'));
      await tester.pumpAndSettle();
      expect(calls.length, 1);
      expect(calls.single['price'], 1200);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TextField), findsNothing);
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
  testWidgets('fare balances use grouped tenge amounts', (tester) async {
    await tester.pumpWidget(wrap(const Scaffold(
        body: FareComposer(
            user: {'balance': 1000000},
            bonus: {'balance': 1000, 'maxSpendPercent': 100}))));
    expect(find.text('1 000 000 ₸'), findsOneWidget);
    expect(find.textContaining('1 000 ₸'), findsOneWidget);
  });
}
