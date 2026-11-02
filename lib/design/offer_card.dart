import 'dart:async';
import 'package:flutter/material.dart';
import '/flutter_flow/internationalization.dart';
import 'mtaxi_theme.dart';
import 'mtaxi_icon.dart';
import '/flutter_flow/flutter_flow_util.dart' show formatAppCurrency;

class DriverOfferCard extends StatefulWidget {
  const DriverOfferCard(
      {super.key,
      required this.offer,
      this.passengerPrice,
      this.now,
      this.onAccept,
      this.onDecline,
      this.busy = false});
  final Map<String, dynamic> offer;
  final num? passengerPrice;
  final DateTime Function()? now;
  final VoidCallback? onAccept, onDecline;
  final bool busy;
  @override
  State<DriverOfferCard> createState() => _DriverOfferCardState();
}

class _DriverOfferCardState extends State<DriverOfferCard> {
  Timer? _expiryTimer, _countdownTimer;
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  DateTime? get _expiry =>
      DateTime.tryParse((widget.offer['expiresAt'] ?? '').toString());
  bool _expired = false;
  @override
  void initState() {
    super.initState();
    _scheduleExpiry();
  }

  @override
  void didUpdateWidget(DriverOfferCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offer['expiresAt'] != widget.offer['expiresAt'] ||
        oldWidget.offer['id'] != widget.offer['id']) _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    _countdownTimer?.cancel();
    final expiry = _expiry;
    _expired = expiry != null && !expiry.isAfter(_now);
    if (expiry != null && !_expired) {
      _expiryTimer = Timer(expiry.difference(_now), () {
        _countdownTimer?.cancel();
        if (mounted) setState(() => _expired = true);
      });
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final busy = widget.busy;
    final onAccept = widget.onAccept, onDecline = widget.onDecline;
    String tr(String ru, String kk) =>
        FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
    final expired = _expired;
    final rating = offer['rating'] as num?;
    final name = (offer['driverName'] ?? '').toString().trim();
    final price = offer['price'] is num ? offer['price'] as num : null;
    final original = widget.passengerPrice;
    final difference =
        price != null && original != null ? price - original : null;
    final seconds = _expiry == null
        ? null
        : ((_expiry!.difference(_now).inMilliseconds / 1000).ceil())
            .clamp(0, 30);
    final scheme = Theme.of(context).colorScheme;
    return MTaxiCard(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: MTaxiDesign.surface,
                    borderRadius: BorderRadius.circular(15)),
                child:
                    const Icon(Icons.person_outline, color: MTaxiDesign.ink)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name.isEmpty ? tr('Водитель', 'Жүргізуші') : name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  if (rating == null)
                    Text(tr('Пока нет оценок', 'Әзірге баға жоқ'),
                        style: const TextStyle(fontSize: 12))
                  else
                    Row(children: [
                      MTaxiIcon('star', size: 14, color: scheme.secondary),
                      const SizedBox(width: 5),
                      Flexible(
                          child: Text(
                              '${rating.toStringAsFixed(1)} · ${offer['ratingCount'] ?? '—'}',
                              style: const TextStyle(fontSize: 12))),
                    ]),
                ])),
          ]),
          const SizedBox(height: 14),
          if ((offer['driverCar'] ?? '').toString().trim().isNotEmpty)
            Text(offer['driverCar'].toString()),
          if ((offer['driverPlate'] ?? '').toString().trim().isNotEmpty)
            Text(offer['driverPlate'].toString(),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(offer['etaMinutes'] == null
              ? tr('Время подачи уточняется', 'Келу уақыты нақтылануда')
              : tr('Подача примерно через ${offer['etaMinutes']} мин',
                  'Шамамен ${offer['etaMinutes']} минуттан кейін келеді')),
          if (offer['completedTrips'] is num)
            Text(
                tr('Завершено ${offer['completedTrips']} поездок',
                    '${offer['completedTrips']} сапар аяқталды'),
                style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          if (original != null) ...[
            Container(
              key: const ValueKey('offer-fare-comparison'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Ваша цена: ', 'Сіздің бағаңыз: ') +
                        formatAppCurrency(original)),
                    const SizedBox(height: 6),
                    Text(tr('Цена водителя', 'Жүргізушінің бағасы'),
                        style: const TextStyle(fontSize: 12)),
                    Text(price == null ? '—' : formatAppCurrency(price),
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w700)),
                    if (difference != null)
                      Text(difference == 0
                          ? tr('Без доплаты', 'Қосымша ақысыз')
                          : difference > 0
                              ? tr('Доплата: ', 'Қосымша ақы: ') +
                                  formatAppCurrency(difference)
                              : tr('Дешевле на ', 'Арзанырақ: ') +
                                  formatAppCurrency(-difference)),
                  ]),
            ),
          ] else
            Text(price == null ? '—' : formatAppCurrency(price),
                style:
                    const TextStyle(fontSize: 33, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
              expired
                  ? tr('Предложение истекло', 'Ұсыныс мерзімі аяқталды')
                  : seconds == null
                      ? tr('Доступность подтвердим на сервере',
                          'Қолжетімділігі серверде тексеріледі')
                      : tr('На ответ осталось $seconds сек',
                          'Жауап беруге $seconds сек қалды'),
              style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Text(
              tr('Новая цена применяется только после вашего согласия и подтверждения сервера.',
                  'Жаңа баға сіздің келісіміңізден және сервер растауынан кейін ғана қолданылады.'),
              style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: busy || expired ? null : onAccept,
              child: Text(busy
                  ? tr('Проверяем…', 'Тексерілуде…')
                  : tr('Принять предложение', 'Ұсынысты қабылдау'))),
          TextButton(
              onPressed: busy || expired ? null : onDecline,
              child: Text(tr('Отклонить', 'Қабылдамау'))),
        ]));
  }
}
