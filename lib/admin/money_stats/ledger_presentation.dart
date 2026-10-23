/// Direction of the displayed operation, not a change to any balance.
int ledgerDirection(Map<String, dynamic> entry) {
  final type = entry['type']?.toString() ?? '';
  if (const {'payment_failed', 'withdrawal_requested', 'withdrawal_rejected'}
      .contains(type)) return 0;
  if (const {
    'driver_top_up',
    'driver_welcome_bonus',
    'daily_driver_bonus',
    'passenger_cashback',
    'passenger_trip_payment',
    'passenger_trip_refund',
    'order_commission_refund',
  }.contains(type)) return 1;
  if (const {'order_commission', 'driver_withdrawal', 'passenger_trip_reserve'}
      .contains(type)) return -1;
  final before = double.tryParse('${entry['balanceBefore']}');
  final after = double.tryParse('${entry['balanceAfter']}');
  if (before == null || after == null) return 0;
  return after.compareTo(before);
}
