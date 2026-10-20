import 'dart:io' show Platform;

import '../../auth/backend_auth/auth_util.dart';
import '../backend_calls/backend_calls.dart';
import 'push_notifications_state.dart';

import 'package:flutter/foundation.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

export 'push_notifications_handler.dart';
export 'push_notifications_state.dart';
export 'serialization_util.dart';

class UserTokenInfo {
  const UserTokenInfo(this.userPath, this.fcmToken);
  final String userPath;
  final String fcmToken;
}

const _apnsTokenRetryAttempts = 20;
const _apnsTokenRetryDelay = Duration(milliseconds: 500);

Future<NotificationSettings?> _requestPushPermission() async {
  if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) {
    return null;
  }

  return FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
    announcement: false,
    carPlay: false,
    criticalAlert: false,
  );
}

Future<String?> _getFcmTokenAfterNativeRegistration() async {
  if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) {
    return null;
  }

  final messaging = FirebaseMessaging.instance;
  await messaging.setAutoInitEnabled(true);
  await messaging.getNotificationSettings();
  if (Platform.isIOS) {
    for (var attempt = 0; attempt < _apnsTokenRetryAttempts; attempt++) {
      final apnsToken = await messaging.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        break;
      }
      await Future.delayed(_apnsTokenRetryDelay);
    }
  }
  return messaging.getToken();
}

Future<String?> _getApnsTokenIfAvailable() async {
  if (kIsWeb || !Platform.isIOS) {
    return null;
  }

  final messaging = FirebaseMessaging.instance;
  for (var attempt = 0; attempt < _apnsTokenRetryAttempts; attempt++) {
    final apnsToken = await messaging.getAPNSToken();
    if (apnsToken != null && apnsToken.isNotEmpty) {
      return apnsToken;
    }
    await Future.delayed(_apnsTokenRetryDelay);
  }
  return null;
}

Stream<UserTokenInfo> getFcmTokenStream(String userPath) =>
    Stream.value(!kIsWeb && (Platform.isIOS || Platform.isAndroid))
        .where((shouldGetToken) => shouldGetToken)
        .asyncMap<String?>((_) => _requestPushPermission().then(
              (settings) {
                final status = settings?.authorizationStatus;
                return status == AuthorizationStatus.authorized ||
                        status == AuthorizationStatus.provisional
                    ? _getFcmTokenAfterNativeRegistration()
                    : null;
              },
            ))
        .switchMap((fcmToken) => Stream.value(fcmToken)
            .merge(FirebaseMessaging.instance.onTokenRefresh))
        .where((fcmToken) => fcmToken != null && fcmToken.isNotEmpty)
        .map((token) => UserTokenInfo(userPath, token!));

final fcmTokenUserStream = authenticatedUserStream
    .where((user) => user != null)
    .map((user) => user!.reference.path)
    .distinct()
    .switchMap(getFcmTokenStream)
    .asyncMap((userTokenInfo) async {
  final apnsToken = await _getApnsTokenIfAvailable();
  return makeCloudCall(
    'addFcmToken',
    {
      'userDocPath': userTokenInfo.userPath,
      'fcmToken': userTokenInfo.fcmToken,
      'deviceType': Platform.isIOS ? 'iOS' : 'Android',
      if (apnsToken != null && apnsToken.isNotEmpty) 'apnsToken': apnsToken,
    },
  );
});

Future<void> syncCurrentFcmTokenState({
  String? appState,
  bool? orderAlertsEnabled,
}) async {
  final userDocPath = currentUserDocument?.reference.path ?? '';
  if (userDocPath.isEmpty) {
    return;
  }
  await syncFcmTokenStateForUserPath(
    userDocPath: userDocPath,
    appState: appState,
    orderAlertsEnabled: orderAlertsEnabled,
  );
}
