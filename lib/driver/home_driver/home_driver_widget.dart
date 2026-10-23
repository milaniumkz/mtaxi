import '/design/bottom_navigation.dart';
import '/design/order_preview.dart';
import '/design/mtaxi_theme.dart';
import '/design/map_attribution.dart';
import 'package:flutter_map/flutter_map.dart' as maps;
import 'package:latlong2/latlong.dart' as geo;
import '/trips/order_offers.dart';
import '/auth/backend_auth/auth_util.dart';
import '/backend/app_settings/app_settings.dart';
import '/backend/backend.dart';
import '/backend/backend_orders.dart';
import '/backend/backend_user_adapter.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/backend/order_state_compat.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

import '/flutter_flow/instant_timer.dart';
import 'dart:async';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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

const _mtaxiMint = Color(0xFF126E68);
const _mtaxiMuted = Color(0xFF5C6862);
const _mtaxiLightText = Color(0xFF17111D);

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
  bool _tabActive = true;
  bool _showFeed = false;
  String? _feedType;
  bool _redirectingToPassengerMode = false;
  bool _recoveringActiveDriverOrder = false;
  bool _openingAcceptedDriverOrder = false;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  LatLng? currentUserLocationValue;
  double? _lastGpsAccuracy;
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
    final elapsed = DateTime.now().difference(date);
    if (!elapsed.isNegative && elapsed < const Duration(minutes: 1))
      return FFLocalizations.of(context)
          .getVariableText(ruText: 'Только что', kkText: 'Жаңа ғана');
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
    return MTaxiCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(_orderTypeTitle(orderType),
                style: const TextStyle(fontSize: 12)),
            Text(_orderTimeLabel(context, order),
                style: const TextStyle(fontSize: 12))
          ]),
      const SizedBox(height: 16),
      Text(from,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Text('→ $to'),
      if (_orderDistanceLabel(order) != null) ...[
        const SizedBox(height: 10),
        _orderDistanceText(order)
      ],
      if (comment.isNotEmpty) ...[const SizedBox(height: 10), Text(comment)],
      const SizedBox(height: 18),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Text(formatAppCurrency(order.price),
                style:
                    const TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
            const DecoratedBox(
                decoration: BoxDecoration(
                    color: MTaxiDesign.gold,
                    borderRadius: BorderRadius.all(Radius.circular(14))),
                child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Text('Посмотреть',
                        style: TextStyle(
                            color: MTaxiDesign.ink,
                            fontWeight: FontWeight.w700)))),
          ]),
    ]));
  }

  Widget _intercityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: MTaxiDesign.muted.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MTaxiDesign.muted),
      ),
      child: const Text(
        'МЕЖГОРОД',
        style: TextStyle(
          color: MTaxiDesign.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _deliveryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF126E68).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF126E68)),
      ),
      child: const Text(
        'ДОСТАВКА',
        style: TextStyle(
          color: const Color(0xFF126E68),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _taxiBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF126E68).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF126E68)),
      ),
      child: const Text(
        'ТАКСИ',
        style: TextStyle(
          color: const Color(0xFF126E68),
          fontSize: 12,
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
        if (!_tabActive ||
            !(ModalRoute.of(context)?.isCurrent ?? true) ||
            (WidgetsBinding.instance.lifecycleState != null &&
                WidgetsBinding.instance.lifecycleState !=
                    AppLifecycleState.resumed)) return;
        await _resolveLocation();
        if (!_tabActive || !mounted) return;
        final location = currentUserLocationValue;
        if (location != null) {
          await makeCloudCall(
            'updateUserPreferences',
            {
              'coords': {
                'latitude': location.latitude,
                'longitude': location.longitude,
                'accuracy': _lastGpsAccuracy,
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
        _lastGpsAccuracy = position.accuracy;
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
          if (_isActiveOrderForCurrentDriver(latest) &&
              _tabActive &&
              !_openingAcceptedDriverOrder &&
              (ModalRoute.of(context)?.isCurrent ?? false)) {
            await _openAcceptedDriverOrder(latest.reference);
          } else if (_isOrderTakenByAnotherDriver(latest)) {
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabActive = MTaxiTabActivity.isActive(context);
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

  Widget _driverLanding(LatLng center) {
    String tr(String ru, String kk) =>
        FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
    final user = currentUserDocument;
    return Column(children: [
      Expanded(
          child: Stack(children: [
        maps.FlutterMap(
            options: maps.MapOptions(
                initialCenter: geo.LatLng(center.latitude, center.longitude),
                initialZoom: 14,
                maxZoom: 18),
            children: [
              maps.TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mtaxi.app'),
              if (currentUserLocationValue != null)
                maps.MarkerLayer(markers: [
                  maps.Marker(
                      point: geo.LatLng(center.latitude, center.longitude),
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.local_taxi,
                          size: 36, color: MTaxiDesign.ink))
                ]),
              const MTaxiMapAttribution(),
            ]),
        const Positioned(top: 36, left: 22, child: MTaxiBrand()),
      ])),
      ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .5),
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(tr('Хорошего дня!', 'Күніңіз сәтті өтсін!'),
                        style: const TextStyle(
                            fontSize: 27, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    MTaxiCard(
                        child: Wrap(spacing: 24, runSpacing: 16, children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('Денежный счёт', 'Ақша шоты')),
                            const SizedBox(height: 6),
                            Text(
                                user == null
                                    ? '—'
                                    : formatAppCurrency(user.balance),
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w700))
                          ]),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr(
                                'Бонусы на комиссию', 'Комиссияға бонустар')),
                            const SizedBox(height: 6),
                            Text(
                                user?.snapshotData['bonusBalance'] is num
                                    ? formatAppCurrency(
                                        (user!.snapshotData['bonusBalance']
                                                as num)
                                            .toDouble())
                                    : '—',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w700))
                          ]),
                    ])),
                    const SizedBox(height: 18),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: MTaxiDesign.ink,
                            foregroundColor: Colors.white),
                        onPressed: () => setState(() => _showFeed = true),
                        child:
                            Text(tr('Смотреть заказы', 'Тапсырыстарды қарау'))),
                    const SizedBox(height: 12),
                    Text(
                        tr('Бонусы оплачивают комиссию сервиса. Деньги и бонусы учитываются отдельно.',
                            'Бонустар сервис комиссиясын төлейді. Ақша мен бонустар бөлек есептеледі.'),
                        style: const TextStyle(fontSize: 12)),
                  ]))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFFCFCFA);
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : _mtaxiLightText;
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8EDF1);
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
              if (!_showFeed) return _driverLanding(effectiveLocation);
              final orderStream = _driverOrderStream();
              return StreamBuilder<List<OrderRecord>>(
                  stream: orderStream,
                  initialData: const [],
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(FFLocalizations.of(context).getVariableText(
                              ruText: 'Не удалось загрузить заказы',
                              kkText: 'Тапсырыстар жүктелмеді')),
                          TextButton(
                              onPressed: () => setState(() {}),
                              child: Text(FFLocalizations.of(context)
                                  .getVariableText(
                                      ruText: 'Повторить',
                                      kkText: 'Қайталау'))),
                        ]),
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
                      if (_feedType != null && type != _feedType) return false;
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
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(children: [
                              IconButton(
                                  tooltip: 'К карте',
                                  onPressed: () =>
                                      setState(() => _showFeed = false),
                                  icon: const Icon(Icons.arrow_back)),
                              Expanded(
                                  child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(children: [
                                        for (final entry in <String?, String>{
                                          null: 'Все',
                                          'taxi': 'Такси',
                                          'delivery': 'Доставка'
                                        }.entries)
                                          Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 8),
                                              child: ChoiceChip(
                                                  label: Text(entry.value),
                                                  selected:
                                                      _feedType == entry.key,
                                                  selectedColor:
                                                      MTaxiDesign.gold,
                                                  onSelected: (_) => setState(
                                                      () => _feedType =
                                                          entry.key)))
                                      ])))
                            ])),
                        const DriverBonusCard(),
                        Container(
                          height: 58,
                          color: surface,
                          alignment: Alignment.center,
                          child: Text(
                            'Заказы рядом',
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
                                  const EdgeInsets.fromLTRB(22, 12, 22, 24),
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
                                                  ((currentUserDocument
                                                                      ?.snapshotData[
                                                                  'bonusBalance']
                                                              as num?)
                                                          ?.toDouble() ??
                                                      0)) <
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
                                      final previewStream =
                                          orderDetailsStreamFromBackend(
                                              driverOrderRecord.reference.path);
                                      var openingAssignedOrder = false;
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
                                              stream: previewStream,
                                              initialData: driverOrderRecord,
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
                                                if (isAssignedToCurrentDriver &&
                                                    liveOrder.status >= 2 &&
                                                    !openingAssignedOrder &&
                                                    (ModalRoute.of(context)
                                                            ?.isCurrent ??
                                                        false)) {
                                                  openingAssignedOrder = true;
                                                  WidgetsBinding.instance
                                                      .addPostFrameCallback(
                                                          (_) async {
                                                    if (!mounted ||
                                                        !context.mounted)
                                                      return;
                                                    Navigator.of(context).pop();
                                                    await _openAcceptedDriverOrder(
                                                        liveOrder.reference);
                                                  });
                                                }
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
                                                          0.88,
                                                      decoration: BoxDecoration(
                                                        color: surface,
                                                      ),
                                                      child: OrderPreview(
                                                        order: {
                                                          ...liveOrder
                                                              .snapshotData,
                                                          'price':
                                                              liveOrder.price,
                                                          'ot': liveOrder.ot,
                                                          'kuda':
                                                              liveOrder.kuda,
                                                          'fromPoint': liveOrder
                                                                      .otCoords ==
                                                                  null
                                                              ? null
                                                              : {
                                                                  'lat': liveOrder
                                                                      .otCoords!
                                                                      .latitude,
                                                                  'lng': liveOrder
                                                                      .otCoords!
                                                                      .longitude
                                                                },
                                                          'toPoint': liveOrder
                                                                      .kudaCoords ==
                                                                  null
                                                              ? null
                                                              : {
                                                                  'lat': liveOrder
                                                                      .kudaCoords!
                                                                      .latitude,
                                                                  'lng': liveOrder
                                                                      .kudaCoords!
                                                                      .longitude
                                                                }
                                                        },
                                                        unavailable:
                                                            !isOrderAvailable,
                                                        busy: _takingOrderIds
                                                            .contains(liveOrder
                                                                .reference.id),
                                                        onOffer: () =>
                                                            proposeDriverPrice(
                                                                context,
                                                                liveOrder
                                                                    .reference
                                                                    .path,
                                                                initialPrice:
                                                                    liveOrder
                                                                        .price
                                                                        .toInt()),
                                                        onAccept: () async {
                                                          if (isAssignedToCurrentDriver) {
                                                            Navigator.pop(
                                                                context);
                                                            await _openAcceptedDriverOrder(
                                                                liveOrder
                                                                    .reference);
                                                          } else if (isOrderAvailable) {
                                                            await _acceptAndOpenDriverOrder(
                                                                parentContext,
                                                                liveOrder);
                                                          }
                                                        },
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
                                                        font: TextStyle(
                                                          fontFamily:
                                                              'Noto Sans',
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
