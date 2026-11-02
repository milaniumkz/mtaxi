import 'dart:async';
import '/backend/push_notifications/driver_order_notifications.dart';

import '/auth/backend_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/backend_session.dart';
import '/backend/backend_user_adapter.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/backend/order_state_compat.dart';
import 'push_deep_link_router.dart';
import 'push_notification_inbox.dart';
import '../firebase/firebase_config.dart';
import '../../flutter_flow/flutter_flow_util.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:package_info_plus/package_info_plus.dart';

final _handledMessageIds = <String?>{};

class PushNotificationsHandler extends StatefulWidget {
  const PushNotificationsHandler({Key? key, required this.child})
      : super(key: key);

  final Widget child;

  @override
  _PushNotificationsHandlerState createState() =>
      _PushNotificationsHandlerState();
}

class _PushNotificationsHandlerState extends State<PushNotificationsHandler> {
  bool _loading = false;
  static const Duration _bootstrapTimeout = Duration(milliseconds: 1500);
  static const Duration _userDocWaitTimeout = Duration(seconds: 3);

  DocumentReference? _pushOrderRef(Map<String, dynamic> data) {
    final candidates = [
      data['orderDocPath'],
      data['orderRef'],
      data['orderPath'],
      data['activePassengerOrderRef'],
      data['activeDriverOrderRef'],
    ];
    for (final candidate in candidates) {
      final path = (candidate ?? '').toString().trim();
      if (path.startsWith('order/') || path.startsWith('orders/')) {
        return BackendRefs.instance.doc(path);
      }
    }
    return null;
  }

  String? _foregroundPushMessage(
    Map<String, dynamic> data, {
    RemoteNotification? notification,
  }) {
    final body = (notification?.body ?? data['body'] ?? '').toString().trim();
    if (body.isNotEmpty) {
      return body;
    }

    final type = (data['type'] ?? '').toString().trim().toUpperCase();
    final orderStatus =
        int.tryParse((data['orderStatus'] ?? '').toString().trim());
    if (type == PushDeepLinkRouter.orderCancelledType) {
      return 'Заказ отменен';
    }
    if (type != PushDeepLinkRouter.orderStatusChangedType ||
        orderStatus == null) {
      return null;
    }

    switch (orderStatus) {
      case 1:
      case 2:
        return 'Водитель принял заказ';
      case 3:
        return 'Водитель приехал';
      case 4:
        return 'Поездка началась';
      case 5:
        return 'Заказ завершен';
      case 6:
        return 'Заказ отменен';
      default:
        return null;
    }
  }

  void _showForegroundPushMessage(
    Map<String, dynamic> data, {
    RemoteNotification? notification,
  }) {
    final type = (data['type'] ?? '').toString().trim().toUpperCase();
    final orderStatus =
        int.tryParse((data['orderStatus'] ?? '').toString().trim());
    final orderRef = _pushOrderRef(data);
    final targetRole = (data['targetRole'] ?? '').toString().trim();
    final audience = targetRole.toLowerCase() == PushDeepLinkRouter.targetDriver
        ? 'driver'
        : 'passenger';
    if (audience == 'driver' &&
        type == PushDeepLinkRouter.orderAvailableType &&
        !shouldAnnounceDriverAvailableOrderOnce(orderRef)) {
      return;
    }
    if ((type == PushDeepLinkRouter.orderStatusChangedType ||
            type == PushDeepLinkRouter.orderCancelledType) &&
        orderStatus != null &&
        !shouldAnnounceOrderStatusOnce(
          audience: audience,
          orderRef: orderRef,
          status: orderStatus,
        )) {
      return;
    }
    if (audience == 'driver' &&
        type == PushDeepLinkRouter.orderAvailableType &&
        data['overlayEligible']?.toString() == 'true') {
      unawaited(showNearbyDriverOrder(data));
      return;
    }
    final message = _foregroundPushMessage(
      data,
      notification: notification,
    );
    if (message == null || message.isEmpty) {
      return;
    }
    final ctx = mounted ? context : appNavigatorKey.currentContext;
    if (ctx == null) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    if (audience == 'driver' &&
        data['overlayEligible']?.toString() == 'true' &&
        (type == PushDeepLinkRouter.orderAvailableType ||
            type == PushDeepLinkRouter.orderCancelledType)) {
      unawaited(_playDriverPushSound());
    }
  }

