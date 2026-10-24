import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '/backend/backend_calls/backend_calls.dart';

/// Android keeps a visible, user-controlled location notification while online.
class DriverBackgroundLocation {
  static StreamSubscription<Position>? _stream;
  static Position? latest;
  static bool _sending = false;
  static DateTime? _sentAt;
  static Future<void> sync(Map<String, dynamic>? user) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final active = user?['isDriver'] == true &&
        user?['statusDriver'] == 'approved' &&
        user?['blocked'] != true &&
        (user?['driverOnLine'] == true ||
            user?['hasActiveDriverOrder'] == true);
    if (!active) {
      await _stream?.cancel();
      _stream = null;
      latest = null;
      return;
    }
    if (_stream != null) return;
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;
    _stream = Geolocator.getPositionStream(
            locationSettings: AndroidSettings(
                forceLocationManager: true,
                accuracy: LocationAccuracy.high,
                distanceFilter: 5,
                intervalDuration: const Duration(seconds: 3),
                foregroundNotificationConfig: const ForegroundNotificationConfig(
                    notificationTitle: 'MTaxi · вы на линии',
                    notificationText:
                        'Геопозиция обновляется для заказов рядом. Чтобы остановить — сойдите с линии.',
                    enableWakeLock: true,
                    setOngoing: true)))
        .listen((p) {
      latest = p;
      if (_sending ||
          (_sentAt != null &&
              DateTime.now().difference(_sentAt!).inSeconds < 3)) return;
      _sending = true;
      unawaited(() async {
        try {
          final r = await makeCloudCall('updateUserPreferences', {
            'coords': {
              'latitude': p.latitude,
              'longitude': p.longitude,
              'accuracy': p.accuracy
            }
          });
          if (r['success'] == true) _sentAt = DateTime.now();
          if (r['user'] is Map) {
            final u = r['user'] as Map;
            if (u['blocked'] == true ||
                u['driverOnLine'] != true && u['hasActiveDriverOrder'] != true)
              await sync(null);
          }
        } finally {
          _sending = false;
        }
      }());
    }, onError: (_) {
      _stream?.cancel();
      _stream = null;
      latest = null;
    });
  }
}
