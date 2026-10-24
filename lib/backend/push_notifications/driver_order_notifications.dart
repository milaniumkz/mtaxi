import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide NotificationVisibility;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as geo;
import '/auth/backend_auth/auth_util.dart';
import '/backend/backend_session.dart' show getStoredBackendAccessToken;
import '/backend/backend_calls/backend_calls.dart';
import '/backend/push_notifications/push_notifications_state.dart';
import '/backend/push_notifications/push_notifications_util.dart'
    show enableBrowserPushForCurrentUser;
import '/design/mtaxi_theme.dart';
import '/design/mtaxi_icon.dart';
import '/flutter_flow/flutter_flow_util.dart' show formatAppCurrency;
import '/flutter_flow/internationalization.dart';
import '/flutter_flow/nav/nav.dart' show appNavigatorKey;
import '/trips/order_offers.dart' show driverOfferIncrements;
import '/trips/driver_offer_waiting.dart';

const _popupKey = 'mtaxi_driver_order_popup_v1';
const _actionKey = 'mtaxi_driver_overlay_action_v1';
final _notifications = FlutterLocalNotificationsPlugin();
bool _notificationInitialized = false;
bool get _android => !kIsWeb && Platform.isAndroid;

Future<void> _initNotifications() async {
  if (_notificationInitialized || !_android) return;
  await _notifications.initialize(
      const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (_) => launchUrl(
          Uri.parse('mtaxi://mtaxi.com/homeDriver'),
          mode: LaunchMode.externalApplication));
  final android = _notifications.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(const AndroidNotificationChannel(
      'mtaxi_orders_nearby', 'Заказы рядом',
      description: 'Новые заказы в радиусе одного километра',
      importance: Importance.high));
  await android?.createNotificationChannel(const AndroidNotificationChannel(
      'mtaxi_orders_quiet', 'Остальные заказы',
      description: 'Обычные уведомления без всплывающего окна',
      importance: Importance.low,
      playSound: false));
  _notificationInitialized = true;
}

Future<bool> enableDriverOrderNotifications() async {
  if (kIsWeb) {
    try {
      return await enableBrowserPushForCurrentUser();
    } catch (_) {
      return false;
    }
  }
  if (!(Platform.isAndroid || Platform.isIOS)) return false;
  final permission = await FirebaseMessaging.instance
      .requestPermission(alert: true, badge: true, sound: true);
  final push =
      permission.authorizationStatus == AuthorizationStatus.authorized ||
          permission.authorizationStatus == AuthorizationStatus.provisional;
  if (_android) {
    await _initNotifications();
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) await FlutterOverlayWindow.requestPermission();
    await registerDriverOverlayCapability();
    if (!await FlutterOverlayWindow.isPermissionGranted()) return false;
  }
  await syncFcmTokenStateForUserPath(
      userDocPath: currentUserDocument?.reference.path ?? '',
      orderAlertsEnabled: true);
  return push;
}

String? _capabilitySyncKey;
bool _capabilitySyncBusy = false;
Future<void> registerDriverOverlayCapability() async {
  if (!_android || currentUserDocument == null || _capabilitySyncBusy) return;
  final key =
      '$currentUserUid:${currentUserDocument?.snapshotData['driverOnLine']}';
  if (_capabilitySyncKey == key) return;
  _capabilitySyncBusy = true;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await makeCloudCall('addFcmToken', {
      'userDocPath': currentUserDocument!.reference.path,
      'fcmToken': token,
      'deviceType': 'Android',
      'supportsOrderOverlay': true,
      'orderAlertsEnabled':
          currentUserDocument?.snapshotData['driverOnLine'] == true
    });
    _capabilitySyncKey = key;
  } catch (_) {
  } finally {
    _capabilitySyncBusy = false;
  }
}

final Set<String> _shownNearby = {};
bool _popupOpening = false;
Future<bool> showNearbyDriverOrder(Map<String, dynamic> payload) async {
  final path = payload['orderDocPath']?.toString() ?? '';
  if (_popupOpening || path.isEmpty || _shownNearby.contains(path))
    return false;
  _popupOpening = true;
  try {
    return await _showNearbyDriverOrder(payload, path);
  } catch (_) {
    return false;
  } finally {
    _popupOpening = false;
  }
}