  Future<void> _playDriverPushSound() async {
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

  String _safeFallbackRouteForTargetRole(String targetRole) {
    switch (targetRole.trim().toLowerCase()) {
      case PushDeepLinkRouter.targetDriver:
        return PushDeepLinkRouter.safeDriverFallbackRoute;
      case PushDeepLinkRouter.targetAdmin:
        return PushDeepLinkRouter.safeAdminFallbackRoute;
      case PushDeepLinkRouter.targetPassenger:
      default:
        return PushDeepLinkRouter.safePassengerFallbackRoute;
    }
  }

  Future<void> _navigateToDecision(
    PushRouteDecision decision,
    Map<String, dynamic> messageData,
  ) async {
    if (!decision.allowed) {
      debugPrint(
        'PushNotificationsHandler: navigation blocked by guard '
        '(${decision.reason}) for payload ${messageData['type']}',
      );
      return;
    }
    final targetRole = (messageData['targetRole'] ?? '').toString();
    final fallbackRoute = _safeFallbackRouteForTargetRole(targetRole);
    final targetRoute = parametersBuilderMap.containsKey(decision.routeName)
        ? decision.routeName
        : fallbackRoute;
    final parametersBuilder = parametersBuilderMap[targetRoute];
    final initialParameterData = getInitialParameterData(messageData);

    if (parametersBuilder == null) {
      debugPrint(
        'PushNotificationsHandler: no parameters builder for $targetRoute, '
        'navigating without params',
      );
      if (mounted) {
        context.goNamed(targetRoute);
      } else {
        appNavigatorKey.currentContext?.goNamed(targetRoute);
      }
      return;
    }

    final parameterData = await parametersBuilder(initialParameterData);
    if (mounted) {
      context.goNamed(
        targetRoute,
        pathParameters: parameterData.pathParameters,
        extra: parameterData.extra,
      );
    } else {
      appNavigatorKey.currentContext?.goNamed(
        targetRoute,
        pathParameters: parameterData.pathParameters,
        extra: parameterData.extra,
      );
    }
  }

  Future<void> _navigateToSafeFallback(
    Map<String, dynamic> messageData, {
    String reason = '',
  }) async {
    final currentUser = currentUserDocument;
    final currentResolvedMode = UserModeResolver.resolveActiveMode(currentUser);
    var fallbackRoute = switch (currentResolvedMode) {
      'admin' => PushDeepLinkRouter.safeAdminFallbackRoute,
      'driver' => PushDeepLinkRouter.safeDriverFallbackRoute,
      _ => PushDeepLinkRouter.safePassengerFallbackRoute,
    };
    if (currentResolvedMode == 'passenger' &&
        getEffectivePassengerOrderRef(currentUser) != null) {
      fallbackRoute = PushDeepLinkRouter.passengerOrderRoute;
    }
    if (currentResolvedMode == 'driver' &&
        getEffectiveDriverOrderRef(currentUser) != null) {
      fallbackRoute = 'homeDriverOrder';
    }
    debugPrint(
      'PushNotificationsHandler: navigating to safe fallback '
      '$fallbackRoute${reason.isNotEmpty ? ' ($reason)' : ''}',
    );
    if (mounted) {
      context.goNamed(fallbackRoute);
    } else {
      appNavigatorKey.currentContext?.goNamed(fallbackRoute);
    }
  }

  Future<void> _ackPushReceipt(
    RemoteMessage message, {
    String route = '',
    required String eventType,
  }) async {
    final notificationId =
        (message.data['notificationId'] ?? '').toString().trim();
    if (notificationId.isEmpty) {
      return;
    }
    final sentAtMs =
        int.tryParse((message.data['sentAtMs'] ?? '').toString().trim());
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    String appVersion = '';
    String buildNumber = '';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version.trim();
      buildNumber = packageInfo.buildNumber.trim();
    } catch (_) {}
    unawaited(
      makeCloudCall(
        'ackPushDelivery',
        {
          'notificationId': notificationId,
          'sentAtMs': sentAtMs,
          'receivedAtMs': nowMs,
          'openedAtMs': nowMs,
          'eventType': eventType,
          'platform': isAndroid ? 'android' : 'ios',
          'appVersion': appVersion,
          'buildNumber': buildNumber,
          'route': route,
        },
      ),
    );
  }

