import 'package:flutter_test/flutter_test.dart';
import 'package:mtaxi/admin/money_stats/ledger_presentation.dart';

void main() {
  test('credits from completed trips and bonuses have positive signs', () {
    for (final type in [
      'driver_welcome_bonus',
      'daily_driver_bonus',
      'passenger_cashback',
      'passenger_trip_payment',
      'driver_top_up',
      'passenger_trip_refund',
      'order_commission_refund'
    ]) {
      expect(ledgerDirection({'type': type, 'amount': 1000}), 1, reason: type);
    }
  });
  test('an unpaid request, rejected withdrawal or payment error is not a debit',
      () {
    for (final type in [
      'payment_failed',
      'withdrawal_requested',
      'withdrawal_rejected'
    ]) {
      expect(
          ledgerDirection({
            'type': type,
            'amount': 1000,
            'balanceBefore': 3000,
            'balanceAfter': 3000
          }),
          0,
          reason: type);
    }
  });
  test(
      'commission paid with bonuses remains a debit even when cash is unchanged',
      () {
    expect(
        ledgerDirection({
          'type': 'order_commission',
          'amount': 50,
          'cashAmount': 0,
          'bonusAmount': 50,
          'balanceBefore': 0,
          'balanceAfter': 0
        }),
        -1);
    expect(
        ledgerDirection({
          'type': 'passenger_trip_reserve',
          'amount': 500,
          'cashAmount': 486,
          'bonusAmount': 14
        }),
        -1);
  });
  test('unknown operations require an actual balance delta to assign a sign',
      () {
    expect(ledgerDirection({'type': 'new_operation', 'amount': 1000}), 0);
    expect(ledgerDirection({'balanceBefore': 1000, 'balanceAfter': 500}), -1);
    expect(ledgerDirection({'balanceBefore': 500, 'balanceAfter': 1000}), 1);
  });
}
