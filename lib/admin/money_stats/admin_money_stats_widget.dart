import '/auth/backend_auth/auth_util.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/admin/admin_utils.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _mtaxiPageBg = Color(0xFF12051B);
const _mtaxiSurface = Color(0xFFFFFFFF);
const _mtaxiMint = Color(0xFF28D8C6);

class AdminMoneyStatsWidget extends StatefulWidget {
  const AdminMoneyStatsWidget({super.key});

  static String routeName = 'adminMoneyStats';
  static String routePath = '/admin/moneyStats';

  @override
  State<AdminMoneyStatsWidget> createState() => _AdminMoneyStatsWidgetState();
}

class _AdminMoneyStatsWidgetState extends State<AdminMoneyStatsWidget> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();
  String _period = '7d';

  DateTime? _asDate(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _setPeriod(String period) {
    final now = DateTime.now();
    setState(() {
      _period = period;
      _toDate = now;
      if (period == 'today') {
        _fromDate = now;
      } else if (period == '30d') {
        _fromDate = now.subtract(const Duration(days: 30));
      } else if (period == 'month') {
        _fromDate = DateTime(now.year, now.month, 1);
      } else {
        _fromDate = now.subtract(const Duration(days: 7));
      }
    });
  }

  Future<_MoneyStats> _loadStats() async {
    return _loadBackendStats();
  }

  Future<_MoneyStats> _loadBackendStats() async {
    final from = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final to = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);
    final response = await makeCloudCall('getMoneyStats', {
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
    });
    if (response['success'] != true) {
      throw Exception(response['error']?.toString() ?? 'Не удалось загрузить');
    }

    final totals = response['totals'] is Map
        ? Map<String, dynamic>.from(response['totals'])
        : const <String, dynamic>{};
    final ledger = response['ledger'] is List
        ? (response['ledger'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final payments = response['payments'] is List
        ? (response['payments'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final withdrawalsRaw = response['withdrawals'] is List
        ? (response['withdrawals'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final driverBalancesRaw = response['driverBalances'] is List
        ? (response['driverBalances'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

    var topupCount = 0;
    var pendingCount = 0;
    var failedCount = 0;
    var chargedCount = 0;
    var refundedCount = 0;
    var withdrawalCount = 0;
    var pendingWithdrawalCount = 0;
    final operations = <_MoneyOperation>[];

    for (final payment in payments) {
      final status = (payment['status'] ?? '').toString().toLowerCase();
      if (status == 'confirmed' || status == 'success' || status == 'paid') {
        topupCount++;
      } else if (status == 'pending') {
        pendingCount++;
      } else if (status == 'failed') {
        failedCount++;
      }
    }

    for (final withdrawal in withdrawalsRaw) {
      final status = (withdrawal['status'] ?? '').toString().toLowerCase();
      if (status == 'success' || status == 'approved') {
        withdrawalCount++;
      } else if (status == 'pending') {
        pendingWithdrawalCount++;
      }
    }

    for (final entry in ledger) {
      final type = (entry['type'] ?? '').toString();
      final amount = _asDouble(entry['amount']);
      final date = _asDate(entry['createdAt']);
      if (type == 'order_commission') {
        chargedCount++;
      }
      if (type.contains('refund')) {
        refundedCount++;
      }
      final positive = type == 'driver_top_up' ||
          type.contains('refund') ||
          type == 'withdrawal_rejected';
      operations.add(_MoneyOperation(
        date: date,
        title: _backendOperationTitle(type),
        subtitle: [
          (entry['userId'] ?? '').toString(),
          (entry['orderId'] ??
                  entry['paymentId'] ??
                  entry['withdrawalId'] ??
                  '')
              .toString(),
        ].where((item) => item.trim().isNotEmpty).join(' • '),
        amount: amount,
        positive: positive,
      ));
    }
    operations.sort((a, b) => (b.date ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(a.date ?? DateTime.fromMillisecondsSinceEpoch(0)));

    final topBalances = driverBalancesRaw
        .map((item) => _DriverBalance(
              name: (item['name'] ?? '').toString(),
              phone: (item['phone'] ?? '').toString(),
              balance: _asDouble(item['balance']),
            ))
        .toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));

    return _MoneyStats(
      topups: _asDouble(totals['topUps']),
      pendingTopups: _asDouble(totals['pendingTopUps']),
      failedTopups: _asDouble(totals['failedTopUps']),
      commissionCharged: _asDouble(totals['orderCommissions']),
      commissionRefunded: _asDouble(totals['refunds']),
      withdrawals: _asDouble(totals['withdrawals']),
      pendingWithdrawals: _asDouble(totals['pendingWithdrawals']),
      driverBalances: _asDouble(totals['totalDriverBalance']),
      negativeBalances: _asDouble(totals['negativeDriverBalance']),
      topupCount: topupCount,
      pendingCount: pendingCount,
      failedCount: failedCount,
      chargedCount: chargedCount,
      refundedCount: refundedCount,
      withdrawalCount: withdrawalCount,
      pendingWithdrawalCount: pendingWithdrawalCount,
      driversWithBalance: (_asDouble(totals['driversWithBalance'])).toInt(),
      operations: operations.take(80).toList(),
      topBalances: topBalances.take(10).toList(),
    );
  }

  String _backendOperationTitle(String type) {
    switch (type) {
      case 'driver_top_up':
        return 'Пополнение';
      case 'payment_failed':
        return 'Ошибка оплаты';
      case 'withdrawal_requested':
        return 'Заявка на вывод';
      case 'driver_withdrawal':
        return 'Вывод средств';
      case 'withdrawal_rejected':
        return 'Вывод отклонен';
      case 'order_commission':
        return 'Списание комиссии';
      case 'order_commission_refund':
        return 'Возврат комиссии';
    }
    return type.isEmpty ? 'Операция' : type;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = isAdminUser(currentUserDocument);
    return Scaffold(
      backgroundColor: _mtaxiPageBg,
      appBar: AppBar(
        backgroundColor: _mtaxiPageBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Назад',
          color: Colors.white,
          onPressed: () => context.goNamed(AdminHomeWidget.routeName),
        ),
        title: Text(
          'Статистика денег',
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                font: GoogleFonts.readexPro(fontWeight: FontWeight.w600),
                color: Colors.white,
                letterSpacing: 0.0,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
      body: SafeArea(
        child: !isAdmin
            ? Center(
                child: Text(
                  'Доступ только для администратора',
                  style: FlutterFlowTheme.of(context).bodyLarge,
                ),
              )
            : FutureBuilder<_MoneyStats>(
                future: _loadStats(),
                builder: (context, snapshot) {
                  final stats = snapshot.data;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildPeriodControls(context),
                      const SizedBox(height: 12),
                      if (!snapshot.hasData)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        _buildSummary(context, stats!),
                        const SizedBox(height: 12),
                        _buildQuickActions(context),
                        const SizedBox(height: 12),
                        _buildBalances(context, stats),
                        const SizedBox(height: 12),
                        _buildOperations(context, stats),
                      ],
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildPeriodControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _periodButton('today', 'Сегодня'),
              _periodButton('7d', '7 дней'),
              _periodButton('30d', '30 дней'),
              _periodButton('month', 'Месяц'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _dateField(context, 'С', _fromDate, true)),
              const SizedBox(width: 8),
              Expanded(child: _dateField(context, 'По', _toDate, false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodButton(String value, String label) {
    final selected = _period == value;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => _setPeriod(value),
      selectedColor: FlutterFlowTheme.of(context).primary,
      labelStyle: TextStyle(color: selected ? Colors.white : null),
    );
  }

  Widget _dateField(
    BuildContext context,
    String label,
    DateTime value,
    bool from,
  ) {
    return TextField(
      readOnly: true,
      controller: TextEditingController(
        text: dateTimeFormat(
          'd.MM.yyyy',
          value,
          locale: FFLocalizations.of(context).languageCode,
        ),
      ),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked == null) return;
        setState(() {
          _period = 'custom';
          if (from) {
            _fromDate = picked;
          } else {
            _toDate = picked;
          }
        });
      },
    );
  }

  Widget _buildSummary(BuildContext context, _MoneyStats stats) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _statCard(
          context,
          'Пополнения',
          formatAppCurrency(stats.topups),
          '${stats.topupCount} оплачено',
          Icons.add_card,
          Colors.green,
        ),
        _statCard(
          context,
          'Ожидают оплаты',
          formatAppCurrency(stats.pendingTopups),
          '${stats.pendingCount} платежей',
          Icons.hourglass_top,
          Colors.orange,
        ),
        _statCard(
          context,
          'Списано комиссий',
          formatAppCurrency(stats.commissionCharged),
          '${stats.chargedCount} заказов',
          Icons.remove_circle_outline,
          Colors.red,
        ),
        _statCard(
          context,
          'Возвраты',
          formatAppCurrency(stats.commissionRefunded),
          '${stats.refundedCount} возвратов',
          Icons.replay_circle_filled,
          Colors.blue,
        ),
        _statCard(
          context,
          'Выводы',
          formatAppCurrency(stats.withdrawals),
          '${stats.withdrawalCount} подтверждено',
          Icons.account_balance,
          Colors.indigo,
        ),
        _statCard(
          context,
          'Ожидают вывода',
          formatAppCurrency(stats.pendingWithdrawals),
          '${stats.pendingWithdrawalCount} заявок',
          Icons.pending_actions,
          Colors.deepOrange,
        ),
        _statCard(
          context,
          'Чистое списание',
          formatAppCurrency(stats.commissionCharged +
              stats.withdrawals -
              stats.commissionRefunded),
          'Комиссия и выводы минус возвраты',
          Icons.account_balance_wallet,
          Colors.purple,
        ),
        _statCard(
          context,
          'Ошибки оплат',
          formatAppCurrency(stats.failedTopups),
          '${stats.failedCount} платежей',
          Icons.error_outline,
          Colors.grey,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(context),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _actionButton('Платежи', Icons.payments, () {
            context.pushNamedAuth(
              AdminCollectionWidget.routeName,
              context.mounted,
              queryParameters: {'collection': 'payments'},
            );
          }),
          _actionButton('Заявки вывода', Icons.account_balance, () {
            context.pushNamedAuth(
              AdminCollectionWidget.routeName,
              context.mounted,
              queryParameters: {'collection': 'withdrawals'},
            );
          }),
          _actionButton('Балансы водителей', Icons.people, () {
            context.pushNamedAuth(
              AdminCollectionWidget.routeName,
              context.mounted,
              queryParameters: {'collection': 'users'},
            );
          }),
          _actionButton('Комиссия', Icons.percent, () {
            context.pushNamedAuth(
              AdminCollectionWidget.routeName,
              context.mounted,
              queryParameters: {'collection': 'appSettings'},
            );
          }),
          _actionButton('Заказы', Icons.receipt_long, () {
            context.pushNamedAuth(
              AdminCollectionWidget.routeName,
              context.mounted,
              queryParameters: {'collection': 'order'},
            );
          }),
        ],
      ),
    );
  }

  Widget _actionButton(String text, IconData icon, VoidCallback onTap) {
    return FFButtonWidget(
      onPressed: onTap,
      text: text,
      icon: Icon(icon, size: 18),
      options: FFButtonOptions(
        height: 38,
        color: _mtaxiMint,
        textStyle: FlutterFlowTheme.of(context)
            .bodyMedium
            .override(color: Colors.white, fontWeight: FontWeight.w600),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildBalances(BuildContext context, _MoneyStats stats) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Текущие балансы водителей',
            style: FlutterFlowTheme.of(context)
                .bodyLarge
                .override(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('Всего на балансах: ${formatAppCurrency(stats.driverBalances)}'),
          Text('Водителей с балансом: ${stats.driversWithBalance}'),
          if (stats.negativeBalances < 0)
            Text(
              'Минусовые балансы: ${formatAppCurrency(stats.negativeBalances)}',
              style: const TextStyle(color: Colors.red),
            ),
          const Divider(height: 20),
          ...stats.topBalances.map(
            (item) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(item.name.isNotEmpty ? item.name : item.phone),
              subtitle: item.phone.isNotEmpty ? Text(item.phone) : null,
              trailing: Text(
                formatAppCurrency(item.balance),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: item.balance < 0 ? Colors.red : Colors.green,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperations(BuildContext context, _MoneyStats stats) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Последние операции за период',
            style: FlutterFlowTheme.of(context)
                .bodyLarge
                .override(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (stats.operations.isEmpty)
            Text('Операций за выбранный период нет',
                style: FlutterFlowTheme.of(context).bodyMedium)
          else
            ...stats.operations.map(
              (item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.positive ? Icons.arrow_downward : Icons.arrow_upward,
                  color: item.positive ? Colors.green : Colors.red,
                ),
                title: Text(item.title),
                subtitle: Text(
                  '${item.subtitle}\n${item.date == null ? '' : dateTimeFormat('d.MM HH:mm', item.date, locale: FFLocalizations.of(context).languageCode)}',
                ),
                trailing: Text(
                  '${item.positive ? '+' : '-'}${formatAppCurrency(item.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: item.positive ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statCard(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(title, style: FlutterFlowTheme.of(context).bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: FlutterFlowTheme.of(context)
                .titleMedium
                .override(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: FlutterFlowTheme.of(context).bodySmall),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration(BuildContext context) {
    return BoxDecoration(
      color: _mtaxiSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: FlutterFlowTheme.of(context).alternate),
    );
  }
}

class _MoneyStats {
  _MoneyStats({
    required this.topups,
    required this.pendingTopups,
    required this.failedTopups,
    required this.commissionCharged,
    required this.commissionRefunded,
    required this.withdrawals,
    required this.pendingWithdrawals,
    required this.driverBalances,
    required this.negativeBalances,
    required this.topupCount,
    required this.pendingCount,
    required this.failedCount,
    required this.chargedCount,
    required this.refundedCount,
    required this.withdrawalCount,
    required this.pendingWithdrawalCount,
    required this.driversWithBalance,
    required this.operations,
    required this.topBalances,
  });

  final double topups;
  final double pendingTopups;
  final double failedTopups;
  final double commissionCharged;
  final double commissionRefunded;
  final double withdrawals;
  final double pendingWithdrawals;
  final double driverBalances;
  final double negativeBalances;
  final int topupCount;
  final int pendingCount;
  final int failedCount;
  final int chargedCount;
  final int refundedCount;
  final int withdrawalCount;
  final int pendingWithdrawalCount;
  final int driversWithBalance;
  final List<_MoneyOperation> operations;
  final List<_DriverBalance> topBalances;
}

class _MoneyOperation {
  _MoneyOperation({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.positive,
  });

  final DateTime? date;
  final String title;
  final String subtitle;
  final double amount;
  final bool positive;
}

class _DriverBalance {
  _DriverBalance({
    required this.name,
    required this.phone,
    required this.balance,
  });

  final String name;
  final String phone;
  final double balance;
}
