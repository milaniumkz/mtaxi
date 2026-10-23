import '/design/bottom_navigation.dart';
import '/trips/trip_receipt.dart';
import '/design/trip_panel.dart';
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

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'home_driver_order_model.dart';
export 'home_driver_order_model.dart';

const _mtaxiPageBg = Color(0xFF12051B);
const _mtaxiMint = Color(0xFF126E68);
const _mtaxiMuted = Color(0xFFB8AFC4);
const _mtaxiLightMuted = Color(0xFF7C7484);

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
  bool _tabActive = true;
  bool _receiptShowing = false;
  final Set<String> _shownReceipts = {};
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_formatPhone(phone), style: FlutterFlowTheme.of(context).bodySmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
            onPressed: () => _callPhone(phone),
            icon: const Icon(Icons.call_outlined, size: 18),
            label: Text(_tr(ru: 'Позвонить', kk: 'Қоңырау'))),
        OutlinedButton.icon(
            onPressed: () => _openWhatsApp(phone),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('WhatsApp')),
      ]),
    ]);
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
    if (_receiptShowing) return;
    _pendingDriverAlerts.clear();
    if (status == 5 && _shownReceipts.add(orderRef.path)) {
      _receiptShowing = true;
      try {
        await showTripReceipt(context, orderRef.path, driver: true);
      } finally {
        _receiptShowing = false;
      }
      if (!mounted) return;
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.isNotEmpty ? error : fallbackError)));
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

    if (nextStatus == 5) {
      await _showDriverClosureAlert(status: 5, orderRef: order.reference);
    } else if (response['navigateHome'] == true) {
      await _leaveOrderScreen();
    } else {
      FFAppState().syncLegacyOrderRefs(
        passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
        driverOrderRef: order.reference,
      );
      FFAppState().update(() {});
    }
  }

  Future<void> _resolveLocation() async {
    if (!_tabActive) return;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabActive = MTaxiTabActivity.isActive(context);
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
          if (!_tabActive ||
              !(ModalRoute.of(context)?.isCurrent ?? true) ||
              (WidgetsBinding.instance.lifecycleState != null &&
                  WidgetsBinding.instance.lifecycleState !=
                      AppLifecycleState.resumed)) return;
          await _resolveLocation();
          if (!_tabActive || !mounted) return;
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
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFFCFCFA);
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
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
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Flexible(
                                            child: SingleChildScrollView(
                                          child: TripPanel(
                                            order: {
                                              ...order.snapshotData,
                                              'ot': order.ot,
                                              'kuda': order.kuda,
                                              'price': order.price
                                            },
                                            status: effectiveStatus,
                                            driver: true,
                                            showActions: false,
                                            busy: _statusActionInFlight,
                                            contacts: canShowPassengerContacts
                                                ? _buildPassengerContactActions(
                                                    (order.snapshotData[
                                                                'customerPhone'] ??
                                                            '')
                                                        .toString())
                                                : const SizedBox.shrink(),
                                            onAdvance: () => _advanceOrderStatus(
                                                order,
                                                nextStatus: effectiveStatus + 1,
                                                fallbackError: _tr(
                                                    ru: 'Не удалось подтвердить действие',
                                                    kk: 'Әрекет расталмады')),
                                          ),
                                        )),
                                        const SizedBox(height: 12),
                                        FilledButton(
                                            style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF1B242B),
                                                foregroundColor: Colors.white),
                                            onPressed: _statusActionInFlight
                                                ? null
                                                : () => _advanceOrderStatus(
                                                    order,
                                                    nextStatus:
                                                        effectiveStatus + 1,
                                                    fallbackError: _tr(
                                                        ru:
                                                            'Не удалось подтвердить действие',
                                                        kk:
                                                            'Әрекет расталмады')),
                                            child: Text(_statusActionInFlight
                                                ? _tr(
                                                    ru: 'Подтверждаем…',
                                                    kk: 'Расталуда…')
                                                : effectiveStatus == 2
                                                    ? _tr(
                                                        ru: 'Я на месте',
                                                        kk: 'Мен келдім')
                                                    : effectiveStatus == 3
                                                        ? _tr(
                                                            ru:
                                                                'Начать поездку',
                                                            kk:
                                                                'Сапарды бастау')
                                                        : _tr(
                                                            ru: 'Завершить поездку',
                                                            kk: 'Сапарды аяқтау'))),
                                      ]),
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
