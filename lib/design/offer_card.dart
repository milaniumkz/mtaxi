import 'dart:async';
import 'package:flutter/material.dart';
import '/flutter_flow/internationalization.dart';
import 'mtaxi_theme.dart';

class DriverOfferCard extends StatefulWidget {
  const DriverOfferCard(
      {super.key,
      required this.offer,
      this.onAccept,
      this.onDecline,
      this.busy = false});
  final Map<String, dynamic> offer;
  final VoidCallback? onAccept, onDecline;
  final bool busy;
  @override
  State<DriverOfferCard> createState() => _DriverOfferCardState();
}

class _DriverOfferCardState extends State<DriverOfferCard> {
  Timer? _expiryTimer;
  bool _expired = false;
  @override
  void initState() {
    super.initState();
    _scheduleExpiry();
  }

  @override
  void didUpdateWidget(DriverOfferCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offer['expiresAt'] != widget.offer['expiresAt'])
      _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final expiry =
        DateTime.tryParse((widget.offer['expiresAt'] ?? '').toString());
    _expired = expiry != null && !expiry.isAfter(DateTime.now());
    if (expiry != null && expiry.isAfter(DateTime.now()))
      _expiryTimer = Timer(expiry.difference(DateTime.now()), () {
        if (mounted) setState(() => _expired = true);
      });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
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
                  Text(
                      rating == null
                          ? tr('Пока нет оценок', 'Әзірге баға жоқ')
                          : '${rating.toStringAsFixed(1)} ★ · ${offer['ratingCount'] ?? '—'}',
                      style: const TextStyle(fontSize: 12)),
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
              : tr('До вас ≈${offer['etaMinutes']} мин',
                  'Сізге дейін ≈${offer['etaMinutes']} мин')),
          if (offer['completedTrips'] is num)
            Text(
                tr('Завершено ${offer['completedTrips']} поездок',
                    '${offer['completedTrips']} сапар аяқталды'),
                style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          Text('${offer['price'] ?? '—'} ₸',
              style:
                  const TextStyle(fontSize: 33, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
              expired
                  ? tr('Предложение истекло', 'Ұсыныс мерзімі аяқталды')
                  : tr('Предложение действует до 2 минут',
                      'Ұсыныс 2 минутқа дейін жарамды'),
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
