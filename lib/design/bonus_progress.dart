import 'package:flutter/material.dart';
import '/flutter_flow/internationalization.dart';
import '/flutter_flow/flutter_flow_util.dart' show formatAppCurrency;
import 'mtaxi_theme.dart';

class BonusProgress extends StatelessWidget {
  const BonusProgress({super.key, required this.data, this.detailed = false});
  final Map<String, dynamic> data;
  final bool detailed;
  @override
  Widget build(BuildContext context) {
    String tr(String ru, String kk) =>
        FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
    final enabled = data['enabled'] == true;
    final count = (data['completedOrders'] as num?)?.toInt();
    final target = (data['targetOrders'] as num?)?.toInt();
    final reward = data['reward'] as num?;
    final balance = data['balance'] as num?;
    final progress = count != null && target != null && target > 0
        ? (count / target).clamp(0.0, 1.0).toDouble()
        : null;
    if (!detailed)
      return MTaxiCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
            Text(
                enabled
                    ? tr('Акция: ${count ?? '—'}/${target ?? '—'} заказов',
                        'Акция: ${count ?? '—'}/${target ?? '—'} тапсырыс')
                    : tr('Акция отключена', 'Акция өшірілген'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (enabled && progress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress, minHeight: 5)
            ],
            const SizedBox(height: 8),
            Text(
                data['awarded'] == true
                    ? tr('Награда за сегодня начислена',
                        'Бүгінгі сыйақы есептелді')
                    : reward == null
                        ? tr('Награда уточняется', 'Сыйақы нақтылануда')
                        : tr(
                            'Награда ${formatAppCurrency(reward.toDouble())} · до 00:00',
                            'Сыйақы ${formatAppCurrency(reward.toDouble())} · 00:00-ге дейін'),
                style: const TextStyle(fontSize: 12)),
          ]));
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          MTaxiCard(
              color: detailed ? MTaxiDesign.gold : null,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Бонусы водителя', 'Жүргізуші бонустары'),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: detailed ? MTaxiDesign.ink : null)),
                    const SizedBox(height: 12),
                    Text(
                        balance == null
                            ? '—'
                            : formatAppCurrency(balance.toDouble()),
                        style: TextStyle(
                            fontSize: detailed ? 36 : 25,
                            fontWeight: FontWeight.w700,
                            color: detailed ? MTaxiDesign.ink : null)),
                    const SizedBox(height: 10),
                    Text(
                        tr('Только на комиссию сервиса. Вывод недоступен.',
                            'Тек сервис комиссиясына. Шығаруға болмайды.'),
                        style: TextStyle(
                            color: detailed ? MTaxiDesign.ink : null)),
                  ])),
          const SizedBox(height: 16),
          MTaxiCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    enabled
                        ? tr('Акция на сегодня', 'Бүгінгі акция')
                        : tr('Акция отключена', 'Акция өшірілген'),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                if (enabled) ...[
                  const SizedBox(height: 18),
                  if (detailed)
                    Center(
                        child: SizedBox(
                            width: 112,
                            height: 112,
                            child:
                                Stack(alignment: Alignment.center, children: [
                              SizedBox.expand(
                                  child: CircularProgressIndicator(
                                      value: progress,
                                      strokeWidth: 7,
                                      backgroundColor: MTaxiDesign.surface,
                                      color: MTaxiDesign.gold)),
                              Text('${count ?? '—'}/${target ?? '—'}',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700)),
                            ])))
                  else
                    LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: MTaxiDesign.surface),
                  const SizedBox(height: 16),
                  Text(tr(
                      'Выполнено ${count ?? '—'} из ${target ?? '—'} заказов',
                      '${target ?? '—'} тапсырыстың ${count ?? '—'} орындалды')),
                  const SizedBox(height: 10),
                  if (reward != null)
                    Text(
                        tr('Награда: ${formatAppCurrency(reward.toDouble())}',
                            'Сыйақы: ${formatAppCurrency(reward.toDouble())}'),
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                  if (data['awarded'] == true) ...[
                    const SizedBox(height: 10),
                    Text(tr(
                        'Бонус за сегодня начислен', 'Бүгінгі бонус есептелді'))
                  ],
                ],
                const SizedBox(height: 12),
                Text(tr(
                    'Прогресс обнуляется в 00:00 по времени Казахстана (Asia/Almaty). Накопленные бонусы сохраняются.',
                    'Нәтиже Қазақстан уақытымен (Asia/Almaty) 00:00-де жаңарады. Жиналған бонустар сақталады.')),
              ])),
        ]);
  }
}
