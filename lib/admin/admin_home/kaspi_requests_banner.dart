import 'dart:async';
import 'package:flutter/material.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/flutter_flow/flutter_flow_util.dart';

class KaspiRequestsBanner extends StatefulWidget {
  const KaspiRequestsBanner({super.key});
  @override
  State<KaspiRequestsBanner> createState() => _KaspiRequestsBannerState();
}

class _KaspiRequestsBannerState extends State<KaspiRequestsBanner> {
  Timer? _timer;
  int _count = 0;
  bool _failed = false;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final result = await makeCloudCall('adminListPayments', {'limit': 1});
      if (result['success'] != true) throw StateError('Unavailable');
      if (mounted)
        setState(() {
          _count = (result['pendingKaspiCount'] as num?)?.toInt() ?? 0;
          _failed = false;
        });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
        child: ListTile(
      leading: Icon(Icons.notifications_active_outlined,
          color: _count > 0 ? Colors.orange : null),
      title: Text(_failed
          ? 'Не удалось проверить заявки Kaspi'
          : 'Заявки Kaspi: $_count'),
      subtitle:
          const Text('Выставьте счёт и подтвердите пополнение после оплаты'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.pushNamedAuth('adminCollection', context.mounted,
          queryParameters: {'collection': 'payments'}),
    ));
  }
}
