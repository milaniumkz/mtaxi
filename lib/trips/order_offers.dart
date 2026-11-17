import 'trip_receipt.dart';
import 'dart:math' as math;
import 'driver_offer_waiting.dart';
import '/design/offer_card.dart';
import '/design/mtaxi_theme.dart';
import '/flutter_flow/internationalization.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '/backend/backend_calls/backend_calls.dart';

Future<bool> proposeDriverPrice(BuildContext context, String path,
    {required int price}) async {
  try {
    final response = await makeCloudCall(
        'submitOrderOffer', {'orderDocPath': path, 'price': price});
    if (!context.mounted) return false;
    if (response['success'] == true && response['offer'] is Map) {
      return await Navigator.of(context).push<bool>(MaterialPageRoute(
              builder: (_) => DriverOfferWaiting(
                  orderDocPath: path,
                  offer:
                      Map<String, dynamic>.from(response['offer'] as Map)))) ==
          true;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(response['error']?.toString() ??
            'Не удалось отправить предложение')));
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ответ не получен. Проверьте предложение по заказу.')));
  }
  return false;
}

List<int> driverOfferIncrements(int passengerPrice) {
  final base = passengerPrice.clamp(500, 10000000);
  final room = 10000000 - base;
  if (room <= 0) return const [];
  final quantum = room >= 150 ? 50 : 1;
  final proportional = math.max(100, (base / 250).round() * 50);
  final step = math.min(
      proportional, math.max(quantum, (room ~/ 3 ~/ quantum) * quantum));
  return [
    for (var n = 1; n <= 3; n++)
      if (n * step <= room) n * step
  ];
}

class PassengerOffers extends StatefulWidget {
  const PassengerOffers(
      {super.key, required this.orderDocPath, this.passengerPrice});
  final String orderDocPath;
  final num? passengerPrice;
  @override
  State<PassengerOffers> createState() => _PassengerOffersState();
}

class _PassengerOffersState extends State<PassengerOffers> {
  Timer? _timer;
  List<Map<String, dynamic>> _offers = [];
  bool _busy = false;
  bool _responding = false, _failed = false;
  final Set<String> _decided = {};
  int _generation = 0;
  String? _lastError;
  DateTime? _lastErrorAt;
  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant PassengerOffers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderDocPath != widget.orderDocPath) {
      _generation++;
      _offers = [];
      _decided.clear();
      _lastError = null;
      _lastErrorAt = null;
      _busy = _responding = _failed = false;
      _refresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    final generation = _generation;
    _busy = true;
    try {
      final r = await makeCloudCall(
          'listOrderOffers', {'orderDocPath': widget.orderDocPath});
      if (!mounted || generation != _generation) return;
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
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (generation == _generation) _busy = false;
    }
  }

  void _showDecisionError(String message) {
    final now = DateTime.now();
    if (!mounted ||
        (_lastError == message &&
            _lastErrorAt != null &&
            now.difference(_lastErrorAt!).inSeconds < 5)) return;
    _lastError = message;
    _lastErrorAt = now;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
          content: Text(message), duration: const Duration(seconds: 2)));
  }

  Future<void> _respond(
      Map<String, dynamic> offer, bool accept, String orderPath) async {
    final generation = _generation;
    if (orderPath != widget.orderDocPath) return;
    final id = offer['id']?.toString() ?? '';
    if (_responding || _decided.contains(id)) return;
    final expires = DateTime.tryParse(offer['expiresAt']?.toString() ?? '');
    if (expires != null && !expires.isAfter(DateTime.now())) {
      await _refresh();
      return;
    }
    setState(() => _responding = true);
    try {
      final result = await makeCloudCall('respondOrderOffer', {
        'orderDocPath': orderPath,
        'offerId': offer['id'],
        'accept': accept
      });
      if (!mounted || generation != _generation) return;
      if (result['success'] == true) _decided.add(id);
      if (result['success'] != true)
        _showDecisionError(result['error']?.toString() ??
            'Предложение больше недоступно. Обновите заказ.');
    } catch (_) {
      if (mounted && generation == _generation)
        _showDecisionError(
            'Ответ не получен. Проверяем состояние заказа; цена не считается принятой до подтверждения сервера.');
    } finally {
      if (mounted && generation == _generation)
        setState(() => _responding = false);
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    String tr(String ru, String kk) =>
        FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
    final orderPath = widget.orderDocPath;
    return MTaxiCard(
        padding: const EdgeInsets.all(8),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  _offers.isEmpty
                      ? tr('Ожидаем предложения водителей',
                          'Жүргізуші ұсыныстарын күтудеміз')
                      : tr('Предложения водителей', 'Жүргізуші ұсыныстары'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              if (_responding)
                const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator()),
              if (_failed)
                TextButton(
                    onPressed: _refresh,
                    child: Text(tr('Связь потеряна. Обновить',
                        'Байланыс үзілді. Жаңарту'))),
              if (_offers.isNotEmpty)
                ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: math
                            .min(450, MediaQuery.sizeOf(context).height - 220)
                            .clamp(250, 450)
                            .toDouble()),
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final offer in _offers)
                        DriverOfferCard(
                            key: ValueKey(offer['id']),
                            compact: true,
                            offer: offer,
                            passengerPrice: widget.passengerPrice,
                            busy: _responding,
                            onAccept: () => _respond(offer, true, orderPath),
                            onDecline: () => _respond(offer, false, orderPath)),
                    ]))),
            ]));
  }
}

Future<void> showTripRating(BuildContext context, String orderDocPath) =>
    showTripReceipt(context, orderDocPath);
