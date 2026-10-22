import '/trips/trip_navigation.dart';
import '/auth/backend_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/backend_orders.dart';
import '/backend/backend_user_adapter.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/backend/order_state_compat.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/instant_timer.dart';
import 'dart:async';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'home_driver_order_model.dart';
export 'home_driver_order_model.dart';

const _mtaxiPageBg = Color(0xFF12051B);
const _mtaxiMint = Color(0xFF28D8C6);
const _mtaxiMuted = Color(0xFFB8AFC4);
const _mtaxiLightText = Color(0xFF17111D);
const _mtaxiLightMuted = Color(0xFF7C7484);
const _mtaxiOrange = Color(0xFFFF6500);

class _DriverAlertEvent {
  const _DriverAlertEvent({
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

class HomeDriverOrderWidget extends StatefulWidget {
  const HomeDriverOrderWidget({
    super.key,
    this.orderDocPath,
  });

  static String routeName = 'homeDriverOrder';
  static String routePath = '/homeDriverOrder';

  final String? orderDocPath;

  @override
  State<HomeDriverOrderWidget> createState() => _HomeDriverOrderWidgetState();
}

class _HomeDriverOrderWidgetState extends State<HomeDriverOrderWidget> {
  late HomeDriverOrderModel _model;
  bool _redirectingToPassengerMode = false;
  static const Duration _foreignOrderSyncGrace = Duration(seconds: 3);
  static const Duration _acceptedOrderSyncGrace = Duration(seconds: 20);

  final scaffoldKey = GlobalKey<ScaffoldState>();
  LatLng? currentUserLocationValue;
  int? _lastStatus;
  bool _releasingForeignOrder = false;
  bool _foreignOrderNoticeShown = false;
  bool _statusActionInFlight = false;
  int? _statusActionTarget;
  int? _pendingOrderStatus;
  Timer? _pendingStatusRollbackTimer;
  bool _leavingOrderScreen = false;
  final List<_DriverAlertEvent> _pendingDriverAlerts = [];
  bool _recoveringActiveDriverOrder = false;
  DateTime? _lastLocationWriteAt;
  LatLng? _lastWrittenLocation;
  late final DateTime _openedAt;
  OrderRecord? _lastVisibleDriverOrder;
  DocumentReference? _screenOrderRef;
  bool _verifyingAuthoritativeAssignment = false;

  DocumentReference? _authDriverDocRef() {
    final authUid = currentUserUid.trim();
    if (authUid.isEmpty) {
      return currentUserDocument?.reference;
    }
    return UsersRecord.collection.doc(authUid);
  }

  String _authoritativeDriverPath() {
    return _authDriverDocRef()?.path ??
        currentUserDocument?.reference.path ??
        '';
  }

  void _bindAuthoritativeDriverDoc() {
    unawaited(() async {
      try {
        final response = await makeCloudCall('getSessionBootstrap', const {});
        currentUserDocument =
            await applyBackendUserResponse(response) ?? currentUserDocument;
        if (mounted) {
          safeSetState(() {});
        }
      } catch (_) {}
    }());
  }

  DocumentReference? _effectiveDriverOrderRef() {
    final explicitOrderDocPath = (widget.orderDocPath ?? '').trim();
    if (explicitOrderDocPath.startsWith('order/') ||
        explicitOrderDocPath.startsWith('orders/')) {
      final explicitRef = BackendRefs.instance.doc(explicitOrderDocPath);
      if (FFAppState().shouldIgnoreDriverOrderRef(explicitRef)) {
        return null;
      }
      return explicitRef;
    }
    return getEffectiveDriverOrderRef(currentUserDocument);
  }

  DocumentReference? _currentScreenOrderRef() {
    return _screenOrderRef ??
        _effectiveDriverOrderRef() ??
        _lastVisibleDriverOrder?.reference;
  }

  bool _shouldAttemptActiveDriverOrderRecovery() {
    if (_effectiveDriverOrderRef() != null) {
      return true;
    }
    if (getEffectiveDriverLegacyOrderRef() != null) {
      return true;
    }
    return getUserRoleState(currentUserDocument) == 'DRIVER_ON_TRIP';
  }

  bool _shouldHoldDriverFlowDuringSync() {
    return _effectiveDriverOrderRef() != null || _recoveringActiveDriverOrder;
  }

  bool _isWithinAcceptedOrderSyncGrace([DocumentReference? orderRef]) {
    if (DateTime.now().difference(_openedAt) >= _acceptedOrderSyncGrace) {
      return false;
    }
    final currentOrderPath = _currentScreenOrderRef()?.path;
    final nextPath = orderRef?.path;
    if (currentOrderPath == null || nextPath == null) {
      return true;
    }
    return currentOrderPath == nextPath;
  }

  void _recoverActiveDriverOrderOrLeave() {
    if (_recoveringActiveDriverOrder) return;
    _recoveringActiveDriverOrder = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      DocumentReference? recoveredOrderRef;
      for (var attempt = 0; attempt < 3; attempt++) {
        recoveredOrderRef = await recoverActiveDriverOrderRefFromServer();
        if (recoveredOrderRef != null || !mounted) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
      if (!mounted) return;
      _recoveringActiveDriverOrder = false;
      if (recoveredOrderRef != null) {
        _syncLocalDriverOrderRef(recoveredOrderRef);
        UserModeResolver.setTransientRoleState('DRIVER_ON_TRIP');
        FFAppState().update(() {});
        return;
      }
      _syncLocalDriverOrderRef(null);
      UserModeResolver.clearTransientRoleState();
      FFAppState().update(() {});
      context.goNamed(
        UserModeResolver.canOpenDriverScreens(currentUserDocument)
            ? HomeDriverWidget.routeName
            : HomePageWidget.routeName,
      );
    });
  }

  Widget _buildOpeningOrderState({
    required String message,
    bool showRetry = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40.0,
              height: 40.0,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  _mtaxiMint,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context)
                  .bodyMedium
                  .override(color: _mtaxiMuted),
            ),
            if (showRetry) ...[
              const SizedBox(height: 16),
              FFButtonWidget(
                onPressed: _recoverActiveDriverOrderOrLeave,
                text: _tr(
                  ru: 'Обновить заказ',
                  kk: 'Тапсырысты жаңарту',
                ),
                options: FFButtonOptions(
                  height: 42,
                  width: 180,
                  color: _mtaxiMint,
                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                        color: _mtaxiPageBg,
                        fontWeight: FontWeight.w700,
                      ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _syncLocalDriverOrderRef(DocumentReference? value) {
    if (value != null) {
      _screenOrderRef = value;
    }
    final local = getEffectiveDriverLegacyOrderRef();
    if (local?.path == value?.path) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FFAppState().syncLegacyOrderRefs(
        passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
        driverOrderRef: value,
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

  String _formatPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return value;
    final normalized = digits.startsWith('8') && digits.length == 11
        ? '7${digits.substring(1)}'
        : digits;
    if (normalized.startsWith('7') && normalized.length == 11) {
      return '+7 ${normalized.substring(1, 4)} ${normalized.substring(4, 7)} '
          '${normalized.substring(7, 9)} ${normalized.substring(9, 11)}';
    }
    return '+$normalized';
  }

  String _phoneForCall(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return '';
    final noExtraPlus = digits.replaceFirst(RegExp(r'^\++'), '');
    if (noExtraPlus.isEmpty) return '';
    return '+$noExtraPlus';
  }

  String _phoneDigitsForWhatsApp(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('8') && digits.length == 11) {
      return '7${digits.substring(1)}';
    }
    return digits;
  }

  Future<void> _callPhone(String value) async {
    final phone = _phoneForCall(value);
    if (phone.isEmpty) return;
    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _openWhatsApp(String value) async {
    final digits = _phoneDigitsForWhatsApp(value);
    if (digits.isEmpty) return;
    await launchUrl(
      Uri.parse('https://wa.me/$digits'),
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _buildPassengerContactActions(String phone) {
    if (phone.trim().isEmpty) {
      return Text(
        _tr(
          ru: 'Телефон не указан',
          kk: 'Телефон көрсетілмеген',
        ),
        style: FlutterFlowTheme.of(context).bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _formatPhone(phone),
          style: FlutterFlowTheme.of(context).bodySmall.override(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: FFButtonWidget(
                onPressed: () => _callPhone(phone),
                text: _tr(ru: 'Позвонить', kk: 'Қоңырау'),
                icon: const Icon(Icons.call, size: 16),
                options: FFButtonOptions(
                  height: 34,
                  color: _mtaxiMint,
                  textStyle: FlutterFlowTheme.of(context).bodySmall.override(
                        color: _mtaxiPageBg,
                        fontWeight: FontWeight.w700,
                      ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FFButtonWidget(
                onPressed: () => _openWhatsApp(phone),
                text: 'WhatsApp',
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                options: FFButtonOptions(
                  height: 34,
                  color: const Color(0xFF25D366),
                  textStyle: FlutterFlowTheme.of(context).bodySmall.override(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _orderComment(OrderRecord order) {
    final raw =
        (order.snapshotData['comment'] ?? order.comment).toString().trim();
    return raw;
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
    if (trimmed.isEmpty) {
      return fallback;
    }
    if (_looksLikeCoordinateLabel(trimmed)) {
      return _tr(ru: 'Адрес уточняется', kk: 'Мекенжай нақтылануда');
    }
    return trimmed;
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

  String _orderCustomerName({
    UsersRecord? user,
    required Map<String, dynamic> orderData,
  }) {
    final userName = buildDisplayNameFromData(
      user?.snapshotData ?? const <String, dynamic>{},
      fallback: user?.displayName ?? '',
    );
    if (userName.isNotEmpty) return userName;
    final fallbackKeys = [
      'customerName',
      'customer_name',
      'clientName',
      'userName',
      'name',
      'display_name',
    ];
    for (final key in fallbackKeys) {
      final value = normalizeDisplayText(orderData[key]);
      if (value.isNotEmpty) return value;
    }
    return _tr(
      ru: 'Пассажир',
      kk: 'Жолаушы',
    );
  }

  Future<void> _showDriverStatusAlert(OrderRecord order) async {
    final effectiveStatus = _effectiveDriverRealtimeStatus(order);
    if (!mounted || effectiveStatus < 5) {
      return;
    }
    return _showDriverStatusAlertByStatus(
      status: effectiveStatus,
      orderRef: order.reference,
      message: '',
    );
  }

  Future<void> _showDriverStatusAlertByStatus({
    required int status,
    required DocumentReference orderRef,
    required String message,
  }) async {
    if (!mounted) {
      return;
    }
    if (status >= 5) {
      FFAppState().markDriverOrderClosedLocally(orderRef);
      UserModeResolver.setTransientRoleState(_postTripDriverRoleState());
      if (!_leavingOrderScreen) {
        await _leaveOrderScreen();
      }
    }
  }

  Future<void> _showDriverClosureAlert({
    required int status,
    required DocumentReference orderRef,
    String? overrideMessage,
  }) async {
    if (!mounted) {
      return;
    }
    _pendingDriverAlerts.clear();
    FFAppState().markDriverOrderClosedLocally(orderRef);
    UserModeResolver.setTransientRoleState(_postTripDriverRoleState());
    if (!_leavingOrderScreen) {
      await _leaveOrderScreen();
    }
  }

  void _handleDriverStatusChange(OrderRecord order) {
    final effectiveStatus = _effectiveDriverRealtimeStatus(order);
    if (_lastStatus == null) {
      _lastStatus = effectiveStatus;
      return;
    }
    if (_lastStatus == effectiveStatus) {
      return;
    }
    _lastStatus = effectiveStatus;
    if (effectiveStatus < 5) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_showDriverStatusAlert(order));
    });
  }

  bool _isCurrentDriverOrder(OrderRecord order) {
    final currentDriverPath = _effectiveCurrentDriverPath();
    if (currentDriverPath.isEmpty || order.idDriver == null) {
      return false;
    }
    return order.idDriver!.path == currentDriverPath;
  }

  String _effectiveCurrentDriverPath() {
    final preferredDriverPath = FFAppState().preferredDriverUserDocPath();
    if (preferredDriverPath != null && preferredDriverPath.isNotEmpty) {
      return preferredDriverPath;
    }
    return _authoritativeDriverPath();
  }

  bool _serverSnapshotAssignedToCurrentDriver(
    DocumentReference orderRef,
    Map<String, dynamic>? data,
  ) {
    final currentDriverPath = _effectiveCurrentDriverPath();
    if (currentDriverPath.isEmpty || data == null) {
      return false;
    }
    final rawDriverRef = data['idDriver'];
    final assignedPath =
        rawDriverRef is DocumentReference ? rawDriverRef.path : null;
    final rawStatus = data['status'];
    final status = rawStatus is int
        ? rawStatus
        : rawStatus is num
            ? rawStatus.toInt()
            : rawStatus is String
                ? int.tryParse(rawStatus)
                : null;
    if (assignedPath != currentDriverPath) {
      return false;
    }
    if (status == null) {
      return false;
    }
    if (status >= 5) {
      return false;
    }
    _screenOrderRef = orderRef;
    _syncLocalDriverOrderRef(orderRef);
    UserModeResolver.setTransientRoleState('DRIVER_ON_TRIP');
    FFAppState().update(() {});
    return true;
  }

  bool _shouldKeepAcceptedOrderScreen(DocumentReference orderRef) {
    return _isWithinAcceptedOrderSyncGrace(orderRef) ||
        FFAppState().shouldPreferOptimisticDriverOrder(orderRef) ||
        FFAppState().shouldSuppressDriverOrderAuthoritativeRecovery();
  }

  void _verifyCurrentDriverAssignment(DocumentReference orderRef) {
    if (_verifyingAuthoritativeAssignment || !mounted || _leavingOrderScreen) {
      return;
    }
    _verifyingAuthoritativeAssignment = true;
    unawaited(() async {
      try {
        final backendOrder = await loadOrderDetailsFromBackend(orderRef.path);
        if (!mounted || _leavingOrderScreen) {
          return;
        }
        if (backendOrder != null) {
          _lastVisibleDriverOrder = backendOrder;
        }
        final data = backendOrder?.snapshotData;
        if (data == null) {
          if (_shouldKeepAcceptedOrderScreen(orderRef)) {
            return;
          }
          final recoveredOrderRef =
              await recoverActiveDriverOrderRefFromServer();
          if (!mounted || _leavingOrderScreen) {
            return;
          }
          if (recoveredOrderRef?.path == orderRef.path) {
            _screenOrderRef = recoveredOrderRef;
            _syncLocalDriverOrderRef(recoveredOrderRef);
            UserModeResolver.setTransientRoleState('DRIVER_ON_TRIP');
            FFAppState().update(() {});
            return;
          }
          _releaseForeignOrderAccess();
          return;
        }
        if (_serverSnapshotAssignedToCurrentDriver(orderRef, data)) {
          return;
        }
        final rawStatus = data['status'];
        final status = rawStatus is int
            ? rawStatus
            : rawStatus is num
                ? rawStatus.toInt()
                : rawStatus is String
                    ? int.tryParse(rawStatus)
                    : null;
        final rawDriverRef = data['idDriver'];
        final assignedPath =
            rawDriverRef is DocumentReference ? rawDriverRef.path : null;
        final cancelledBy = (data['cancelledBy'] ?? '').toString().trim();
        final cancelStage = (data['cancelStage'] ?? '').toString().trim();
        final cancelledAt = data['cancelledAt'];
        final isTerminal = (status != null && status >= 5) ||
            cancelledBy.isNotEmpty ||
            cancelStage.isNotEmpty ||
            cancelledAt != null;
        if (_shouldKeepAcceptedOrderScreen(orderRef) &&
            !isTerminal &&
            (assignedPath == null || assignedPath.isEmpty)) {
          return;
        }
        if (_shouldKeepAcceptedOrderScreen(orderRef) &&
            !isTerminal &&
            assignedPath == _effectiveCurrentDriverPath()) {
          _screenOrderRef = orderRef;
          _syncLocalDriverOrderRef(orderRef);
          UserModeResolver.setTransientRoleState('DRIVER_ON_TRIP');
          FFAppState().update(() {});
          return;
        }
        final recoveredOrderRef = await recoverActiveDriverOrderRefFromServer();
        if (!mounted || _leavingOrderScreen) {
          return;
        }
        if (recoveredOrderRef?.path == orderRef.path) {
          _screenOrderRef = recoveredOrderRef;
          _syncLocalDriverOrderRef(recoveredOrderRef);
          UserModeResolver.setTransientRoleState('DRIVER_ON_TRIP');
          FFAppState().update(() {});
          return;
        }
        if (_shouldKeepAcceptedOrderScreen(orderRef) && !isTerminal) {
          return;
        }
        _releaseForeignOrderAccess();
      } catch (_) {
        if (!mounted || _leavingOrderScreen) {
          return;
        }
      } finally {
        _verifyingAuthoritativeAssignment = false;
      }
    }());
  }

  int _effectiveDriverRealtimeStatus(OrderRecord order) {
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
    return order.status;
  }

  void _ensureRealtimeStatusListeners(DocumentReference? orderRef) {
    return;
  }

  void _releaseForeignOrderAccess() {
    if (_releasingForeignOrder || _foreignOrderNoticeShown) return;
    _releasingForeignOrder = true;
    _foreignOrderNoticeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FFAppState().syncLegacyOrderRefs(
        passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
        driverOrderRef: null,
      );
      FFAppState().update(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              ru: 'Заказ взял другой водитель',
              kk: 'Тапсырысты басқа жүргізуші алды',
            ),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      context.goNamed(
        UserModeResolver.canOpenDriverScreens(currentUserDocument)
            ? HomeDriverWidget.routeName
            : HomePageWidget.routeName,
      );
    });
  }

  int _effectiveOrderStatus(OrderRecord order) {
    final pendingStatus = _pendingOrderStatus;
    if (pendingStatus != null && pendingStatus > order.status) {
      return pendingStatus;
    }
    if (order.status == 1) {
      return 2;
    }
    return order.status;
  }

  void _syncPendingOrderStatus(OrderRecord order) {
    final pendingStatus = _pendingOrderStatus;
    if (pendingStatus == null || order.status < pendingStatus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pendingStatusRollbackTimer?.cancel();
      _pendingStatusRollbackTimer = null;
      setState(() {
        _pendingOrderStatus = null;
        _statusActionInFlight = false;
        _statusActionTarget = null;
      });
    });
  }

  void _schedulePendingStatusRollback(String fallbackError) {
    _pendingStatusRollbackTimer?.cancel();
    _pendingStatusRollbackTimer = Timer(const Duration(seconds: 10), () async {
      if (!mounted || _pendingOrderStatus == null) {
        return;
      }

      final recoveredOrderRef = await recoverActiveDriverOrderRefFromServer();
      if (!mounted) {
        return;
      }
      if (recoveredOrderRef != null) {
        _syncLocalDriverOrderRef(recoveredOrderRef);
        UserModeResolver.setTransientRoleState('DRIVER_ON_TRIP');
        setState(() {
          _statusActionInFlight = false;
          _statusActionTarget = null;
        });
        FFAppState().update(() {});
        return;
      }

      setState(() {
        _pendingOrderStatus = null;
        _statusActionInFlight = false;
        _statusActionTarget = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fallbackError),
        ),
      );
    });
  }

  Future<void> _leaveOrderScreen() async {
    if (_leavingOrderScreen) {
      return;
    }
    _leavingOrderScreen = true;
    final currentOrderRef = _currentScreenOrderRef();
    if (currentOrderRef != null) {
      FFAppState().markDriverOrderClosedLocally(currentOrderRef);
    }
    _screenOrderRef = null;
    FFAppState().syncLegacyOrderRefs(
      passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
      driverOrderRef: null,
    );
    FFAppState().update(() {});
    if (!mounted) return;
    context.goNamed(
      UserModeResolver.canOpenDriverScreens(currentUserDocument)
          ? HomeDriverWidget.routeName
          : HomePageWidget.routeName,
    );
  }

  double? _lastGpsAccuracy;

  bool _shouldSyncDriverLocation(LatLng nextLocation) {
    final lastWriteAt = _lastLocationWriteAt;
    final lastLocation = _lastWrittenLocation;
    if (lastWriteAt == null || lastLocation == null) {
      return true;
    }
    final elapsed = DateTime.now().difference(lastWriteAt);
    if (elapsed < const Duration(seconds: 3)) {
      return false;
    }
    final distanceMeters = Geolocator.distanceBetween(
      lastLocation.latitude,
      lastLocation.longitude,
      nextLocation.latitude,
      nextLocation.longitude,
    );
    return distanceMeters >= 15 || elapsed >= const Duration(seconds: 3);
  }

  void _rememberSyncedDriverLocation(LatLng location) {
    _lastLocationWriteAt = DateTime.now();
    _lastWrittenLocation = location;
  }

  void _maybeHandleCompletedOrder(OrderRecord order) {
    return;
  }

  Future<void> _pollDriverOrderState() async {
    if (!mounted || _leavingOrderScreen) {
      return;
    }
    final orderRef = _currentScreenOrderRef();
    if (orderRef == null) {
      return;
    }
    final order = await loadOrderDetailsFromBackend(orderRef.path);
    if (!mounted || _leavingOrderScreen || order == null) {
      return;
    }
    _screenOrderRef = order.reference;
    _lastVisibleDriverOrder = order;
    final effectiveStatus = _effectiveDriverRealtimeStatus(order);
    if (effectiveStatus >= 5 || !_isCurrentDriverOrder(order)) {
      await _showDriverClosureAlert(
        status: effectiveStatus >= 5 ? effectiveStatus : 6,
        orderRef: order.reference,
        overrideMessage: !_isCurrentDriverOrder(order)
            ? _tr(
                ru: 'Статус заказа изменен: заказ снят с водителя',
                kk: 'Тапсырыс күйі өзгерді: тапсырыс жүргізушіден алынды',
              )
            : null,
      );
    }
  }

  String _postTripDriverRoleState() {
    final driverOnLine = currentUserDocument?.snapshotData['driverOnLine'];
    final isOnline = driverOnLine is bool ? driverOnLine : false;
    return isOnline ? 'DRIVER_ONLINE' : 'DRIVER_OFFLINE';
  }

  Future<void> _advanceOrderStatus(
    OrderRecord order, {
    required int nextStatus,
    required String fallbackError,
  }) async {
    if (_statusActionInFlight) return;
    setState(() {
      _statusActionInFlight = true;
      _statusActionTarget = nextStatus;
      _pendingOrderStatus = nextStatus;
    });

    final shouldLeaveImmediately = nextStatus == 5;
    if (shouldLeaveImmediately) {
      UserModeResolver.setTransientRoleState(_postTripDriverRoleState());
      unawaited(_leaveOrderScreen());
    }

    final response = await makeCloudCall(
      'advanceDriverOrderStatus',
      {
        'orderDocPath': order.reference.path,
        'userDocPath': _authoritativeDriverPath(),
        'nextStatus': nextStatus,
      },
    );

    if (!mounted) return;

    final success = response['success'] == true;
    if (!success) {
      final code = (response['code'] ?? '').toString().trim().toLowerCase();
      final error = (response['error'] ?? '').toString().trim();
      final isTransientDelay = response['timeout'] == true ||
          code == 'unavailable' ||
          code == 'deadline-exceeded';
      if (isTransientDelay) {
        setState(() {
          _statusActionInFlight = false;
          _statusActionTarget = null;
        });
        _schedulePendingStatusRollback(
            error.isNotEmpty ? error : fallbackError);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                ru: 'Синхронизируем статус с сервером...',
                kk: 'Күй сервермен синхрондалып жатыр...',
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      _pendingStatusRollbackTimer?.cancel();
      _pendingStatusRollbackTimer = null;
      setState(() {
        _statusActionInFlight = false;
        _statusActionTarget = null;
        _pendingOrderStatus = null;
      });
      if (!shouldLeaveImmediately) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.isNotEmpty ? error : fallbackError),
          ),
        );
      }
      return;
    }

    _pendingStatusRollbackTimer?.cancel();
    _pendingStatusRollbackTimer = null;
    setState(() {
      _statusActionInFlight = false;
      _statusActionTarget = null;
    });

    final responseRoleState = (response['roleState'] ?? '').toString().trim();
    final nextRoleState = nextStatus == 5
        ? (responseRoleState.isNotEmpty
            ? responseRoleState
            : _postTripDriverRoleState())
        : 'DRIVER_ON_TRIP';
    UserModeResolver.setTransientRoleState(nextRoleState);

    if (!shouldLeaveImmediately &&
        (nextStatus == 5 || response['navigateHome'] == true)) {
      await _leaveOrderScreen();
    } else {
      FFAppState().syncLegacyOrderRefs(
        passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
        driverOrderRef: order.reference,
      );
      FFAppState().update(() {});
    }
  }

  String _statusButtonText({
    required int targetStatus,
    required String idleRu,
    required String idleKk,
    required String loadingRu,
    required String loadingKk,
  }) {
    if (_statusActionTarget == targetStatus) {
      return _tr(
        ru: loadingRu,
        kk: loadingKk,
      );
    }
    return _tr(
      ru: idleRu,
      kk: idleKk,
    );
  }

  Future<void> _resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          currentUserLocationValue = null;
        });
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          currentUserLocationValue = null;
        });
        return;
      }
      final position = await getSafeCurrentPosition(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      setState(() {
        _lastGpsAccuracy = position.accuracy;
        currentUserLocationValue =
            LatLng(position.latitude, position.longitude);
      });
    } catch (_) {
      setState(() {
        currentUserLocationValue = null;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _model = createModel(context, () => HomeDriverOrderModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(_resolveLocation());
      _bindAuthoritativeDriverDoc();
      _model.instantTimer = InstantTimer.periodic(
        duration: const Duration(seconds: 1),
        callback: (timer) async {
          await _resolveLocation();
          final nextLocation = currentUserLocationValue;
          if (nextLocation != null && _shouldSyncDriverLocation(nextLocation)) {
            await makeCloudCall(
              'updateUserPreferences',
              {
                'coords': {
                  'latitude': nextLocation.latitude,
                  'longitude': nextLocation.longitude,
                  'accuracy': _lastGpsAccuracy,
                },
              },
            );
            _rememberSyncedDriverLocation(nextLocation);
          }
          await _pollDriverOrderState();
        },
        startImmediately: true,
      );
    });

    unawaited(_resolveLocation());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _pendingStatusRollbackTimer?.cancel();
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFEFF2F6);
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final surfaceAlt =
        isDark ? const Color(0xFF243437) : const Color(0xFFF4F7F8);
    final textColor = isDark ? Colors.white : _mtaxiLightText;
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiLightMuted;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8EDF1);
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
              if (!UserModeResolver.canOpenDriverScreens(
                currentUserDocument,
              )) {
                if (_shouldHoldDriverFlowDuringSync()) {
                  _recoverActiveDriverOrderOrLeave();
                  return _buildOpeningOrderState(
                    message: _tr(
                      ru: 'Синхронизируем режим водителя...',
                      kk: 'Жүргізуші режимі синхрондалуда...',
                    ),
                  );
                }
                if (!_redirectingToPassengerMode) {
                  _redirectingToPassengerMode = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    FFAppState().syncLegacyOrderRefs(
                      passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
                      driverOrderRef: null,
                    );
                    FFAppState().update(() {});
                    context.goNamed(HomePageWidget.routeName);
                    _redirectingToPassengerMode = false;
                  });
                }
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Переключаем в режим пассажира...',
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context)
                          .bodyMedium
                          .override(color: mutedColor),
                    ),
                  ),
                );
              }
              final activeOrderRef = _effectiveDriverOrderRef();
              if (activeOrderRef != null) {
                _screenOrderRef = activeOrderRef;
              }
              _syncLocalDriverOrderRef(activeOrderRef);
              final screenOrderRef = _currentScreenOrderRef();
              _ensureRealtimeStatusListeners(screenOrderRef);
              if (screenOrderRef == null) {
                _ensureRealtimeStatusListeners(null);
                if (_shouldAttemptActiveDriverOrderRecovery()) {
                  _recoverActiveDriverOrderOrLeave();
                  return _buildOpeningOrderState(
                    message: _tr(
                      ru: 'Открываем активный заказ...',
                      kk: 'Белсенді тапсырыс ашылуда...',
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  context.goNamed(HomeDriverWidget.routeName);
                });
                return _buildOpeningOrderState(
                  message: _tr(
                    ru: 'Активный заказ не найден. Возвращаем на главный экран...',
                    kk: 'Белсенді тапсырыс табылмады. Басты экранға қайтарамыз...',
                  ),
                );
              }

              return StreamBuilder<OrderRecord>(
                stream: orderDetailsStreamFromBackend(screenOrderRef.path),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    _recoverActiveDriverOrderOrLeave();
                    return _buildOpeningOrderState(
                      message: _tr(
                        ru: 'Не удалось открыть заказ. Восстанавливаем данные...',
                        kk: 'Тапсырысты ашу мүмкін болмады. Деректер қалпына келтірілуде...',
                      ),
                      showRetry: true,
                    );
                  }
                  final streamedOrder = snapshot.data;
                  if (streamedOrder == null) {
                    return _buildOpeningOrderState(
                      message: _tr(
                        ru: 'Загружаем данные заказа...',
                        kk: 'Тапсырыс деректері жүктелуде...',
                      ),
                    );
                  }
                  final order = streamedOrder;
                  _lastVisibleDriverOrder = order;
                  _syncPendingOrderStatus(order);
                  _maybeHandleCompletedOrder(order);
                  final effectiveRealtimeStatus =
                      _effectiveDriverRealtimeStatus(order);
                  final orderType = _orderType(order);
                  final isCurrentDriverOrder = _isCurrentDriverOrder(order);
                  final localDriverOrderRef = _effectiveDriverOrderRef();
                  if (effectiveRealtimeStatus >= 5) {
                    _handleDriverStatusChange(order);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted || _leavingOrderScreen) return;
                      unawaited(
                        _showDriverClosureAlert(
                          status: effectiveRealtimeStatus,
                          orderRef: order.reference,
                        ),
                      );
                    });
                    return Center(
                      child: SizedBox(
                        width: 40.0,
                        height: 40.0,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _mtaxiMint,
                          ),
                        ),
                      ),
                    );
                  }
                  final waitingForAcceptedOrderSync =
                      localDriverOrderRef?.path == order.reference.path &&
                          !isCurrentDriverOrder &&
                          effectiveRealtimeStatus >= 0 &&
                          effectiveRealtimeStatus < 5;
                  final withinForeignOrderSyncGrace =
                      DateTime.now().difference(_openedAt) <
                          _foreignOrderSyncGrace;
                  if (!isCurrentDriverOrder &&
                      (waitingForAcceptedOrderSync ||
                          withinForeignOrderSyncGrace)) {
                    _verifyCurrentDriverAssignment(order.reference);
                    return _buildOpeningOrderState(
                      message: _tr(
                        ru: 'Заказ принят. Синхронизируем данные...',
                        kk: 'Тапсырыс қабылданды. Деректер синхрондалуда...',
                      ),
                    );
                  }
                  if (!isCurrentDriverOrder) {
                    _verifyCurrentDriverAssignment(order.reference);
                    return _buildOpeningOrderState(
                      message: _tr(
                        ru: 'Проверяем назначение заказа...',
                        kk: 'Тапсырыс тағайындалуын тексеріп жатырмыз...',
                      ),
                    );
                  }
                  final canShowPassengerContacts =
                      isCurrentDriverOrder && _effectiveOrderStatus(order) >= 1;
                  _handleDriverStatusChange(order);

                  if (order.status == 5 || _statusActionTarget == 5) {
                    if (order.status == 5) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted || _leavingOrderScreen) return;
                        unawaited(
                          _showDriverClosureAlert(
                            status: 5,
                            orderRef: order.reference,
                          ),
                        );
                      });
                    }
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 40.0,
                            height: 40.0,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                FlutterFlowTheme.of(context).primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _tr(
                              ru: 'Завершаем заказ...',
                              kk: 'Тапсырысты аяқтап жатырмыз...',
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(color: _mtaxiMuted),
                          ),
                        ],
                      ),
                    );
                  }

                  final effectiveStatus = _effectiveOrderStatus(order);

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: TripNavigation(
                            orderDocPath: order.reference.path, isDriver: true),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * 1.0,
                                maxHeight:
                                    MediaQuery.sizeOf(context).height * 0.54,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: surface,
                                  borderRadius: BorderRadius.circular(20.0),
                                  border: Border.all(color: borderColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.10),
                                      blurRadius: 22,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 30, 20, 20),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          '${_tr(ru: 'Тип', kk: 'Түрі')}: ${_orderTypeLabel(order)}',
                                          style: FlutterFlowTheme.of(context)
                                              .titleMedium
                                              .override(
                                                font: GoogleFonts.readexPro(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                                color: textColor,
                                                fontSize: 18.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          '${_tr(ru: 'Откуда', kk: 'Қайдан')}: ${_safeOrderAddress(order.ot, _tr(ru: 'не указано', kk: 'көрсетілмеген'))}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: FlutterFlowTheme.of(context)
                                              .titleSmall
                                              .override(
                                                color: textColor,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          '${_tr(ru: 'Куда', kk: 'Қайда')}: ${_safeOrderAddress(order.kuda, _tr(ru: 'не указано', kk: 'көрсетілмеген'))}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: FlutterFlowTheme.of(context)
                                              .titleSmall
                                              .override(
                                                color: textColor,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          '${_tr(ru: 'Стоимость', kk: 'Құны')}: ${formatAppCurrency(order.price)}',
                                          style: FlutterFlowTheme.of(context)
                                              .titleMedium
                                              .override(
                                                color: textColor,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        Text(
                                            'Наличными получить: ${order.snapshotData['cashToDriver'] ?? order.price} ₸'),
                                        if ((order.snapshotData[
                                                        'passengerBonusUsed'] ??
                                                    0) +
                                                (order.snapshotData[
                                                        'passengerWalletUsed'] ??
                                                    0) >
                                            0)
                                          Text(
                                              'На денежный баланс после завершения: ${(order.snapshotData['passengerBonusUsed'] ?? 0) + (order.snapshotData['passengerWalletUsed'] ?? 0)} ₸'),
                                        const SizedBox(height: 14),
                                        if (canShowPassengerContacts &&
                                            ((order.snapshotData[
                                                        'customerPhone'] ??
                                                    '')
                                                .toString()
                                                .isNotEmpty))
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            margin: const EdgeInsets.only(
                                                bottom: 6),
                                            decoration: BoxDecoration(
                                              color: surfaceAlt,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: borderColor),
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: _mtaxiMint
                                                      .withValues(alpha: 0.18),
                                                  child: const Icon(
                                                      Icons.person,
                                                      color: _mtaxiMint),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        _orderCustomerName(
                                                          user: null,
                                                          orderData: order
                                                              .snapshotData,
                                                        ),
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .titleSmall
                                                            .override(
                                                              font: GoogleFonts
                                                                  .readexPro(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                              color: textColor,
                                                              fontSize: 15.0,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Builder(
                                                          builder: (context) {
                                                        final customerPhone =
                                                            (order.snapshotData[
                                                                        'customerPhone'] ??
                                                                    '')
                                                                .toString();
                                                        return _buildPassengerContactActions(
                                                          customerPhone,
                                                        );
                                                      }),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (orderType != 'delivery' &&
                                            _orderComment(order)
                                                .isNotEmpty) ...[
                                          Text(
                                            '${_tr(ru: 'Комментарий', kk: 'Пікір')}: ${_orderComment(order)}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(color: mutedColor),
                                          ),
                                        ],
                                        if (_orderDeliveryItem(order)
                                            .isNotEmpty) ...[
                                          Text(
                                            '${_tr(ru: 'Что доставить', kk: 'Не жеткізу керек')}: ${_orderDeliveryItem(order)}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(color: mutedColor),
                                          ),
                                        ],
                                        const SizedBox(height: 22),
                                        if (effectiveStatus == 2)
                                          FFButtonWidget(
                                            showLoadingIndicator: false,
                                            onPressed: _statusActionInFlight
                                                ? null
                                                : () async {
                                                    await _advanceOrderStatus(
                                                      order,
                                                      nextStatus: 3,
                                                      fallbackError: _tr(
                                                        ru: 'Не удалось отметить прибытие',
                                                        kk: 'Келгеніңізді белгілеу мүмкін болмады',
                                                      ),
                                                    );
                                                  },
                                            text: _statusButtonText(
                                              targetStatus: 3,
                                              idleRu: 'Я на месте',
                                              idleKk: 'Мен орнымдамын',
                                              loadingRu: 'Отмечаем...',
                                              loadingKk: 'Белгілеп жатырмыз...',
                                            ),
                                            options: FFButtonOptions(
                                              height: 44.0,
                                              color: _mtaxiOrange,
                                              textStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .override(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        if (effectiveStatus == 3)
                                          FFButtonWidget(
                                            showLoadingIndicator: false,
                                            onPressed: _statusActionInFlight
                                                ? null
                                                : () async {
                                                    await _advanceOrderStatus(
                                                      order,
                                                      nextStatus: 4,
                                                      fallbackError: _tr(
                                                        ru: 'Не удалось начать поездку',
                                                        kk: 'Сапарды бастау мүмкін болмады',
                                                      ),
                                                    );
                                                  },
                                            text: _statusButtonText(
                                              targetStatus: 4,
                                              idleRu: 'Начать поездку',
                                              idleKk: 'Сапарды бастау',
                                              loadingRu: 'Запускаем...',
                                              loadingKk: 'Бастап жатырмыз...',
                                            ),
                                            options: FFButtonOptions(
                                              height: 44.0,
                                              color: const Color(0xFF3FCBC0),
                                              textStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .override(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        if (effectiveStatus == 4)
                                          FFButtonWidget(
                                            showLoadingIndicator: false,
                                            onPressed: _statusActionInFlight
                                                ? null
                                                : () async {
                                                    await _advanceOrderStatus(
                                                      order,
                                                      nextStatus: 5,
                                                      fallbackError: _tr(
                                                        ru: 'Не удалось завершить заказ',
                                                        kk: 'Тапсырысты аяқтау мүмкін болмады',
                                                      ),
                                                    );
                                                  },
                                            text: _statusButtonText(
                                              targetStatus: 5,
                                              idleRu: 'Завершить',
                                              idleKk: 'Аяқтау',
                                              loadingRu: 'Завершаем...',
                                              loadingKk: 'Аяқтап жатырмыз...',
                                            ),
                                            options: FFButtonOptions(
                                              height: 44.0,
                                              color: const Color(0xFF2B9A8E),
                                              textStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .override(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
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
