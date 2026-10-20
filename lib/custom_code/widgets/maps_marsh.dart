// ignore_for_file: unused_import, unnecessary_import, deprecated_member_use

// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:math';
import '/backend/backend_calls/backend_calls.dart';
import '/flutter_flow/lat_lng.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

class MapsMarsh extends StatefulWidget {
  const MapsMarsh({
    super.key,
    this.width,
    this.height,
    this.pointA,
    this.pointB,
    required this.zoom,
  });

  final double? width;
  final double? height;
  final LatLng? pointA;
  final LatLng? pointB;
  final double zoom;

  @override
  State<MapsMarsh> createState() => _MapsMarshState();
}

class _MapsMarshState extends State<MapsMarsh> {
  final MapController _mapController = MapController();
  List<latlng.LatLng> routePoints = [];
  bool _mapReady = false;
  String? _lastRouteKey;

  double _autoZoom() {
    final points = <LatLng>[
      if (widget.pointA != null) widget.pointA!,
      if (widget.pointB != null) widget.pointB!,
      ...routePoints.map((point) => LatLng(point.latitude, point.longitude)),
    ];
    if (points.isEmpty) {
      return widget.zoom;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    final maxDiff = max((maxLat - minLat).abs(), (maxLng - minLng).abs());
    if (maxDiff <= 0.003) return 16.0;
    if (maxDiff <= 0.008) return 15.0;
    if (maxDiff <= 0.015) return 14.0;
    if (maxDiff <= 0.03) return 13.0;
    if (maxDiff <= 0.07) return 12.0;
    if (maxDiff <= 0.15) return 11.0;
    if (maxDiff <= 0.35) return 10.0;
    if (maxDiff <= 0.8) return 9.0;
    return 8.0;
  }

  @override
  void initState() {
    super.initState();
    getRoute();
  }

  @override
  void didUpdateWidget(covariant MapsMarsh oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_routeKey(widget.pointA, widget.pointB) !=
        _routeKey(oldWidget.pointA, oldWidget.pointB)) {
      getRoute();
      _fitMapToCurrentRoute();
    }
  }

  String _routeKey(LatLng? pointA, LatLng? pointB) {
    String part(LatLng? point) {
      if (point == null) return 'null';
      return '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}';
    }

    return '${part(pointA)}>${part(pointB)}';
  }

  List<latlng.LatLng> _currentMapPoints() {
    return [
      if (widget.pointA != null) toLatLng(widget.pointA!),
      if (widget.pointB != null) toLatLng(widget.pointB!),
      ...routePoints,
    ];
  }

  void _fitMapToCurrentRoute() {
    if (!_mapReady || !mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mapReady || !mounted) {
        return;
      }
      final points = _currentMapPoints();
      if (points.isEmpty) {
        return;
      }
      if (points.length == 1) {
        _mapController.move(points.first, max(widget.zoom, 16.0));
        return;
      }
      try {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.fromLTRB(42, 42, 42, 300),
            maxZoom: 16.0,
          ),
        );
      } catch (_) {
        final center = latlng.LatLng(
          points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
          points.map((p) => p.longitude).reduce((a, b) => a + b) /
              points.length,
        );
        _mapController.move(center, _autoZoom());
      }
    });
  }

  Future<void> getRoute() async {
    final routeKey = _routeKey(widget.pointA, widget.pointB);
    if (widget.pointA == null || widget.pointB == null) {
      _lastRouteKey = routeKey;
      if (!mounted) return;
      setState(() {
        routePoints = [];
      });
      _fitMapToCurrentRoute();
      return;
    }

    if (_lastRouteKey == routeKey && routePoints.isNotEmpty) {
      return;
    }
    _lastRouteKey = routeKey;

    try {
      final response = await makeCloudCall(
        'routeLookup',
        {
          'fromLat': widget.pointA!.latitude,
          'fromLng': widget.pointA!.longitude,
          'toLat': widget.pointB!.latitude,
          'toLng': widget.pointB!.longitude,
        },
        timeout: const Duration(seconds: 8),
      );
      final coords = response['coordinates'];
      if (response['success'] == true && coords is List) {
        if (!mounted) return;
        setState(() {
          routePoints = coords
              .map<latlng.LatLng>(
                (c) => latlng.LatLng(
                  (c[1] as num).toDouble(),
                  (c[0] as num).toDouble(),
                ),
              )
              .toList();
        });
        _fitMapToCurrentRoute();
      } else {
        debugPrint('Ошибка при получении маршрута: ${response['error']}');
        if (!mounted) return;
        setState(() {
          routePoints = [];
        });
        _fitMapToCurrentRoute();
      }
    } catch (e) {
      debugPrint('Ошибка при получении маршрута: $e');
      if (!mounted) return;
      setState(() {
        routePoints = [];
      });
      _fitMapToCurrentRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = [
      if (widget.pointA != null) widget.pointA!,
      if (widget.pointB != null) widget.pointB!,
    ];
    final hasRoutePoints = widget.pointA != null && widget.pointB != null;
    final center = hasRoutePoints
        ? latlng.LatLng(
            (widget.pointA!.latitude + widget.pointB!.latitude) / 2,
            (widget.pointA!.longitude + widget.pointB!.longitude) / 2,
          )
        : points.isNotEmpty
            ? toLatLng(points.first)
            : const latlng.LatLng(49.948, 82.628);
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 300,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: points.isEmpty ? 11.0 : _autoZoom(),
              onMapReady: () {
                _mapReady = true;
                _fitMapToCurrentRoute();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                maxZoom: 19,
                userAgentPackageName: 'com.mtaxi.app',
              ),
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4.0,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (widget.pointA != null) _buildMarker(widget.pointA!),
                  if (widget.pointB != null) _buildMarker(widget.pointB!),
                ],
              ),
            ],
          ),
          if (points.isEmpty)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.08),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'Координаты не определены',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Marker _buildMarker(LatLng point) {
    return Marker(
      point: toLatLng(point),
      width: 50,
      height: 50,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40.0),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.error,
            color: Colors.red,
            size: 30,
          ),
        ),
      ),
    );
  }

  latlng.LatLng toLatLng(LatLng coords) {
    return latlng.LatLng(coords.latitude, coords.longitude);
  }
}
