import '/driver/home_driver/driver_bonus_card.dart';
import '/design/mtaxi_icon.dart';
import 'package:flutter/material.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/design/mtaxi_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

Future<void> showTripReceipt(BuildContext context, String path,
        {bool driver = false}) =>
    Navigator.of(context).push<void>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _TripReceipt(path: path, driver: driver)));

class _TripReceipt extends StatefulWidget {
  const _TripReceipt({required this.path, required this.driver});
  final String path;
  final bool driver;
  @override
  State<_TripReceipt> createState() => _TripReceiptState();
}

class _TripReceiptState extends State<_TripReceipt> {
  late Future<Map<String, dynamic>> _request;
  int _stars = 0;
  bool _saving = false;
  String? _error;
  String tr(String ru, String kk) =>
      FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final result =
        await makeCloudCall('getOrderDetails', {'orderDocPath': widget.path});
    final order = result['order'];
    if (result['success'] != true || order is! Map || order['status'] != 5)
      throw StateError('Receipt not confirmed');
    return Map<String, dynamic>.from(order);
  }

  Future<void> _rate() async {
    if (_saving || _stars == 0) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await makeCloudCall(
        'rateTripDriver', {'orderDocPath': widget.path, 'stars': _stars});
    if (!mounted) return;
    if (result['success'] == true) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _error = result['error']?.toString() ??
          tr('Не удалось сохранить оценку. Повторите.',
              'Баға сақталмады. Қайталаңыз.');
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(tr('Поездка завершена', 'Сапар аяқталды'))),
        body: FutureBuilder<Map<String, dynamic>>(
            future: _request,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return MTaxiFeedback(
                    title: tr('Проверяем итог поездки',
                        'Сапар қорытындысы тексерілуде'),
                    message: '',
                    loading: true);
              if (snapshot.hasError || !snapshot.hasData)
                return MTaxiFeedback(
                    title: tr(
                        'Итог пока недоступен', 'Қорытынды әзірге қолжетімсіз'),
                    message: tr(
                        'Проверьте связь. Повторная загрузка не выполняет оплату.',
                        'Байланысты тексеріңіз. Қайта жүктеу төлем жасамайды.'),
                    onRetry: () => setState(() => _request = _load()));
              final order = snapshot.data!;
              String money(dynamic value) =>
                  value is num ? formatAppCurrency(value.toDouble()) : '—';
              return ListView(padding: const EdgeInsets.all(22), children: [
                Center(
                    child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                            color: MTaxiDesign.gold.withValues(alpha: .25),
                            borderRadius: BorderRadius.circular(24)),
                        child: const Icon(Icons.check, size: 36))),
                const SizedBox(height: 24),
                Text(
                    widget.driver
                        ? tr('Заказ выполнен', 'Тапсырыс орындалды')
                        : tr('Спасибо за поездку!', 'Сапарыңыз үшін рақмет!'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 31, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                MTaxiCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Text(tr('Стоимость поездки', 'Сапар құны')),
                      const SizedBox(height: 10),
                      Text(money(order['price']),
                          style: const TextStyle(
                              fontSize: 36, fontWeight: FontWeight.w700)),
                      const Divider(height: 28),
                      Text(order['ot']?.toString() ?? '—'),
                      const SizedBox(height: 10),
                      MTaxiDestinationLine(order['kuda']?.toString() ?? '—'),
                      const Divider(height: 28),
                      if (widget.driver) ...[
                        Text(tr('Наличными: ${money(order['cashToDriver'])}',
                            'Қолма-қол: ${money(order['cashToDriver'])}')),
                        const SizedBox(height: 10),
                        Text(tr(
                            'На денежный счёт: ${money(order['passengerBonusUsed'] is num && order['passengerWalletUsed'] is num ? (order['passengerBonusUsed'] as num) + (order['passengerWalletUsed'] as num) : null)}',
                            'Ақша шотына: ${money(order['passengerBonusUsed'] is num && order['passengerWalletUsed'] is num ? (order['passengerBonusUsed'] as num) + (order['passengerWalletUsed'] as num) : null)}')),
                        const SizedBox(height: 12),
                        Text(tr(
                            'Комиссия учитывается отдельно. Актуальные денежный и бонусный балансы — во вкладке «Счёт».',
                            'Комиссия бөлек есептеледі. Ақша мен бонус теңгерімі «Шот» бөлімінде.')),
                      ] else
                        Text(order['paymentMode'] == 'wallet'
                            ? tr('Оплата со счёта приложения',
                                'Қосымша шотынан төлеу')
                            : tr('Оплата наличными', 'Қолма-қол төлеу')),
                    ])),
                if (widget.driver) ...[
                  const SizedBox(height: 16),
                  const DriverBonusCard()
                ],
                if (!widget.driver) ...[
                  const SizedBox(height: 24),
                  Text(tr('Как прошла поездка?', 'Сапар қалай өтті?'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  Wrap(alignment: WrapAlignment.center, children: [
                    for (var n = 1; n <= 5; n++)
                      IconButton(
                          tooltip: tr('Оценка $n из 5', '5-тен $n баға'),
                          onPressed:
                              _saving ? null : () => setState(() => _stars = n),
                          icon: Icon(
                              n <= _stars ? Icons.star : Icons.star_outline),
                          color: MTaxiDesign.teal)
                  ]),
                  if (_error != null)
                    Semantics(
                        liveRegion: true,
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  FilledButton(
                      onPressed: _saving || _stars == 0 ? null : _rate,
                      child: Text(_saving
                          ? tr('Сохраняем…', 'Сақталуда…')
                          : tr('Оценить поездку', 'Сапарды бағалау'))),
                  TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: Text(tr('Позже', 'Кейін'))),
                ] else ...[
                  const SizedBox(height: 24),
                  FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr('К заказам', 'Тапсырыстарға')))
                ],
              ]);
            }),
      ));
}
