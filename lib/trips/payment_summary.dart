import '/flutter_flow/flutter_flow_util.dart' show formatAppCurrency;

String passengerPaymentSummary(Map order, String Function(String, String) tr) {
  num amount(String key) => order[key] is num ? order[key] as num : 0;
  final bonus = amount('passengerBonusUsed');
  final wallet = amount('passengerWalletUsed');
  if (bonus <= 0 && wallet <= 0) {
    return order['paymentMode'] == 'wallet'
        ? tr('Оплата со счёта приложения', 'Қосымша шотынан төлеу')
        : tr('Оплата наличными', 'Қолма-қол төлеу');
  }
  final cash = order['cashToDriver'] is num
      ? amount('cashToDriver')
      : order['paymentMode'] == 'wallet'
          ? 0
          : (amount('price') - bonus - wallet).clamp(0, double.infinity);
  return [
    if (bonus > 0)
      tr('Бонусами: ${formatAppCurrency(bonus)}',
          'Бонустармен: ${formatAppCurrency(bonus)}'),
    if (wallet > 0)
      tr('Со счёта: ${formatAppCurrency(wallet)}',
          'Шоттан: ${formatAppCurrency(wallet)}'),
    tr('Наличными водителю: ${formatAppCurrency(cash)}',
        'Жүргізушіге қолма-қол: ${formatAppCurrency(cash)}'),
  ].join('\n');
}
