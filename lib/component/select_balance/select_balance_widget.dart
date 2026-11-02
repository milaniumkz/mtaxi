import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
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

class _SelectBalanceWidgetState extends State<SelectBalanceWidget>
    with WidgetsBindingObserver {
  final _amount = TextEditingController();
  final _phone = TextEditingController();
  String _requestKey = const Uuid().v4();
  String? _fingerprint;
  String? _paymentId;
  String? _paymentUrl;
  String? _paymentProvider;
  String? _error;
  String _status = 'pending';
  bool _automatic = false;
  String? _bankState, _invoiceStatus, _createState, _automationError;
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
          'paymentUrl': _paymentUrl,
          'paymentProvider': _paymentProvider,
          'status': _status,
          'automatic': _automatic
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
        _paymentUrl = saved['paymentUrl'] as String?;
        _paymentProvider = saved['paymentProvider'] as String?;
        _status = saved['status'] as String? ?? 'pending';
        _automatic = saved['automatic'] == true;
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
      if (mounted) {
        setState(() => _restoring = false);
        if (_paymentId != null) unawaited(_refresh());
      }
    }
  }

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
            'method': 'kaspi_qr',
            'idempotencyKey': _requestKey,
          },
          timeout: const Duration(seconds: 45));
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
        _readInvoiceStatus(response);
        _uncertain = false;
      });
      await _persist();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
      if (_status == 'pending' && _paymentUrl?.isNotEmpty == true)
        await _openKaspi();
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
          _readInvoiceStatus(response);
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

  void _readInvoiceStatus(Map<String, dynamic> response) {
    _automatic = response['automatic'] == true;
    _paymentUrl = response['paymentUrl']?.toString() ?? _paymentUrl;
    _paymentProvider =
        response['paymentProvider']?.toString() ?? _paymentProvider;
    _bankState = response['bankState']?.toString();
    _invoiceStatus = response['invoiceStatus']?.toString();
    _createState = response['invoiceCreateState']?.toString();
    _automationError = response['automationError']?.toString();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _paymentId != null)
      unawaited(_refresh());
  }

  Future<void> _openKaspi() async {
    final url = Uri.tryParse(_paymentUrl ?? '');
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'pay.kaspi.kz' ||
        url.userInfo.isNotEmpty) return;
    try {
      final opened = await launchUrl(url,
          mode: kIsWeb
              ? LaunchMode.platformDefault
              : LaunchMode.externalApplication,
          webOnlyWindowName: '_self');
      if (!opened && mounted)
        setState(() => _error =
            'Не удалось открыть Kaspi. Скопируйте ссылку или попробуйте ещё раз.');
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'Не удалось открыть Kaspi. Скопируйте ссылку или попробуйте ещё раз.');
    }
  }

  String _paymentMessage() {
    if (_status == 'success')
      return 'Счёт оплачен. Деньги зачислены на баланс.';
    if (_bankState == 'cancelled')
      return 'Счёт отменён. Деньги не зачислялись.';
    if (_bankState == 'expired')
      return 'Срок оплаты счёта истёк. Деньги не зачислялись.';
    if (_status == 'failed')
      return 'Счёт отклонён или отменён. Деньги не зачислялись.';
    if (_automationError == 'KASPI_PAYMENT_BINDING_MISMATCH')
      return 'Сумма или данные оплаты не совпали. Обратитесь в поддержку; повторно оплачивать не нужно.';
    if (_automationError == 'KASPI_INVOICE_UNLINKED')
      return 'Платёж связан с другой кассой. Обратитесь в поддержку, не создавая повторную оплату.';
    if (_createState == 'unknown' || _createState == 'creating')
      return 'Результат создания платежа уточняется. Не повторяйте оплату. При необходимости обратитесь в поддержку.';
    if (!_automatic)
      return 'Заявка отправлена. Ожидайте счёт в Kaspi. После оплаты администратор подтвердит пополнение.';
    if (_automationError != null)
      return 'Проверка временно недоступна. Сервер повторит её автоматически. Если счёт уже пришёл, не создавайте новый.';
    if (_paymentProvider == 'kaspi_qr')
      return _paymentUrl?.isNotEmpty == true
          ? 'Ссылка готова. Оплатите в Kaspi. После подтверждения банка деньги автоматически поступят на ваш баланс MTaxi.'
          : 'Готовим ссылку для оплаты. Статус обновится автоматически.';
    if (_invoiceStatus == 'sent')
      return 'Счёт выставлен на ${_phone.text}. Оплатите его в Kaspi.kz. Оплату проверим и зачислим деньги автоматически.';
    return 'Выставляем счёт на ${_phone.text}. Статус обновится автоматически.';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
                          tr('Kaspi · пополнение баланса',
                              'Kaspi · теңгерімді толықтыру'),
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                ])),
                const SizedBox(height: 16),
                if (_paymentId == null) ...[
                  Text(tr(
                      '1. Укажите номер телефона и сумму.\n2. Нажмите «Пополнить баланс» — откроется оплата Kaspi.\n3. После оплаты деньги поступят на ваш баланс MTaxi автоматически.',
                      '1. Телефон нөмірі мен соманы енгізіңіз.\n2. «Теңгерімді толықтыру» түймесін басыңыз — Kaspi төлемі ашылады.\n3. Төлемнен кейін ақша MTaxi теңгеріміне автоматты түседі.')),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      enabled: !_busy && !_uncertain && !_restoring,
                      decoration: InputDecoration(
                          labelText: tr('Номер Kaspi', 'Kaspi нөмірі'),
                          hintText: '+7XXXXXXXXXX')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      enabled: !_busy && !_uncertain && !_restoring,
                      decoration: InputDecoration(
                          labelText: tr(
                              'Сумма пополнения, ₸', 'Толықтыру сомасы, ₸'))),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: _busy || _restoring ? null : _submit,
                      child: Text(_busy
                          ? tr('Отправляем…', 'Жіберілуде…')
                          : _uncertain
                              ? tr('Повторить проверку заявки',
                                  'Өтінімді қайта тексеру')
                              : tr(
                                  'Пополнить баланс', 'Теңгерімді толықтыру'))),
                ] else ...[
                  Text(
                    '${tr('Сумма заявки', 'Өтінім сомасы')}: ${_amount.text} ₸',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(_paymentMessage()),
                  if (_status == 'pending' &&
                      _paymentUrl?.isNotEmpty == true) ...[
                    FilledButton(
                        onPressed: _busy ? null : _openKaspi,
                        child: Text(tr('Открыть Kaspi для оплаты',
                            'Төлеу үшін Kaspi ашу'))),
                    TextButton(
                        onPressed: () => Clipboard.setData(
                            ClipboardData(text: _paymentUrl!)),
                        child:
                            Text(tr('Копировать ссылку', 'Сілтемені көшіру'))),
                  ],
                  if (_status == 'pending')
                    TextButton(
                        onPressed: _busy ? null : _refresh,
                        child: Text(tr('Проверить оплату', 'Төлемді тексеру'))),
                  if (_status == 'success' || _status == 'failed')
                    TextButton(
                        onPressed: () {
                          setState(() {
                            _paymentId = null;
                            _paymentUrl = null;
                            _paymentProvider = null;
                            _requestKey = const Uuid().v4();
                            _fingerprint = null;
                            _status = 'pending';
                            _automatic = false;
                            _bankState = null;
                            _invoiceStatus = null;
                            _createState = null;
                            _automationError = null;
                          });
                        },
                        child: Text(tr('Новое пополнение', 'Жаңа толықтыру'))),
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
                    child: Text(tr('Закрыть', 'Жабу'))),
              ]),
        ),
      ))),
    );
  }
}
