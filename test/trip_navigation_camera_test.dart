import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mtaxi/trips/trip_navigation.dart';

void main() {
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
