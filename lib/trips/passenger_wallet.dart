import 'package:flutter/material.dart';
import '/backend/backend_calls/backend_calls.dart';

class FareChoice {
  const FareChoice(this.price, this.wallet, this.bonuses);
  final int price;
  final bool wallet;
  final bool bonuses;
}

Future<void> showPassengerTopUp(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final amount = TextEditingController();
  final phone = TextEditingController();
  String? error;
  bool saving = false;
  await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
                title: const Text('Пополнить личный счёт'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                      'Введите сумму и номер Kaspi. Администратор выставит счёт, а после проверки оплаты зачислит деньги.'),
                  TextField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Сумма, ₸')),
                  TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(labelText: 'Номер Kaspi, +7…')),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ]),
                actions: [
                  TextButton(
                      onPressed: saving ? null : () => Navigator.pop(dialog),
                      child: const Text('Отмена')),
                  FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final value = int.tryParse(amount.text);
                              if (value == null || value <= 0) {
                                update(() => error = 'Введите сумму');
                                return;
                              }
                              update(() {
                                saving = true;
                                error = null;
                              });
                              final result = await makeCloudCall(
                                  'createPassengerTopUpPayment', {
                                'amount': value,
                                'kaspiPhone': phone.text,
                                'idempotencyKey':
                                    'passenger-${DateTime.now().microsecondsSinceEpoch}'
                              });
                              if (!dialog.mounted) return;
                              if (result['success'] == true) {
                                Navigator.pop(dialog);
                                messenger.showSnackBar(const SnackBar(
                                    content: Text(
                                        'Заявка отправлена. Ожидайте счёт в Kaspi.')));
                              } else {
                                update(() {
                                  saving = false;
                                  error = result['error']?.toString() ??
                                      'Не удалось отправить заявку';
                                });
                              }
                            },
                      child: Text(saving ? 'Отправляем…' : 'Отправить заявку'))
                ],
              )));
  amount.dispose();
  phone.dispose();
}

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
  if (!context.mounted || r['success'] != true) return null;
  final bonus = r['passengerBonus'] as Map? ?? {};
  final user = r['user'] as Map? ?? {};
  final price = TextEditingController(text: '500');
  bool wallet = false, bonuses = false;
  String? error;
  final result = await showDialog<FareChoice>(
      context: context,
      builder: (dialog) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
                title: const Text('Предложите свою цену'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: price,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Цена поездки, ₸',
                          helperText: 'Минимум 500 ₸ в любом посёлке')),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Оплатить со счёта приложения'),
                      subtitle: Text('Деньги: ${user['balance'] ?? 0} ₸'),
                      value: wallet,
                      onChanged: (v) => update(() => wallet = v)),
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Использовать бонусы'),
                      subtitle: Text(
                          'Доступно: ${bonus['balance'] ?? 0} ₸; до ${bonus['maxSpendPercent'] ?? 100}% поездки'),
                      value: bonuses,
                      onChanged: (v) => update(() => bonuses = v ?? false)),
                  const Text(
                      'Водитель может принять вашу цену или предложить свою. До вашего согласия другая цена не применяется.'),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('Отмена')),
                  FilledButton(
                      onPressed: () {
                        final value = int.tryParse(price.text);
                        if (value == null || value < 500 || value > 10000000) {
                          update(() => error = 'Введите целую цену от 500 ₸');
                          return;
                        }
                        Navigator.pop(
                            dialog, FareChoice(value, wallet, bonuses));
                      },
                      child: const Text('Искать водителя'))
                ],
              )));
  price.dispose();
  return result;
}
