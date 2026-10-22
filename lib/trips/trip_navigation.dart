import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';
import '/backend/backend_calls/backend_calls.dart';

/// Driver positions are published by the active trip screen with GPS accuracy.
/// This view only displays positions the server considers fresh.
class TripNavigation extends StatefulWidget {
  const TripNavigation(
      {super.key, required this.orderDocPath, this.isDriver = false});
  final String orderDocPath;
  final bool isDriver;
  @override
  State<TripNavigation> createState() => _TripNavigationState();
}

class _TripNavigationState extends State<TripNavigation> {
  final _map = MapController();
  final _tts = FlutterTts();
  Timer? _timer;
  bool _busy = false, _voice = false, _ready = false;
  Map<String, dynamic>? _trip;
  List<LatLng> _route = [];
  List<Map> _steps = [];
  DateTime? _routedAt;
  int? _routedStatus;
  String _message = 'Загружаем маршрут…', _spoken = '';
  int _step = 1;
  LatLng? _p(dynamic value) {
    if (value is! Map) return null;
    final a = value['lat'] ?? value['latitude'],
        b = value['lng'] ?? value['longitude'];
    return a is num && b is num ? LatLng(a.toDouble(), b.toDouble()) : null;
  }

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_busy) return;
    _busy = true;
    try {
      final trip = await makeCloudCall(
          'getTripTracking', {'orderDocPath': widget.orderDocPath});
      if (!mounted) return;
      if (trip['success'] != true) {
        setState(() => _message = 'Маршрут недоступен');
        return;
      }
      final position = _p(trip['driverPosition']);
      final status = (trip['status'] as num?)?.toInt() ?? 0;
      final pickup = _p(trip['from']), destination = _p(trip['to']);
      final target = status < 4 ? pickup : destination;
      setState(() => _trip = trip);
      if (position == null) {
        setState(() => _message = 'Ожидаем свежую геопозицию водителя');
        return;
      }
      if (_ready && widget.isDriver) _map.move(position, _map.camera.zoom);
      if (target != null &&
          (_routedAt == null ||
              _routedStatus != status ||
              DateTime.now().difference(_routedAt!).inSeconds >= 20)) {
        _routedAt = DateTime.now();
        _routedStatus = status;
        final result = await makeCloudCall('routeLookup', {
          'from': {'lat': position.latitude, 'lng': position.longitude},
          'to': {'lat': target.latitude, 'lng': target.longitude}
        });
        if (!mounted) return;
        if (result['success'] == true) {
          final coordinates =
              (result['coordinates'] as List? ?? []).whereType<List>();
          final points = coordinates
              .where((p) => p.length >= 2)
              .map((p) =>
                  LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
              .toList();
          setState(() {
            _route = points;
            _steps = (result['steps'] as List? ?? []).whereType<Map>().toList();
            _step = _steps.length > 1 ? 1 : 0;
            final minutes =
                ((result['durationSeconds'] as num? ?? 0) / 60).ceil();
            _message =
                '${status < 4 ? 'До посадки' : 'До назначения'} ≈ $minutes мин · без учёта пробок';
          });
          if (_ready && !widget.isDriver && points.length > 1)
            _map.fitCamera(CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(points),
                padding: const EdgeInsets.fromLTRB(40, 160, 40, 320)));
        } else {
          setState(() {
            _steps = [];
            _message = 'Не удалось построить маршрут. Повторяем…';
          });
        }
      }
      if (widget.isDriver && _steps.isNotEmpty) {
        final location = _steps[_step]['location'];
        if (location is List && location.length >= 2) {
          final distance = const Distance()(
              position,
              LatLng((location[1] as num).toDouble(),
                  (location[0] as num).toDouble()));
          final instruction = _steps[_step]['instruction']?.toString() ??
              'Продолжайте движение';
          if (distance < 200) {
            final text = distance < 35
                ? instruction
                : 'Через ${((distance / 50).round() * 50)} метров. $instruction';
            setState(() => _message = text);
            final key =
                '${location.join(',')}:${distance < 35 ? 'near' : 'ahead'}';
            if (_voice && key != _spoken) {
              _spoken = key;
              await _tts.speak(text);
            }
          }
          if (distance < 25 && _step < _steps.length - 1) _step++;
        }
      }
    } catch (_) {
      if (mounted)
        setState(() => _message = 'Нет связи с маршрутом. Повторяем…');
    } finally {
      _busy = false;
    }
  }

  Future<void> _toggleVoice() async {
    if (_voice) {
      await _tts.stop();
      if (mounted) setState(() => _voice = false);
      return;
    }
    try {
      await _tts.setLanguage('ru-RU');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      final voices = await _tts.getVoices;
      if (voices is List) {
        final russian = voices
            .whereType<Map>()
            .where((v) => v['locale'].toString().startsWith('ru'))
            .toList();
        final preferred = russian
            .where((v) =>
                '${v['name']} ${v['gender']}'.toLowerCase().contains('female'))
            .toList();
        final voice = preferred.isNotEmpty
            ? preferred.first
            : (russian.isNotEmpty ? russian.first : null);
        if (voice != null)
          await _tts.setVoice({
            'name': voice['name'].toString(),
            'locale': voice['locale'].toString()
          });
      }
      if (!mounted) return;
      setState(() => _voice = true);
      _spoken = '';
      await _tts.speak('Голосовые подсказки включены');
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Русская озвучка недоступна. Проверьте голосовые пакеты устройства.')));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = _p(_trip?['driverPosition']),
        pickup = _p(_trip?['from']),
        destination = _p(_trip?['to']);
    final center = position ?? pickup ?? const LatLng(53.538, 75.313);
    return Stack(children: [
      FlutterMap(
          mapController: _map,
          options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              onMapReady: () {
                _ready = true;
              }),
          children: [
            TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.milanium.mtaxi'),
            if (_route.length > 1)
              PolylineLayer(polylines: [
                Polyline(
                    points: _route,
                    strokeWidth: 5,
                    color: Theme.of(context).colorScheme.primary)
              ]),
            MarkerLayer(markers: [
              if (pickup != null)
                Marker(
                    point: pickup,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.person_pin_circle,
                        color: Colors.green, size: 36)),
              if (destination != null)
                Marker(
                    point: destination,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.flag, color: Colors.red, size: 32)),
              if (position != null)
                Marker(
                    point: position,
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.local_taxi,
                        color: Colors.deepPurple, size: 38)),
            ]),
            const RichAttributionWidget(attributions: [
              TextSourceAttribution('OpenStreetMap contributors')
            ]),
          ]),
      Positioned(
          top: 90,
          left: 12,
          right: 12,
          child: Card(
              child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    Expanded(child: Text(_message)),
                    if (widget.isDriver)
                      IconButton(
                          tooltip:
                              _voice ? 'Выключить озвучку' : 'Включить озвучку',
                          onPressed: _toggleVoice,
                          icon:
                              Icon(_voice ? Icons.volume_up : Icons.volume_off))
                  ])))),
    ]);
  }
}
