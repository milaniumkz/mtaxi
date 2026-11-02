import 'package:flutter/material.dart';
import '/backend/backend_calls/backend_calls.dart';

class KaspiPosConnectionCard extends StatefulWidget {
  const KaspiPosConnectionCard({super.key});
  @override
  State<KaspiPosConnectionCard> createState() => _KaspiPosConnectionCardState();
}

class _KaspiPosConnectionCardState extends State<KaspiPosConnectionCard> {
  final _phone = TextEditingController(text: '+7');
  final _otp = TextEditingController();
  Map<String, dynamic> _status = {};
  bool _busy = false, _expanded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final response = await makeCloudCall('adminKaspiPosStatus', const {});
    if (!mounted) return;
    setState(() {
      if (response['status'] is Map) {
        _status = Map<String, dynamic>.from(response['status'] as Map);
      }
      if (response['success'] != true) {
        _error = response['error']?.toString() ??
            'Не удалось проверить подключение кассы.';
      }
    });
  }

  Future<void> _run(String method,
      [Map<String, dynamic> data = const {}]) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await makeCloudCall(method, data,
          timeout: const Duration(seconds: 45));
      if (!mounted) return;
      if (response['status'] is Map) {
        setState(() =>
            _status = Map<String, dynamic>.from(response['status'] as Map));
      } else {
        await _loadStatus();
      }
      if (mounted && response['success'] != true) {
        setState(() => _error = '${response['error'] ?? 'Операция не выполнена.'}'
            '${response['bankCode'] == null ? '' : '\nКод Kaspi: ${response['bankCode']}'}');
      }
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'Ответ не получен. Обновите состояние подключения перед повтором.');
    } finally {
      if (method == 'adminKaspiPosVerifyLogin') _otp.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = _status['connected'] == true;
    final pending = _status['pendingAuth'] == true;
    final enabled = _status['enabled'] == true;
    final organization = _status['organization'] is Map
        ? _status['organization'] as Map
        : const {};
    final organizations =
        (_status['organizations'] as List? ?? []).whereType<Map>().toList();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ExpansionTile(
        leading: const Icon(Icons.account_balance_outlined),
        title: const Text('Касса Kaspi Pay'),
        subtitle: Text(connected
            ? (_status['connectionActive'] == true
                ? 'Соединение проверено'
                : 'Вход выполнен · проверьте соединение')
            : pending
                ? 'Ожидается SMS-код кассира'
                : 'Не подключена'),
        onExpansionChanged: (value) => setState(() => _expanded = value),
        children: _expanded
            ? [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                            'Сторонняя автоматизация Kaspi Pay. Вход выполняется номером кассира и SMS-кодом; может регистрироваться отдельное устройство. Банковская сессия хранится на сервере и не передаётся браузеру.'),
                        const SizedBox(height: 12),
                        if (_busy) const LinearProgressIndicator(),
                        if (!enabled)
                          const Text(
                              'Подключение выключено или не настроено на сервере. Другие функции админки доступны.'),
                        if (enabled && !connected && !pending) ...[
                          TextField(
                            key: const ValueKey('kaspi-pos-phone'),
                            controller: _phone,
                            enabled: !_busy,
                            keyboardType: TextInputType.phone,
                            autofillHints: null,
                            decoration: const InputDecoration(
                                labelText: 'Номер кассира Kaspi Pay'),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            key: const ValueKey('kaspi-pos-send-sms'),
                            onPressed: _busy
                                ? null
                                : () => _run('adminKaspiPosStartLogin',
                                    {'phone': _phone.text.trim()}),
                            child: const Text('Получить SMS для входа'),
                          ),
                        ],
                        if (pending) ...[
                          Text(
                              'Код для ${_status['phoneHint'] ?? 'номера кассира'}. Вводите код только здесь, не в переписке.'),
                          TextField(
                            key: const ValueKey('kaspi-pos-otp'),
                            controller: _otp,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            enableSuggestions: false,
                            autocorrect: false,
                            decoration: const InputDecoration(
                                labelText: 'SMS-код Kaspi'),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            key: const ValueKey('kaspi-pos-verify'),
                            onPressed: _busy
                                ? null
                                : () => _run('adminKaspiPosVerifyLogin', {
                                      'challengeId': _status['challengeId'],
                                      'otp': _otp.text.trim()
                                    }),
                            child: const Text('Подтвердить вход'),
                          ),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run('adminKaspiPosDisconnect'),
                              child: const Text('Отменить вход')),
                        ],
                        if (connected) ...[
                          Text(
                              'Организация: ${organization['name'] ?? '—'}\nИИН/БИН: ${organization['iin'] ?? '—'}'),
                          if (_status['merchantVerified'] != true)
                            Text(
                                'Организация не совпадает с ИП оператора MTaxi. Счета заблокированы.',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                          if (organizations.length > 1)
                            DropdownButtonFormField<String>(
                              initialValue: organizations
                                      .any((o) => o['id'] == organization['id'])
                                  ? organization['id']?.toString()
                                  : null,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Организация Kaspi'),
                              items: organizations
                                  .map((o) => DropdownMenuItem(
                                      value: o['id'].toString(),
                                      child: Text(
                                          o['name']?.toString() ??
                                              'Организация',
                                          overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: _busy
                                  ? null
                                  : (value) {
                                      if (value != null)
                                        _run('adminKaspiPosSelectOrganization',
                                            {'organizationId': value});
                                    },
                            ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            key: const ValueKey('kaspi-pos-check'),
                            onPressed: _busy
                                ? null
                                : () => _run('adminKaspiPosCheckConnection'),
                            child: const Text('Проверить соединение без счёта'),
                          ),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run('adminKaspiPosDisconnect'),
                              child: const Text('Отключить кассу здесь')),
                          const Text(
                              'Отключение удаляет сессию на сервере MTaxi. Отзыв устройства выполняется в Kaspi Pay. Счета создаются отдельно в заявках на пополнение; проверка соединения не выставляет счёт и не зачисляет деньги.'),
                        ],
                        TextButton(
                            onPressed: _busy
                                ? null
                                : () => _run('adminKaspiPosStatus'),
                            child: const Text('Обновить состояние')),
                        if (_error != null)
                          Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                      ]),
                )
              ]
            : const [],
      ),
    );
  }
}
