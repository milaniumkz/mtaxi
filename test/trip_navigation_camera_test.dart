import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mtaxi/trips/trip_navigation.dart';

void main() {
  test('arrival is never announced in advance, including the 50m case', () {
    for (final distance in [200.0, 100.0, 50.0, 26.0]) {
      expect(
          navigationSpeechText('Вы прибыли к месту назначения', distance,
              pickup: false),
          isNull);
    }
    expect(
        navigationSpeechText('Вы прибыли к месту назначения', 25,
            pickup: false),
        'Вы приехали.');
    expect(
        navigationSpeechText('Вы прибыли к месту назначения', 10, pickup: true),
        'Вы на месте посадки.');
    expect(navigationSpeechText('Поверните налево', 50, pickup: false),
        'Через 50 метров, Поверните налево');
    expect(navigationSpeechText('Поверните направо', 20, pickup: false),
        'Поверните направо');
  });
  for (final height in [320.0, 932.0]) {
    test('driver at pickup keeps finite map coordinates at height $height', () {
      final camera = MapCamera.initialCamera(const MapOptions(
              initialCenter: LatLng(53.538, 75.313), initialZoom: 15))
          .withNonRotatedSize(Point(430, height));
      final fitted = navigationRouteFit(
              const [LatLng(53.538, 75.313), LatLng(53.538, 75.313)], height)
          .fit(camera);
      expect(fitted.zoom.isFinite, isTrue);
      expect(fitted.zoom, lessThanOrEqualTo(17));
      expect(fitted.center.latitude.isFinite, isTrue);
      expect(fitted.center.longitude.isFinite, isTrue);
    });
  }
}
