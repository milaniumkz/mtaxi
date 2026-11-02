import 'package:flutter/material.dart';
import '/backend/backend_calls/backend_calls.dart';

class KaspiPaymentActions extends StatefulWidget {
  const KaspiPaymentActions(
      {super.key, required this.payment, required this.onChanged});
  final Map<String, dynamic> payment;
  final VoidCallback onChanged;
  @override
  State<KaspiPaymentActions> createState() => _KaspiPaymentActionsState();
}

class _KaspiPaymentActionsState extends State<KaspiPaymentActions> {
  bool _busy = false;
  String? _error;

  Future<void> _act(String method, String? question,
      {bool sendInvoice = false}) async {
    final confirmed = question == null
        ? true
        : await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('Заявка Kaspi'),
                  content: Text(question),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Отмена')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Подтвердить'))
                  ],
                ));
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await makeCloudCall(
          method,
          {
            'paymentId': widget.payment['paymentId'],
            if (sendInvoice) 'confirm': true
          },
          timeout: const Duration(seconds: 45));
      if (response['success'] != true)
        throw Exception(response['error'] ?? 'Не удалось сохранить');
      widget.onChanged();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final posAttempt = widget.payment['kaspiPosAttemptId'] != null;
    final posOperation = widget.payment['kaspiPosOperationId'];
    final bankState = widget.payment['kaspiPosBankState'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Kaspi: ${widget.payment['kaspiPhone'] ?? ''}'),
      Text(widget.payment['invoiceStatus'] == 'sent'
          ? 'Счёт выставлен — ожидается оплата'
          : 'Нужно выставить счёт'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (!posAttempt && widget.payment['invoiceStatus'] != 'sent')
          OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _act('adminKaspiPosSendInvoice',
                      'Выставить реальный счёт Kaspi на ${widget.payment['amount']} ₸ для ${widget.payment['kaspiPhone']}? Повторное выставление этой заявки будет заблокировано.',
                      sendInvoice: true),
              child: const Text('Выставить счёт через Kaspi Pay')),
        if (posOperation != null)
          OutlinedButton(
              onPressed:
                  _busy ? null : () => _act('adminKaspiPosCheckInvoice', null),
              child: const Text('Проверить оплату в Kaspi')),
        if (!posAttempt && widget.payment['invoiceStatus'] != 'sent')
          OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _act('adminMarkKaspiInvoiceSent',
                      'Счёт уже выставлен в Kaspi?'),
              child: const Text('Счёт выставлен')),
        FilledButton(
            onPressed: _busy || (posAttempt && bankState != 'paid')
                ? null
                : () => _act('confirmDriverTopUpPayment',
                    'Вы получили ${widget.payment['amount']} ₸ от пользователя? Подтверждение зачислит деньги на его денежный счёт.'),
            child: const Text('Подтвердить оплату')),
        TextButton(
            onPressed: _busy ||
                    (posAttempt &&
                        !['cancelled', 'failed', 'expired'].contains(bankState))
                ? null
                : () => _act('failDriverTopUpPayment',
                    'Отклонить заявку без зачисления денег?'),
            child: const Text('Отклонить')),
      ]),
      if (posAttempt) ...[
        const SizedBox(height: 8),
        Text(widget.payment['kaspiPosCreateState'] == 'unknown' ||
                widget.payment['kaspiPosCreateState'] == 'creating'
            ? 'Результат выставления не подтверждён. Проверьте историю в Kaspi Pay; не создавайте второй счёт.'
            : 'Статус банка: ${({
                  'paid': 'Оплачен',
                  'pending': 'Ожидается оплата',
                  'cancelled': 'Отменён',
                  'failed': 'Отклонён',
                  'expired': 'Истёк'
                })[bankState] ?? 'Не подтверждён'}'),
        const Text(
            'Проверка не зачисляет деньги автоматически. Для зачисления нужен подтверждённый статус оплаты и отдельное подтверждение администратора. Отмена счёта пока выполняется в Kaspi Pay, затем проверьте статус здесь.'),
      ],
      if (_error != null)
        Text(_error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ]);
  }
}
