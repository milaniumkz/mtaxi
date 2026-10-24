import 'trip_receipt.dart';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import 'driver_offer_waiting.dart';
import '/flutter_flow/flutter_flow_util.dart' show formatAppCurrency;
import '/design/offer_card.dart';
import '/design/mtaxi_theme.dart';
import '/flutter_flow/internationalization.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '/backend/backend_calls/backend_calls.dart';

Future<void> proposeDriverPrice(BuildContext context, String path,
    {int initialPrice = 500}) async {
  final result = await showDialog<int>(
      context: context,
      builder: (_) => _OfferPriceDialog(initialPrice: initialPrice));
  if (result == null || !context.mounted) return;
  String tr(String ru, String kk) =>
      FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
  try {
    final response = await makeCloudCall(
        'submitOrderOffer', {'orderDocPath': path, 'price': result});
    if (!context.mounted) return;
    if (response['success'] == true && response['offer'] is Map) {
      final offer = Map<String, dynamic>.from(response['offer'] as Map);
      final accepted = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) =>
              DriverOfferWaiting(orderDocPath: path, offer: offer)));
      if (accepted == true && context.mounted) {
        context.goNamed('homeDriverOrder',
            queryParameters: {'orderDocPath': path});
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(response['error']?.toString() ??
              tr('Не удалось отправить предложение', 'Ұсыныс жіберілмеді'))));
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('Ответ не получен. Проверьте предложения по заказу.',
            'Жауап алынбады. Тапсырыс ұсыныстарын тексеріңіз.'))));
  }
}

class _OfferPriceDialog extends StatefulWidget {
  const _OfferPriceDialog({required this.initialPrice});
  final int initialPrice;
  @override
  State<_OfferPriceDialog> createState() => _OfferPriceDialogState();
}

/// Three proportional surcharges, rounded to 50 tenge for everyday fares.
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

class _OfferPriceDialogState extends State<_OfferPriceDialog> {
  bool _decided = false;
  int? _selected;
  void _finish(int? value) {
    if (_decided) return;
    _decided = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    String tr(String ru, String kk) =>
        FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
    final base = widget.initialPrice.clamp(500, 10000000);
    final increments = driverOfferIncrements(base);
    String money(int value) => formatAppCurrency(value.toDouble());
    return AlertDialog(
      title: Text(tr('Предложить цену', 'Баға ұсыну')),
      content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('Цена пассажира', 'Жолаушы бағасы')),
              const SizedBox(height: 6),
              Text(money(base),
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text(tr('Выберите доплату к этой цене',
                  'Осы бағаға қосымша ақыны таңдаңыз')),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final stacked = constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(16) > 24;
                final width = stacked
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 16) / 3;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final extra in increments)
                    SizedBox(
                        width: width,
                        child: OutlinedButton(
                          key: ValueKey('driver-offer-plus-$extra'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 14),
                            foregroundColor:
                                Theme.of(context).colorScheme.onSurface,
                            backgroundColor: _selected == extra
                                ? MTaxiDesign.gold.withValues(alpha: .25)
                                : Theme.of(context).colorScheme.surface,
                            side: BorderSide(
                                color: _selected == extra
                                    ? MTaxiDesign.gold
                                    : Theme.of(context).dividerColor,
                                width: _selected == extra ? 2 : 1),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => setState(() => _selected = extra),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text('+',
                                style: TextStyle(
                                    fontSize: 32,
                                    height: 1,
                                    fontWeight: FontWeight.w700)),
                            Text(money(extra),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text(tr('Итого', 'Барлығы'),
                                style: const TextStyle(fontSize: 12)),
                            Text(money(base + extra),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13)),
                          ]),
                        )),
                ]);
              }),
              const SizedBox(height: 14),
              Text(
                  increments.isEmpty
                      ? tr(
                          'Достигнута максимальная цена. Можно принять цену пассажира.',
                          'Ең жоғары бағаға жетті. Жолаушы бағасын қабылдауға болады.')
                      : tr(
                          'Предложение отправится после подтверждения. Заказ начнётся только с согласия пассажира.',
                          'Ұсыныс растаудан кейін жіберіледі. Тапсырыс жолаушы келіскенде ғана басталады.'),
                  style: const TextStyle(fontSize: 12)),
            ],
          ))),
      actions: [
        TextButton(
            onPressed: () => _finish(null),
            child: Text(tr('Отмена', 'Бас тарту'))),
        FilledButton(
            onPressed:
                _selected == null ? null : () => _finish(base + _selected!),
            child: Text(_selected == null
                ? tr('Предложить', 'Ұсыну')
                : tr('Предложить за ${money(base + _selected!)}',
                    '${money(base + _selected!)} ұсыну'))),
      ],
    );
  }
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
    var decided = false;
    final accept = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (dialog) => SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: DriverOfferCard(
              offer: offer,
              onAccept: () {
                if (decided) return;
                decided = true;
                Navigator.pop(dialog, true);
              },
              onDecline: () {
                if (decided) return;
                decided = true;
                Navigator.pop(dialog, false);
              })),
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
