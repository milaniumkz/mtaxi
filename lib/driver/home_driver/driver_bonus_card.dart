import '/design/bonus_progress.dart';
import '/design/mtaxi_theme.dart';
import '/flutter_flow/internationalization.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '/backend/backend_calls/backend_calls.dart';

class DriverBonusCard extends StatefulWidget {
  const DriverBonusCard({super.key, this.detailed = false});
  final bool detailed;

  @override
  State<DriverBonusCard> createState() => _DriverBonusCardState();
}

class _DriverBonusCardState extends State<DriverBonusCard> {
  Timer? _timer;
  Map<String, dynamic>? _bonus;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final response = await makeCloudCall('getSessionBootstrap', const {});
      if (response['success'] != true || response['driverBonus'] is! Map) {
        throw StateError('Bonus status unavailable');
      }
      if (mounted) {
        setState(() {
          _bonus = Map<String, dynamic>.from(response['driverBonus'] as Map);
          _failed = false;
        });
      }
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
    String tr(String ru, String kk) =>
        FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
    return Padding(
        padding: widget.detailed
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_bonus != null)
                BonusProgress(data: _bonus!, detailed: widget.detailed)
              else
                MTaxiCard(
                    child: Text(_failed
                        ? tr('Бонусы временно недоступны',
                            'Бонустар уақытша қолжетімсіз')
                        : tr('Загружаем условия акции…',
                            'Акция шарттары жүктелуде…'))),
              if (_failed)
                TextButton(
                    onPressed: _refresh,
                    child: Text(tr('Не удалось обновить. Повторить',
                        'Жаңарту мүмкін болмады. Қайталау'))),
              if (!widget.detailed && _bonus != null)
                TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (context) => Scaffold(
                                appBar: AppBar(
                                    title: Text(tr('Бонусы водителя',
                                        'Жүргізуші бонустары'))),
                                body: const SingleChildScrollView(
                                    padding: EdgeInsets.all(22),
                                    child: DriverBonusCard(detailed: true))))),
                    child: Text(tr('Условия акции', 'Акция шарттары'))),
            ]));
  }
}
