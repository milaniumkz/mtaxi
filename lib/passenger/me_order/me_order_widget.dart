import '/auth/backend_auth/auth_util.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'me_order_model.dart';
export 'me_order_model.dart';

const _mtaxiOrange = Color(0xFFFF6500);
const _mtaxiText = Color(0xFF1E1525);
const _mtaxiMuted = Color(0xFF73677C);

class MeOrderWidget extends StatefulWidget {
  const MeOrderWidget({super.key});

  static String routeName = 'meOrder';
  static String routePath = '/meOrder';

  @override
  State<MeOrderWidget> createState() => _MeOrderWidgetState();
}

class _MeOrderWidgetState extends State<MeOrderWidget> {
  late MeOrderModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

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

  DateTime? _dateFromBackendOrder(Map<String, dynamic> data) {
    final raw = data['createdAt'] ?? data['date'] ?? data['updatedAt'];
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw?.toString() ?? '');
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _statusLabel(int status) {
    if (status == 0) {
      return 'Ожидание водителя';
    } else if (status == 1) {
      return 'Водитель принял заказ';
    } else if (status == 2) {
      return 'Водитель в пути';
    } else if (status == 3) {
      return 'Водитель приехал';
    } else if (status == 4) {
      return 'Вы в пути';
    }
    return 'Завершен';
  }

  Future<List<_OrderHistoryItem>> _loadBackendOrders() async {
    final response = await makeCloudCall('listMyOrders', {
      'includeClosed': true,
      'limit': 200,
    });
    final orders =
        (response['orders'] as List? ?? const []).whereType<Map>().map((item) {
      final data = Map<String, dynamic>.from(item);
      return _OrderHistoryItem(
        ot: data['ot']?.toString() ?? '',
        kuda: data['kuda']?.toString() ?? '',
        price: _asDouble(data['price']),
        status: _asInt(data['status']),
        date: _dateFromBackendOrder(data),
      );
    }).toList()
          ..sort((a, b) {
            final aDate = a.date;
            final bDate = b.date;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });
    return orders;
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MeOrderModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDriverMode = UserModeResolver.canOpenDriverScreens(
      currentUserDocument,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFEFF2F6);
    final appBarBg = isDark ? const Color(0xFF13191D) : const Color(0xFFFF6500);
    final appBarText = isDark ? Colors.white : Colors.white;
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: appBarBg,
          iconTheme: IconThemeData(color: appBarText),
          automaticallyImplyLeading: true,
          title: Text(
            isDriverMode ? 'История водителя' : 'Мои заказы',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.outfit(
                    fontWeight:
                        FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  color: appBarText,
                  fontSize: 22.0,
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: true,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: FutureBuilder<List<_OrderHistoryItem>>(
            future: _loadBackendOrders(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return _loadingIndicator(context);
              }
              return _ordersList(snapshot.data ?? const []);
            },
          ),
        ),
      ),
    );
  }

  Widget _loadingIndicator(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 50.0,
        height: 50.0,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            _mtaxiOrange,
          ),
        ),
      ),
    );
  }

  Widget _ordersList(List<_OrderHistoryItem> orders) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Заказов пока нет',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  color: mutedColor,
                ),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...orders.map(_orderCard),
        ],
      ),
    );
  }

  Widget _orderCard(_OrderHistoryItem order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : _mtaxiText;
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8E2EC);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _mtaxiOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: _mtaxiOrange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_safeOrderAddress(order.ot)} - ${_safeOrderAddress(order.kuda)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.0,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                formatAppCurrency(order.price),
                style: FlutterFlowTheme.of(context).titleMedium.override(
                      color: _mtaxiOrange,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _mtaxiOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(order.status),
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        color: _mtaxiOrange,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          if (order.date != null) ...[
            const SizedBox(height: 8),
            Text(
              '${dateTimeFormat(
                "d/M/y",
                order.date,
                locale: FFLocalizations.of(context).languageCode,
              )} ${dateTimeFormat(
                "Hm",
                order.date,
                locale: FFLocalizations.of(context).languageCode,
              )}',
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    color: mutedColor,
                    letterSpacing: 0.0,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderHistoryItem {
  const _OrderHistoryItem({
    required this.ot,
    required this.kuda,
    required this.price,
    required this.status,
    required this.date,
  });

  final String ot;
  final String kuda;
  final double price;
  final int status;
  final DateTime? date;
}
