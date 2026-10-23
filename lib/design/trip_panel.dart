import '/design/mtaxi_icon.dart';
import 'package:flutter/material.dart';
import '/flutter_flow/internationalization.dart';
import '/flutter_flow/flutter_flow_util.dart' show formatAppCurrency;
import 'mtaxi_theme.dart';

class TripPanel extends StatelessWidget {
  const TripPanel(
      {super.key,
      required this.order,
      required this.status,
      required this.driver,
      required this.contacts,
      this.onAdvance,
      this.onCancel,
      this.busy = false,
      this.showActions = true});
  final Map<String, dynamic> order;
  final int status;
  final bool driver, busy, showActions;
  final Widget contacts;
  final VoidCallback? onAdvance, onCancel;
  @override
  Widget build(BuildContext context) {
    String tr(String ru, String kk) =>
        FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
    String value(String field, String fallback) {
      final text = (order[field] ?? '').toString().trim();
      return text.isEmpty ? fallback : text;
    }

    final heading = driver
        ? (status == 3
            ? tr('Ожидайте пассажира', 'Жолаушыны күтіңіз')
            : status == 4
                ? tr('Поездка идёт', 'Сапар жүріп жатыр')
                : tr('К месту посадки', 'Отыру орнына'))
        : (status == 3
            ? tr('Выходите', 'Шығыңыз')
            : status == 4
                ? tr('Вы в пути', 'Сіз жолдасыз')
                : tr('Водитель едет к вам', 'Жүргізуші сізге келе жатыр'));
    final price = order['price'] as num?;
    final cash = order['cashToDriver'] as num?;
    final wallet = order['passengerWalletUsed'] as num?;
    final bonus = order['passengerBonusUsed'] as num?;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
              child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 20),
          Text(heading,
              style:
                  const TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          MTaxiCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    driver && status >= 4
                        ? tr('Маршрут поездки', 'Сапар бағыты')
                        : tr('Место посадки', 'Отыру орны'),
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Text(
                    value('ot', tr('Адрес уточняется', 'Мекенжай нақтылануда')),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                MTaxiDestinationLine(value(
                    'kuda', tr('Адрес уточняется', 'Мекенжай нақтылануда'))),
              ])),
          const SizedBox(height: 14),
          Row(children: [
            const CircleAvatar(
                backgroundColor: MTaxiDesign.surface,
                foregroundColor: MTaxiDesign.ink,
                child: Icon(Icons.person_outline)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      value(
                          driver ? 'customerName' : 'driverName',
                          driver
                              ? tr('Пассажир', 'Жолаушы')
                              : tr('Водитель', 'Жүргізуші')),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  if (!driver)
                    Text([order['driverCar'], order['driverPlate']]
                        .where(
                            (e) => e != null && e.toString().trim().isNotEmpty)
                        .join(' · ')),
                ])),
          ]),
          const SizedBox(height: 10),
          contacts,
          const SizedBox(height: 14),
          MTaxiCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                _line(tr('Стоимость поездки', 'Сапар құны'),
                    price == null ? '—' : formatAppCurrency(price.toDouble())),
                if (driver) ...[
                  const Divider(height: 24),
                  _line(tr('Получить наличными', 'Қолма-қол алу'),
                      cash == null ? '—' : formatAppCurrency(cash.toDouble())),
                  const SizedBox(height: 10),
                  _line(
                      tr('На денежный счёт', 'Ақша шотына'),
                      wallet == null || bonus == null
                          ? '—'
                          : formatAppCurrency((wallet + bonus).toDouble())),
                  const SizedBox(height: 10),
                  Text(
                      tr('Комиссия сервиса учитывается отдельно. Это не чистый заработок.',
                          'Сервис комиссиясы бөлек есептеледі. Бұл таза табыс емес.'),
                      style: const TextStyle(fontSize: 12)),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(order['paymentMode'] == 'wallet'
                      ? tr(
                          'Оплата со счёта приложения', 'Қосымша шотынан төлеу')
                      : tr('Оплата наличными', 'Қолма-қол төлеу')),
                ],
              ])),
          if (value('comment', '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(value('comment', ''))
          ],
          if (value('deliveryItem', '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(value('deliveryItem', ''))
          ],
          const SizedBox(height: 18),
          if (showActions && driver && status >= 2 && status <= 4)
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: MTaxiDesign.ink,
                  foregroundColor: Colors.white),
              onPressed: busy ? null : onAdvance,
              child: Text(busy
                  ? tr('Подтверждаем…', 'Расталуда…')
                  : status == 2
                      ? tr('Я на месте', 'Мен келдім')
                      : status == 3
                          ? tr('Начать поездку', 'Сапарды бастау')
                          : tr('Завершить поездку', 'Сапарды аяқтау')),
            ),
          if (showActions && driver && status == 3) ...[
            const SizedBox(height: 12),
            Text(
                tr('Перед началом убедитесь, что пассажир в машине.',
                    'Бастамас бұрын жолаушының көлікте екеніне көз жеткізіңіз.'),
                style: const TextStyle(fontSize: 12))
          ],
          if (!driver && status < 4 && onCancel != null)
            TextButton(
                onPressed: busy ? null : onCancel,
                child: Text(busy
                    ? tr('Проверяем…', 'Тексерілуде…')
                    : tr('Отменить заказ', 'Тапсырысты болдырмау'))),
          if (status >= 4)
            Text(
                tr('После начала поездки отмена недоступна.',
                    'Сапар басталғаннан кейін бас тартуға болмайды.'),
                style: const TextStyle(fontSize: 12)),
        ]);
  }

  Widget _line(String title, String value) => Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 14,
          runSpacing: 6,
          children: [
            Text(title),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700))
          ]);
}
