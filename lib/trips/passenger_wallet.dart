import '/flutter_flow/flutter_flow_util.dart';
import '/design/fare_composer.dart';
import '/component/select_balance/select_balance_widget.dart';
import 'package:flutter/material.dart';
import '/backend/backend_calls/backend_calls.dart';

class FareChoice {
  const FareChoice(this.price, this.wallet, this.bonuses);
  final int price;
  final bool wallet;
  final bool bonuses;
}

Future<void> showPassengerTopUp(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: const SelectBalanceWidget(passenger: true),
      ),
    );

class PassengerWalletButton extends StatelessWidget {
  const PassengerWalletButton({super.key});
  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        heroTag: 'passengerWallet',
        icon: const Icon(Icons.account_balance_wallet_outlined),
        label: const Text('Мой счёт'),
        onPressed: () async {
          final r = await makeCloudCall('getSessionBootstrap', const {});
          if (!context.mounted) return;
          if (r['success'] != true) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Не удалось загрузить баланс')));
            return;
          }
          final user = r['user'] as Map? ?? {};
          final bonus = r['passengerBonus'] as Map? ?? {};
          await showDialog<void>(
              context: context,
              builder: (dialog) => AlertDialog(
                      title: const Text('Личный счёт'),
                      content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Деньги: ${user['balance'] ?? 0} ₸',
                                style: Theme.of(context).textTheme.titleLarge),
                            Text('Бонусы: ${bonus['balance'] ?? 0} ₸',
                                style: Theme.of(context).textTheme.titleLarge),
                            Text(
                                'Возвращаем ${bonus['percent'] ?? 2}% бонусами за завершённые поездки.'),
                            Text(
                                'Бонусами можно оплатить до ${bonus['maxSpendPercent'] ?? 100}% поездки.'),
                          ]),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(dialog),
                            child: const Text('Закрыть')),
                        FilledButton(
                            onPressed: () {
                              Navigator.pop(dialog);
                              showPassengerTopUp(context);
                            },
                            child: const Text('Пополнить через Kaspi'))
                      ]));
        },
      );
}

Future<FareChoice?> choosePassengerFare(BuildContext context) async {
  final r = await makeCloudCall('getSessionBootstrap', const {});
  if (!context.mounted) return null;
  if (r['success'] != true) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Не удалось проверить счёт. Повторите выбор цены после восстановления связи.')));
    return null;
  }
  return showModalBottomSheet<FareChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FareComposer(
        from: FFAppState().otkkudaString,
        to: FFAppState().kudaString,
        user: r['user'] as Map? ?? {},
        bonus: r['passengerBonus'] as Map? ?? {}),
  );
}
