import 'dart:async';
import 'package:flutter/material.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/flutter_flow/flutter_flow_util.dart' show formatAppCurrency;
import '/flutter_flow/internationalization.dart';
import '/design/mtaxi_theme.dart';

class DriverOfferWaiting extends StatefulWidget {
  const DriverOfferWaiting(
      {super.key, required this.orderDocPath, required this.offer, this.now});
  final DateTime Function()? now;
  final String orderDocPath;
  final Map<String, dynamic> offer;
  @override
  State<DriverOfferWaiting> createState() => _DriverOfferWaitingState();
}

class _DriverOfferWaitingState extends State<DriverOfferWaiting> {
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  Timer? _timer;
  late final DateTime _deadline;
  bool _busy = false, _finished = false;
  int _remaining = 30;
  @override
  void initState() {
    super.initState();
    _deadline =
        DateTime.tryParse(widget.offer['expiresAt']?.toString() ?? '') ??
            _now.add(const Duration(seconds: 30));
    _remaining =
        (_deadline.difference(_now).inMilliseconds / 1000).ceil().clamp(0, 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _finished) return;
      setState(() => _remaining =
          (_deadline.difference(_now).inMilliseconds / 1000)
              .ceil()
              .clamp(0, 30));
      if (_remaining % 2 == 0 || _remaining == 0) unawaited(_refresh());
    });
    unawaited(_refresh());
  }

  String tr(String ru, String kk) =>
      FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
  void _finish(bool accepted, String? message) {
    if (_finished || !mounted) return;
    _finished = true;
    _timer?.cancel();
    if (message != null)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop(accepted);
  }

  Future<void> _refresh() async {
    if (_busy || _finished) return;
    _busy = true;
    try {
      final r = await makeCloudCall(
              'listOrderOffers', {'orderDocPath': widget.orderDocPath})
          .timeout(const Duration(seconds: 5));
      if (!mounted || _finished) return;
      if (r['success'] == true) {
        if (r['assignedToCurrentDriver'] == true) {
          _finish(true, null);
          return;
        }
        final offers = (r['offers'] as List? ?? []).whereType<Map>();
        final own =
            offers.where((x) => x['id'] == widget.offer['id']).firstOrNull;
        if (own?['status'] == 'declined') {
          _finish(
              false,
              tr('Пассажир отклонил предложение',
                  'Жолаушы ұсынысты қабылдамады'));
          return;
        }
        if (_remaining == 0 ||
            own?['status'] == 'expired' ||
            (r['orderStatus'] as num? ?? 0) != 0) {
          _finish(
              false,
              tr('Предложение завершено. Вы снова в ленте заказов.',
                  'Ұсыныс аяқталды. Тапсырыстар тізіміне оралдыңыз.'));
        }
      } else if (_remaining == 0) {
        _finish(
            false,
            tr('Время ожидания истекло. Проверяем статус заказа.',
                'Күту уақыты аяқталды. Тапсырыс күйін тексереміз.'));
      }
    } catch (_) {
      if (mounted && _remaining == 0)
        _finish(
            false,
            tr('Нет связи. Проверяем статус заказа в ленте.',
                'Байланыс жоқ. Тапсырыс күйін тізімде тексереміз.'));
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: _finished,
      child: Scaffold(
        appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(tr('Предложение отправлено', 'Ұсыныс жіберілді'))),
        body: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                      width: 96,
                      height: 96,
                      child: Stack(alignment: Alignment.center, children: [
                        SizedBox.expand(
                            child: CircularProgressIndicator(
                                value: _remaining / 30,
                                color: MTaxiDesign.teal,
                                strokeWidth: 6)),
                        Text('$_remaining',
                            style: const TextStyle(
                                fontSize: 34, fontWeight: FontWeight.w700)),
                      ])),
                  const SizedBox(height: 28),
                  Text(
                      tr('Ожидаем ответ пассажира',
                          'Жолаушының жауабын күтеміз'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 25, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(
                      formatAppCurrency(
                          (widget.offer['price'] as num? ?? 0).toDouble()),
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Text(
                      tr('У пассажира 30 секунд на ответ. Если предложение не принято, вы автоматически вернётесь в ленту.',
                          'Жолаушыға жауап беру үшін 30 секунд беріледі. Ұсыныс қабылданбаса, тізімге автоматты түрде ораласыз.'),
                      textAlign: TextAlign.center),
                ]))),
      ));
}