  Future<void> _refreshCurrentUserDocumentOnce() async {
    try {
      final response = await mtaxiBackendCall(
        'getSessionBootstrap',
        const {},
        timeout: _bootstrapTimeout,
      );
      final user = response['user'];
      if (response['success'] == true && user is Map) {
        currentUserDocument = usersRecordFromBackendUser(
          Map<String, dynamic>.from(user),
        );
        await saveBackendUserFromResponse(response);
      }
    } catch (e) {
      debugPrint('PushNotificationsHandler backend user refresh failed: $e');
    }
  }

  void _applyBootstrapResponse(Map<String, dynamic> response) {
    if (response['success'] != true) {
      return;
    }
    final passengerOrderPath =
        (response['activePassengerOrderRef'] ?? '').toString().trim();
    final driverOrderPath =
        (response['activeDriverOrderRef'] ?? '').toString().trim();
    final roleState = (response['roleState'] ?? '').toString().trim();

    FFAppState().syncLegacyOrderRefs(
      passengerOrderRef: passengerOrderPath.isNotEmpty
          ? BackendRefs.instance.doc(passengerOrderPath)
          : null,
      driverOrderRef: driverOrderPath.isNotEmpty
          ? BackendRefs.instance.doc(driverOrderPath)
          : null,
    );
    if (roleState.isNotEmpty) {
      UserModeResolver.setTransientRoleState(roleState);
    }
    FFAppState().update(() {});
  }

