import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '/design/mtaxi_theme.dart';
import '/flutter_flow/internationalization.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '/auth/backend_auth/auth_util.dart';
import '/backend/backend_calls/backend_calls.dart';

class SelectBalanceWidget extends StatefulWidget {
  const SelectBalanceWidget({super.key, this.passenger = false});
  final bool passenger;
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
  bool _restoring = true;
  bool _uncertain = false;
  late final String _storageKey;

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageKey,
        jsonEncode({
          'key': _requestKey,
          'amount': _amount.text,
          'phone': _phone.text,
          'fingerprint': _fingerprint,
          'paymentId': _paymentId,
          'status': _status
        }));
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final saved = jsonDecode(raw) as Map;
        if (!mounted) return;
        _requestKey = saved['key'] as String;
        _amount.text = saved['amount'] as String;
        _phone.text = saved['phone'] as String;
        _fingerprint = saved['fingerprint'] as String?;
        _paymentId = saved['paymentId'] as String?;
        _status = saved['status'] as String? ?? 'pending';
        _uncertain = _paymentId == null;
        if (_paymentId != null) {
          _timer =
              Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
        }
      }
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _storageKey =
        'mtaxi_topup_${currentUserUid}_${widget.passenger ? 'passenger' : 'driver'}';
    _phone.text = currentUserDocument?.phoneNumber ?? '';
    _restore();
  }

  Future<void> _submit() async {
    if (_busy || _restoring) return;
    final amount = double.tryParse(_amount.text.replaceAll(',', '.').trim());
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        (widget.passenger &&
            (amount != amount.truncateToDouble() || amount > 1000000))) {
      setState(() => _error = widget.passenger
          ? 'Введите целую сумму от 1 до 1 000 000 ₸'
          : 'Введите корректную сумму');
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
      // Persist before sending so closing/reopening after a lost response reuses the same request.
      _uncertain = true;
      await _persist();
      final response = await makeCloudCall(
          widget.passenger
              ? 'createPassengerTopUpPayment'
              : 'createDriverTopUpPayment',
          {
            'amount': amount,
            'kaspiPhone': _phone.text.trim(),
            'method': 'kaspi_manual',
            'idempotencyKey': _requestKey,
          });
      if (response['success'] != true) {
        final code = (response['code'] ?? '').toString();
        if (code == 'PAYMENT_AMOUNT_INVALID' ||
            code == 'KASPI_PHONE_INVALID' ||
            code == 'DRIVER_PROFILE_REQUIRED') {
          _uncertain = false;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_storageKey);
        }
        throw Exception(response['error'] ??
            'Ответ не подтверждён. Повторите проверку этой заявки.');
      }
      if (!mounted) return;
      setState(() {
        _paymentId = response['paymentId']?.toString();
        _status = response['paymentStatus']?.toString() ?? 'pending';
        _uncertain = false;
      });
      await _persist();
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
    setState(() => _busy = true);
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
      if (_status == 'success' || _status == 'failed') {
        _timer?.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_storageKey);
      }
    } catch (_) {
      if (mounted)
        setState(() =>
            _error = 'Не удалось обновить статус. Нажмите «Проверить оплату».');
    } finally {
      if (mounted) setState(() => _busy = false);
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
    String tr(String ru, String kk) =>
        FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
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
                const MTaxiBrand(),
                const SizedBox(height: 28),
                Text(tr('Пополнить счёт', 'Шотты толықтыру'),
                    style: const TextStyle(
                        fontSize: 31, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                MTaxiCard(
                    child: Row(children: [
                  const CircleAvatar(
                      backgroundColor: Color(0xFFE84339),
                      foregroundColor: Colors.white,
                      child: Text('K',
                          style: TextStyle(fontWeight: FontWeight.w700))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          tr('Kaspi · счёт от администратора',
                              'Kaspi · әкімші жіберетін шот'),
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                ])),
                const SizedBox(height: 16),
                if (_paymentId == null) ...[
                  Text(tr(
                      '1. Укажите сумму и номер Kaspi.\n2. Администратор выставит счёт.\n3. После оплаты и проверки деньги поступят на баланс.',
                      '1. Сома мен Kaspi нөмірін көрсетіңіз.\n2. Әкімші шот жібереді.\n3. Төлем тексерілгеннен кейін ақша теңгерімге түседі.')),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      enabled: !_busy && !_uncertain && !_restoring,
                      decoration: const InputDecoration(
                          labelText: 'Номер Kaspi', hintText: '+7XXXXXXXXXX')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      enabled: !_busy && !_uncertain && !_restoring,
                      decoration: const InputDecoration(
                          labelText: 'Сумма пополнения, ₸')),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: _busy || _restoring ? null : _submit,
                      child: Text(_busy
                          ? tr('Отправляем…', 'Жіберілуде…')
                          : _uncertain
                              ? tr('Повторить проверку заявки',
                                  'Өтінімді қайта тексеру')
                              : tr('Запросить счёт Kaspi',
                                  'Kaspi шотын сұрау'))),
                ] else ...[
                  Text(_status == 'success'
                      ? 'Оплата подтверждена. Деньги зачислены на баланс.'
                      : _status == 'failed'
                          ? 'Заявка отклонена администратором.'
                          : 'Заявка отправлена. Ожидайте счёт в Kaspi на номер ${_phone.text}. После оплаты администратор подтвердит пополнение.'),
                  if (_status == 'pending')
                    TextButton(
                        onPressed: _busy ? null : _refresh,
                        child: const Text('Проверить оплату')),
                ],
                if (_uncertain)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(tr(
                          'Ответ ещё не подтверждён. Повторная проверка использует ту же заявку; сумма и номер сохранены.',
                          'Жауап әлі расталмады. Қайта тексеру сол өтінімді қолданады; сома мен нөмір сақталған.'))),
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