Future<bool> _showNearbyDriverOrder(
    Map<String, dynamic> payload, String path) async {
  if (payload['type'] != 'ORDER_AVAILABLE' ||
      payload['overlayEligible']?.toString() != 'true') return false;
  final sent = int.tryParse(payload['sentAtMs']?.toString() ?? '');
  if (sent == null || DateTime.now().millisecondsSinceEpoch - sent > 30000)
    return false;
  final bootstrap = await makeCloudCall('getSessionBootstrap', {});
  final user = bootstrap['user'];
  if (user is! Map ||
      user['isDriver'] != true ||
      user['statusDriver'] != 'approved' ||
      user['driverOnLine'] != true ||
      user['hasActiveDriverOrder'] == true ||
      user['blocked'] == true) return false;
  if (payload['driverUserId'] != null && payload['driverUserId'] != user['id'])
    return false;
  final details = await makeCloudCall(
      'getOrderDetails', {'orderDocPath': payload['orderDocPath']});
  final order = details['order'];
  if (order is! Map || order['status'] != 0) return false;
  final data = <String, dynamic>{
    ...payload,
    'driverUserId': user['id'],
    'orderPrice': order['price'],
    'pickupAddress': order['ot'],
    'destinationAddress': order['kuda'],
    'orderType': order['type'],
    'orderComment': order['comment'],
    'deliveryItem': order['deliveryItem'],
    'popupExpiresAt':
        DateTime.now().add(const Duration(seconds: 30)).toIso8601String()
  };
  final coords = user['coords'], pickup = order['fromPoint'];
  double? n(dynamic v) => num.tryParse(v?.toString() ?? '')?.toDouble();
  bool near = false;
  if (coords is Map && pickup is Map) {
    final lat = n(coords['latitude'] ?? coords['lat']),
        lng = n(coords['longitude'] ?? coords['lng']),
        a = n(pickup['latitude'] ?? pickup['lat']),
        b = n(pickup['longitude'] ?? pickup['lng']);
    final accuracy = n(user['coordsAccuracy']);
    final stamp = DateTime.tryParse(user['coordsUpdatedAt']?.toString() ?? '');
    if (lat != null &&
        lng != null &&
        a != null &&
        b != null &&
        accuracy != null &&
        accuracy > 0 &&
        accuracy <= 100 &&
        stamp != null &&
        DateTime.now().difference(stamp).inSeconds <= 30) {
      final distance =
          const geo.Distance()(geo.LatLng(lat, lng), geo.LatLng(a, b));
      near = distance + accuracy <= 1000;
      data['distanceMeters'] = distance.round();
    }
  }
  if (!near) {
    if (_android) await _ordinaryOrderNotice(data, quiet: true);
    return false;
  }
  _shownNearby.add(path);
  if (_shownNearby.length > 250) _shownNearby.remove(_shownNearby.first);

  if (_android) {
    await _initNotifications();
    if (!await FlutterOverlayWindow.isPermissionGranted() ||
        await FlutterOverlayWindow.isActive()) {
      await _ordinaryOrderNotice(data,
          quiet: await FlutterOverlayWindow.isActive());
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_popupKey, jsonEncode(data));
    try {
      await FlutterOverlayWindow.showOverlay(
          height: WindowSize.fullCover,
          width: WindowSize.matchParent,
          alignment: OverlayAlignment.center,
          flag: OverlayFlag.defaultFlag,
          enableDrag: false,
          overlayTitle: 'MTaxi · заказ рядом',
          overlayContent: 'Выберите действие по заказу',
          visibility: NotificationVisibility.visibilityPrivate);
      // The plugin may prewarm its overlay engine before a payload exists.
      // Notify it after the native service is ready; the persisted payload also
      // covers a fresh engine starting after process termination.
      for (var attempt = 0;
          attempt < 20 && !await FlutterOverlayWindow.isActive();
          attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (await FlutterOverlayWindow.isActive())
        await FlutterOverlayWindow.shareData(data);
      return true;
    } catch (_) {
      await _ordinaryOrderNotice(data);
      return false;
    }
  }
  final context = appNavigatorKey.currentContext;
  if (context == null) return false;
  await showDialog<void>(
      context: context,
      builder: (_) =>
          Dialog.fullscreen(child: DriverOrderPopup(initialData: data)));
  return true;
}

Future<void> _ordinaryOrderNotice(Map<String, dynamic> data,
    {bool quiet = false}) async {
  await _initNotifications();
  await _notifications.show(
      data['orderDocPath'].toString().hashCode & 0x7fffffff,
      '${quiet ? 'Новый заказ' : 'Заказ рядом'} · ${data['orderPrice']} ₸',
      '${data['pickupAddress']} → ${data['destinationAddress']}',
      NotificationDetails(
          android: AndroidNotificationDetails(
              quiet ? 'mtaxi_orders_quiet' : 'mtaxi_orders_nearby',
              quiet ? 'Остальные заказы' : 'Заказы рядом',
              importance: quiet ? Importance.low : Importance.high,
              priority: quiet ? Priority.low : Priority.high,
              playSound: !quiet)),
      payload: jsonEncode(data));
}

class DriverOrderOverlayApp extends StatelessWidget {
  const DriverOrderOverlayApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: MTaxiDesign.theme(Brightness.light),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('kk')],
      localizationsDelegates: const [
        FFLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      home: const DriverOrderPopup(overlay: true));
}

