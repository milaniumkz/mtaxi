// ignore_for_file: unused_import, unnecessary_import, deprecated_member_use

// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import '/backend/backend_calls/backend_calls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

class IntercityMap extends StatefulWidget {
  const IntercityMap({
    super.key,
    this.width,
    this.height,
    this.onFromAddressChanged,
    this.onToAddressChanged,
    this.onDistanceChanged,
    this.onFromCoordsChanged,
    this.onToCoordsChanged,
  });

  final double? width;
  final double? height;
  final Function(String)? onFromAddressChanged;
  final Function(String)? onToAddressChanged;
  final Function(double)? onDistanceChanged;
  final Function(latlng.LatLng)? onFromCoordsChanged;
  final Function(latlng.LatLng)? onToCoordsChanged;

  @override
  State<IntercityMap> createState() => _IntercityMapState();
}

class _IntercityMapState extends State<IntercityMap> {
  bool get _isKazakh =>
      FFLocalizations.of(context).languageCode.toLowerCase().startsWith('kk');

  String _tr(String ru, String kk) => _isKazakh ? kk : ru;

  String get _languageCode => _isKazakh ? 'kk' : 'ru';

  late MapController _mapController;
  latlng.LatLng? _from;
  latlng.LatLng? _to;
  List<latlng.LatLng> _routePoints = [];
  String _activeField = 'from';
  bool _isLoading = false;
  double _distanceKm = 0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  Future<void> _handleTap(latlng.LatLng coords) async {
    final tappedField = _activeField;
    setState(() {
      _isLoading = true;
    });
    try {
      if (tappedField == 'from') {
        setState(() {
          _from = coords;
          _activeField = 'to';
        });
        widget.onFromCoordsChanged?.call(coords);
      } else {
        setState(() {
          _to = coords;
          _activeField = 'from';
        });
        widget.onToCoordsChanged?.call(coords);
      }

      final resolvedAddress = await _reverseGeocode(coords);
      if (tappedField == 'from' &&
          _from?.latitude == coords.latitude &&
          _from?.longitude == coords.longitude) {
        widget.onFromAddressChanged?.call(resolvedAddress);
      } else if (tappedField == 'to' &&
          _to?.latitude == coords.latitude &&
          _to?.longitude == coords.longitude) {
        widget.onToAddressChanged?.call(resolvedAddress);
      }

      if (_from != null && _to != null) {
        unawaited(_fetchRoute(_from!, _to!));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchRoute(latlng.LatLng from, latlng.LatLng to) async {
    try {
      final response = await makeCloudCall(
        'routeLookup',
        {
          'fromLat': from.latitude,
          'fromLng': from.longitude,
          'toLat': to.latitude,
          'toLng': to.longitude,
        },
        timeout: const Duration(seconds: 8),
      );
      final coordinates = response['coordinates'];
      if (response['success'] == true && coordinates is List) {
        final distanceKm =
            double.tryParse(response['distanceKm']?.toString() ?? '') ?? 0;
        setState(() {
          _routePoints = coordinates
              .map<latlng.LatLng>((coord) => latlng.LatLng(
                    (coord[1] as num).toDouble(),
                    (coord[0] as num).toDouble(),
                  ))
              .toList();
          _distanceKm = distanceKm;
        });

        widget.onDistanceChanged?.call(distanceKm);
        _centerMapOnRoute(_routePoints);
      } else {
        if (!mounted) return;
        setState(() {
          _routePoints = [];
          _distanceKm = 0;
        });
      }
    } catch (e) {
      debugPrint('Ошибка получения межгород маршрута: $e');
      if (!mounted) return;
      setState(() {
        _routePoints = [];
        _distanceKm = 0;
      });
    }
  }

  Future<String> _reverseGeocode(latlng.LatLng coords) async {
    try {
      final response = await makeCloudCall(
        'reverseGeocodeLookup',
        {
          'lat': coords.latitude,
          'lng': coords.longitude,
          'language': _languageCode,
        },
        timeout: const Duration(seconds: 8),
      );
      final address = (response['address']?.toString() ?? '').trim();
      if (response['success'] == true && address.isNotEmpty) {
        return address;
      }
    } catch (_) {}
    return _tr('Адрес уточняется', 'Мекенжай нақтылануда');
  }

  void _centerMapOnRoute(List<latlng.LatLng> routePoints) {
    if (routePoints.isEmpty) return;
    double minLat = routePoints.first.latitude;
    double maxLat = routePoints.first.latitude;
    double minLng = routePoints.first.longitude;
    double maxLng = routePoints.first.longitude;
    for (final point in routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    final center = latlng.LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(center, 10);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayBg = isDark
        ? const Color(0xFF13191D).withOpacity(0.92)
        : Colors.white.withOpacity(0.9);
    final overlayText = isDark ? Colors.white : Colors.black87;
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 280,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const latlng.LatLng(0, 0),
              initialZoom: 2,
              onTap: (tapPosition, point) => _handleTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                maxZoom: 19,
                userAgentPackageName: 'com.mtaxi.app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_from != null)
                    Marker(
                      point: _from!,
                      width: 36,
                      height: 36,
                      child: const Icon(Icons.circle,
                          color: Colors.green, size: 28),
                    ),
                  if (_to != null)
                    Marker(
                      point: _to!,
                      width: 36,
                      height: 36,
                      child: const Icon(Icons.location_on,
                          color: Colors.red, size: 28),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: overlayBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _activeField == 'from'
                    ? _tr('Точка отправления', 'Жөнелу нүктесі')
                    : _tr('Точка назначения', 'Жету нүктесі'),
                style: TextStyle(
                  fontSize: 12,
                  color: overlayText,
                ),
              ),
            ),
          ),
          if (_distanceKm > 0)
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: overlayBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_distanceKm.toStringAsFixed(1)} км',
                  style: TextStyle(
                    fontSize: 12,
                    color: overlayText,
                  ),
                ),
              ),
            ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.2),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
