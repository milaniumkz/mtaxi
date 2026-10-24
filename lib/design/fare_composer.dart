import '/design/mtaxi_icon.dart';
import 'package:flutter/material.dart';
import '/flutter_flow/internationalization.dart';
import '/flutter_flow/flutter_flow_util.dart' show formatAppCurrency;
import '/trips/passenger_wallet.dart' show FareChoice;
import 'mtaxi_theme.dart';

/// Local quote editing only. The caller creates/reserves the order afterwards.
class FareComposer extends StatefulWidget {
  const FareComposer(
      {super.key, required this.user, required this.bonus, this.from, this.to});
  final Map user, bonus;
  final String? from, to;
  @override
  State<FareComposer> createState() => _FareComposerState();
}

class _FareComposerState extends State<FareComposer> {
  final _price = TextEditingController(text: '500');
  bool _wallet = false, _bonuses = false;
  bool _submitted = false;
  String? _error;
  String tr(String ru, String kk) =>
      FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _adjust(int delta) {
    final value = int.tryParse(_price.text) ?? 500;
    setState(() {
      _price.text = (value + delta).clamp(500, 10000000).toString();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            22, 22, 22, 22 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                    child: Text(tr('Ваша цена', 'Сіздің бағаңыз'),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700))),
                IconButton(
                    tooltip: tr('Закрыть', 'Жабу'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close))
              ]),
              if (widget.from?.isNotEmpty == true ||
                  widget.to?.isNotEmpty == true) ...[
                const SizedBox(height: 14),
                MTaxiCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(widget.from ?? '—'),
                      const SizedBox(height: 10),
                      MTaxiDestinationLine(widget.to ?? '—')
                    ])),
              ],
              const SizedBox(height: 18),
              MTaxiCard(
                  child: Row(children: [
                IconButton(
                    tooltip: tr('Уменьшить на 100 тенге', '100 теңгеге азайту'),
                    onPressed: () => _adjust(-100),
                    icon: const Icon(Icons.remove_circle_outline)),
                Expanded(
                    child: TextField(
                        key: const ValueKey('fare-price'),
                        controller: _price,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            fontSize: 31, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                            suffixText: '₸',
                            labelText: tr('Цена поездки', 'Сапар бағасы'),
                            errorText: _error))),
                IconButton(
                    tooltip:
                        tr('Увеличить на 100 тенге', '100 теңгеге арттыру'),
                    onPressed: () => _adjust(100),
                    icon: const Icon(Icons.add_circle_outline)),
              ])),
              const SizedBox(height: 10),
              Text(
                  tr('Минимум 500 ₸. Вы можете предложить больше.',
                      'Кемінде 500 ₸. Көбірек ұсына аласыз.'),
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 20),
              Text(tr('Как оплатить', 'Қалай төлеу керек'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: !_wallet,
                  onChanged: (_) => setState(() => _wallet = false),
                  title: Text(tr('Наличными', 'Қолма-қол')),
                  secondary: const Icon(Icons.payments_outlined)),
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _wallet,
                  onChanged: widget.user['balance'] is num
                      ? (_) => setState(() => _wallet = true)
                      : null,
                  title: Text(tr('Со счёта приложения', 'Қосымша шотынан')),
                  subtitle: Text(widget.user['balance'] is num
                      ? formatAppCurrency(widget.user['balance'] as num)
                      : tr('Баланс недоступен', 'Теңгерім қолжетімсіз')),
                  secondary: const Icon(Icons.account_balance_wallet_outlined)),
              const Divider(),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _bonuses,
                  onChanged: widget.bonus['balance'] is num
                      ? (value) => setState(() => _bonuses = value)
                      : null,
                  title:
                      Text(tr('Использовать бонусы', 'Бонустарды пайдалану')),
                  subtitle: Text(widget.bonus['balance'] is num
                      ? tr(
                          'Доступно ${formatAppCurrency(widget.bonus['balance'] as num)} · до ${widget.bonus['maxSpendPercent'] ?? '—'}% поездки',
                          '${formatAppCurrency(widget.bonus['balance'] as num)} бар · сапардың ${widget.bonus['maxSpendPercent'] ?? '—'}%-на дейін')
                      : tr('Бонусы недоступны', 'Бонустар қолжетімсіз'))),
              const SizedBox(height: 12),
              Text(
                  tr('Водитель может предложить свою цену. Она применяется только после вашего согласия.',
                      'Жүргізуші өз бағасын ұсына алады. Ол тек сіздің келісіміңізден кейін қолданылады.'),
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 20),
              FilledButton(
                  key: const ValueKey('fare-submit'),
                  onPressed: () {
                    if (_submitted) return;
                    final value = int.tryParse(_price.text.trim());
                    if (value == null || value < 500 || value > 10000000) {
                      setState(() => _error = tr(
                          'Целая цена от 500 до 10 000 000 ₸',
                          '500–10 000 000 ₸ аралығындағы бүтін баға'));
                      return;
                    }
                    _submitted = true;
                    Navigator.pop(
                        context, FareChoice(value, _wallet, _bonuses));
                  },
                  child: Text(tr('Искать водителя', 'Жүргізушіні іздеу'))),
            ]),
      ));
}
