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

  Future<void> _act(String method, String question) async {
    final confirmed = await showDialog<bool>(
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
          method, {'paymentId': widget.payment['paymentId']});
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Kaspi: ${widget.payment['kaspiPhone'] ?? ''}'),
      Text(widget.payment['invoiceStatus'] == 'sent'
          ? 'Счёт выставлен — ожидается оплата'
          : 'Нужно выставить счёт'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (widget.payment['invoiceStatus'] != 'sent')
          OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _act('adminMarkKaspiInvoiceSent',
                      'Счёт уже выставлен в Kaspi?'),
              child: const Text('Счёт выставлен')),
        FilledButton(
            onPressed: _busy
                ? null
                : () => _act('confirmDriverTopUpPayment',
                    'Вы получили ${widget.payment['amount']} ₸ от водителя? Подтверждение зачислит деньги на его баланс.'),
            child: const Text('Подтвердить оплату')),
        TextButton(
            onPressed: _busy
                ? null
                : () => _act('failDriverTopUpPayment',
                    'Отклонить заявку без зачисления денег?'),
            child: const Text('Отклонить')),
      ]),
      if (_error != null)
        Text(_error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ]);
  }
}
