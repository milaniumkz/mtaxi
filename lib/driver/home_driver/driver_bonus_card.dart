import 'dart:async';
import 'package:flutter/material.dart';
import '/backend/backend_calls/backend_calls.dart';

class DriverBonusCard extends StatefulWidget {
  const DriverBonusCard({super.key});

  @override
  State<DriverBonusCard> createState() => _DriverBonusCardState();
}

class _DriverBonusCardState extends State<DriverBonusCard> {
  Timer? _timer;
  Map<String, dynamic>? _bonus;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final response = await makeCloudCall('getSessionBootstrap', const {});
      if (response['success'] != true || response['driverBonus'] is! Map) {
        throw StateError('Bonus status unavailable');
      }
      if (mounted) {
        setState(() {
          _bonus = Map<String, dynamic>.from(response['driverBonus'] as Map);
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bonus = _bonus;
    final enabled = bonus?['enabled'] == true;
    final count = (bonus?['completedOrders'] as num?)?.toInt() ?? 0;
    final target = (bonus?['targetOrders'] as num?)?.toInt() ?? 0;
    final balance = (bonus?['balance'] as num?) ?? 0;
    final reward = (bonus?['reward'] as num?) ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Бонусы: ${balance.toStringAsFixed(0)} ₸',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            if (_failed)
              TextButton(
                  onPressed: _refresh,
                  child: const Text('Не удалось обновить бонусы. Повторить'))
            else if (bonus == null)
              const Text('Загружаем условия акции…')
            else if (enabled) ...[
              Text(
                  'Сегодня: $count из $target заказов — ${reward.toStringAsFixed(0)} ₸'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                  value: target > 0
                      ? (count / target).clamp(0.0, 1.0).toDouble()
                      : 0),
              if (bonus['awarded'] == true)
                const Text('Бонус за сегодня начислен!'),
              const Text('Прогресс обнуляется в 00:00 по времени Казахстана.'),
            ] else
              const Text('Сейчас акция отключена'),
            const Text(
                'Бонусы сохраняются и оплачивают комиссию сервиса. Вывод недоступен.'),
          ],
        ),
      ),
    );
  }
}