class DriverOrderPopup extends StatefulWidget {
  const DriverOrderPopup({super.key, this.initialData, this.overlay = false});
  final Map<String, dynamic>? initialData;
  final bool overlay;
  @override
  State<DriverOrderPopup> createState() => _DriverOrderPopupState();
}

class _DriverOrderPopupState extends State<DriverOrderPopup> {
  Map<String, dynamic>? _data;
  bool _busy = false, _prices = false;
  String? _error;
  Timer? _expiry;
  StreamSubscription<dynamic>? _messages;
  @override
  void initState() {
    super.initState();
    if (widget.overlay)
      _messages = FlutterOverlayWindow.overlayListener.listen((event) {
        if (event is Map && !_busy)
          unawaited(_load(Map<String, dynamic>.from(event)));
      });
    unawaited(_load());
  }

  Future<void> _load([Map<String, dynamic>? event]) async {
    Map<String, dynamic>? data = event ?? widget.initialData;
    if (widget.overlay && data == null) {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      final raw = p.getString(_popupKey);
      if (raw != null) data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    }
    if (!mounted) return;
    if (data == null) return;
    _expiry?.cancel();
    setState(() => _data = data);
    final deadline =
        DateTime.tryParse(data['popupExpiresAt']?.toString() ?? '');
    final time = deadline?.difference(DateTime.now()) ?? Duration.zero;
    if (time <= Duration.zero) {
      await _close();
      return;
    }
    _expiry = Timer(time, () {
      if (!_busy) unawaited(_close());
    });
  }

