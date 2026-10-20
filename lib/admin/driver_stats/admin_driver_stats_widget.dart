import '/auth/backend_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/admin/admin_utils.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_driver_stats_model.dart';
export 'admin_driver_stats_model.dart';

const _mtaxiPageBg = Color(0xFF12051B);
const _mtaxiSurface = Color(0xFFFFFFFF);

class AdminDriverStatsWidget extends StatefulWidget {
  const AdminDriverStatsWidget({super.key});

  static String routeName = 'adminDriverStats';
  static String routePath = '/admin/driverStats';

  @override
  State<AdminDriverStatsWidget> createState() => _AdminDriverStatsWidgetState();
}

class _AdminDriverStatsWidgetState extends State<AdminDriverStatsWidget> {
  static const int _cancelledOrderStatus = 6;
  late AdminDriverStatsModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  DocumentReference? _driverRef;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();

  double _commissionDay = 10;

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _dateFromBackendOrder(Map<String, dynamic> data) {
    final raw = data['createdAt'] ?? data['date'] ?? data['updatedAt'];
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw?.toString() ?? '');
  }

  String _orderTypeLabel(String type) {
    if (type == 'delivery') return 'Доставка';
    if (type == 'intercity') return 'Межгород';
    return 'Такси';
  }

  bool _looksLikeCoordinateLabel(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final compact = normalized
        .replaceFirst(
          RegExp(r'^(координаты|coordinates)\s*:\s*', caseSensitive: false),
          '',
        )
        .trim();
    return RegExp(
      r'^[-+]?\d{1,2}(?:\.\d+)?\s*,\s*[-+]?\d{1,3}(?:\.\d+)?$',
    ).hasMatch(compact);
  }

  String _safeOrderAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Адрес не указан';
    }
    if (_looksLikeCoordinateLabel(trimmed)) {
      return 'Адрес уточняется';
    }
    return trimmed;
  }

  double _commissionFromPercent({
    required double price,
    required double percent,
  }) {
    if (price <= 0 || percent <= 0) return 0;
    return (price * percent) / 100.0;
  }

  int _orderStatusFromData(Map<String, dynamic> data) {
    final raw = data['status'];
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminDriverStatsModel());
    _loadCommission();
  }

  Future<void> _loadCommission() async {
    try {
      final response = await makeCloudCall('getRuntimeSettings', {});
      final settings = Map<String, dynamic>.from(
        response['settings'] as Map? ?? const {},
      );
      final commission = _asDouble(settings['orderCommissionPercent']);
      if (commission > 0) {
        _commissionDay = commission;
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<List<_BackendDriverOption>> _loadBackendDrivers() async {
    final response = await makeCloudCall('adminListUsers', {
      'role': 'driver',
      'limit': 500,
    });
    final users = (response['users'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((user) {
      final status = (user['statusDriver'] ??
              user['driverRegistrationStatus'] ??
              user['status'])
          ?.toString()
          .toLowerCase();
      return user['isDriver'] == true &&
          (status == 'approved' || status == 'active' || status == 'одобрен');
    }).map((user) {
      final path = user['userDocPath']?.toString() ?? 'users/${user['id']}';
      final name = buildDisplayNameFromData(user);
      final phone = normalizeDisplayText(user['phone'] ?? user['phone_number']);
      return _BackendDriverOption(
        ref: BackendRefs.instance.doc(path),
        label: '$name $phone'.trim(),
      );
    }).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return users;
  }

  Future<_BackendDriverStats> _loadBackendDriverStats() async {
    final driverRef = _driverRef;
    if (driverRef == null) {
      return const _BackendDriverStats.empty();
    }

    final responses = await Future.wait([
      makeCloudCall('adminListOrders', {
        'driverDocPath': driverRef.path,
        'limit': 500,
      }),
      makeCloudCall('getRuntimeSettings', {}),
    ]);
    final ordersResponse = responses[0];
    final settingsResponse = responses[1];
    final commissionPercent = _asDouble(
      (settingsResponse['settings'] as Map?)?['orderCommissionPercent'],
    );
    final start = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final end = DateTime(
      _toDate.year,
      _toDate.month,
      _toDate.day,
      23,
      59,
      59,
    );
    final orders = (ordersResponse['orders'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((order) {
      final dt = _dateFromBackendOrder(order);
      if (dt == null) return false;
      return !dt.isBefore(start) && !dt.isAfter(end);
    }).toList()
      ..sort((a, b) {
        final aDate = _dateFromBackendOrder(a);
        final bDate = _dateFromBackendOrder(b);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    var total = 0;
    var cancelledCount = 0;
    var taxiCount = 0;
    var deliveryCount = 0;
    var intercityCount = 0;
    var totalAmount = 0.0;
    var totalCommission = 0.0;
    final rows = <_BackendDriverOrderView>[];

    for (final order in orders) {
      final status = _orderStatusFromData(order);
      final type = order['type']?.toString() ?? 'taxi';
      final price = _asDouble(order['price']);
      final createdAt = _dateFromBackendOrder(order);
      rows.add(_BackendDriverOrderView(
        createdAt: createdAt,
        type: type,
        price: price,
        ot: order['ot']?.toString() ?? '',
        kuda: order['kuda']?.toString() ?? '',
      ));
      if (status == _cancelledOrderStatus) {
        cancelledCount++;
        continue;
      }
      total++;
      if (type == 'delivery') {
        deliveryCount++;
      } else if (type == 'intercity') {
        intercityCount++;
      } else {
        taxiCount++;
      }
      totalAmount += price;
      totalCommission += _commissionFromPercent(
        price: price,
        percent: commissionPercent > 0 ? commissionPercent : _commissionDay,
      );
    }

    return _BackendDriverStats(
      total: total,
      cancelledCount: cancelledCount,
      taxiCount: taxiCount,
      deliveryCount: deliveryCount,
      intercityCount: intercityCount,
      totalAmount: totalAmount,
      totalCommission: totalCommission,
      orders: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = isAdminUser(currentUserDocument);

    return Scaffold(
      key: scaffoldKey,
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
          'Статистика водителя',
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                font: GoogleFonts.readexPro(
                  fontWeight: FontWeight.w600,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
                letterSpacing: 0.0,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontStyle:
                    FlutterFlowTheme.of(context).headlineMedium.fontStyle,
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
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FutureBuilder<List<_BackendDriverOption>>(
                    future: _loadBackendDrivers(),
                    builder: (context, snapshot) {
                      final drivers = snapshot.data ?? const [];
                      return _driverDropdown(
                        drivers
                            .map(
                              (driver) => DropdownMenuItem<DocumentReference>(
                                value: driver.ref,
                                child: Text(driver.label),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          readOnly: true,
                          controller: TextEditingController(
                            text: dateTimeFormat(
                              'yMMMd',
                              _fromDate,
                              locale: FFLocalizations.of(context).languageCode,
                            ),
                          ),
                          decoration: InputDecoration(
                            labelText: 'С',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _fromDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() => _fromDate = date);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          readOnly: true,
                          controller: TextEditingController(
                            text: dateTimeFormat(
                              'yMMMd',
                              _toDate,
                              locale: FFLocalizations.of(context).languageCode,
                            ),
                          ),
                          decoration: InputDecoration(
                            labelText: 'По',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _toDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() => _toDate = date);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_driverRef == null)
                    Text(
                      'Выберите водителя для просмотра статистики.',
                      style: FlutterFlowTheme.of(context).bodyMedium,
                    ),
                  if (_driverRef != null)
                    FutureBuilder<_BackendDriverStats>(
                      future: _loadBackendDriverStats(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Ошибка загрузки статистики. Попробуйте выбрать водителя снова.',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(color: Colors.red),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        return _buildBackendStats(snapshot.data!);
                      },
                    ),
                ],
              ),
      ),
    );
  }

  Widget _driverDropdown(List<DropdownMenuItem<DocumentReference>> items) {
    return DropdownButtonFormField<DocumentReference>(
      initialValue: _driverRef,
      items: items,
      onChanged: (value) {
        setState(() => _driverRef = value);
      },
      decoration: InputDecoration(
        labelText: 'Водитель',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildBackendStats(_BackendDriverStats stats) {
    final driverIncome = stats.totalAmount - stats.totalCommission;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _statRow('Количество заказов', '${stats.total}'),
        _statRow('Отменено', '${stats.cancelledCount}'),
        _statRow('Такси', '${stats.taxiCount}'),
        _statRow('Доставка', '${stats.deliveryCount}'),
        _statRow('Межгород', '${stats.intercityCount}'),
        _statRow('Сумма заказов', formatAppCurrency(stats.totalAmount)),
        _statRow(
          'Удержано (комиссия)',
          formatAppCurrency(stats.totalCommission),
        ),
        _statRow('Доход водителя', formatAppCurrency(driverIncome)),
        const SizedBox(height: 16),
        Text(
          'Список заказов',
          style: FlutterFlowTheme.of(context).bodyLarge.override(
                font: GoogleFonts.readexPro(
                  fontWeight: FontWeight.w600,
                ),
              ),
        ),
        const SizedBox(height: 8),
        if (stats.orders.isEmpty)
          Text(
            'Нет заказов за выбранный период.',
            style: FlutterFlowTheme.of(context).bodyMedium,
          ),
        ...stats.orders.map((order) {
          final date = order.createdAt;
          final dateText = date != null
              ? '${dateTimeFormat("yMMMd", date, locale: FFLocalizations.of(context).languageCode)} ${dateTimeFormat("Hm", date, locale: FFLocalizations.of(context).languageCode)}'
              : 'Дата не указана';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _mtaxiSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: FlutterFlowTheme.of(context).alternate,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dateText • ${_orderTypeLabel(order.type)}',
                  style: FlutterFlowTheme.of(context).bodyMedium,
                ),
                const SizedBox(height: 4),
                Text('Откуда: ${_safeOrderAddress(order.ot)}'),
                Text('Куда: ${_safeOrderAddress(order.kuda)}'),
                Text('Цена: ${formatAppCurrency(order.price)}'),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _statRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: FlutterFlowTheme.of(context).bodyMedium,
            ),
          ),
          Text(
            value,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _BackendDriverOption {
  const _BackendDriverOption({
    required this.ref,
    required this.label,
  });

  final DocumentReference ref;
  final String label;
}

class _BackendDriverOrderView {
  const _BackendDriverOrderView({
    required this.createdAt,
    required this.type,
    required this.price,
    required this.ot,
    required this.kuda,
  });

  final DateTime? createdAt;
  final String type;
  final double price;
  final String ot;
  final String kuda;
}

class _BackendDriverStats {
  const _BackendDriverStats({
    required this.total,
    required this.cancelledCount,
    required this.taxiCount,
    required this.deliveryCount,
    required this.intercityCount,
    required this.totalAmount,
    required this.totalCommission,
    required this.orders,
  });

  const _BackendDriverStats.empty()
      : total = 0,
        cancelledCount = 0,
        taxiCount = 0,
        deliveryCount = 0,
        intercityCount = 0,
        totalAmount = 0,
        totalCommission = 0,
        orders = const [];

  final int total;
  final int cancelledCount;
  final int taxiCount;
  final int deliveryCount;
  final int intercityCount;
  final double totalAmount;
  final double totalCommission;
  final List<_BackendDriverOrderView> orders;
}
