import 'trip_receipt.dart';
import '/design/offer_card.dart';
import '/design/mtaxi_theme.dart';
import '/flutter_flow/internationalization.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '/backend/backend_calls/backend_calls.dart';

Future<void> proposeDriverPrice(BuildContext context, String path,
    {int initialPrice = 500}) async {
  final price =
      TextEditingController(text: initialPrice.clamp(500, 10000000).toString());
  var submitted = false;
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
                      if (submitted) return;
                      final v = int.tryParse(price.text);
                      if (v != null && v >= 500 && v <= 10000000) {
                        submitted = true;
                        Navigator.pop(dialog, v);
                      }
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
  bool _responding = false, _failed = false;
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
      if (!mounted) return;
      if (r['success'] != true) {
        setState(() => _failed = true);
        return;
      }
      final offers = (r['offers'] as List? ?? [])
          .whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
      setState(() {
        _offers = offers;
        _failed = false;
      });
      if (!_dialog) {
        for (final offer in offers) {
          if (_seen.add(offer['id'].toString())) {
            await _show(offer);
            break;
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _busy = false;
    }
  }

  Future<void> _show(Map<String, dynamic> offer) async {
    if (_dialog || _responding) return;
    _dialog = true;
    final accept = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (dialog) => SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: DriverOfferCard(
              offer: offer,
              onAccept: () => Navigator.pop(dialog, true),
              onDecline: () => Navigator.pop(dialog, false))),
    );
    _dialog = false;
    if (accept == null || !mounted) return;
    setState(() => _responding = true);
    try {
      final result = await makeCloudCall('respondOrderOffer', {
        'orderDocPath': widget.orderDocPath,
        'offerId': offer['id'],
        'accept': accept
      });
      if (!mounted) return;
      if (result['success'] != true)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['error']?.toString() ??
                'Предложение больше недоступно. Обновите заказ.')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Ответ не получен. Проверяем состояние заказа; цена не считается принятой до подтверждения сервера.')));
    } finally {
      if (mounted) setState(() => _responding = false);
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    String tr(String ru, String kk) =>
        FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
    return MTaxiCard(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Text(
              _offers.isEmpty
                  ? tr('Ожидаем предложения водителей',
                      'Жүргізуші ұсыныстарын күтудеміз')
                  : tr('Предложения водителей', 'Жүргізуші ұсыныстары'),
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if (_responding)
            const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator()),
          if (_failed)
            TextButton(
                onPressed: _refresh,
                child: Text(tr(
                    'Связь потеряна. Обновить', 'Байланыс үзілді. Жаңарту'))),
          if (_offers.isNotEmpty)
            ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                    child: Column(children: [
                  for (final offer in _offers)
                    ListTile(
                      enabled: !_responding,
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                          backgroundColor: MTaxiDesign.surface,
                          foregroundColor: MTaxiDesign.ink,
                          child: Icon(Icons.person_outline)),
                      title: Text(
                          '${offer['driverName'] ?? tr('Водитель', 'Жүргізуші')} · ${offer['price']} ₸'),
                      subtitle: Text(offer['etaMinutes'] == null
                          ? tr('Время подачи уточняется',
                              'Келу уақыты нақтылануда')
                          : tr('До вас ≈${offer['etaMinutes']} мин',
                              'Сізге дейін ≈${offer['etaMinutes']} мин')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _show(offer),
                    )
                ]))),
        ]));
  }
}

Future<void> showTripRating(BuildContext context, String orderDocPath) =>
    showTripReceipt(context, orderDocPath);