  Future<void> _close() async {
    _expiry?.cancel();
    if (widget.overlay) {
      final p = await SharedPreferences.getInstance();
      await p.remove(_popupKey);
      if (mounted)
        setState(() {
          _data = null;
          _prices = false;
          _busy = false;
          _error = null;
        });
      if (await FlutterOverlayWindow.isActive())
        await FlutterOverlayWindow.closeOverlay();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit(int? extra) async {
    final d = _data;
    if (d == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final path = d['orderDocPath']?.toString() ?? '';
    final base = num.tryParse(d['orderPrice'].toString())?.toInt() ?? 500;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      if ((await getStoredBackendAccessToken()).isEmpty)
        throw StateError('Войдите в приложение, чтобы взять заказ.');
      final session = await makeCloudCall('getSessionBootstrap', {});
      final driver = session['user'];
      if (driver is! Map ||
          driver['id'] != d['driverUserId'] ||
          driver['driverOnLine'] != true ||
          driver['statusDriver'] != 'approved' ||
          driver['blocked'] == true)
        throw StateError('Сначала выйдите на линию в приложении.');
      final r = await makeCloudCall(
          extra == null ? 'acceptOrder' : 'submitOrderOffer',
          {'orderDocPath': path, if (extra != null) 'price': base + extra});
      if (r['success'] != true)
        throw StateError(r['error']?.toString() ?? 'Заказ больше недоступен');
      final action = {
        'kind': extra == null ? 'accepted' : 'offer',
        'userId': d['driverUserId'],
        'orderDocPath': path,
        if (extra != null) 'offer': r['offer']
      };
      if (widget.overlay) {
        final p = await SharedPreferences.getInstance();
        await p.setString(_actionKey, jsonEncode(action));
        await _close();
        await launchUrl(
            Uri(
                scheme: 'mtaxi',
                host: 'mtaxi.com',
                path: extra == null ? '/homeDriverOrder' : '/homeDriver',
                queryParameters: {if (extra == null) 'orderDocPath': path}),
            mode: LaunchMode.externalApplication);
      } else {
        await _close();
        await _openAction(action);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = e is StateError
              ? e.message.toString()
              : 'Нет связи. Проверьте статус заказа в приложении.';
        });
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _messages?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final price =
        num.tryParse(d?['orderPrice']?.toString() ?? '')?.toInt() ?? 500;
    return Material(
        color: Colors.black54,
        child: SafeArea(
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Card(
                        child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: d == null
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                        Row(children: [
                                          const Expanded(
                                              child: Text('Заказ рядом',
                                                  style: TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.w700))),
                                          IconButton(
                                              onPressed: _busy ? null : _close,
                                              icon: const MTaxiIcon('close'))
                                        ]),
                                        Text(
                                            formatAppCurrency(price.toDouble()),
                                            style: const TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 16),
                                        Text('Откуда',
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant)),
                                        Text(
                                            d['pickupAddress']?.toString() ??
                                                'Адрес уточняется',
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 12),
                                        Text('Куда',
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant)),
                                        Text(
                                            d['destinationAddress']
                                                    ?.toString() ??
                                                'Адрес уточняется',
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 20),
                                        if (_error != null)
                                          Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 12),
                                              child: Text(_error!,
                                                  style: TextStyle(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .error))),
                                        if (_busy)
                                          const Center(
                                              child:
                                                  CircularProgressIndicator())
                                        else if (_prices) ...[
                                          const Text(
                                              'Выберите доплату к цене пассажира'),
                                          const SizedBox(height: 10),
                                          for (final extra
                                              in driverOfferIncrements(price))
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 8),
                                                child: FilledButton(
                                                    onPressed: () =>
                                                        _submit(extra),
                                                    child: Text(
                                                        '+ ${formatAppCurrency(extra.toDouble())} · итого ${formatAppCurrency((price + extra).toDouble())}'))),
                                        ] else ...[
                                          FilledButton(
                                              onPressed: () => _submit(null),
                                              child: const Text('Взять заказ')),
                                          const SizedBox(height: 10),
                                          OutlinedButton(
                                              onPressed: () => setState(
                                                  () => _prices = true),
                                              child: const Text(
                                                  'Предложить цену')),
                                        ],
                                      ])))))));
  }
}

bool _consuming = false;
Future<void> consumePendingDriverOverlayAction() async {
  if (!_android || _consuming || currentUserDocument == null) return;
  _consuming = true;
  try {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    final raw = p.getString(_actionKey);
    if (raw == null) return;
    final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    await p.remove(_actionKey);
    if (data['userId'] != currentUserUid) return;
    await _openAction(data);
  } finally {
    _consuming = false;
  }
}

Future<void> _openAction(Map<String, dynamic> action) async {
  final nav = appNavigatorKey.currentState,
      context = appNavigatorKey.currentContext;
  if (nav == null || context == null) return;
  final path = action['orderDocPath'].toString();
  if (action['kind'] == 'accepted') {
    context.goNamed('homeDriverOrder', queryParameters: {'orderDocPath': path});
    return;
  }
  if (action['offer'] is! Map) return;
  final accepted = await nav.push<bool>(MaterialPageRoute(
      builder: (_) => DriverOfferWaiting(
          orderDocPath: path,
          offer: Map<String, dynamic>.from(action['offer'] as Map))));
  if (accepted == true && context.mounted)
    context.goNamed('homeDriverOrder', queryParameters: {'orderDocPath': path});
}
