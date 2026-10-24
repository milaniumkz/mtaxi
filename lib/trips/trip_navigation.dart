import '/design/bottom_navigation.dart';
import '/design/map_attribution.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import '/design/mtaxi_icon.dart';
import '/design/mtaxi_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';
import '/backend/backend_calls/backend_calls.dart';

CameraFit navigationRouteFit(List<LatLng> points, double height) =>
    CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      maxZoom: 17,
      minZoom: 3,
      padding: EdgeInsets.fromLTRB(24, height * .18, 24, height * .60),
    );

String? navigationSpeechText(String instruction, double distance,
    {required bool pickup}) {
  if (!distance.isFinite || distance < 0) return null;
  final arrival = instruction.toLowerCase().contains('прибы') ||
      instruction.toLowerCase().contains('arriv');
  if (arrival)
    return distance <= 25
        ? (pickup ? 'Вы на месте посадки.' : 'Вы приехали.')
        : null;
  if (distance >= 200) return null;
  return distance < 35
      ? instruction
      : 'Через ${(distance / 50).round() * 50} метров, $instruction';
}

/// Driver positions are published by the active trip screen with GPS accuracy.
/// This view only displays positions the server considers fresh.
class TripNavigation extends StatefulWidget {
  const TripNavigation(
      {super.key,
      required this.orderDocPath,
      this.isDriver = false,
      this.driverPosition,
      this.driverHeading});
  final String orderDocPath;
  final bool isDriver;
  final LatLng? driverPosition;
  final double? driverHeading;
  @override
  State<TripNavigation> createState() => _TripNavigationState();
}

