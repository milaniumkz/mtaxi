import '/trips/trip_navigation.dart';
import '/trips/order_offers.dart';
import '/auth/backend_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/backend_orders.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/backend/order_state_compat.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import '/index.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'seach_driver_model.dart';
export 'seach_driver_model.dart';

const _mtaxiMint = Color(0xFF28D8C6);
const _mtaxiDanger = Color(0xFFFF5263);
const _mtaxiLightText = Color(0xFF17111D);
const _mtaxiLightMuted = Color(0xFF7C7484);
const _mtaxiLightBorder = Color(0xFFE8EDF1);
const _mtaxiPlum = Color(0xFF2D3844);

class _PassengerAlertEvent {
  const _PassengerAlertEvent({
    required this.status,
    required this.orderRef,
    required this.message,
    required this.isClosure,
  });

  final int status;
  final DocumentReference orderRef;
  final String message;
  final bool isClosure;
}

class SeachDriverWidget extends StatefulWidget {
  const SeachDriverWidget({
    super.key,
    this.orderDocPath,
  });

  static String routeName = 'seachDriver';
  static String routePath = '/seachDriver';
  final String? orderDocPath;

  @override
  State<SeachDriverWidget> createState() => _SeachDriverWidgetState();
}

class _SeachDriverWidgetState extends State<SeachDriverWidget> {
  late SeachDriverModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<String> _expireCheckedOrderIds = {};
  int? _lastOrderStatus;
  bool _cancelInProgress = false;
  final Set<String> _ratingPrompts = {};
  bool _recoveringPassengerOrder = false;
  bool _leavingClosedPassengerOrder = false;
  final List<_PassengerAlertEvent> _pendingPassengerAlerts = [];
  DocumentReference? _screenOrderRef;
  DocumentReference? _lastVisiblePassengerOrderRef;
  OrderRecord? _lastVisiblePassengerOrder;
  String? _optimisticallyCancelledOrderPath;
  DateTime? _optimisticallyCancelledAt;

  bool _shouldIgnoreOrderRef(DocumentReference? ref) {
    if (FFAppState().shouldIgnorePassengerOrderRef(ref)) {
      return true;
    }
    final ignoredPath = _optimisticallyCancelledOrderPath;
    final ignoredAt = _optimisticallyCancelledAt;
    if (ref?.path == null || ignoredPath == null || ignoredAt == null) {
      return false;
    }
    if (ref!.path != ignoredPath) {
      return false;
    }
    return DateTime.now().difference(ignoredAt) < const Duration(seconds: 15);
  }

  DocumentReference? _explicitPassengerOrderRef() {
    final path = (widget.orderDocPath ?? '').trim();
    if (path.startsWith('order/') || path.startsWith('orders/')) {
      final explicitRef = BackendRefs.instance.doc(path);
      if (_shouldIgnoreOrderRef(explicitRef)) {
        return null;
      }
      return explicitRef;
    }
    return null;
  }

  DocumentReference? _effectivePassengerOrderRef() {
    final explicitRef = _explicitPassengerOrderRef();
    if (explicitRef != null) {
      return explicitRef;
    }
    final ref = getEffectivePassengerOrderRef(currentUserDocument);
    if (_shouldIgnoreOrderRef(ref)) {
      return null;
    }
    return ref;
  }

  DocumentReference? _currentScreenOrderRef() {
    if (FFAppState().passengerOrderCreationInFlight &&
        _explicitPassengerOrderRef() == null &&
        _effectivePassengerOrderRef() == null) {
      return null;
    }
    return _screenOrderRef ??
        _effectivePassengerOrderRef() ??
        _lastVisiblePassengerOrderRef;
  }

  bool _canHoldCachedPassengerOrderDuringSync() {
    final cachedOrder = _lastVisiblePassengerOrder;
    if (cachedOrder == null) {
      return false;
    }
    final status = cachedOrder.status;
    return status >= 0 && status < 5;
  }

  bool _canHoldAssignedOrderDuringSync(OrderRecord order, int effectiveStatus) {
    return effectiveStatus > 0 && effectiveStatus < 5;
  }

  int _effectivePassengerOrderStatus(OrderRecord order) {
    final cancelledBy =
        (order.snapshotData['cancelledBy'] ?? '').toString().trim();
    final cancelStage =
        (order.snapshotData['cancelStage'] ?? '').toString().trim();
    final cancelledAt = order.snapshotData['cancelledAt'];
    if ((cancelledBy.isNotEmpty ||
            cancelStage.isNotEmpty ||
            cancelledAt != null) &&
        order.status < 5) {
      return 6;
    }
    final rawStatus = order.snapshotData['status'];
    final parsedStatus = rawStatus is int
        ? rawStatus
        : rawStatus is num
            ? rawStatus.toInt()
            : rawStatus is String
                ? int.tryParse(rawStatus)
                : null;
    final status = parsedStatus ?? order.status;
    if (status <= 0 && order.idDriver != null) {
      return 2;
    }
    if (status == 1) {
      return 2;
    }
    return status;
  }

