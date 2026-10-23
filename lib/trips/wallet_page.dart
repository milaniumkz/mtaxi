import '/component/select_balance/select_balance_widget.dart';
import 'package:flutter/material.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/design/mtaxi_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/driver/home_driver/driver_bonus_card.dart';
import 'passenger_wallet.dart';

/// Reads the existing session contract; never adjusts balances locally.
class WalletPage extends StatefulWidget {
  const WalletPage({super.key, this.driver = false});
  final bool driver;
  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late Future<Map<String, dynamic>> _request;
  String tr(String ru, String kk) =>
      FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final result = await makeCloudCall('getSessionBootstrap', const {});
    if (result['success'] != true || result['user'] is! Map)
      throw StateError('Wallet unavailable');
    return Map<String, dynamic>.from(result);
  }

  void _refresh() => setState(() => _request = _load());
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.driver
                ? tr('Счёт водителя', 'Жүргізуші шоты')
                : tr('Кошелёк', 'Әмиян'))),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _request,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return MTaxiFeedback(
                  title: tr('Загружаем счёт', 'Шот жүктелуде'),
                  message: tr('Проверяем баланс на сервере.',
                      'Сервердегі теңгерім тексерілуде.'),
                  loading: true);
            if (snapshot.hasError || !snapshot.hasData)
              return MTaxiFeedback(
                  title: tr('Счёт недоступен', 'Шот қолжетімсіз'),
                  message: tr(
                      'Проверьте подключение и повторите. Деньги не списывались.',
                      'Байланысты тексеріп, қайталаңыз. Ақша алынған жоқ.'),
                  onRetry: _refresh);
            final data = snapshot.data!;
            final user = data['user'] as Map;
            final bonus =
                data[widget.driver ? 'driverBonus' : 'passengerBonus'] as Map?;
            return RefreshIndicator(
                onRefresh: () async {
                  _refresh();
                  await _request;
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                  children: [
                    MTaxiCard(
                        color: MTaxiDesign.ink,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr('Денежный баланс', 'Ақша теңгерімі'),
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 12),
                              Text(
                                  user['balance'] is num
                                      ? formatAppCurrency(
                                          (user['balance'] as num).toDouble())
                                      : tr('Недоступен', 'Қолжетімсіз'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 22),
                              SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      if (widget.driver) {
                                        await showModalBottomSheet<void>(
                                            context: context,
                                            isScrollControlled: true,
                                            useSafeArea: true,
                                            builder: (context) => Padding(
                                                padding: EdgeInsets.only(
                                                    bottom:
                                                        MediaQuery.viewInsetsOf(
                                                                context)
                                                            .bottom),
                                                child:
                                                    const SelectBalanceWidget()));
                                      } else {
                                        await showPassengerTopUp(context);
                                      }
                                      if (mounted) _refresh();
                                    },
                                    icon: const Icon(Icons.add),
                                    label: Text(tr('Пополнить через Kaspi',
                                        'Kaspi арқылы толықтыру')),
                                  )),
                            ])),
                    const SizedBox(height: 16),
                    MTaxiCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            const Icon(Icons.stars_outlined,
                                color: MTaxiDesign.teal),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(
                                    tr('Бонусный баланс', 'Бонус теңгерімі'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17)))
                          ]),
                          const SizedBox(height: 14),
                          Text(
                              bonus?['balance'] is num
                                  ? formatAppCurrency(
                                      (bonus!['balance'] as num).toDouble())
                                  : tr('Недоступен', 'Қолжетімсіз'),
                              style: const TextStyle(
                                  fontSize: 31, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          Text(widget.driver
                              ? tr(
                                  'Только на комиссию сервиса. Вывод недоступен.',
                                  'Тек сервис комиссиясына. Шығаруға болмайды.')
                              : tr(
                                  'Можно оплатить часть или всю следующую поездку — в пределах условий программы.',
                                  'Бағдарлама шарттары бойынша келесі сапарды ішінара немесе толық төлеуге болады.')),
                          if (!widget.driver) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                        builder: (_) =>
                                            PassengerBonusPage(bonus: bonus))),
                                icon: const Icon(Icons.arrow_forward),
                                label: Text(tr('Как работают бонусы',
                                    'Бонустар қалай жұмыс істейді'))),
                          ],
                        ])),
                    const SizedBox(height: 20),
                    if (widget.driver)
                      const DriverBonusCard()
                    else ...[
                      Text(tr('Оплата поездок', 'Сапар ақысын төлеу'),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      MTaxiCard(
                          child: Column(children: [
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.payments_outlined),
                            title: Text(tr('Наличными водителю',
                                'Жүргізушіге қолма-қол'))),
                        const Divider(),
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                                Icons.account_balance_wallet_outlined),
                            title: Text(
                                tr('Со счёта приложения', 'Қосымша шотынан'))),
                      ])),
                      const SizedBox(height: 16),
                      Text(tr(
                          'Способ оплаты выбирается при заказе. Деньги и бонусы резервируются после создания заказа, а не при открытии кошелька.',
                          'Төлем әдісі тапсырыс кезінде таңдалады. Ақша мен бонустар әмиян ашылғанда емес, тапсырыс жасалғанда резервтеледі.')),
                    ],
                  ],
                ));
          },
        ),
      );
}

class PassengerBonusPage extends StatelessWidget {
  const PassengerBonusPage({super.key, required this.bonus});
  final Map? bonus;
  @override
  Widget build(BuildContext context) {
    String tr(String ru, String kk) =>
        FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
    return Scaffold(
        appBar: AppBar(title: Text(tr('Мои бонусы', 'Менің бонустарым'))),
        body: ListView(padding: const EdgeInsets.all(22), children: [
          MTaxiCard(
              color: MTaxiDesign.gold,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Бонусный баланс', 'Бонус теңгерімі'),
                        style: const TextStyle(color: MTaxiDesign.ink)),
                    const SizedBox(height: 12),
                    Text(
                        bonus?['balance'] is num
                            ? formatAppCurrency(
                                (bonus!['balance'] as num).toDouble())
                            : '—',
                        style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: MTaxiDesign.ink)),
                  ])),
          const SizedBox(height: 24),
          Text(tr('Больше поездок — больше бонусов', 'Көп сапар — көп бонус'),
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Text(bonus?['percent'] is num
              ? tr('Возвращаем ${bonus!['percent']}% за завершённую поездку.',
                  'Аяқталған сапар үшін ${bonus!['percent']}% қайтарамыз.')
              : tr('Условия начисления временно недоступны.',
                  'Есептеу шарттары уақытша қолжетімсіз.')),
          const SizedBox(height: 16),
          Text(bonus?['maxSpendPercent'] is num
              ? tr(
                  'Оплачивайте бонусами до ${bonus!['maxSpendPercent']}% поездки.',
                  'Сапардың ${bonus!['maxSpendPercent']}%-на дейін бонуспен төлеңіз.')
              : tr('Лимит оплаты временно недоступен.',
                  'Төлем шегі уақытша қолжетімсіз.')),
          const SizedBox(height: 16),
          Text(tr(
              'Использование бонусов выбирается перед заказом. Бонусы нельзя вывести деньгами.',
              'Бонустарды пайдалану тапсырыс алдында таңдалады. Бонустарды ақшалай шығаруға болмайды.')),
        ]));
  }
}
