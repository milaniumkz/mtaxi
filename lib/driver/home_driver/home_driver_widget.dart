import '/auth/backend_auth/auth_util.dart';
import '/backend/app_settings/app_settings.dart';
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
import 'package:webviewx_plus/webviewx_plus.dart';
import 'home_driver_model.dart';
import 'driver_bonus_card.dart';
export 'home_driver_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _mtaxiMint = Color(0xFF28D8C6);
const _mtaxiMuted = Color(0xFF73677C);
const _mtaxiLightText = Color(0xFF17111D);
const _mtaxiLightMuted = Color(0xFF7C7484);
const _mtaxiOrange = Color(0xFFFF6500);

class HomeDriverWidget extends StatefulWidget {
  const HomeDriverWidget({
    super.key,
    this.allowedTypes,
    this.emptyText = 'Нет заказов в радиусе 10 км',
  });

  final Set<String>? allowedTypes;
  final String emptyText;

  static String routeName = 'homeDriver';
  static String routePath = '/homeDriver';

  @override
  State<HomeDriverWidget> createState() => _HomeDriverWidgetState();
}

class _HomeDriverWidgetState extends State<HomeDriverWidget> {
  late HomeDriverModel _model;
  bool _redirectingToPassengerMode = false;
  bool _recoveringActiveDriverOrder = false;
  bool _openingAcceptedDriverOrder = false;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  LatLng? currentUserLocationValue;
  String? _locationError;
  final Set<String> _seenOrderIds = {};
  final Map<String, DocumentReference> _visibleOrderRefsById = {};
  final Set<String> _checkingUnavailableOrderIds = {};
  final Map<String, int> _knownOrderStatuses = {};
  bool _didInitOrderStatusTracker = false;
  AppRuntimeSettings _runtimeSettings = AppRuntimeSettings.defaults;
  bool _soundEnabledUi = true;
  final Set<String> _takingOrderIds = {};
  final Set<String> _dismissedUnavailableOrderIds = {};
  final Set<String> _notifiedUnavailableOrderIds = {};
  final Set<String> _acceptedOrderIds = {};
  final Set<String> _autoClosingUnavailableOrderIds = {};
  List<OrderRecord> _lastNonEmptyDriverOrders = const [];
  DateTime? _lastNonEmptyDriverOrdersAt;
  static const _uuid = Uuid();
  static const String _seenOrderSoundPrefsKey = 'driver_seen_order_sound_ids';
  static const int _seenOrderSoundLimit = 250;

  double get _maxOrderDistanceKm => 10;

  Duration get _pendingOrderTtl =>
      Duration(minutes: _runtimeSettings.orderPendingTtlMin);