  void _syncLocalPassengerOrderRef(DocumentReference? value) {
    if (value != null) {
      _screenOrderRef = value;
    }
    final local = getEffectivePassengerLegacyOrderRef();
    if (local?.path == value?.path) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FFAppState().syncLegacyOrderRefs(
        passengerOrderRef: value,
        driverOrderRef: getEffectiveDriverLegacyOrderRef(),
      );
      FFAppState().update(() {});
    });
  }

  String _tr({
    required String ru,
    required String kk,
  }) {
    return FFLocalizations.of(context).getVariableText(
      ruText: ru,
      kkText: kk,
    );
  }

  Widget _buildOrderCreationError(String message) {
    final text = message.trim().isNotEmpty
        ? message.trim()
        : _tr(
            ru: 'Не удалось создать заказ. Проверьте интернет и попробуйте еще раз.',
            kk: 'Тапсырыс жасау мүмкін болмады. Интернетті тексеріп, қайталап көріңіз.',
          );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 44,
              color: FlutterFlowTheme.of(context).primary,
            ),
            const SizedBox(height: 16),
            Text(
              _tr(
                ru: 'Заказ не создан',
                kk: 'Тапсырыс жасалмады',
              ),
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodyMedium,
            ),
            const SizedBox(height: 20),
            FFButtonWidget(
              onPressed: () {
                FFAppState().clearPassengerOrderCreationState();
                context.goNamed(HomePageWidget.routeName);
              },
              text: _tr(
                ru: 'Повторить',
                kk: 'Қайталау',
              ),
              options: FFButtonOptions(
                height: 44,
                width: 180,
                color: FlutterFlowTheme.of(context).primary,
                textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                      font: GoogleFonts.readexPro(),
                      color: Colors.white,
                    ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                FFAppState().clearPassengerOrderCreationState();
                context.goNamed(HomePageWidget.routeName);
              },
              child: Text(
                _tr(
                  ru: 'Назад к заказу',
                  kk: 'Тапсырысқа қайту',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _recoverPassengerOrderOrReturnHome() {
    if (_recoveringPassengerOrder) return;
    _recoveringPassengerOrder = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      DocumentReference? recoveredOrderRef;
      for (var attempt = 0; attempt < 3; attempt++) {
        recoveredOrderRef = await recoverActivePassengerOrderRefFromServer();
        if (_shouldIgnoreOrderRef(recoveredOrderRef)) {
          recoveredOrderRef = null;
        }
        if (recoveredOrderRef != null || !mounted) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
      if (!mounted) return;
      _recoveringPassengerOrder = false;
      if (recoveredOrderRef != null) {
        _lastVisiblePassengerOrderRef = recoveredOrderRef;
        FFAppState().syncLegacyOrderRefs(
          passengerOrderRef: recoveredOrderRef,
          driverOrderRef: getEffectiveDriverLegacyOrderRef(),
        );
        FFAppState().clearPassengerOrderCreationState();
        FFAppState().update(() {});
        return;
      }
      if (FFAppState().passengerOrderCreationInFlight) {
        FFAppState().update(() {});
        return;
      }
      _lastVisiblePassengerOrderRef = null;
      FFAppState().syncLegacyOrderRefs(
        passengerOrderRef: null,
        driverOrderRef: getEffectiveDriverLegacyOrderRef(),
      );
      FFAppState().clearPassengerOrderCreationState();
      FFAppState().update(() {});
      context.goNamed(HomePageWidget.routeName);
    });
  }

  void _exitClosedPassengerOrder({
    DocumentReference? orderRef,
  }) {
    if (_leavingClosedPassengerOrder) {
      return;
    }
    _leavingClosedPassengerOrder = true;
    FFAppState().markPassengerOrderCancelledLocally(
      orderRef ?? _currentScreenOrderRef(),
      duration: const Duration(minutes: 5),
    );
    _screenOrderRef = null;
    _lastVisiblePassengerOrderRef = null;
    _lastVisiblePassengerOrder = null;
    FFAppState().forcePassengerMode();
    UserModeResolver.setTransientRoleState('PASSENGER');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      FFAppState().syncLegacyOrderRefs(
        passengerOrderRef: null,
        driverOrderRef: null,
      );
      FFAppState().clearPassengerOrderCreationState();
      FFAppState().update(() {});
      context.goNamed(
        HomePageWidget.routeName,
        queryParameters: {
          'forcePassenger': '1',
        },
      );
    });
  }

  String _phoneDigitsForWhatsApp(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('8') && digits.length == 11) {
      return '7${digits.substring(1)}';
    }
    return digits;
  }

  Future<void> _callDriver(String value) async {
    final digits = _phoneDigitsForWhatsApp(value);
    if (digits.isEmpty) return;
    await launchUrl(Uri.parse('tel:+$digits'));
  }

  Future<void> _openDriverWhatsApp(String value) async {
    final digits = _phoneDigitsForWhatsApp(value);
    if (digits.isEmpty) return;
    await launchUrl(
      Uri.parse('https://wa.me/$digits'),
      mode: LaunchMode.externalApplication,
    );
  }

  String _orderComment(OrderRecord order) {
    return (order.snapshotData['comment'] ?? order.comment).toString().trim();
  }

  String _orderDeliveryItem(OrderRecord order) {
    return (order.snapshotData['deliveryItem'] ??
            order.snapshotData['delivery_item'] ??
            order.snapshotData['deliveryItemText'] ??
            order.snapshotData['whatDelivery'] ??
            order.snapshotData['what_deliver'] ??
            order.snapshotData['item'] ??
            '')
        .toString()
        .trim();
  }

  String _orderType(OrderRecord order) {
    final raw =
        (order.snapshotData['type'] ?? 'taxi').toString().trim().toLowerCase();
    if (raw == 'delivery' || raw == 'intercity') return raw;
    return 'taxi';
  }

  String _orderTypeLabel(OrderRecord order) {
    switch (_orderType(order)) {
      case 'delivery':
        return _tr(ru: 'Доставка', kk: 'Жеткізу');
      case 'intercity':
        return _tr(ru: 'Межгород', kk: 'Қалааралық');
      default:
        return _tr(ru: 'Такси', kk: 'Такси');
    }
  }

  String _safeOrderAddress(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _orderDistanceLabel(OrderRecord order) {
    final rawDistance = order.snapshotData['distanceKm'] ??
        order.snapshotData['distance_km'] ??
        order.snapshotData['routeDistanceKm'];
    final distance = castToType<double>(rawDistance);
    if (distance == null || distance <= 0) {
      final from = order.ot.trim();
      final to = order.kuda.trim();
      if (from.isNotEmpty && to.isNotEmpty) {
        return '${_tr(ru: 'Маршрут', kk: 'Бағыт')}: $from → $to';
      }
      return _tr(ru: 'Маршрут уточняется', kk: 'Бағыт нақтылануда');
    }
    final value = distance.toStringAsFixed(distance >= 10 ? 0 : 1);
    return '${_tr(ru: 'Расстояние', kk: 'Қашықтық')}: $value км';
  }

  Widget _buildOrderInfoCard(
    OrderRecord order, {
    String? statusText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : _mtaxiLightText;
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiLightMuted;
    final borderColor = isDark ? const Color(0xFF2C3A3F) : _mtaxiLightBorder;
    final routePillBg =
        isDark ? const Color(0xFF243437) : const Color(0xFFEFF2F6);
    final deliveryItem = _orderDeliveryItem(order);
    final comment = _orderComment(order);
    final type = _orderType(order);
    final title = statusText ??
        _tr(
          ru: 'Ищем водителя',
          kk: 'Жүргізуші ізделуде',
        );
    final isSearching = title.toLowerCase().contains('ищем') ||
        title.toLowerCase().contains('ізделуде');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSearching) ...[
            Text(
              _tr(
                ru: 'Открываем активный заказ',
                kk: 'Белсенді тапсырыс ашылуда',
              ),
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).titleLarge.override(
                    font: GoogleFonts.readexPro(fontWeight: FontWeight.w800),
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              _tr(
                ru: 'Ищем водителя рядом с вами',
                kk: 'Жаныңыздағы жүргізушіні іздейміз',
              ),
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context)
                  .bodySmall
                  .override(color: mutedColor),
            ),
            const SizedBox(height: 36),
            Center(
              child: Container(
                width: 250,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: routePillBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  _tr(ru: 'Маршрут построен', kk: 'Маршрут құрылды'),
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        color: _mtaxiMint,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 36),
          ] else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _mtaxiMint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _tr(ru: 'ЗАКАЗ ПРИНЯТ', kk: 'ТАПСЫРЫС ҚАБЫЛДАНДЫ'),
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        color: _mtaxiMint,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: FlutterFlowTheme.of(context).titleLarge.override(
                    font: GoogleFonts.readexPro(fontWeight: FontWeight.w700),
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.zero,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_tr(ru: 'Откуда', kk: 'Қайдан')}: ${_safeOrderAddress(order.ot, _tr(ru: 'не указано', kk: 'көрсетілмеген'))}',
                  style: FlutterFlowTheme.of(context).bodyLarge.override(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_tr(ru: 'Куда', kk: 'Қайда')}: ${_safeOrderAddress(order.kuda, _tr(ru: 'не указано', kk: 'көрсетілмеген'))}',
                  style: FlutterFlowTheme.of(context).bodyLarge.override(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  _orderDistanceLabel(order),
                  style: FlutterFlowTheme.of(context)
                      .bodyMedium
                      .override(color: mutedColor),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _orderTypeLabel(order),
                        style: FlutterFlowTheme.of(context)
                            .bodySmall
                            .override(color: mutedColor),
                      ),
                    ),
                    Text(
                      formatAppCurrency(order.price),
                      style: FlutterFlowTheme.of(context).bodyLarge.override(
                            font: GoogleFonts.readexPro(
                              fontWeight: FontWeight.w700,
                            ),
                            color: isDark ? Colors.white : _mtaxiPlum,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (type == 'delivery' && deliveryItem.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${_tr(ru: 'Что доставить', kk: 'Не жеткізу керек')}: $deliveryItem',
              style: FlutterFlowTheme.of(context)
                  .bodySmall
                  .override(color: mutedColor),
            ),
          ],
          if (type != 'delivery' && comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${_tr(ru: 'Комментарий', kk: 'Пікір')}: $comment',
              style: FlutterFlowTheme.of(context)
                  .bodySmall
                  .override(color: mutedColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingCreationPreviewCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final surfaceAlt =
        isDark ? const Color(0xFF243437) : const Color(0xFFF7F5F8);
    final textColor = isDark ? Colors.white : _mtaxiLightText;
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiLightMuted;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8EDF1);
    final orderType = FFAppState().serviceType.trim().isNotEmpty
        ? FFAppState().serviceType.trim()
        : (FFAppState().delivery ? 'delivery' : 'taxi');
    String orderTypeLabel;
    switch (orderType) {
      case 'delivery':
        orderTypeLabel = _tr(ru: 'Доставка', kk: 'Жеткізу');
        break;
      case 'intercity':
        orderTypeLabel = _tr(ru: 'Межгород', kk: 'Қалааралық');
        break;
      default:
        orderTypeLabel = _tr(ru: 'Такси', kk: 'Такси');
    }
    final from = _safeOrderAddress(
      FFAppState().otkkudaString,
      _tr(ru: 'не указано', kk: 'көрсетілмеген'),
    );
    final to = _safeOrderAddress(
      FFAppState().kudaString,
      _tr(ru: 'Адрес уточняется', kk: 'Мекенжай нақтылануда'),
    );
    final comment = FFAppState().comment.trim();
    final deliveryItem = FFAppState().deliveryItem.trim();
    final price = FFAppState().price.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            blurRadius: 28,
            color: Colors.black.withValues(alpha: 0.14),
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF4A5A60) : const Color(0xFFD8D3DC),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _mtaxiMint.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_rounded,
                color: _mtaxiMint,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _tr(
              ru: 'Ищем водителя',
              kk: 'Жүргізуші ізделуде',
            ),
            textAlign: TextAlign.center,
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  font: GoogleFonts.readexPro(fontWeight: FontWeight.w700),
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            _tr(
              ru: 'Заказ создан. Водители уже видят его в ленте.',
              kk: 'Тапсырыс жасалды. Жүргізушілер оны қазірдің өзінде көреді.',
            ),
            textAlign: TextAlign.center,
            style: FlutterFlowTheme.of(context)
                .bodySmall
                .override(color: mutedColor),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surfaceAlt,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_tr(ru: 'Откуда', kk: 'Қайдан')}: $from',
                  style: FlutterFlowTheme.of(context)
                      .bodyMedium
                      .override(color: mutedColor),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_tr(ru: 'Куда', kk: 'Қайда')}: $to',
                  style: FlutterFlowTheme.of(context)
                      .bodyMedium
                      .override(color: mutedColor),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        orderTypeLabel,
                        style: FlutterFlowTheme.of(context)
                            .bodySmall
                            .override(color: mutedColor),
                      ),
                    ),
                    if (price.isNotEmpty)
                      Text(
                        '$price ₸',
                        style: FlutterFlowTheme.of(context).bodyLarge.override(
                              font: GoogleFonts.readexPro(
                                fontWeight: FontWeight.w700,
                              ),
                              color: isDark ? Colors.white : _mtaxiPlum,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (orderType == 'delivery' && deliveryItem.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${_tr(ru: 'Что доставить', kk: 'Не жеткізу керек')}: $deliveryItem',
              style: FlutterFlowTheme.of(context)
                  .bodySmall
                  .override(color: mutedColor),
            ),
          ],
          if (orderType != 'delivery' && comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${_tr(ru: 'Комментарий', kk: 'Пікір')}: $comment',
              style: FlutterFlowTheme.of(context)
                  .bodySmall
                  .override(color: mutedColor),
            ),
          ],
        ],
      ),
    );
  }

  String _orderDriverName(OrderRecord order, UsersRecord? driver) {
    final fromUser = buildDisplayNameFromData(
      driver?.snapshotData ?? const <String, dynamic>{},
      fallback: driver?.displayName ?? '',
    );
    if (fromUser.isNotEmpty) return fromUser;
    final fromOrder = normalizeDisplayText(order.snapshotData['driverName']);
    if (fromOrder.isNotEmpty) return fromOrder;
    return _tr(ru: 'Водитель', kk: 'Жүргізуші');
  }

  String _orderDriverPhone(OrderRecord order, UsersRecord? driver) {
    final fromUser = (driver?.phoneNumber ?? '').trim();
    if (fromUser.isNotEmpty) return fromUser;
    return (order.snapshotData['driverPhone'] ?? '').toString().trim();
  }

  String _activeOrderStatusText(int status) {
    switch (status) {
      case 0:
        return _tr(ru: 'Ищем водителя', kk: 'Жүргізуші ізделуде');
      case 1:
      case 2:
        return _tr(
            ru: 'Водитель принял заказ', kk: 'Жүргізуші тапсырысты қабылдады');
      case 3:
        return _tr(ru: 'Водитель прибыл', kk: 'Жүргізуші келді');
      case 4:
        return _tr(ru: 'Поездка началась', kk: 'Сапар басталды');
      case 5:
        return _tr(ru: 'Заказ завершен', kk: 'Тапсырыс аяқталды');
      case 6:
        return _tr(ru: 'Заказ отменен', kk: 'Тапсырыс болдырылмады');
      default:
        return _tr(ru: 'Статус обновляется', kk: 'Күй жаңартылуда');
    }
  }

  String _activeOrderStatusHint(int status) {
    switch (status) {
      case 1:
      case 2:
        return _tr(ru: 'Водитель едет к вам', kk: 'Жүргізуші сізге келе жатыр');
      case 3:
        return _tr(ru: 'Можно выходить к машине', kk: 'Көлікке шығуға болады');
      case 4:
        return _tr(ru: 'Вы в пути', kk: 'Сіз жолдасыз');
      default:
        return '';
    }
  }

  Future<void> _showPassengerClosureAlert(
    OrderRecord order, {
    String? overrideMessage,
  }) async {
    return _showPassengerClosureAlertByStatus(
      status: _effectivePassengerOrderStatus(order),
      orderRef: order.reference,
      overrideMessage: overrideMessage,
    );
  }

  Future<void> _showPassengerClosureAlertByStatus({
    required int status,
    required DocumentReference orderRef,
    String? overrideMessage,
  }) async {
    _pendingPassengerAlerts.clear();
    if (status == 5 && mounted && _ratingPrompts.add(orderRef.path)) {
      await showTripRating(context, orderRef.path);
    }
    if (mounted) _exitClosedPassengerOrder(orderRef: orderRef);
  }

  String? _passengerStatusAlertMessage(int status) {
    switch (status) {
      case 1:
      case 2:
        return _tr(
          ru: 'Водитель принял заказ и едет к вам',
          kk: 'Жүргізуші тапсырысты қабылдап, сізге келе жатыр',
        );
      case 3:
        return _tr(
          ru: 'Водитель приехал',
          kk: 'Жүргізуші келді',
        );
      case 4:
        return _tr(
          ru: 'Поездка началась',
          kk: 'Сапар басталды',
        );
      default:
        return null;
    }
  }

  Future<void> _showPassengerStatusAlert(OrderRecord order) async {
    if (!mounted) {
      return;
    }
    final status = _effectivePassengerOrderStatus(order);
    if (!shouldAnnounceOrderStatusOnce(
      audience: 'passenger',
      orderRef: order.reference,
      status: status,
    )) {
      return;
    }
    final message = _passengerStatusAlertMessage(status);
    if (message == null || message.isEmpty) {
      return;
    }
    if (status == 3) {
      unawaited(_playDriverArrivedSound());
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _maybeNotifyOrderStatus(OrderRecord order) {
    final status = _effectivePassengerOrderStatus(order);
    if (_lastOrderStatus == status) {
      return;
    }
    _lastOrderStatus = status;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (status >= 5) {
        _exitClosedPassengerOrder(orderRef: order.reference);
        return;
      }
      unawaited(_showPassengerStatusAlert(order));
    });
  }

  Future<void> _playDriverArrivedSound() async {
    if (!FFAppState().soundEnabled) {
      return;
    }
    var customPlayed = false;
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('audios/whatsapp_notification.mp3'));
      unawaited(player.onPlayerComplete.first.then((_) => player.dispose()));
      customPlayed = true;
    } catch (_) {}
    if (!customPlayed) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
      try {
        await FlutterRingtonePlayer().playNotification();
      } catch (_) {}
    }
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  Future<bool> _cancelPassengerOrder(OrderRecord order) async {
    final response = await makeCloudCall(
        'cancelPassengerOrder', {'orderDocPath': order.reference.path});
    if (response['success'] == true) return true;
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(response['error']?.toString() ??
              'Не удалось отменить заказ. Проверьте связь.')));
    return false;
  }

  Future<void> _cancelPassengerOrderConfirmed(
    OrderRecord order, {
    bool restoreDraft = false,
  }) async {
    if (_cancelInProgress) {
      return;
    }
    if (mounted) {
      setState(() {
        _cancelInProgress = true;
      });
    } else {
      _cancelInProgress = true;
    }

    bool confirmed = false;
    try {
      confirmed = await _cancelPassengerOrder(order);
    } finally {
      if (mounted) setState(() => _cancelInProgress = false);
    }
    if (!confirmed || !mounted) return;

    _optimisticallyCancelledOrderPath = order.reference.path;
    _optimisticallyCancelledAt = DateTime.now();
    FFAppState().markPassengerOrderCancelledLocally(order.reference);
    FFAppState().forcePassengerMode();
    _lastVisiblePassengerOrderRef = null;
    _lastVisiblePassengerOrder = null;
    UserModeResolver.setTransientRoleState('PASSENGER');
    try {
      await makeCloudCall(
        'updateUserPreferences',
        {
          'userDocPath': currentUserDocument?.reference.path,
          'targetRoleState': 'PASSENGER',
        },
        timeout: const Duration(seconds: 8),
      );
    } catch (_) {}
    UserModeResolver.setTransientRoleState('PASSENGER');
    FFAppState().syncLegacyOrderRefs(
      passengerOrderRef: null,
      driverOrderRef: null,
    );
    if (restoreDraft) {
      FFAppState().otkkudaString = order.ot;
      FFAppState().kudaString = order.kuda;
      FFAppState().otkudaCoord = order.otCoords;
      FFAppState().kudaCoords = order.kudaCoords;
      FFAppState().comment = order.comment;
      FFAppState().deliveryItem = (order.snapshotData['deliveryItem'] ??
              order.snapshotData['delivery_item'] ??
              '')
          .toString();
      final orderType = (order.snapshotData['type'] as String?) ?? 'taxi';
      FFAppState().serviceType = orderType;
      if (orderType == 'delivery') {
        FFAppState().delivery = true;
        FFAppState().taxi = false;
      } else if (orderType == 'intercity') {
        FFAppState().delivery = false;
        FFAppState().taxi = false;
      } else {
        FFAppState().delivery = false;
        FFAppState().taxi = true;
      }
    } else {
      FFAppState().clearPassengerOrderCreationState();
    }
    FFAppState().update(() {});
    if (!mounted) {
      return;
    }
    context.goNamed(
      HomePageWidget.routeName,
      queryParameters: {
        'forcePassenger': '1',
      },
    );
  }

  Future<void> _restorePendingOrderDraftAndExit(
    OrderRecord order, {
    bool showSnack = false,
  }) async {
    _lastVisiblePassengerOrderRef = null;
    _lastVisiblePassengerOrder = null;
    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заказ отменен. Исполнитель не найден'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    FFAppState().otkkudaString = order.ot;
    FFAppState().kudaString = order.kuda;
    FFAppState().otkudaCoord = order.otCoords;
    FFAppState().kudaCoords = order.kudaCoords;
    FFAppState().comment = order.comment;
    FFAppState().deliveryItem = (order.snapshotData['deliveryItem'] ??
            order.snapshotData['delivery_item'] ??
            '')
        .toString();
    final orderType = (order.snapshotData['type'] as String?) ?? 'taxi';
    FFAppState().serviceType = orderType;
    if (orderType == 'delivery') {
      FFAppState().delivery = true;
      FFAppState().taxi = false;
    } else if (orderType == 'intercity') {
      FFAppState().delivery = false;
      FFAppState().taxi = false;
    } else {
      FFAppState().delivery = false;
      FFAppState().taxi = true;
    }
    FFAppState().syncLegacyOrderRefs(
      passengerOrderRef: null,
      driverOrderRef: getEffectiveDriverLegacyOrderRef(),
    );
    FFAppState().update(() {});
    if (!mounted) return;
    context.goNamed(HomePageWidget.routeName);
  }

  Future<void> _maybeRequestPendingOrderExpiration(OrderRecord order) async {
    final orderId = order.reference.id;
    if (_expireCheckedOrderIds.contains(orderId)) {
      return;
    }
    _expireCheckedOrderIds.add(orderId);
    final response = await makeCloudCall('expirePendingOrderIfNeeded', {
      'orderDocPath': order.reference.path,
    });
    if (!mounted) return;
    final success = response['success'] == true;
    final status = int.tryParse(response['status']?.toString() ?? '');
    if (!success) {
      _expireCheckedOrderIds.remove(orderId);
      return;
    }
    if (response['expired'] == true || (status != null && status >= 6)) {
      await _restorePendingOrderDraftAndExit(order, showSnack: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SeachDriverModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFEFF2F6);
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : _mtaxiLightText;
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiLightMuted;
    final borderColor = isDark ? const Color(0xFF2C3A3F) : _mtaxiLightBorder;
    final mintButtonText = isDark ? const Color(0xFF071718) : Colors.white;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: pageBg,
        body: SafeArea(
          top: true,
          child: AuthUserStreamWidget(
            builder: (context) {
              final effectiveOrderRef = _effectivePassengerOrderRef();
              final hasExplicitOrderRef = _explicitPassengerOrderRef() != null;
              if (effectiveOrderRef != null) {
                FFAppState().allowPassengerWaitingScreen(effectiveOrderRef);
                FFAppState().clearIgnoredPassengerOrderRef(
                  effectiveOrderRef.path,
                );
                _lastVisiblePassengerOrderRef = effectiveOrderRef;
                _screenOrderRef = effectiveOrderRef;
              }
              final orderRef = _currentScreenOrderRef();
              _syncLocalPassengerOrderRef(effectiveOrderRef);
              if (orderRef == null) {
                final cachedOrder = _lastVisiblePassengerOrder;
                final creationInFlight =
                    FFAppState().passengerOrderCreationInFlight;
                final creationError =
                    FFAppState().passengerOrderCreationError.trim();
                if (creationInFlight) {
                  _recoverPassengerOrderOrReturnHome();
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildPendingCreationPreviewCard(),
                    ),
                  );
                }
                if (creationError.isNotEmpty) {
                  return _buildOrderCreationError(creationError);
                }
                if (_canHoldCachedPassengerOrderDuringSync() &&
                    cachedOrder != null) {
                  _recoverPassengerOrderOrReturnHome();
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildOrderInfoCard(
                        cachedOrder,
                        statusText: _activeOrderStatusText(
                          _effectivePassengerOrderStatus(cachedOrder),
                        ),
                      ),
                    ),
                  );
                }
                _recoverPassengerOrderOrReturnHome();
                return Center(
                  child: SizedBox(
                    width: 50.0,
                    height: 50.0,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _mtaxiMint,
                      ),
                    ),
                  ),
                );
              }
              return StreamBuilder<OrderRecord>(
                stream: orderDetailsStreamFromBackend(orderRef.path),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    final cachedOrder = _lastVisiblePassengerOrder;
                    if (cachedOrder != null &&
                        cachedOrder.reference.path == orderRef.path &&
                        _canHoldCachedPassengerOrderDuringSync()) {
                      _recoverPassengerOrderOrReturnHome();
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildOrderInfoCard(
                            cachedOrder,
                            statusText: _activeOrderStatusText(
                              _effectivePassengerOrderStatus(cachedOrder),
                            ),
                          ),
                        ),
                      );
                    }
                    _recoverPassengerOrderOrReturnHome();
                    return Center(
                      child: SizedBox(
                        width: 50.0,
                        height: 50.0,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _mtaxiMint,
                          ),
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    final cachedOrder = _lastVisiblePassengerOrder;
                    if (cachedOrder != null &&
                        cachedOrder.reference.path == orderRef.path) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildOrderInfoCard(
                            cachedOrder,
                            statusText: _activeOrderStatusText(
                              _effectivePassengerOrderStatus(cachedOrder),
                            ),
                          ),
                        ),
                      );
                    }
                    return Center(
                      child: SizedBox(
                        width: 50.0,
                        height: 50.0,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _mtaxiMint,
                          ),
                        ),
                      ),
                    );
                  }

                  final order = snapshot.data!;
                  _screenOrderRef = order.reference;
                  final cachedOrderForSameRef =
                      _lastVisiblePassengerOrder?.reference.path ==
                              order.reference.path
                          ? _lastVisiblePassengerOrder
                          : null;
                  final currentEffectiveStatus =
                      _effectivePassengerOrderStatus(order);
                  final cachedEffectiveStatus = cachedOrderForSameRef == null
                      ? null
                      : _effectivePassengerOrderStatus(cachedOrderForSameRef);
                  final shouldHoldAssignedDriverSnapshot =
                      order.idDriver == null &&
                          cachedOrderForSameRef?.idDriver != null &&
                          _canHoldAssignedOrderDuringSync(
                            cachedOrderForSameRef!,
                            _effectivePassengerOrderStatus(
                              cachedOrderForSameRef,
                            ),
                          );
                  final shouldHoldStatusRegression =
                      cachedOrderForSameRef != null &&
                          cachedEffectiveStatus != null &&
                          currentEffectiveStatus < cachedEffectiveStatus &&
                          _canHoldAssignedOrderDuringSync(
                            cachedOrderForSameRef,
                            cachedEffectiveStatus,
                          );
                  final visibleOrder = shouldHoldAssignedDriverSnapshot ||
                          shouldHoldStatusRegression
                      ? cachedOrderForSameRef
                      : order;
                  _lastVisiblePassengerOrderRef = order.reference;
                  _lastVisiblePassengerOrder = visibleOrder;
                  if (FFAppState().passengerOrderCreationInFlight ||
                      FFAppState().passengerOrderCreationError.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      FFAppState().clearPassengerOrderCreationState();
                    });
                  }
                  final effectiveStatus =
                      _effectivePassengerOrderStatus(visibleOrder);
                  _maybeNotifyOrderStatus(visibleOrder);

                  if (effectiveStatus == 0 &&
                      order.idDriver == null &&
                      !hasExplicitOrderRef &&
                      !FFAppState().shouldShowPassengerWaitingScreen(
                        order.reference,
                      )) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      context.goNamed(HomePageWidget.routeName);
                    });
                    return const SizedBox.shrink();
                  }

                  if (effectiveStatus == 0 && order.idDriver == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      unawaited(_maybeRequestPendingOrderExpiration(order));
                    });
                  }

                  if (effectiveStatus >= 5) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      unawaited(_showPassengerClosureAlert(order));
                    });
                    return Center(
                      child: SizedBox(
                        width: 50.0,
                        height: 50.0,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _mtaxiMint,
                          ),
                        ),
                      ),
                    );
                  }

                  if (visibleOrder.idDriver == null) {
                    if (_canHoldAssignedOrderDuringSync(
                        order, effectiveStatus)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        unawaited(
                          Future<void>.delayed(
                            const Duration(milliseconds: 250),
                            () async {
                              if (!mounted) return;
                              final recoveredOrderRef =
                                  await recoverActivePassengerOrderRefFromServer();
                              if (!mounted || recoveredOrderRef == null) {
                                return;
                              }
                              _lastVisiblePassengerOrderRef = recoveredOrderRef;
                              FFAppState().syncLegacyOrderRefs(
                                passengerOrderRef: recoveredOrderRef,
                                driverOrderRef:
                                    getEffectiveDriverLegacyOrderRef(),
                              );
                              FFAppState().update(() {});
                            },
                          ),
                        );
                      });
                    }
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            color: pageBg,
                          ),
                        ),
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 28, 16, 92),
                            child: Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PassengerOffers(
                                        orderDocPath:
                                            visibleOrder.reference.path),
                                    _buildOrderInfoCard(
                                      visibleOrder,
                                      statusText: _tr(
                                        ru: _canHoldAssignedOrderDuringSync(
                                          order,
                                          effectiveStatus,
                                        )
                                            ? 'Водитель назначается...'
                                            : 'Идет поиск водителя',
                                        kk: _canHoldAssignedOrderDuringSync(
                                          order,
                                          effectiveStatus,
                                        )
                                            ? 'Жүргізуші тағайындалуда...'
                                            : 'Жүргізуші ізделуде',
                                      ),
                                    ),
                                  ]),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16.0,
                          right: 16.0,
                          bottom: 16.0,
                          child: FFButtonWidget(
                            onPressed: () async {
                              await _cancelPassengerOrderConfirmed(
                                visibleOrder,
                              );
                            },
                            text: _cancelInProgress
                                ? _tr(
                                    ru: 'Отменяем...',
                                    kk: 'Болдырылуда...',
                                  )
                                : _tr(
                                    ru: 'Отменить заказ',
                                    kk: 'Тапсырысты болдырмау',
                                  ),
                            options: FFButtonOptions(
                              height: 52.0,
                              color: _mtaxiDanger,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                              borderSide: BorderSide(
                                color: Colors.transparent,
                              ),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  final driverName = _orderDriverName(visibleOrder, null);
                  final driverPhone = _orderDriverPhone(visibleOrder, null);
                  final driverCar =
                      (visibleOrder.snapshotData['driverCar'] ?? '')
                          .toString()
                          .trim();
                  final driverPlate =
                      (visibleOrder.snapshotData['driverPlate'] ?? '')
                          .toString()
                          .trim();
                  final orderType =
                      (visibleOrder.snapshotData['type'] as String?)?.trim() ??
                          'taxi';
                  final orderComment = _orderComment(visibleOrder);
                  final deliveryItem = _orderDeliveryItem(visibleOrder);

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: TripNavigation(
                            orderDocPath: visibleOrder.reference.path,
                            isDriver: false),
                      ),
                      Positioned(
                        left: 16.0,
                        right: 16.0,
                        bottom: 16.0,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * 0.56,
                          ),
                          child: Card(
                            clipBehavior: Clip.antiAliasWithSaveLayer,
                            color: surface,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: borderColor),
                              borderRadius: BorderRadius.circular(14.0),
                            ),
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 10, 18, 18),
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: 42,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF4A5A60)
                                            : const Color(0xFFD8D3DC),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _mtaxiMint.withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        _tr(
                                          ru: 'ЗАКАЗ ПРИНЯТ',
                                          kk: 'ТАПСЫРЫС ҚАБЫЛДАНДЫ',
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .override(
                                              color: _mtaxiMint,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (_activeOrderStatusHint(
                                    effectiveStatus,
                                  ).isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _activeOrderStatusHint(effectiveStatus),
                                      style: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .override(color: mutedColor),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: EdgeInsets.zero,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(0),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                driverName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .titleSmall
                                                    .override(
                                                      font:
                                                          GoogleFonts.readexPro(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                      color: textColor,
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              if (driverCar.isNotEmpty)
                                                Text(
                                                  driverCar,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodySmall
                                                      .override(
                                                        color: textColor,
                                                      ),
                                                ),
                                              if (driverPlate.isNotEmpty)
                                                Text(
                                                  '${_tr(ru: 'Госномер', kk: 'Мемлекеттік нөмір')}: $driverPlate',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodySmall
                                                      .override(
                                                        color: textColor,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (driverPhone.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FFButtonWidget(
                                            onPressed: () =>
                                                _callDriver(driverPhone),
                                            text: _tr(
                                              ru: 'Позвонить',
                                              kk: 'Қоңырау',
                                            ),
                                            icon: const Icon(
                                              Icons.call,
                                              size: 18,
                                            ),
                                            options: FFButtonOptions(
                                              height: 52,
                                              color: _mtaxiMint,
                                              textStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .override(
                                                        color: mintButtonText,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FFButtonWidget(
                                            onPressed: () =>
                                                _openDriverWhatsApp(
                                              driverPhone,
                                            ),
                                            text: 'WhatsApp',
                                            icon: const Icon(
                                              Icons.chat_bubble_outline,
                                              size: 18,
                                            ),
                                            options: FFButtonOptions(
                                              height: 52,
                                              color: const Color(0xFF25D366),
                                              textStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .override(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  FFButtonWidget(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            _tr(
                                              ru: 'Геолокация водителя обновляется',
                                              kk: 'Жүргізушінің геолокациясы жаңартылуда',
                                            ),
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    text: _tr(
                                      ru: 'Где водитель',
                                      kk: 'Жүргізуші қайда',
                                    ),
                                    icon: const Icon(
                                      Icons.near_me_outlined,
                                      size: 18,
                                    ),
                                    options: FFButtonOptions(
                                      height: 56,
                                      color: _mtaxiPlum,
                                      textStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .override(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  if (orderType != 'delivery' &&
                                      orderComment.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '${_tr(ru: 'Комментарий', kk: 'Пікір')}: $orderComment',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: FlutterFlowTheme.of(context)
                                          .bodySmall,
                                    ),
                                  ],
                                  if (orderType == 'delivery' &&
                                      deliveryItem.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '${_tr(ru: 'Что доставить', kk: 'Не жеткізу керек')}: $deliveryItem',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: FlutterFlowTheme.of(context)
                                          .bodySmall,
                                    ),
                                  ],
                                  if (effectiveStatus == 2 ||
                                      effectiveStatus == 3) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _tr(
                                        ru: 'Отмена доступна до начала поездки.',
                                        kk: 'Болдырмау жүргізуші келгенге дейін қолжетімді.',
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodySmall,
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () async {
                                          if (_cancelInProgress) {
                                            return;
                                          }
                                          final confirmed =
                                              await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) =>
                                                        AlertDialog(
                                                      title: Text(
                                                        _tr(
                                                          ru: 'Отменить заказ?',
                                                          kk: 'Тапсырысты болдырмау керек пе?',
                                                        ),
                                                      ),
                                                      content: Text(
                                                        _tr(
                                                          ru: 'Заказ уже принят водителем. Отмена возможна до его приезда. После частых отмен ограничивается только оформление нового заказа.',
                                                          kk: 'Тапсырысты жүргізуші қабылдады. Болдырмау ол келгенге дейін мүмкін. Жиі болдырмаудан кейін тек жаңа тапсырыс рәсімдеу шектеледі.',
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(ctx)
                                                                  .pop(false),
                                                          child: Text(
                                                            _tr(
                                                              ru: 'Назад',
                                                              kk: 'Артқа',
                                                            ),
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(ctx)
                                                                  .pop(true),
                                                          child: Text(
                                                            _tr(
                                                              ru: 'Отменить',
                                                              kk: 'Болдырмау',
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ) ??
                                                  false;
                                          if (!confirmed) return;
                                          await _cancelPassengerOrderConfirmed(
                                            order,
                                          );
                                        },
                                        icon: Icon(
                                          Icons.cancel_outlined,
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                          size: 18,
                                        ),
                                        label: Text(
                                          _cancelInProgress
                                              ? _tr(
                                                  ru: 'Отменяем...',
                                                  kk: 'Болдырылуда...',
                                                )
                                              : _tr(
                                                  ru: 'Отменить заказ',
                                                  kk: 'Тапсырысты болдырмау',
                                                ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall
                                              .override(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .error,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
