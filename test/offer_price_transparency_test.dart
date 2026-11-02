import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtaxi/design/offer_card.dart';
import 'design_flow_test.dart' show wrap;

void main() {
  testWidgets(
      'passenger sees original fare, surcharge and actual response deadline',
      (tester) async {
    var now = DateTime.utc(2030, 1, 1);
    var accepted = 0;
    final expires = now.add(const Duration(seconds: 30));
    await tester.pumpWidget(wrap(Scaffold(
        body: SingleChildScrollView(
            child: DriverOfferCard(
      passengerPrice: 500,
      offer: {
        'id': 'transparent-offer',
        'price': 700,
        'driverName': 'Тестовый водитель',
        'expiresAt': expires.toIso8601String(),
      },
      now: () => now,
      onAccept: () => accepted++,
    )))));
    expect(find.textContaining('Ваша цена: 500'), findsOneWidget);
    expect(find.textContaining('Доплата: 200'), findsOneWidget);
    expect(find.text('На ответ осталось 30 сек'), findsOneWidget);
    expect(find.textContaining('2 минут'), findsNothing);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('На ответ осталось 29 сек'), findsOneWidget);
    now = expires;
    await tester.pump(const Duration(seconds: 29));
    expect(find.text('Предложение истекло'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(accepted, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('same or lower driver fare never displays an invented surcharge',
      (tester) async {
    for (final price in [500, 700]) {
      await tester.pumpWidget(wrap(Scaffold(
          body: SingleChildScrollView(
              child: DriverOfferCard(
        key: ValueKey(price),
        passengerPrice: 700,
        offer: {'price': price, 'driverName': 'Водитель'},
      )))));
      expect(find.textContaining('Доплата:'), findsNothing);
      expect(
          find.textContaining(price == 500 ? 'Дешевле на 200' : 'Без доплаты'),
          findsOneWidget);
      expect(find.text('Доступность подтвердим на сервере'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