  double get _driverMinBalanceToTakeOrder =>
      _runtimeSettings.driverMinBalanceToTakeOrder;

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
    return getEffectiveDriverOrderRef(currentUserDocument);
  }

  String _postTripDriverRoleState() {
    final driverOnLine = currentUserDocument?.snapshotData['driverOnLine'];
    final isOnline = driverOnLine is bool ? driverOnLine : false;
    return isOnline ? 'DRIVER_ONLINE' : 'DRIVER_OFFLINE';
  }

  bool _shouldHoldDriverFlowDuringSync() {
    return _openingAcceptedDriverOrder ||
        FFAppState().shouldSuppressDriverOrderAuthoritativeRecovery() ||
        _effectiveDriverOrderRef() != null ||
        _recoveringActiveDriverOrder;
  }

  bool _hasOrderCancellationMarker(OrderRecord order) {
    final cancelledBy =
        (order.snapshotData['cancelledBy'] ?? '').toString().trim();
    final cancelStage =
        (order.snapshotData['cancelStage'] ?? '').toString().trim();
    final cancelledAt = order.snapshotData['cancelledAt'];
    return cancelledBy.isNotEmpty ||
        cancelStage.isNotEmpty ||
        cancelledAt != null;
  }

  bool _isActiveOrderForCurrentDriver(OrderRecord order) {
    final driverPath = _authoritativeDriverPath();
    final assignedPath = order.idDriver?.path ?? '';
    return driverPath.isNotEmpty &&
        assignedPath == driverPath &&
        order.status >= 0 &&
        order.status < 5 &&
        !_hasOrderCancellationMarker(order);
  }

  void _clearClosedDriverOrder(
    DocumentReference? orderRef, {
    bool notifyCancelled = false,
  }) {
    FFAppState().markDriverOrderClosedLocally(orderRef);
    FFAppState().clearPreferredDriverActiveOrder(orderRef?.path);
    _syncLocalDriverOrderRef(null);
    UserModeResolver.setTransientRoleState(_postTripDriverRoleState());
    if (notifyCancelled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showDriverFeedMessage('Заказ отменен пассажиром');
        unawaited(_playSoundForType('taxi'));
      });
    }
  }

  void _recoverActiveDriverOrderIfNeeded() {
    if (_recoveringActiveDriverOrder) return;
    _recoveringActiveDriverOrder = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final optimisticLocalRef = getEffectiveDriverLegacyOrderRef();
      if (FFAppState().shouldPreferOptimisticDriverOrder(optimisticLocalRef)) {
        _recoveringActiveDriverOrder = false;
        if (optimisticLocalRef != null) {
          final latest = await loadOrderDetailsFromBackend(
            optimisticLocalRef.path,
          );
          if (!mounted) return;
          if (latest == null || !_isActiveOrderForCurrentDriver(latest)) {
            _clearClosedDriverOrder(
              optimisticLocalRef,
              notifyCancelled: latest == null
                  ? false
                  : latest.status == 6 || _hasOrderCancellationMarker(latest),
            );
            FFAppState().update(() {});
            return;
          }
          _syncLocalDriverOrderRef(optimisticLocalRef);
          UserModeResolver.setTransientRoleState('DRIVER_ON_TRIP');
          FFAppState().update(() {});
          if (!mounted) return;
          context.goNamed(
            HomeDriverOrderWidget.routeName,
            queryParameters: {
              'orderDocPath': optimisticLocalRef.path,
            },
            extra: <String, dynamic>{
              kTransitionInfoKey: TransitionInfo(
                hasTransition: true,
                transitionType: PageTransitionType.scale,
                alignment: Alignment.bottomCenter,
              ),
            },
          );
        }
        return;
      }
      final recoveredOrderRef = await recoverActiveDriverOrderRefFromServer();
      if (!mounted) return;
      _recoveringActiveDriverOrder = false;
      if (recoveredOrderRef == null) {
        _clearClosedDriverOrder(optimisticLocalRef);
        FFAppState().update(() {});
        return;
      }
      final latest = await loadOrderDetailsFromBackend(recoveredOrderRef.path);
      if (!mounted) return;
      if (latest == null || !_isActiveOrderForCurrentDriver(latest)) {
        _clearClosedDriverOrder(
          recoveredOrderRef,
          notifyCancelled: latest == null
              ? false
              : latest.status == 6 || _hasOrderCancellationMarker(latest),
        );
        FFAppState().update(() {});
        return;
      }
      _syncLocalDriverOrderRef(recoveredOrderRef);
      UserModeResolver.setTransientRoleState('DRIVER_ON_TRIP');
      FFAppState().update(() {});
      if (!mounted) return;
      context.goNamed(
        HomeDriverOrderWidget.routeName,
        queryParameters: {
          'orderDocPath': recoveredOrderRef.path,
        },
        extra: <String, dynamic>{
          kTransitionInfoKey: TransitionInfo(
            hasTransition: true,
            transitionType: PageTransitionType.scale,
            alignment: Alignment.bottomCenter,
          ),
        },
      );
    });
  }

  void _syncLocalDriverOrderRef(DocumentReference? value) {
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

  Duration _driverOrderDelay() {
    final data = currentUserDocument?.snapshotData ?? const <String, dynamic>{};
    if (data['vip'] == true) {
      return Duration.zero;
    }
    final maxDelay = _runtimeSettings.driverOrderMaxDelaySec.clamp(0, 10);
    final rawDelay = data['orderDelaySeconds'];
    final parsedDelay = rawDelay is num
        ? rawDelay.toInt()
        : int.tryParse(rawDelay?.toString() ?? '');
    final safeDelay = (parsedDelay ?? maxDelay).clamp(0, maxDelay);
    return Duration(seconds: safeDelay);
  }

  bool _isOrderDelayElapsed(DateTime now, DateTime orderCreatedAt) {
    final delay = _driverOrderDelay();
    if (delay <= Duration.zero) {
      return true;
    }
    return !now.difference(orderCreatedAt).isNegative &&
        now.difference(orderCreatedAt) >= delay;
  }

  void _restartOrderListRefreshTimer() {
    _model.orderListRefreshTimer?.cancel();
    _model.orderListRefreshTimer = InstantTimer.periodic(
      duration: const Duration(seconds: 1),
      callback: (_) {
        if (!mounted) return;
        safeSetState(() {});
      },
      startImmediately: false,
    );
  }

  String _orderDeliveryItem(Map<String, dynamic> data) {
    return (data['deliveryItem'] ??
            data['delivery_item'] ??
            data['deliveryItemText'] ??
            data['whatDelivery'] ??
            data['what_deliver'] ??
            data['item'] ??
            '')
        .toString()
        .trim();
  }

  String _orderComment(Map<String, dynamic> data, String fallback) {
    final value = (data['comment'] ?? fallback).toString().trim();
    return value;
  }

  String _orderTypeTitle(String orderType) {
    switch (orderType) {
      case 'delivery':
        return 'Доставка';
      case 'intercity':
        return 'Межгород';
      default:
        return 'Такси';
    }
  }

  String _safeOrderAddress(
    OrderRecord order,
    String field,
  ) {
    final directValue = field == 'ot' ? order.ot : order.kuda;
    if (directValue.trim().isNotEmpty) {
      return directValue.trim();
    }
    final data = order.snapshotData;
    final aliases = field == 'ot'
        ? const ['ot', 'from', 'fromAddress', 'addressFrom', 'pickupAddress']
        : const ['kuda', 'to', 'toAddress', 'addressTo', 'destinationAddress'];
    for (final key in aliases) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  Widget _orderAddressBlock(
    OrderRecord order, {
    TextStyle? style,
  }) {
    final from = _safeOrderAddress(order, 'ot');
    final to = _safeOrderAddress(order, 'kuda');
    if (from.isEmpty && to.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (from.isNotEmpty) Text('Откуда: $from', style: style),
          if (to.isNotEmpty) Text('Куда: $to', style: style),
        ],
      ),
    );
  }

  String? _orderDistanceLabel(OrderRecord order) {
    final rawDistance = order.snapshotData['distanceKm'] ??
        order.snapshotData['distance_km'] ??
        order.snapshotData['routeDistanceKm'];
    final distance = castToType<double>(rawDistance);
    if (distance == null || distance <= 0) {
      return null;
    }
    return 'Расстояние: ${distance.toStringAsFixed(distance >= 10 ? 0 : 1)} км';
  }

  Widget _orderDistanceText(OrderRecord order, {TextStyle? style}) {
    final label = _orderDistanceLabel(order);
    if (label == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(label, style: style),
    );
  }

  DateTime? _orderDate(OrderRecord order) {
    final dateCreateRaw = order.snapshotData['dateCreate'];
    final createdAtRaw = order.snapshotData['created_at'];
    return order.date ??
        (dateCreateRaw is DateTime ? dateCreateRaw : null) ??
        (createdAtRaw is DateTime ? createdAtRaw : null);
  }

  String _orderTimeLabel(BuildContext context, OrderRecord order) {
    final date = _orderDate(order);
    if (date == null) {
      return '--:--';
    }
    return dateTimeFormat(
      "Hm",
      date,
      locale: FFLocalizations.of(context).languageCode,
    );
  }

  Widget _buildDriverOrderSummary(
    BuildContext context,
    OrderRecord order,
    String orderType,
    UsersRecord? passenger,
  ) {
    final comment = orderType == 'delivery'
        ? _orderDeliveryItem(order.snapshotData)
        : _orderComment(order.snapshotData, order.comment);
    final from = _safeOrderAddress(order, 'ot');
    final to = _safeOrderAddress(order, 'kuda');
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 26, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _orderTypeTitle(orderType),
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  color: _mtaxiOrange,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          if (from.isNotEmpty)
            Text(
              'Откуда: $from',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FlutterFlowTheme.of(context).bodyLarge.override(
                    color: _mtaxiLightText,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          const SizedBox(height: 8),
          if (to.isNotEmpty)
            Text(
              'Куда: $to',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FlutterFlowTheme.of(context).bodyLarge.override(
                    color: _mtaxiLightText,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Стоимость: ${formatAppCurrency(order.price)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlutterFlowTheme.of(context).bodyLarge.override(
                        color: _mtaxiLightText,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 106,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _mtaxiOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Взять',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    color: _mtaxiLightMuted,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _intercityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: const Text(
        'МЕЖГОРОД',
        style: TextStyle(
          color: Colors.orange,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _deliveryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green),
      ),
      child: const Text(
        'ДОСТАВКА',
        style: TextStyle(
          color: Colors.green,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _taxiBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue),
      ),
      child: const Text(
        'ТАКСИ',
        style: TextStyle(
          color: Colors.blue,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  bool _isOrderTakenByAnotherDriver(OrderRecord order) {
    final driverPath = _authoritativeDriverPath();
    final assignedDriver = order.idDriver;
    return order.status > 0 &&
        order.status < 5 &&
        assignedDriver != null &&
        assignedDriver.path != driverPath;
  }

  String _unavailableOrderMessage(OrderRecord order) {
    if (order.status >= 5) return 'Заказ уже закрыт';
    if (_isOrderTakenByAnotherDriver(order)) {
      return 'Заказ взял другой водитель';
    }
    return 'Заказ взял другой водитель';
  }

  Future<void> _loadSoundEnabledPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('ff_soundEnabled');
      if (!mounted) return;
      setState(() {
        _soundEnabledUi = saved ?? FFAppState().soundEnabled;
      });
      FFAppState().soundEnabled = _soundEnabledUi;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _soundEnabledUi = FFAppState().soundEnabled;
      });
    }
  }

  Future<void> _loadSeenOrderSoundIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_seenOrderSoundPrefsKey) ?? const [];
      _seenOrderIds
        ..clear()
        ..addAll(ids.where((id) => id.trim().isNotEmpty));
    } catch (_) {}
  }

  Future<void> _persistSeenOrderSoundIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = _seenOrderIds.toList();
      final limited = ids.length <= _seenOrderSoundLimit
          ? ids
          : ids.sublist(ids.length - _seenOrderSoundLimit);
      await prefs.setStringList(_seenOrderSoundPrefsKey, limited);
    } catch (_) {}
  }

  Future<void> _loadRuntimeSettings() async {
    final settings = await getAppRuntimeSettings();
    _runtimeSettings = settings;
    _restartLocationSyncTimer();
    if (!mounted) return;
    setState(() {});
  }

  void _restartLocationSyncTimer() {
    _model.instantTimer?.cancel();
    _model.instantTimer = InstantTimer.periodic(
      duration: Duration(seconds: _runtimeSettings.driverCoordsUpdateSec),
      callback: (timer) async {
        await _resolveLocation();
        final location = currentUserLocationValue;
        if (location != null) {
          await makeCloudCall(
            'updateUserPreferences',
            {
              'coords': {
                'latitude': location.latitude,
                'longitude': location.longitude,
              },
            },
          );
        }
      },
      startImmediately: true,
    );
  }

  String _emptyText(BuildContext context) {
    if (widget.emptyText != 'Нет заказов в радиусе 10 км') {
      return widget.emptyText;
    }
    final radius = _maxOrderDistanceKm;
    final radiusText =
        radius % 1 == 0 ? radius.toStringAsFixed(0) : radius.toStringAsFixed(1);
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Нет заказов в радиусе $radiusText км',
      kkText: '$radiusText км радиуста тапсырыс жоқ',
    );
  }

  String _normalizedCityKey(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  double? _distanceKm(LatLng? a, LatLng? b) {
    if (a == null || b == null) return null;
    final meters = Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
    return meters / 1000.0;
  }

  bool _isWithinDriverOrderRadius(LatLng orderLocation) {
    final locations = <LatLng?>[
      currentUserLocationValue,
      currentUserDocument?.coords,
    ];
    for (final location in locations) {
      final distKm = _distanceKm(location, orderLocation);
      if (distKm != null && distKm <= _maxOrderDistanceKm) {
        return true;
      }
    }
    return false;
  }

  Stream<List<OrderRecord>> _driverOrderStream() {
    return availableDriverOrdersStreamFromBackend(
      driverLocation: () =>
          currentUserLocationValue ?? currentUserDocument?.coords,
      radiusKm: _maxOrderDistanceKm,
    );
  }

  Future<void> _resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Включите геолокацию';
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
          _locationError = 'Дайте доступ к геолокации';
          currentUserLocationValue = null;
        });
        return;
      }
      final position = await getSafeCurrentPosition(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      setState(() {
        _locationError = null;
        currentUserLocationValue =
            LatLng(position.latitude, position.longitude);
      });
    } catch (_) {
      setState(() {
        _locationError = 'Не удалось получить геолокацию';
        currentUserLocationValue = null;
      });
    }
  }

  Future<Map<String, dynamic>> _takeOrder(OrderRecord order) async {
    final driverRef = _authDriverDocRef();
    if (driverRef == null) {
      return {
        'accepted': false,
        'code': 'UNAUTHENTICATED',
        'message': 'Пользователь не авторизован',
      };
    }

    try {
      final clientRuntime = await getClientRuntimeContext();
      final response = await makeCloudCall('acceptOrder', {
        'orderDocPath': order.reference.path,
        'userDocPath': driverRef.path,
        'claimRequestId': _uuid.v4(),
        'platform': clientRuntime['platform'] ?? currentClientPlatform(),
        'appVersion': clientRuntime['appVersion'] ?? '',
      });
      final accepted = response['accepted'] == true;
      final code = (response['code'] ?? '').toString().trim();
      final message =
          (response['message'] ?? response['error'] ?? '').toString().trim();
      return {
        'accepted': accepted,
        'code': code,
        'message': message,
        'orderDocPath': (response['orderDocPath'] ?? '').toString().trim(),
        'driverDocPath': (response['driverDocPath'] ?? '').toString().trim(),
        'status': response['status'],
      };
    } catch (_) {
      return {
        'accepted': false,
        'code': 'ORDER_ACCEPT_FAILED',
        'message': 'Не удалось взять заказ',
      };
    }
  }

  void _stabilizeAcceptedDriverOrder(String? orderDocPath) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      DocumentReference? resolvedOrderRef;
      final normalizedPath = (orderDocPath ?? '').trim();
      if (normalizedPath.startsWith('order/') ||
          normalizedPath.startsWith('orders/')) {
        resolvedOrderRef = BackendRefs.instance.doc(normalizedPath);
      }
      if (resolvedOrderRef == null) {
        resolvedOrderRef = await recoverActiveDriverOrderRefFromServer();
      }
      if (!mounted || resolvedOrderRef == null) return;
      _syncLocalDriverOrderRef(resolvedOrderRef);
      UserModeResolver.setTransientRoleState('DRIVER_ON_TRIP');
      FFAppState().update(() {});
    });
  }

  Future<void> _openAcceptedDriverOrder(DocumentReference orderRef) async {
    if (!mounted) return;
    setState(() {
      _openingAcceptedDriverOrder = true;
    });
    FFAppState().syncLegacyOrderRefs(
      passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
      driverOrderRef: orderRef,
    );
    FFAppState().markDriverOrderAcceptedLocally(
      orderRef,
      driverDocPath: _authoritativeDriverPath(),
    );
    UserModeResolver.setTransientRoleState('DRIVER_ON_TRIP');
    FFAppState().update(() {});
    _stabilizeAcceptedDriverOrder(orderRef.path);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.goNamed(
        HomeDriverOrderWidget.routeName,
        queryParameters: {
          'orderDocPath': orderRef.path,
        },
        extra: <String, dynamic>{
          kTransitionInfoKey: TransitionInfo(
            hasTransition: true,
            transitionType: PageTransitionType.scale,
            alignment: Alignment.bottomCenter,
          ),
        },
      );
    });
  }

  Future<void> _acceptAndOpenDriverOrder(
    BuildContext context,
    OrderRecord order,
  ) async {
    if (_takingOrderIds.contains(order.reference.id)) {
      return;
    }
    setState(() {
      _takingOrderIds.add(order.reference.id);
      _openingAcceptedDriverOrder = true;
    });
    _acceptedOrderIds.add(order.reference.id);
    _dismissedUnavailableOrderIds.remove(order.reference.id);
    _notifiedUnavailableOrderIds.remove(order.reference.id);
    _autoClosingUnavailableOrderIds.remove(order.reference.id);

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    final result = await _takeOrder(order);
    if (!mounted) {
      return;
    }

    setState(() {
      _takingOrderIds.remove(order.reference.id);
    });

    final accepted = result['accepted'] == true;
    final code = (result['code'] ?? '').toString().trim();
    final message = (result['message'] ?? '').toString().trim();
    final acceptedOrderDocPath =
        (result['orderDocPath'] ?? '').toString().trim();
    final acceptedDriverDocPath =
        (result['driverDocPath'] ?? '').toString().trim();

    if (!accepted) {
      setState(() {
        _openingAcceptedDriverOrder = false;
        _acceptedOrderIds.remove(order.reference.id);
      });
      if (code == 'ORDER_ALREADY_TAKEN' || code == 'ORDER_NOT_ACTIVE') {
        _dismissedUnavailableOrderIds.add(order.reference.id);
      }
      _showDriverFeedMessage(
        code == 'DRIVER_BALANCE_TOO_LOW'
            ? 'Недостаточно баланса для принятия заказа'
            : (message.isNotEmpty ? message : 'Не удалось взять заказ'),
      );
      return;
    }

    final authoritativeOrderRef = acceptedOrderDocPath.isNotEmpty
        ? BackendRefs.instance.doc(acceptedOrderDocPath)
        : order.reference;
    if (acceptedDriverDocPath.startsWith('users/')) {
      try {
        final response = await makeCloudCall('getSessionBootstrap', const {});
        currentUserDocument =
            await applyBackendUserResponse(response) ?? currentUserDocument;
      } catch (_) {}
    }
    FFAppState().syncLegacyOrderRefs(
      passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
      driverOrderRef: authoritativeOrderRef,
    );
    FFAppState().markDriverOrderAcceptedLocally(
      authoritativeOrderRef,
      driverDocPath: acceptedDriverDocPath.isNotEmpty
          ? acceptedDriverDocPath
          : _authoritativeDriverPath(),
    );
    UserModeResolver.setTransientRoleState('DRIVER_ON_TRIP');
    FFAppState().update(() {});
    _stabilizeAcceptedDriverOrder(authoritativeOrderRef.path);
    await _openAcceptedDriverOrder(authoritativeOrderRef);
  }

  void _showOrderUnavailableOnce(
    BuildContext context,
    String orderId,
    String message,
  ) {
    if (_acceptedOrderIds.contains(orderId)) {
      return;
    }
    if (!_notifiedUnavailableOrderIds.add(orderId)) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showDriverFeedMessage(String message) {
    final messengerContext = scaffoldKey.currentContext ?? context;
    ScaffoldMessenger.of(messengerContext).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _trackVisibleOrderAvailability(
    BuildContext context,
    List<OrderRecord> visibleOrders,
  ) {
    final currentIds = visibleOrders.map((order) => order.reference.id).toSet();
    final disappearedIds = _visibleOrderRefsById.keys
        .where((orderId) => !currentIds.contains(orderId))
        .toList();
    for (final order in visibleOrders) {
      _visibleOrderRefsById[order.reference.id] = order.reference;
    }
    for (final orderId in disappearedIds) {
      final orderRef = _visibleOrderRefsById[orderId];
      if (orderRef == null ||
          _acceptedOrderIds.contains(orderId) ||
          !_checkingUnavailableOrderIds.add(orderId)) {
        _visibleOrderRefsById.remove(orderId);
        continue;
      }
      unawaited(() async {
        try {
          final latest = await loadOrderDetailsFromBackend(orderRef.path);
          if (latest == null) {
            return;
          }
          if (!mounted) return;
          if (_isOrderTakenByAnotherDriver(latest)) {
            setState(() {
              _dismissedUnavailableOrderIds.add(orderId);
            });
            _showOrderUnavailableOnce(
              context,
              orderId,
              'Заказ взял другой водитель',
            );
          }
        } catch (_) {
        } finally {
          _checkingUnavailableOrderIds.remove(orderId);
          _visibleOrderRefsById.remove(orderId);
        }
      }());
    }
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomeDriverModel());
    _soundEnabledUi = FFAppState().soundEnabled;
    _loadSoundEnabledPreference();
    _loadSeenOrderSoundIds();
    _loadRuntimeSettings();
    _bindAuthoritativeDriverDoc();
    _restartOrderListRefreshTimer();

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (!UserModeResolver.canOpenDriverScreens(currentUserDocument)) {
        if (_shouldHoldDriverFlowDuringSync()) {
          _recoverActiveDriverOrderIfNeeded();
        }
        return;
      }
      await _resolveLocation();
      final activeOrderRef = _effectiveDriverOrderRef();
      if ((!_openingAcceptedDriverOrder &&
              activeOrderRef?.id != null &&
              activeOrderRef?.id != '') ||
          FFAppState().shouldSuppressDriverOrderAuthoritativeRecovery()) {
        _recoverActiveDriverOrderIfNeeded();
      }
      _restartLocationSyncTimer();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.orderListRefreshTimer?.cancel();
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
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8EDF1);
    final ctaTextColor =
        isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    if (!UserModeResolver.canOpenDriverScreens(currentUserDocument)) {
      if (_shouldHoldDriverFlowDuringSync()) {
        _recoverActiveDriverOrderIfNeeded();
        return Scaffold(
          key: scaffoldKey,
          backgroundColor: pageBg,
          body: SafeArea(
            top: true,
            child: Center(
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
                      'Синхронизируем режим водителя...',
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context)
                          .bodyMedium
                          .override(color: mutedColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      if (!_redirectingToPassengerMode) {
        _redirectingToPassengerMode = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.goNamed(HomePageWidget.routeName);
          _redirectingToPassengerMode = false;
        });
      }
      return Scaffold(
        key: scaffoldKey,
        backgroundColor: pageBg,
        body: SafeArea(
          top: true,
          child: Center(
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
          ),
        ),
      );
    }
    final effectiveLocation =
        currentUserLocationValue ?? currentUserDocument?.coords;
    if (effectiveLocation == null) {
      return Scaffold(
        key: scaffoldKey,
        backgroundColor: pageBg,
        body: SafeArea(
          top: true,
          child: Center(
            child: Text(
              _locationError ?? 'Включите геолокацию',
              style: FlutterFlowTheme.of(context)
                  .bodyMedium
                  .override(color: mutedColor),
            ),
          ),
        ),
      );
    }

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
              final activeOrderRef = _effectiveDriverOrderRef();
              _syncLocalDriverOrderRef(activeOrderRef);
              if (_openingAcceptedDriverOrder) {
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
                          'Открываем информацию о заказе...',
                          textAlign: TextAlign.center,
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final hasAuthoritativeActiveOrder = activeOrderRef != null;
              final shouldRecoverDriverOrderInBackground =
                  !_openingAcceptedDriverOrder &&
                      !hasAuthoritativeActiveOrder &&
                      (getEffectiveDriverLegacyOrderRef() != null ||
                          getUserRoleState(currentUserDocument) ==
                              'DRIVER_ON_TRIP' ||
                          FFAppState()
                              .shouldSuppressDriverOrderAuthoritativeRecovery());
              if (shouldRecoverDriverOrderInBackground) {
                _recoverActiveDriverOrderIfNeeded();
              }
              if (_openingAcceptedDriverOrder || hasAuthoritativeActiveOrder) {
                _recoverActiveDriverOrderIfNeeded();
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
                          'Открываем активный заказ...',
                          textAlign: TextAlign.center,
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final orderStream = _driverOrderStream();
              return StreamBuilder<List<OrderRecord>>(
                  stream: orderStream,
                  initialData: const [],
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Не удалось загрузить заказы',
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(color: _mtaxiMuted),
                        ),
                      );
                    }
                    final driverOrderRecordList =
                        snapshot.data ?? <OrderRecord>[];
                    for (final order in driverOrderRecordList) {
                      if (_isOrderTakenByAnotherDriver(order) ||
                          order.status >= 5) {
                        _dismissedUnavailableOrderIds.add(order.reference.id);
                      }
                    }
                    _trackOrderCancellation(driverOrderRecordList);
                    final now = DateTime.now();
                    final allowedTypes = widget.allowedTypes;
                    final driverCityKey =
                        _normalizedCityKey(currentUserDocument?.city);
                    final visibleOrders = driverOrderRecordList.where((order) {
                      final dateCreateRaw = order.snapshotData['dateCreate'];
                      final date = order.date ??
                          (dateCreateRaw is DateTime ? dateCreateRaw : null);
                      final statusRaw = order.snapshotData['status'];
                      final parsedStatus = statusRaw is num
                          ? statusRaw.toInt()
                          : int.tryParse(statusRaw?.toString() ?? '');
                      final status = parsedStatus ?? 0;
                      if (status != 0 || date == null) {
                        return false;
                      }
                      if (!_isOrderDelayElapsed(now, date)) {
                        return false;
                      }
                      final type =
                          (order.snapshotData['type'] as String?) ?? 'taxi';
                      if (allowedTypes != null && allowedTypes.isNotEmpty) {
                        if (!allowedTypes.contains(type)) {
                          return false;
                        }
                      }
                      if (order.snapshotData['backendSource'] == true) {
                        return now.difference(date) < _pendingOrderTtl;
                      }
                      final coordsForDistance =
                          order.otCoords ?? order.kudaCoords;
                      if (coordsForDistance == null) {
                        final orderCityKey = _normalizedCityKey(order.city);
                        if (driverCityKey.isEmpty ||
                            orderCityKey.isEmpty ||
                            driverCityKey != orderCityKey) {
                          return false;
                        }
                        return now.difference(date) < _pendingOrderTtl;
                      }
                      if (!_isWithinDriverOrderRadius(coordsForDistance)) {
                        return false;
                      }
                      return now.difference(date) < _pendingOrderTtl;
                    }).toList()
                      ..sort((a, b) {
                        final aType = (a.snapshotData['type'] as String?) ?? '';
                        final bType = (b.snapshotData['type'] as String?) ?? '';
                        if (aType == 'intercity' && bType != 'intercity') {
                          return -1;
                        }
                        if (aType != 'intercity' && bType == 'intercity') {
                          return 1;
                        }
                        return (b.date ?? now).compareTo(a.date ?? now);
                      });
                    final nowAfterFilter = DateTime.now();
                    if (visibleOrders.isNotEmpty) {
                      _lastNonEmptyDriverOrders = List<OrderRecord>.from(
                        visibleOrders,
                      );
                      _lastNonEmptyDriverOrdersAt = nowAfterFilter;
                    }
                    final canHoldLastOrders = visibleOrders.isEmpty &&
                        _lastNonEmptyDriverOrders.isNotEmpty &&
                        _lastNonEmptyDriverOrdersAt != null &&
                        nowAfterFilter.difference(
                              _lastNonEmptyDriverOrdersAt!,
                            ) <
                            const Duration(seconds: 3);
                    final displayOrders = canHoldLastOrders
                        ? List<OrderRecord>.from(_lastNonEmptyDriverOrders)
                        : visibleOrders;
                    _trackVisibleOrderAvailability(context, displayOrders);
                    displayOrders.removeWhere(
                      (order) => _dismissedUnavailableOrderIds
                          .contains(order.reference.id),
                    );
                    if (_soundEnabledUi) {
                      _playNewOrderSounds(displayOrders);
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const DriverBonusCard(),
                        Container(
                          height: 58,
                          color: surface,
                          alignment: Alignment.center,
                          child: Text(
                            'Лента заказов',
                            style: FlutterFlowTheme.of(context)
                                .titleLarge
                                .override(
                                  color: textColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        if (displayOrders.isEmpty)
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  _emptyText(context),
                                  textAlign: TextAlign.center,
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(color: mutedColor),
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 26, 16, 150),
                              itemCount: displayOrders.length,
                              itemBuilder: (context, driverIndex) {
                                final driverOrderRecord =
                                    displayOrders[driverIndex];
                                final orderType = (driverOrderRecord
                                        .snapshotData['type'] as String?) ??
                                    'taxi';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 24.0),
                                  child: InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      final parentContext = context;
                                      final isVip = (currentUserDocument
                                              ?.snapshotData['vip'] as bool?) ??
                                          false;
                                      if (!isVip &&
                                          ((currentUserDocument?.balance ?? 0) +
                                              ((currentUserDocument?.snapshotData['bonusBalance'] as num?)?.toDouble() ?? 0)) <
                                              _driverMinBalanceToTakeOrder) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Пополните счет',
                                            ),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                        return;
                                      }
                                      if (activeOrderRef?.id != null &&
                                          activeOrderRef?.id != '') {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'У вас уже есть активный заказ'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                        return;
                                      }
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        backgroundColor: surface,
                                        barrierColor: Colors.black54,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(22),
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        enableDrag: false,
                                        context: context,
                                        builder: (context) {
                                          return WebViewAware(
                                            child: StreamBuilder<OrderRecord>(
                                              stream: Stream.value(
                                                driverOrderRecord,
                                              ),
                                              builder:
                                                  (context, orderSnapshot) {
                                                final wasAcceptedLocally =
                                                    _acceptedOrderIds.contains(
                                                  driverOrderRecord
                                                      .reference.id,
                                                );
                                                final isTakingThisOrder =
                                                    _takingOrderIds.contains(
                                                  driverOrderRecord
                                                      .reference.id,
                                                );
                                                if (orderSnapshot.hasError) {
                                                  if (wasAcceptedLocally ||
                                                      isTakingThisOrder) {
                                                    _stabilizeAcceptedDriverOrder(
                                                      driverOrderRecord
                                                          .reference.path,
                                                    );
                                                    return const SizedBox(
                                                      height: 220,
                                                      child: Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                                    );
                                                  }
                                                  return SizedBox(
                                                    height: 220,
                                                    child: Center(
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(16.0),
                                                        child: Text(
                                                          'Не удалось загрузить заказ. Попробуйте открыть его снова.',
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }
                                                if (!orderSnapshot.hasData) {
                                                  return const SizedBox(
                                                    height: 220,
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                  );
                                                }
                                                final liveOrder =
                                                    orderSnapshot.data!;
                                                final liveOrderType = (liveOrder
                                                            .snapshotData[
                                                        'type'] as String?) ??
                                                    'taxi';
                                                final liveIsIntercity =
                                                    liveOrderType ==
                                                        'intercity';
                                                final isOrderAvailable =
                                                    liveOrder.status == 0 &&
                                                        liveOrder.idDriver ==
                                                            null;
                                                final isAssignedToCurrentDriver =
                                                    liveOrder.status < 5 &&
                                                        (liveOrder.idDriver
                                                                    ?.path ==
                                                                _authoritativeDriverPath() ||
                                                            wasAcceptedLocally);
                                                if (!isOrderAvailable &&
                                                    !isAssignedToCurrentDriver &&
                                                    !_takingOrderIds.contains(
                                                      liveOrder.reference.id,
                                                    ) &&
                                                    _autoClosingUnavailableOrderIds
                                                        .add(
                                                      liveOrder.reference.id,
                                                    )) {
                                                  WidgetsBinding.instance
                                                      .addPostFrameCallback(
                                                          (_) {
                                                    if (!mounted) return;
                                                    _dismissedUnavailableOrderIds
                                                        .add(liveOrder
                                                            .reference.id);
                                                    Navigator.of(context)
                                                        .maybePop();
                                                    _showOrderUnavailableOnce(
                                                      parentContext,
                                                      liveOrder.reference.id,
                                                      _unavailableOrderMessage(
                                                        liveOrder,
                                                      ),
                                                    );
                                                  });
                                                }

                                                return GestureDetector(
                                                  onTap: () {
                                                    FocusScope.of(context)
                                                        .unfocus();
                                                    FocusManager
                                                        .instance.primaryFocus
                                                        ?.unfocus();
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        MediaQuery.viewInsetsOf(
                                                            context),
                                                    child: Container(
                                                      height: MediaQuery.sizeOf(
                                                                  context)
                                                              .height *
                                                          0.55,
                                                      decoration: BoxDecoration(
                                                        color: surface,
                                                      ),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        children: [
                                                          const SizedBox(
                                                              height: 12),
                                                          Text(
                                                            'Детали заказа',
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .headlineSmall
                                                                .override(
                                                                  color:
                                                                      textColor,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                              height: 12),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        16),
                                                            child: (isOrderAvailable ||
                                                                    isAssignedToCurrentDriver)
                                                                ? Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Row(
                                                                        children: [
                                                                          Text(
                                                                            'Время: ${_orderTimeLabel(context, liveOrder)}',
                                                                            style:
                                                                                FlutterFlowTheme.of(context).bodyMedium.override(color: textColor),
                                                                          ),
                                                                          if (liveIsIntercity) ...[
                                                                            const SizedBox(width: 8),
                                                                            Container(
                                                                              padding: const EdgeInsets.symmetric(
                                                                                horizontal: 8,
                                                                                vertical: 2,
                                                                              ),
                                                                              decoration: BoxDecoration(
                                                                                color: Colors.orange.withValues(alpha: 0.15),
                                                                                borderRadius: BorderRadius.circular(8),
                                                                                border: Border.all(
                                                                                  color: Colors.orange,
                                                                                ),
                                                                              ),
                                                                              child: const Text(
                                                                                'МЕЖГОРОД',
                                                                                style: TextStyle(
                                                                                  color: Colors.orange,
                                                                                  fontWeight: FontWeight.w600,
                                                                                  fontSize: 11,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ],
                                                                      ),
                                                                      _orderDistanceText(
                                                                          liveOrder),
                                                                      _orderAddressBlock(
                                                                          liveOrder),
                                                                      Text(
                                                                        'Стоимость: ${formatAppCurrency(liveOrder.price)}',
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .titleMedium
                                                                            .override(
                                                                              color: _mtaxiMint,
                                                                              fontWeight: FontWeight.w800,
                                                                            ),
                                                                      ),
                                                                      const SizedBox(
                                                                          height:
                                                                              6),
                                                                      if (liveOrderType !=
                                                                              'delivery' &&
                                                                          _orderComment(liveOrder.snapshotData, liveOrder.comment)
                                                                              .isNotEmpty)
                                                                        Text(
                                                                          'Комментарий: ${_orderComment(liveOrder.snapshotData, liveOrder.comment)}',
                                                                          style: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .override(color: mutedColor),
                                                                        ),
                                                                      if (_orderDeliveryItem(
                                                                              liveOrder.snapshotData)
                                                                          .isNotEmpty) ...[
                                                                        const SizedBox(
                                                                            height:
                                                                                6),
                                                                        Text(
                                                                          'Что доставить: ${_orderDeliveryItem(liveOrder.snapshotData)}',
                                                                          style: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .override(color: mutedColor),
                                                                        ),
                                                                      ],
                                                                    ],
                                                                  )
                                                                : Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                        _unavailableOrderMessage(
                                                                          liveOrder,
                                                                        ),
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .titleMedium
                                                                            .override(color: textColor),
                                                                      ),
                                                                      const SizedBox(
                                                                          height:
                                                                              8),
                                                                      Text(
                                                                        'Закройте окно заказа.',
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .override(color: mutedColor),
                                                                      ),
                                                                    ],
                                                                  ),
                                                          ),
                                                          const Spacer(),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(16),
                                                            child: Builder(
                                                              builder:
                                                                  (context) {
                                                                final isTakingOrder =
                                                                    _takingOrderIds
                                                                        .contains(
                                                                  liveOrder
                                                                      .reference
                                                                      .id,
                                                                );
                                                                return FFButtonWidget(
                                                                  onPressed: isAssignedToCurrentDriver
                                                                      ? () async {
                                                                          FFAppState()
                                                                              .syncLegacyOrderRefs(
                                                                            passengerOrderRef:
                                                                                getEffectivePassengerLegacyOrderRef(),
                                                                            driverOrderRef:
                                                                                liveOrder.reference,
                                                                          );
                                                                          UserModeResolver
                                                                              .setTransientRoleState(
                                                                            'DRIVER_ON_TRIP',
                                                                          );
                                                                          FFAppState()
                                                                              .update(() {});
                                                                          Navigator
                                                                              .pop(
                                                                            context,
                                                                          );
                                                                          parentContext
                                                                              .goNamed(
                                                                            HomeDriverOrderWidget.routeName,
                                                                            extra: <String,
                                                                                dynamic>{
                                                                              kTransitionInfoKey: TransitionInfo(
                                                                                hasTransition: true,
                                                                                transitionType: PageTransitionType.scale,
                                                                                alignment: Alignment.bottomCenter,
                                                                              ),
                                                                            },
                                                                          );
                                                                        }
                                                                      : !isOrderAvailable
                                                                          ? () async {
                                                                              _dismissedUnavailableOrderIds.add(
                                                                                liveOrder.reference.id,
                                                                              );
                                                                              Navigator.pop(context);
                                                                            }
                                                                          : () async {
                                                                              await _acceptAndOpenDriverOrder(
                                                                                parentContext,
                                                                                liveOrder,
                                                                              );
                                                                            },
                                                                  text: !isOrderAvailable
                                                                      ? 'Закрыть'
                                                                      : isTakingOrder
                                                                          ? 'Принимаем заказ...'
                                                                          : 'Взять заказ',
                                                                  options:
                                                                      FFButtonOptions(
                                                                    height: 44,
                                                                    color: !isOrderAvailable &&
                                                                            !isAssignedToCurrentDriver
                                                                        ? Colors
                                                                            .white
                                                                            .withValues(alpha: 0.12)
                                                                        : isTakingOrder
                                                                            ? Colors.white.withValues(alpha: 0.12)
                                                                            : _mtaxiMint,
                                                                    textStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .titleSmall
                                                                        .override(
                                                                          color:
                                                                              ctaTextColor,
                                                                          fontWeight:
                                                                              FontWeight.w800,
                                                                        ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            12),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: surface,
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        12, 10, 6, 8),
                                                child: Text(
                                                  _orderTimeLabel(
                                                    context,
                                                    driverOrderRecord,
                                                  ),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts
                                                            .readexPro(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        fontSize: 12.0,
                                                        color: _mtaxiMuted,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                ),
                                              ),
                                              if (orderType == 'intercity') ...[
                                                const SizedBox(width: 4),
                                                _intercityBadge(),
                                              ],
                                              if (orderType == 'delivery') ...[
                                                const SizedBox(width: 4),
                                                _deliveryBadge(),
                                              ],
                                              if (orderType == 'taxi') ...[
                                                const SizedBox(width: 4),
                                                _taxiBadge(),
                                              ],
                                            ],
                                          ),
                                          _buildDriverOrderSummary(
                                            context,
                                            driverOrderRecord,
                                            orderType,
                                            null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  });
            },
          ),
        ),
      ),
    );
  }

  void _playNewOrderSounds(List<OrderRecord> orders) {
    final newOrders = orders
        .where((order) => !_seenOrderIds.contains(order.reference.id))
        .toList();
    if (newOrders.isEmpty) {
      return;
    }
    for (final order in newOrders) {
      _seenOrderIds.add(order.reference.id);
    }
    unawaited(_persistSeenOrderSoundIds());
    final type = (newOrders.first.snapshotData['type'] as String?) ?? 'taxi';
    _playSoundForType(type);
  }

  void _trackOrderCancellation(List<OrderRecord> orders) {
    final next = <String, int>{};
    final currentDriverPath = _authoritativeDriverPath();
    for (final order in orders) {
      next[order.reference.id] = order.status;
      final prevStatus = _knownOrderStatuses[order.reference.id];
      final isAssignedToCurrentDriver = currentDriverPath.isNotEmpty &&
          order.idDriver?.path == currentDriverPath;
      if (_didInitOrderStatusTracker &&
          prevStatus != null &&
          prevStatus != 6 &&
          order.status == 6 &&
          isAssignedToCurrentDriver) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Заказ отменен пассажиром'),
              duration: Duration(seconds: 3),
            ),
          );
        });
      }
    }
    _knownOrderStatuses
      ..clear()
      ..addAll(next);
    _didInitOrderStatusTracker = true;
  }

  Future<void> _playSoundForType(String type) async {
    final normalizedType = type.trim().toLowerCase();
    final assetName = switch (normalizedType) {
      'delivery' || 'gruz' => 'audios/delivery.wav',
      'intercity' || 'citytocity' || 'city_to_city' => 'audios/intercity.wav',
      _ => 'audios/taxi.wav',
    };
    var customPlayed = false;
    try {
      final player = AudioPlayer();
      await player.play(AssetSource(assetName));
      unawaited(player.onPlayerComplete.first
          .timeout(const Duration(seconds: 5), onTimeout: () {})
          .then((_) => player.dispose()));
      customPlayed = true;
    } catch (_) {}
    if (!customPlayed) {
      try {
        final player = AudioPlayer();
        await player.play(AssetSource('audios/whatsapp_notification.mp3'));
        unawaited(player.onPlayerComplete.first
            .timeout(const Duration(seconds: 5), onTimeout: () {})
            .then((_) => player.dispose()));
        customPlayed = true;
      } catch (_) {}
    }
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
}
