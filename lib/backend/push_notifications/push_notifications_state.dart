import 'dart:io' show Platform;

import '../backend_calls/backend_calls.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kFcmAppStateForeground = 'foreground';
const kFcmAppStateBackground = 'background';
const kFcmAppStateTerminated = 'terminated';
const _apnsTokenRetryAttempts = 20;
const _apnsTokenRetryDelay = Duration(milliseconds: 500);
const _fcmStateSyncMinInterval = Duration(hours: 6);

bool get supportsFcmTokenStateSync =>
    !kIsWeb && (Platform.isIOS || Platform.isAndroid);

String? get currentFcmDeviceType {
  if (!supportsFcmTokenStateSync) return null;
  return Platform.isIOS ? 'iOS' : 'Android';
}

Future<void> syncFcmTokenStateForUserPath({
  required String userDocPath,
  String? appState,
  bool? orderAlertsEnabled,
}) async {
  if (!supportsFcmTokenStateSync) {
    return;
  }
  if ((appState == null || appState.isEmpty) && orderAlertsEnabled == null) {
    return;
  }

  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );
    final status = settings.authorizationStatus;
    if (status != AuthorizationStatus.authorized &&
        status != AuthorizationStatus.provisional) {
      debugPrint('FCM token state not synced: push permission is $status');
      return;
    }

    String? apnsToken;
    if (Platform.isIOS) {
      for (var attempt = 0; attempt < _apnsTokenRetryAttempts; attempt++) {
        apnsToken = await messaging.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) {
          break;
        }
        await Future.delayed(_apnsTokenRetryDelay);
      }
    }
    final token = await messaging.getToken();
    final deviceType = currentFcmDeviceType;
    if (token == null || token.isEmpty || deviceType == null) {
      return;
    }
    final syncKey =
        'ff_fcm_state_sync_${userDocPath.replaceAll('/', '_')}_$token';
    final syncValue = [
      deviceType,
      apnsToken ?? '',
      appState ?? '',
      orderAlertsEnabled?.toString() ?? '',
    ].join('|');
    final prefs = await SharedPreferences.getInstance();
    final lastValue = prefs.getString('${syncKey}_value') ?? '';
    final lastAtMs = prefs.getInt('${syncKey}_at') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (lastValue == syncValue &&
        nowMs - lastAtMs < _fcmStateSyncMinInterval.inMilliseconds) {
      return;
    }

    final payload = <String, dynamic>{
      'userDocPath': userDocPath,
      'fcmToken': token,
      'deviceType': deviceType,
      if (apnsToken != null && apnsToken.isNotEmpty) 'apnsToken': apnsToken,
      if (appState != null && appState.isNotEmpty) 'appState': appState,
      if (orderAlertsEnabled != null) 'orderAlertsEnabled': orderAlertsEnabled,
    };

    await makeCloudCall('updateFcmTokenState', payload);
    await prefs.setString('${syncKey}_value', syncValue);
    await prefs.setInt('${syncKey}_at', nowMs);
  } catch (e) {
    debugPrint('Failed to sync FCM token state: $e');
  }
}
