import 'package:flutter_test/flutter_test.dart';
import 'package:mtaxi/trips/payment_summary.dart';

void main() {
  String ru(String a, String b) => a;
  test(
      'cash-only fallback remains cash',
      () => expect(
          passengerPaymentSummary({'price': 500, 'paymentMode': 'cash'}, ru),
          'Оплата наличными'));
  test(
      'full bonus payment explicitly requires zero cash',
      () => expect(
          passengerPaymentSummary({
            'price': 700,
            'paymentMode': 'cash',
            'passengerBonusUsed': 700,
            'passengerWalletUsed': 0,
            'cashToDriver': 0
          }, ru),
          'Бонусами: 700 ₸\nНаличными водителю: 0 ₸'));
  test(
      'mixed payment separates all three amounts',
      () => expect(
          passengerPaymentSummary({
            'price': 1200,
            'paymentMode': 'cash',
            'passengerBonusUsed': 200,
            'passengerWalletUsed': 300,
            'cashToDriver': 700
          }, ru),
          'Бонусами: 200 ₸\nСо счёта: 300 ₸\nНаличными водителю: 700 ₸'));
  test(
      'wallet plus bonuses does not imply cash',
      () => expect(
          passengerPaymentSummary({
            'price': 500,
            'paymentMode': 'wallet',
            'passengerBonusUsed': 100,
            'passengerWalletUsed': 400
          }, ru),
          'Бонусами: 100 ₸\nСо счёта: 400 ₸\nНаличными водителю: 0 ₸'));
  test(
      'Kazakh amounts are translated and grouped',
      () => expect(
          passengerPaymentSummary(
              {'price': 1000, 'passengerBonusUsed': 1000, 'cashToDriver': 0},
              (ru, kk) => kk),
          'Бонустармен: 1 000 ₸\nЖүргізушіге қолма-қол: 0 ₸'));
}
