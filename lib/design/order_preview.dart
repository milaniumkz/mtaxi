import '/design/mtaxi_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/flutter_flow/internationalization.dart';
import 'map_attribution.dart';
import 'mtaxi_theme.dart';

class OrderPreview extends StatefulWidget {
  const OrderPreview(
      {super.key,
      required this.order,
      required this.onAccept,
      required this.onOffer,
      this.unavailable = false,
      this.busy = false,
      this.mapOnly = false});
  final Map<String, dynamic> order;
  final VoidCallback onAccept, onOffer;
  final bool unavailable, busy, mapOnly;
  @override
  State<OrderPreview> createState() => _OrderPreviewState();
}

class _OrderPreviewState extends State<OrderPreview> {
  final _map = MapController();
  List<LatLng> _route = [];
  bool _ready = false;
  String? _routeMessage;
  LatLng? _point(dynamic value) => value is Map &&
          value['lat'] is num &&
          value['lng'] is num
      ? LatLng(
          (value['lat'] as num).toDouble(), (value['lng'] as num).toDouble())
      : null;
  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final from = _point(widget.order['fromPoint']),
        to = _point(widget.order['toPoint']);
    if (from == null || to == null) return;
    final result = await makeCloudCall('routeLookup', {
      'from': {'lat': from.latitude, 'lng': from.longitude},
      'to': {'lat': to.latitude, 'lng': to.longitude}
    });
    if (!mounted) return;
    setState(() {
      _route = (result['coordinates'] as List? ?? [])
          .whereType<List>()
          .where((e) => e.length >= 2 && e[0] is num && e[1] is num)
          .map(
              (e) => LatLng((e[1] as num).toDouble(), (e[0] as num).toDouble()))
          .toList();
      if (result['success'] != true || _route.length < 2)
        _routeMessage = 'Маршрут временно недоступен';
    });
    if (_ready && _route.length > 1)
      _map.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(_route),
          maxZoom: 17,
          padding: const EdgeInsets.all(30)));
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String tr(String ru, String kk) =>
        FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
    final from = _point(widget.order['fromPoint']),
        to = _point(widget.order['toPoint']);
    if (widget.mapOnly) {
      if (from == null) return const SizedBox.shrink();
      return FlutterMap(
          mapController: _map,
          options: MapOptions(
              initialCenter: from,
              initialZoom: 14,
              maxZoom: 18,
              onMapReady: () {
                _ready = true;
              }),
          children: [
            TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mtaxi.app'),
            if (_route.length > 1)
              PolylineLayer(polylines: [
                Polyline(
                    points: _route, color: MTaxiDesign.teal, strokeWidth: 5)
              ]),
            MarkerLayer(markers: [
              Marker(
                  point: from,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on,
                      color: MTaxiDesign.ink, size: 36)),
              if (to != null)
                Marker(
                    point: to,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.flag,
                        color: MTaxiDesign.teal, size: 32))
            ]),
            const MTaxiMapAttribution(),
          ]);
    }
    return SafeArea(
        top: false,
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(tr('Детали заказа', 'Тапсырыс мәліметтері'),
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700))),
                    IconButton(
                        tooltip: tr('Закрыть', 'Жабу'),
                        onPressed:
                            widget.busy ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close))
                  ]),
                  const SizedBox(height: 14),
                  if (from != null)
                    ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                            height: 220,
                            child: FlutterMap(
                                mapController: _map,
                                options: MapOptions(
                                    initialCenter: from,
                                    initialZoom: 13,
                                    maxZoom: 18,
                                    onMapReady: () {
                                      _ready = true;
                                      if (_route.length > 1)
                                        _map.fitCamera(CameraFit.bounds(
                                            bounds:
                                                LatLngBounds.fromPoints(_route),
                                            maxZoom: 17,
                                            padding: const EdgeInsets.all(30)));
                                    }),
                                children: [
                                  TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.mtaxi.app'),
                                  if (_route.length > 1)
                                    PolylineLayer(polylines: [
                                      Polyline(
                                          points: _route,
                                          color: MTaxiDesign.teal,
                                          strokeWidth: 4)
                                    ]),
                                  MarkerLayer(markers: [
                                    Marker(
                                        point: from,
                                        width: 36,
                                        height: 36,
                                        child: const Icon(Icons.location_on,
                                            color: MTaxiDesign.ink, size: 32)),
                                    if (to != null)
                                      Marker(
                                          point: to,
                                          width: 36,
                                          height: 36,
                                          child: const Icon(Icons.location_on,
                                              color: MTaxiDesign.teal,
                                              size: 32))
                                  ]),
                                  const MTaxiMapAttribution(),
                                ]))),
                  if (_routeMessage != null)
                    Text(tr('Маршрут временно недоступен',
                        'Бағыт уақытша қолжетімсіз')),
                  const SizedBox(height: 20),
                  Text('${widget.order['price'] ?? '—'} ₸',
                      style: const TextStyle(
                          fontSize: 36, fontWeight: FontWeight.w700)),
                  Text(tr('Цена пассажира', 'Жолаушы бағасы'),
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 20),
                  MTaxiCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        Text(widget.order['ot']?.toString() ?? '—',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        MTaxiDestinationLine(
                            widget.order['kuda']?.toString() ?? '—')
                      ])),
                  if ((widget.order['comment'] ?? '')
                      .toString()
                      .isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(widget.order['comment'].toString())
                  ],
                  if ((widget.order['deliveryItem'] ?? '')
                      .toString()
                      .isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(widget.order['deliveryItem'].toString())
                  ],
                  const SizedBox(height: 20),
                  if (!widget.unavailable) ...[
                    FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: MTaxiDesign.ink,
                            foregroundColor: Colors.white),
                        onPressed: widget.busy ? null : widget.onOffer,
                        child: Text(
                            tr('Предложить свою цену', 'Өз бағаңызды ұсыну'))),
                    const SizedBox(height: 10),
                    Text(
                        tr('Пассажир ответит в течение 30 секунд. Заказ начнётся после согласия пассажира.',
                            'Жолаушы 30 секунд ішінде жауап береді. Тапсырыс жолаушы келіскеннен кейін басталады.'),
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 14),
                    OutlinedButton(
                        onPressed: widget.busy ? null : widget.onAccept,
                        child: Text(widget.busy
                            ? tr('Подтверждаем…', 'Расталуда…')
                            : tr('Принять цену пассажира',
                                'Жолаушы бағасын қабылдау'))),
                  ] else
                    Text(tr('Заказ больше недоступен',
                        'Тапсырыс енді қолжетімсіз')),
                ])));
  }
}