class _TripNavigationState extends State<TripNavigation>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _map = MapController();
  final _tts = FlutterTts();
  bool _tabActive = true;
  Timer? _timer;
  bool _busy = false, _voice = false, _ready = false;
  Map<String, dynamic>? _trip;
  List<LatLng> _route = [];
  List<Map> _steps = [];
  DateTime? _routedAt;
  int? _routedStatus;
  String _message = 'Загружаем маршрут…';
  final Set<String> _spoken = {};
  bool _voiceBusy = false, _follow = true;
  int _speechGeneration = 0;
  late final AnimationController _motion;
  LatLng? _display, _motionFrom, _motionTo, _lastRaw;
  double _heading = 0, _headingFrom = 0, _headingTo = 0;
  DateTime? _lastSpokenAt;
  int _step = 1;
  LatLng? _p(dynamic value) {
    if (value is! Map) return null;
    final a = value['lat'] ?? value['latitude'],
        b = value['lng'] ?? value['longitude'];
    return a is num && b is num ? LatLng(a.toDouble(), b.toDouble()) : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = MTaxiTabActivity.isActive(context);
    if (!active && _tabActive) _tts.stop();
    _tabActive = active;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _motion = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..addListener(() {
        final a = _motionFrom, b = _motionTo;
        if (a == null || b == null || !mounted) return;
        final t = Curves.easeOut.transform(_motion.value);
        setState(() {
          _display = LatLng(a.latitude + (b.latitude - a.latitude) * t,
              a.longitude + (b.longitude - a.longitude) * t);
          _heading = _headingFrom +
              ((_headingTo - _headingFrom + 540) % 360 - 180) * t;
        });
        _followCamera();
      });
    _updatePosition(widget.driverPosition, widget.driverHeading);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if ((ModalRoute.of(context)?.isCurrent ?? true) &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed)) _refresh();
    });
  }

  @override
  void didUpdateWidget(covariant TripNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDriver && widget.driverPosition != null)
      _updatePosition(widget.driverPosition, widget.driverHeading);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _speechGeneration++;
      unawaited(_tts.stop());
    }
  }

  void _updatePosition(LatLng? next, [double? heading]) {
    if (next == null) return;
    final previous = _lastRaw;
    final moved = previous == null ? 0.0 : const Distance()(previous, next);
    final nextHeading = heading != null && heading.isFinite && heading >= 0
        ? heading % 360
        : previous != null && moved >= 5
            ? const Distance().bearing(previous, next) % 360
            : _heading;
    _lastRaw = next;
    if (_display == null) {
      _display = next;
      _heading = nextHeading;
      return;
    }
    if (moved < .5 && ((_heading - nextHeading + 540) % 360 - 180).abs() < 1)
      return;
    _motionFrom = _display;
    _motionTo = next;
    _headingFrom = _heading;
    _headingTo = nextHeading;
    _motion.forward(from: 0);
  }

  void _followCamera() {
    if (!_ready ||
        !widget.isDriver ||
        !_follow ||
        _display == null ||
        !_tabActive) return;
    _map.rotate(-_heading);
    _map.move(_display!, _map.camera.zoom,
        offset: Offset(0, -_map.camera.nonRotatedSize.y * .24));
  }

  Future<void> _speak(String text, String key) async {
    if (!_voice || !_tabActive || _spoken.contains(key)) return;
    if (_lastSpokenAt != null &&
        DateTime.now().difference(_lastSpokenAt!).inSeconds < 4 &&
        !key.endsWith(':near') &&
        !key.endsWith(':arrival')) return;
    _spoken.add(key);
    _lastSpokenAt = DateTime.now();
    if (_spoken.length > 100) _spoken.remove(_spoken.first);
    final generation = ++_speechGeneration;
    try {
      await _tts.stop().timeout(const Duration(seconds: 1));
      if (!mounted || !_voice || !_tabActive || generation != _speechGeneration)
        return;
      await _tts.speak(text).timeout(const Duration(seconds: 2));
    } catch (_) {
      /* A speech engine must never stall route and position updates. */
    }
  }

  Future<void> _refresh() async {
    if (_busy || !_tabActive) return;
    _busy = true;
    try {
      final trip = await makeCloudCall(
          'getTripTracking', {'orderDocPath': widget.orderDocPath});
      if (!mounted || !_tabActive) return;
      if (trip['success'] != true) {
        setState(() => _message = 'Маршрут недоступен');
        return;
      }
      final position = widget.isDriver
          ? widget.driverPosition ?? _p(trip['driverPosition'])
          : _p(trip['driverPosition']);
      _updatePosition(position, widget.isDriver ? widget.driverHeading : null);
      final status = (trip['status'] as num?)?.toInt() ?? 0;
      final pickup = _p(trip['from']), destination = _p(trip['to']);
      final target = status < 4 ? pickup : destination;
      setState(() => _trip = trip);
      if (position == null) {
        _motion.stop();
        setState(() {
          _display = null;
          _lastRaw = null;
          _message = 'Ожидаем свежую геопозицию водителя';
        });
        return;
      }
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
        if (!mounted || !_tabActive) return;
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
            final duration = result['durationSeconds'];
            _message = duration is num && duration.isFinite && duration >= 0
                ? '${status < 4 ? 'До посадки' : 'До назначения'} ≈ ${(duration / 60).ceil()} мин · без учёта пробок'
                : 'Маршрут построен. Время уточняется';
          });
          if (_ready && !widget.isDriver && points.length > 1)
            _map.fitCamera(
                navigationRouteFit(points, _map.camera.nonRotatedSize.y));
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
          final arrival = instruction.toLowerCase().contains('прибы') ||
              instruction.toLowerCase().contains('arriv');
          final text =
              navigationSpeechText(instruction, distance, pickup: status < 4);
          if (text != null) {
            if (!widget.isDriver) setState(() => _message = text);
            final key = arrival
                ? '$status:arrival'
                : '$status:${location.join(',')}:${distance < 35 ? 'near' : 'ahead'}';
            unawaited(_speak(text, key));
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
    if (_voiceBusy) return;
    if (_voice) {
      _speechGeneration++;
      if (mounted) setState(() => _voice = false);
      await _tts.stop();
      return;
    }
    _voiceBusy = true;
    try {
      await _tts.awaitSpeakCompletion(false);
      await _tts.setLanguage('ru-RU');
      await _tts.setSpeechRate(kIsWeb ? 1.0 : 0.5);
      await _tts.setPitch(1.0);
      final voices = await _tts.getVoices.timeout(const Duration(seconds: 2));
      if (voices is List) {
        final russian = voices
            .whereType<Map>()
            .where((v) => v['locale'].toString().startsWith('ru'))
            .toList();
        int score(Map v) {
          final text = '${v['name']} ${v['gender']}'.toLowerCase();
          return (RegExp('natural|neural|premium|enhanced').hasMatch(text)
                  ? 30
                  : 0) +
              (RegExp('google|microsoft').hasMatch(text) ? 10 : 0) +
              (RegExp('female|svetlana|milena|irina|elena|светлана|ирина|жен')
                      .hasMatch(text)
                  ? 8
                  : 0);
        }

        russian.sort((a, b) => score(b).compareTo(score(a)));
        final voice = russian.isEmpty ? null : russian.first;
        if (voice != null)
          await _tts.setVoice({
            'name': voice['name'].toString(),
            'locale': voice['locale'].toString()
          });
      }
      if (!mounted || !_tabActive) return;
      setState(() => _voice = true);
      _spoken.clear();
      unawaited(_speak('Голосовые подсказки включены', 'enabled'));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Русская озвучка недоступна. Проверьте голосовые пакеты устройства.')));
    } finally {
      _voiceBusy = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    _timer?.cancel();
    _speechGeneration++;
    _tts.stop();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = _display ?? _p(_trip?['driverPosition']),
        pickup = _p(_trip?['from']),
        destination = _p(_trip?['to']);
    final center = position ?? pickup ?? const LatLng(53.538, 75.313);
    return Stack(children: [
      FlutterMap(
          mapController: _map,
          options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              minZoom: 3,
              maxZoom: 19,
              onMapReady: () {
                _ready = true;
                _followCamera();
              },
              onPositionChanged: (_, gesture) {
                if (gesture && widget.isDriver && _follow)
                  setState(() => _follow = false);
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
                    color: const Color(0xFF188B83))
              ]),
            MarkerLayer(markers: [
              if (pickup != null)
                Marker(
                    point: pickup,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.person_pin_circle,
                        color: const Color(0xFF188B83), size: 36)),
              if (destination != null)
                Marker(
                    point: destination,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.flag,
                        color: const Color(0xFF188B83), size: 32)),
              if (position != null)
                Marker(
                    point: position,
                    width: 44,
                    height: 44,
                    child: Transform.rotate(
                        angle: _heading * math.pi / 180,
                        child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                                color: MTaxiDesign.gold,
                                shape: BoxShape.circle),
                            child: const MTaxiIcon('car',
                                size: 32, color: MTaxiDesign.ink)))),
            ]),
            const MTaxiMapAttribution(),
          ]),
      if (widget.isDriver)
        Positioned(
            top: 16,
            right: 12,
            child: Column(children: [
              Material(
                  color: Theme.of(context).colorScheme.surface,
                  shape: const CircleBorder(),
                  child: IconButton(
                      tooltip:
                          _voice ? 'Выключить озвучку' : 'Включить озвучку',
                      onPressed: _toggleVoice,
                      icon: Icon(_voice ? Icons.volume_up : Icons.volume_off))),
              const SizedBox(height: 8),
              Material(
                  color: Theme.of(context).colorScheme.surface,
                  shape: const CircleBorder(),
                  child: IconButton(
                      tooltip: 'Следовать за машиной',
                      onPressed: () {
                        setState(() => _follow = true);
                        _followCamera();
                      },
                      icon: Icon(Icons.my_location,
                          color: _follow ? MTaxiDesign.teal : null))),
            ])),
      if (!widget.isDriver)
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
                            tooltip: _voice
                                ? 'Выключить озвучку'
                                : 'Включить озвучку',
                            onPressed: _toggleVoice,
                            icon: Icon(
                                _voice ? Icons.volume_up : Icons.volume_off))
                    ])))),
    ]);
  }
}
