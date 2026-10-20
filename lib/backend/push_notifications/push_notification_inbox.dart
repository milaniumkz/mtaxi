import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPendingPushPayloadKey = 'mtaxi_pending_push_payload_v1';

Map<String, dynamic> _serializeRemoteMessage(RemoteMessage message) {
  return {
    'messageId': message.messageId,
    'sentTimeMs': message.sentTime?.millisecondsSinceEpoch,
    'data': message.data,
  };
}

RemoteMessage? _deserializeRemoteMessage(Map<String, dynamic>? payload) {
  if (payload == null) return null;
  final data = payload['data'];
  if (data is! Map) return null;
  final normalizedData = <String, dynamic>{};
  for (final entry in data.entries) {
    normalizedData[entry.key.toString()] = entry.value;
  }
  return RemoteMessage.fromMap({
    'messageId': payload['messageId'],
    'sentTime': payload['sentTimeMs'],
    'data': normalizedData,
  });
}

Future<void> persistPendingPushMessage(RemoteMessage message) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _kPendingPushPayloadKey,
    jsonEncode(_serializeRemoteMessage(message)),
  );
}

Future<RemoteMessage?> consumePendingPushMessage() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kPendingPushPayloadKey);
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  await prefs.remove(_kPendingPushPayloadKey);
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return _deserializeRemoteMessage(decoded);
  } catch (_) {
    return null;
  }
}
