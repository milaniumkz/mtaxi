import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '/backend/backend_calls/backend_calls.dart';

Future<void> openTripChat(BuildContext context, String orderDocPath) =>
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TripChatPage(orderDocPath: orderDocPath)));

class TripChatPage extends StatefulWidget {
  const TripChatPage({super.key, required this.orderDocPath});
  final String orderDocPath;
  @override
  State<TripChatPage> createState() => _TripChatPageState();
}

class _TripChatPageState extends State<TripChatPage> {
  final _text = TextEditingController();
  List<Map> _messages = [];
  Timer? _timer;
  bool _sending = false, _loading = false, _closed = false;
  String? _error, _requestId, _submittedText;
  @override
  void initState() {
    super.initState();
    _reload();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _reload());
  }

  Future<void> _reload() async {
    if (_loading || _closed) return;
    _loading = true;
    try {
      final r = await makeCloudCall(
          'listTripChat', {'orderDocPath': widget.orderDocPath});
      if (!mounted) return;
      setState(() {
        if (r['success'] == true) {
          _messages = (r['messages'] as List? ?? []).whereType<Map>().toList();
          _error = null;
        } else {
          _closed =
              ['TRIP_CHAT_CLOSED', 'TRIP_CHAT_FORBIDDEN'].contains(r['code']);
          _error = r['error']?.toString() ?? 'Не удалось загрузить сообщения';
          if (_closed) _timer?.cancel();
        }
      });
    } catch (_) {
      if (mounted)
        setState(
            () => _error = 'Нет связи. Сообщения обновятся после подключения.');
    } finally {
      _loading = false;
    }
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (_sending || _closed || text.isEmpty) return;
    if (_submittedText != text) {
      _submittedText = text;
      _requestId = const Uuid().v4();
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final r = await makeCloudCall('sendTripChat', {
        'orderDocPath': widget.orderDocPath,
        'text': text,
        'requestId': _requestId
      });
      if (!mounted) return;
      if (r['success'] == true) {
        _text.clear();
        _requestId = null;
        _submittedText = null;
        await _reload();
      } else {
        setState(() {
          _error = r['error']?.toString() ?? 'Не удалось отправить сообщение';
          _closed =
              ['TRIP_CHAT_CLOSED', 'TRIP_CHAT_FORBIDDEN'].contains(r['code']);
        });
      }
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'Ответ не получен. Повторная отправка не создаст дубликат.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Чат поездки')),
      body: SafeArea(
          child: Column(children: [
        const Padding(
            padding: EdgeInsets.all(10),
            child: Text('Связь с участником только во время поездки')),
        Expanded(
            child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final m = _messages[_messages.length - 1 - index];
                  final mine = m['mine'] == true;
                  return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(
                              color: mine
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14)),
                          child: Text(m['text']?.toString() ?? '')));
                })),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.all(10),
              child: Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        if (_closed)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Поездка завершена. Чат закрыт.'))
        else
          Padding(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                    child: TextField(
                        controller: _text,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                            hintText: 'Сообщение', counterText: ''))),
                IconButton(
                    tooltip: 'Отправить',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send))
              ])),
      ])));
}
