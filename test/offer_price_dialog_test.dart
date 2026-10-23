import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtaxi/design/fare_composer.dart';
import 'package:mtaxi/trips/order_offers.dart';
import 'design_flow_test.dart' show wrap;

void main() {
  testWidgets(
      'invalid driver price explains error and repeated cancel preserves screen',
      (tester) async {
    await tester.pumpWidget(wrap(Scaffold(
        body: Builder(
            builder: (context) => FilledButton(
                onPressed: () => proposeDriverPrice(context, 'order/audit'),
                child: const Text('Открыть'))))));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '499');
    await tester.tap(find.text('Предложить'));
    await tester.pump();
    expect(find.text('Целая цена от 500 до 10 000 000 ₸'), findsOneWidget);
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
