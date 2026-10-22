import 'dart:async';
import 'package:flutter/material.dart';
import '/backend/backend_calls/backend_calls.dart';

Future<void> proposeDriverPrice(BuildContext context, String path) async {
  final price = TextEditingController(text: '500');
  final result = await showDialog<int>(
      context: context,
      builder: (dialog) => AlertDialog(
              title: const Text('Предложить свою цену'),
              content: TextField(
                  controller: price,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Цена, ₸',
                      helperText:
                          'Не менее 500 ₸. Время подачи рассчитывается по вашей геопозиции.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog),
                    child: const Text('Отмена')),
                FilledButton(
                    onPressed: () {
                      final v = int.tryParse(price.text);
                      if (v != null && v >= 500 && v <= 10000000)
                        Navigator.pop(dialog, v);
                    },
                    child: const Text('Предложить'))
              ]));
  price.dispose();
  if (result == null || !context.mounted) return;
  final r = await makeCloudCall(
      'submitOrderOffer', {'orderDocPath': path, 'price': result});
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(r['success'] == true
          ? 'Предложение отправлено пассажиру'
          : r['error']?.toString() ?? 'Не удалось отправить предложение')));
}

class PassengerOffers extends StatefulWidget {
  const PassengerOffers({super.key, required this.orderDocPath});
  final String orderDocPath;
  @override
  State<PassengerOffers> createState() => _PassengerOffersState();
}

class _PassengerOffersState extends State<PassengerOffers> {
  Timer? _timer;
  final Set<String> _seen = {};
  List<Map<String, dynamic>> _offers = [];
  bool _busy = false, _dialog = false;
  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    _busy = true;
    try {
      final r = await makeCloudCall(
          'listOrderOffers', {'orderDocPath': widget.orderDocPath});
      if (!mounted || r['success'] != true) return;
      final offers = (r['offers'] as List? ?? [])
          .whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
      setState(() => _offers = offers);
      if (!_dialog) {
        for (final offer in offers) {
          if (_seen.add(offer['id'].toString())) {
            await _show(offer);
            break;
          }
        }
      }
    } finally {
      _busy = false;
    }
  }

  String _details(Map<String, dynamic> o) =>
      '${o['driverName']}\n${o['price']} ₸ · ${o['etaMinutes'] == null ? 'Время подачи уточняется' : '≈${o['etaMinutes']} мин до вас'}\n${o['rating'] == null ? 'Пока нет оценок' : 'Рейтинг: ${(o['rating'] as num).toStringAsFixed(1)} ★ (${o['ratingCount']})'} · ${o['completedTrips'] ?? 0} поездок\n${o['driverCar'] ?? ''} ${o['driverPlate'] ?? ''}';
  Future<void> _show(Map<String, dynamic> offer) async {
    _dialog = true;
    final accept = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: const Text('Предложение водителя'),
                content: Text(_details(offer)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Отклонить')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: Text('Принять за ${offer['price']} ₸'))
                ]));
    _dialog = false;
    if (accept == null || !mounted) return;
    final r = await makeCloudCall('respondOrderOffer', {
      'orderDocPath': widget.orderDocPath,
      'offerId': offer['id'],
      'accept': accept
    });
    if (!mounted) return;
    if (r['success'] != true)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(r['error']?.toString() ?? 'Предложение больше недоступно')));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190),
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                    _offers.isEmpty
                        ? 'Ожидаем предложения водителей'
                        : 'Предложения: ${_offers.length}',
                    style: Theme.of(context).textTheme.titleMedium),
                for (final offer in _offers)
                  ListTile(
                      dense: true,
                      title:
                          Text('${offer['driverName']} · ${offer['price']} ₸'),
                      subtitle: Text(offer['etaMinutes'] == null
                          ? 'Уточняется время подачи'
                          : 'Подача ≈${offer['etaMinutes']} мин'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _show(offer)),
              ])))));
}

Future<void> showTripRating(BuildContext context, String orderDocPath) async {
  final stars = await showDialog<int>(
      context: context,
      builder: (dialog) => AlertDialog(
            title: const Text('Как прошла поездка?'),
            content: Wrap(alignment: WrapAlignment.center, children: [
              for (int n = 1; n <= 5; n++)
                TextButton(
                    onPressed: () => Navigator.pop(dialog, n),
                    child: Text('$n ★'))
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Позже'))
            ],
          ));
  if (stars != null)
    await makeCloudCall(
        'rateTripDriver', {'orderDocPath': orderDocPath, 'stars': stars});
}
