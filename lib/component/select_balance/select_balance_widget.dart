import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '/auth/backend_auth/auth_util.dart';
import '/backend/backend_calls/backend_calls.dart';

class SelectBalanceWidget extends StatefulWidget {
  const SelectBalanceWidget({super.key});
  @override
  State<SelectBalanceWidget> createState() => _SelectBalanceWidgetState();
}

class _SelectBalanceWidgetState extends State<SelectBalanceWidget> {
  final _amount = TextEditingController();
  final _phone = TextEditingController();
  String _requestKey = const Uuid().v4();
  String? _fingerprint;
  String? _paymentId;
  String? _error;
  String _status = 'pending';
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _phone.text = currentUserDocument?.phoneNumber ?? '';
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.').trim());
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _error = 'Введите корректную сумму');
      return;
    }
    final fingerprint = '$amount:${_phone.text.trim()}';
    if (_fingerprint != null && _fingerprint != fingerprint) {
      _requestKey = const Uuid().v4();
    }
    _fingerprint = fingerprint;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await makeCloudCall('createDriverTopUpPayment', {
        'amount': amount,
        'kaspiPhone': _phone.text.trim(),
        'method': 'kaspi_manual',
        'idempotencyKey': _requestKey,
      });
      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Не удалось отправить заявку');
      }
      if (!mounted) return;
      setState(() {
        _paymentId = response['paymentId']?.toString();
        _status = response['paymentStatus']?.toString() ?? 'pending';
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (_busy || _paymentId == null) return;
    _busy = true;
    try {
      final response = await makeCloudCall(
          'getDriverTopUpPaymentStatus', {'paymentId': _paymentId});
      if (response['success'] != true)
        throw StateError('Не удалось проверить заявку');
      if (mounted)
        setState(() {
          _status = response['paymentStatus'].toString();
          _error = null;
        });
      if (_status != 'pending') _timer?.cancel();
    } catch (_) {
      if (mounted)
        setState(() =>
            _error = 'Не удалось обновить статус. Нажмите «Проверить оплату».');
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amount.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
          child: Center(
              child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Пополнение через Kaspi',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                if (_paymentId == null) ...[
                  const Text(
                      'Укажите номер Kaspi и сумму. Администратор выставит счёт; баланс пополнится после проверки оплаты.'),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                          labelText: 'Номер Kaspi',
                          hintText: '+7XXXXXXXXXX',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      enabled: !_busy,
                      decoration: const InputDecoration(
                          labelText: 'Сумма пополнения, ₸',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: _busy ? null : _submit,
                      child:
                          Text(_busy ? 'Отправляем…' : 'Запросить счёт Kaspi')),
                ] else ...[
                  Text(_status == 'success'
                      ? 'Оплата подтверждена. Деньги зачислены на баланс.'
                      : _status == 'failed'
                          ? 'Заявка отклонена администратором.'
                          : 'Заявка отправлена. Ожидайте счёт в Kaspi на номер ${_phone.text}. После оплаты администратор подтвердит пополнение.'),
                  if (_status == 'pending')
                    TextButton(
                        onPressed: _refresh,
                        child: const Text('Проверить оплату')),
                ],
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Закрыть')),
              ]),
        ),
      ))),
    );
  }
}
