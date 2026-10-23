import '/auth/backend_auth/auth_util.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/design/mtaxi_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';

class MeOrderWidget extends StatefulWidget {
  const MeOrderWidget({super.key, this.driver});
  final bool? driver;
  static String routeName = 'meOrder';
  static String routePath = '/meOrder';
  @override
  State<MeOrderWidget> createState() => _MeOrderWidgetState();
}

class _MeOrderWidgetState extends State<MeOrderWidget> {
  late Future<List<Map<String, dynamic>>> _orders;
  int _filter = 0;
  String tr(String ru, String kk) =>
      FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
  @override
  void initState() {
    super.initState();
    _orders = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await makeCloudCall(
        'listMyOrders', {'includeClosed': true, 'limit': 200});
    if (response['success'] != true || response['orders'] is! List)
      throw StateError('History unavailable');
    final driver = widget.driver ??
        (!FFAppState().isPassengerModeForced &&
            UserModeResolver.canOpenDriverScreens(currentUserDocument));
    final uid = currentUserUid.isNotEmpty
        ? currentUserUid
        : currentUserDocument?.reference.id;
    return (response['orders'] as List)
        .whereType<Map>()
        .where((order) =>
            uid == null || order[driver ? 'driverId' : 'passengerId'] == uid)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _retry() => setState(() => _orders = _load());
  int _status(Map order) => (order['status'] as num?)?.toInt() ?? -1;
  String _label(int status) => switch (status) {
        0 => tr('Поиск водителя', 'Жүргізуші ізделуде'),
        1 || 2 => tr('Водитель в пути', 'Жүргізуші жолда'),
        3 => tr('Водитель на месте', 'Жүргізуші келді'),
        4 => tr('Поездка началась', 'Сапар басталды'),
        5 => tr('Завершена', 'Аяқталды'),
        6 => tr('Отменена', 'Болдырылмады'),
        7 => tr('Водитель не найден', 'Жүргізуші табылмады'),
        _ => tr('Статус уточняется', 'Күй нақтылануда'),
      };
  String _address(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return tr('Адрес не указан', 'Мекенжай көрсетілмеген');
    if (RegExp(
            r'^(?:(?:координаты|coordinates)\s*:\s*)?[-+]?\d{1,2}(?:\.\d+)?\s*,\s*[-+]?\d{1,3}(?:\.\d+)?$',
            caseSensitive: false)
        .hasMatch(text)) return tr('Адрес уточняется', 'Мекенжай нақтылануда');
    return text;
  }

  Widget _route(Map order) => Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.radio_button_checked,
              color: MTaxiDesign.teal, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(_address(order['ot'])))
        ]),
        const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(height: 16, child: VerticalDivider(width: 1)))),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.location_on_outlined, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(_address(order['kuda'])))
        ]),
      ]);
  String _fare(Map order) => order['price'] is num
      ? formatAppCurrency((order['price'] as num).toDouble())
      : '—';
  String _date(Map order) {
    final date = DateTime.tryParse(
        (order['createdAt'] ?? order['date'] ?? '').toString());
    return date == null
        ? tr('Дата не указана', 'Күні көрсетілмеген')
        : dateTimeFormat('d MMM, HH:mm', date.toLocal(),
            locale: FFLocalizations.of(context).languageCode);
  }

  Widget _badge(Map order) => DecoratedBox(
      decoration: BoxDecoration(
          color: MTaxiDesign.teal.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(20)),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(_label(_status(order)),
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.secondary))));
  void _details(Map<String, dynamic> order) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (context) => Scaffold(
                appBar: AppBar(
                    title: Text(tr('Детали поездки', 'Сапар мәліметтері'))),
                body: ListView(padding: const EdgeInsets.all(22), children: [
                  Text(_date(order),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Align(alignment: Alignment.centerLeft, child: _badge(order)),
                  const SizedBox(height: 24),
                  MTaxiCard(child: _route(order)),
                  const SizedBox(height: 16),
                  MTaxiCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(tr('Стоимость поездки', 'Сапар құны')),
                        const SizedBox(height: 8),
                        Text(_fare(order),
                            style: const TextStyle(
                                fontSize: 31, fontWeight: FontWeight.w700)),
                        if ((order['driverName'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty) ...[
                          const Divider(height: 28),
                          Text(order['driverName'].toString()),
                          Text([order['driverCar'], order['driverPlate']]
                              .where((e) =>
                                  e != null && e.toString().trim().isNotEmpty)
                              .join(' · '))
                        ],
                        if (order['paymentMode'] != null) ...[
                          const Divider(height: 28),
                          Text(order['paymentMode'] == 'wallet'
                              ? tr('Оплата со счёта приложения',
                                  'Қосымша шотынан төлеу')
                              : tr('Оплата наличными', 'Қолма-қол төлеу'))
                        ],
                        if (order['passengerBonusUsed'] is num &&
                            (order['passengerBonusUsed'] as num) > 0)
                          Text(tr(
                              'Использовано бонусов: ${order['passengerBonusUsed']} ₸',
                              'Пайдаланылған бонустар: ${order['passengerBonusUsed']} ₸')),
                      ])),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                      onPressed: () =>
                          context.pushNamed(SupportChatWidget.routeName),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: Text(
                          tr('Обратиться в поддержку', 'Қолдауға жүгіну'))),
                ]),
              )));
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('История поездок', 'Сапарлар тарихы'))),
        body: Column(children: [
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              child: Row(children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                          selected: _filter == i,
                          selectedColor: MTaxiDesign.gold,
                          label: Text([
                            tr('Все', 'Барлығы'),
                            tr('Завершённые', 'Аяқталған'),
                            tr('Отменённые', 'Болдырылмаған')
                          ][i]),
                          onSelected: (_) => setState(() => _filter = i)))
              ])),
          Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _orders,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done)
                      return MTaxiFeedback(
                          title: tr('Загружаем поездки', 'Сапарлар жүктелуде'),
                          message: '',
                          loading: true);
                    if (snapshot.hasError)
                      return MTaxiFeedback(
                          title: tr('История недоступна', 'Тарих қолжетімсіз'),
                          message: tr('Проверьте подключение к сети.',
                              'Желіге қосылуды тексеріңіз.'),
                          onRetry: _retry);
                    final orders = (snapshot.data ?? [])
                        .where((e) =>
                            _filter == 0 ||
                            (_filter == 1
                                ? _status(e) == 5
                                : [6, 7].contains(_status(e))))
                        .toList();
                    if (orders.isEmpty)
                      return MTaxiFeedback(
                          title: tr('Здесь пока нет поездок',
                              'Мұнда әзірге сапар жоқ'),
                          message: tr('Ваши поездки появятся в истории.',
                              'Сапарларыңыз тарихта пайда болады.'),
                          icon: Icons.route_outlined);
                    return RefreshIndicator(
                        onRefresh: () async {
                          _retry();
                          await _orders;
                        },
                        child: ListView.separated(
                            padding: const EdgeInsets.all(22),
                            itemCount: orders.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final order = orders[i];
                              return Semantics(
                                  button: true,
                                  child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () => _details(order),
                                      child: MTaxiCard(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(_date(order),
                                                style: const TextStyle(
                                                    fontSize: 12)),
                                            const SizedBox(height: 16),
                                            _route(order),
                                            const SizedBox(height: 18),
                                            Wrap(
                                                spacing: 16,
                                                runSpacing: 8,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  Text(_fare(order),
                                                      style: const TextStyle(
                                                          fontSize: 22,
                                                          fontWeight:
                                                              FontWeight.w700)),
                                                  _badge(order)
                                                ]),
                                          ]))));
                            }));
                  })),
        ]),
      );
}