  Future handleOpenedPushNotification() async {
    if (!firebasePushInitialized || (isWeb && !firebaseWebPushEnabled)) {
      return;
    }

    final pendingNotification = await consumePendingPushMessage();
    if (pendingNotification != null) {
      await _handlePushNotification(pendingNotification);
    }

    final notification = await FirebaseMessaging.instance.getInitialMessage();
    if (notification != null) {
      await _handlePushNotification(notification);
    }
    FirebaseMessaging.onMessage.listen((message) {
      final decision = PushDeepLinkRouter.resolveTargetRoute(
        message.data,
        currentUserDocument,
        null,
      );
      _ackPushReceipt(
        message,
        route: decision.routeName,
        eventType: 'received',
      );
      _showForegroundPushMessage(
        message.data,
        notification: message.notification,
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_handlePushNotification);
  }

  Future _handlePushNotification(RemoteMessage message) async {
    if (_handledMessageIds.contains(message.messageId)) {
      return;
    }
    _handledMessageIds.add(message.messageId);
    if (!PushDeepLinkRouter.validatePayload(message.data)) {
      debugPrint(
        'PushNotificationsHandler: invalid push payload ${message.messageId}',
      );
      final targetRole = (message.data['targetRole'] ?? '').toString().trim();
      if (targetRole.isNotEmpty) {
        await _ackPushReceipt(
          message,
          route: _safeFallbackRouteForTargetRole(targetRole),
          eventType: 'opened',
        );
        await _navigateToSafeFallback(
          message.data,
          reason: 'invalid_payload',
        );
      }
      return;
    }
    final decision = PushDeepLinkRouter.resolveTargetRoute(
      message.data,
      currentUserDocument,
      null,
    );
    await _ackPushReceipt(
      message,
      route: decision.routeName,
      eventType: 'opened',
    );

    safeSetState(() => _loading = true);
    try {
      await _waitForCurrentUserDocument();
      final bootstrapResponse =
          await makeCloudCall('getSessionBootstrap', const {})
              .timeout(_bootstrapTimeout);
      _applyBootstrapResponse(bootstrapResponse);
      await _refreshCurrentUserDocumentOnce();
      await _waitForCurrentUserDocument();
      final postBootstrapDecision = PushDeepLinkRouter.resolveTargetRoute(
        message.data,
        currentUserDocument,
        null,
      );
      if (postBootstrapDecision.allowed) {
        await _navigateToDecision(postBootstrapDecision, message.data);
      } else {
        await _navigateToSafeFallback(
          message.data,
          reason: postBootstrapDecision.reason.isNotEmpty
              ? postBootstrapDecision.reason
              : 'post_bootstrap_guard_blocked',
        );
      }
    } catch (e) {
      debugPrint('PushNotificationsHandler error: $e');
      final fallbackDecision = PushDeepLinkRouter.resolveTargetRoute(
        message.data,
        currentUserDocument,
        null,
      );
      if (fallbackDecision.allowed) {
        await _navigateToDecision(fallbackDecision, message.data);
      } else {
        await _navigateToSafeFallback(
          message.data,
          reason: 'push_handler_exception',
        );
      }
    } finally {
      safeSetState(() => _loading = false);
    }
  }

  Future<void> _waitForCurrentUserDocument() async {
    final expectedUid = currentUserUid.trim();
    final hasMatchingUserDoc = currentUserDocument != null &&
        expectedUid.isNotEmpty &&
        currentUserDocument!.reference.id == expectedUid;
    if (hasMatchingUserDoc) {
      return;
    }
    final completer = Completer<void>();
    StreamSubscription? sub;
    Timer? timeout;
    timeout = Timer(_userDocWaitTimeout, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    sub = authenticatedUserStream.listen((user) {
      final latestExpectedUid = currentUserUid.trim();
      final matchesExpectedUser = user != null &&
          latestExpectedUid.isNotEmpty &&
          user.reference.id == latestExpectedUid;
      if (matchesExpectedUser && !completer.isCompleted) {
        completer.complete();
      }
    });
    try {
      await completer.future;
    } finally {
      timeout.cancel();
      await sub.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      handleOpenedPushNotification();
    });
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          widget.child,
          if (_loading)
            IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.08),
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 16),
                child: const SafeArea(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
            ),
        ],
      );
}

class ParameterData {
  const ParameterData(
      {this.requiredParams = const {}, this.allParams = const {}});
  final Map<String, String?> requiredParams;
  final Map<String, dynamic> allParams;

  Map<String, String> get pathParameters => Map.fromEntries(
        requiredParams.entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
  Map<String, dynamic> get extra => Map.fromEntries(
        allParams.entries.where((e) => e.value != null),
      );

  static Future<ParameterData> Function(Map<String, dynamic>) none() =>
      (data) async => ParameterData();
}

final parametersBuilderMap =
    <String, Future<ParameterData> Function(Map<String, dynamic>)>{
  'HomePage': ParameterData.none(),
  'login': ParameterData.none(),
  'smsVirefication': ParameterData.none(),
  'setProfile': ParameterData.none(),
  'cityToCity': ParameterData.none(),
  'profile': ParameterData.none(),
  'meOrder': ParameterData.none(),
  'about': ParameterData.none(),
  'politika': ParameterData.none(),
  'tarif': ParameterData.none(),
  'seachDriver': ParameterData.none(),
  'setProfileDriver': ParameterData.none(),
  'homeDriver': ParameterData.none(),
  'homeDriverOrder': ParameterData.none(),
  'settings': ParameterData.none(),
  'supportChat': ParameterData.none(),
  'adminSupportChats': ParameterData.none(),
  'adminSupportChat': ParameterData.none(),
  'adminDriverStats': ParameterData.none(),
};

Map<String, dynamic> getInitialParameterData(Map<String, dynamic> data) {
  try {
    final parameterDataStr = data['parameterData'];
    if (parameterDataStr == null ||
        parameterDataStr is! String ||
        parameterDataStr.isEmpty) {
      return {};
    }
    return jsonDecode(parameterDataStr) as Map<String, dynamic>;
  } catch (e) {
    debugPrint('Error parsing parameter data: $e');
    return {};
  }
}
