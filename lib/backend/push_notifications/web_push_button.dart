import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../firebase/firebase_config.dart';
import 'push_notifications_util.dart';

class WebPushButton extends StatefulWidget {
  const WebPushButton({super.key});
  @override
  State<WebPushButton> createState() => _WebPushButtonState();
}

class _WebPushButtonState extends State<WebPushButton> {
  bool _busy = false;
  bool _enabled = false;

  Future<void> _enable() async {
    setState(() => _busy = true);
    bool enabled = false;
    try {
      enabled = await enableBrowserPushForCurrentUser();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _busy = false;
      _enabled = enabled;
    });
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
        'Не удалось включить push. Проверьте разрешение на уведомления в настройках браузера и повторите попытку.',
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !firebaseWebPushEnabled) return const SizedBox.shrink();
    return OutlinedButton.icon(
      onPressed: _busy || _enabled ? null : _enable,
      icon: const Icon(Icons.notifications_active_outlined),
      label: Text(_enabled
          ? 'Push-уведомления включены'
          : _busy
              ? 'Включаем…'
              : 'Включить push-уведомления'),
    );
  }
}
