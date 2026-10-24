import '/design/map_attribution.dart';
import '/design/service_type_cards.dart';
import '/design/mtaxi_theme.dart';
// ignore_for_file: unused_import, unused_element, unnecessary_import, deprecated_member_use

// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/backend_session.dart';
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

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

@immutable
class IntercityRoute {
  final String ot;
  final String kuda;
  final double price;

  const IntercityRoute({
    required this.ot,
    required this.kuda,
    required this.price,
  });
}

class DeliveryTaxiMap extends StatefulWidget {
  final double? width;
  final double? height;

  final Function(String)? onFromAddressChanged;
  final Function(String)? onToAddressChanged;
  final Function(latlng.LatLng)? onFromCoordsChanged;
  final Function(latlng.LatLng)? onToCoordsChanged;
  final Function(double)? onDistanceChanged;
  final Function(String)? onServiceTypeChanged;
  final Function(String)? onCommentChanged;
  final Function(String)? onDeliveryItemChanged;
  final Function(double?)? onIntercityPriceChanged;

  final Color? taxiSelectedColor;
  final Color? taxiUnselectedColor;
  final Color? deliverySelectedColor;
  final Color? deliveryUnselectedColor;

  final String? initialFromAddress;
  final String? initialToAddress;
  final String? initialServiceType;
  final String? initialComment;
  final String? initialDeliveryItem;
  final latlng.LatLng? initialFromCoords;
  final latlng.LatLng? initialToCoords;
  final String? priceText;
  final String? cityName;
  final bool intercityEnabled;
  final bool enableAutoLocation;
  final bool enableRemoteGeocoding;
  final bool enableTileLayer;
  final List<IntercityRoute>? intercityRoutesOverride;
  final bool enableTestMapTap;
  final latlng.LatLng? testMapTapPoint;
  final void Function(Future<void> Function(latlng.LatLng))?
      onTestMapTapHandler;

  const DeliveryTaxiMap({
    Key? key,
    this.width,
    this.height,
    this.onFromAddressChanged,
    this.onToAddressChanged,
    this.onFromCoordsChanged,
    this.onToCoordsChanged,
    this.onDistanceChanged,
    this.onServiceTypeChanged,
    this.onCommentChanged,
    this.onDeliveryItemChanged,
    this.onIntercityPriceChanged,
    this.taxiSelectedColor = Colors.green,
    this.taxiUnselectedColor = Colors.grey,
    this.deliverySelectedColor = Colors.blue,
    this.deliveryUnselectedColor = Colors.grey,
    this.initialFromAddress = '',
    this.initialToAddress = '',
    this.initialServiceType = 'taxi',
    this.initialComment = '',
    this.initialDeliveryItem = '',
    this.initialFromCoords,
    this.initialToCoords,
    this.priceText = '',
    this.cityName = '',
    this.intercityEnabled = false,
    this.enableAutoLocation = true,
    this.enableRemoteGeocoding = true,
    this.enableTileLayer = true,
    this.intercityRoutesOverride,
    this.enableTestMapTap = false,
    this.testMapTapPoint,
    this.onTestMapTapHandler,
  }) : super(key: key);

  @override
  _DeliveryTaxiMapState createState() => _DeliveryTaxiMapState();
}

class _DeliveryTaxiMapState extends State<DeliveryTaxiMap> {
  // OpenStreetMap / Nominatim / OSRM
  // Local fallback: do not show the ocean when browser/native location is
  // unavailable. Web over LAN HTTP cannot reliably access geolocation.
  static final latlng.LatLng _defaultCenter = latlng.LatLng(52.3231, 77.1282);

  // Состояние
  late MapController _mapController;
  latlng.LatLng? _userLocation;
  latlng.LatLng? _fromLocation;
  latlng.LatLng? _toLocation;
  bool _isLoading = false;
  bool _isRouteLoading = false;
  double _currentZoom = 17.0;
  String _serviceType = 'taxi';
  bool _editorOpen = false;
  String _activeField = 'from';
  Timer? _fromDebounce;
  Timer? _toDebounce;
  List<String> _fromSuggestions = [];
  List<String> _toSuggestions = [];
  final Map<String, latlng.LatLng> _suggestionCoords = {};
  bool _intercityLoaded = false;
  List<IntercityRoute> _intercityRoutes = [];
  Set<String> _intercityPoints = {};
  IntercityRoute? _selectedIntercityRoute;
  String _selectedIntercityToCity = '';
  String _lastNoRoutesFromCityKey = '';
  int _fromSearchVersion = 0;
  int _toSearchVersion = 0;

  // Маршрут
  List<latlng.LatLng> _routePoints = [];
  double _routeDistance = 0.0;
  int _routeDuration = 0;

  // Контроллеры
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _deliveryItemController = TextEditingController();

  bool get _isKazakh =>
      FFLocalizations.of(context).languageCode.toLowerCase().startsWith('kk');

  String _tr(String ru, String kk) => _isKazakh ? kk : ru;

  String get _languageCode => _isKazakh ? 'kk' : 'ru';

  String _displayPriceText() {
    final raw = (widget.priceText ?? '').trim();
    if (raw.isEmpty) {
      return _selectedIntercityRoute == null
          ? ''
          : formatAppCurrency(_selectedIntercityRoute!.price);
    }
    final normalized = raw
        .replaceAll('₸', '')
        .replaceAll('\u00A0', ' ')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null) {
      return raw.contains('₸') ? raw : '$raw ₸';
    }
    return formatAppCurrency(value);
  }

  String get _resolvingAddressLabel =>
      _tr('Определяем адрес...', 'Мекенжай анықталуда...');

  String get _addressPendingLabel =>
      _tr('Адрес уточняется', 'Мекенжай нақтылануда');

  bool _isCoordinateText(String value) {
    final lower = value.trim().toLowerCase();
    return lower.startsWith('координаты') ||
        lower.startsWith('координаттар') ||
        lower.startsWith('определяем адрес') ||
        lower.startsWith('мекенжай анықталуда');
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _serviceType =
        !widget.intercityEnabled && widget.initialServiceType == 'intercity'
            ? 'taxi'
            : widget.initialServiceType ?? 'taxi';
    _fromController.text = widget.initialFromAddress ?? '';
    _toController.text = widget.initialToAddress ?? '';
    _commentController.text = widget.initialComment ?? '';
    _deliveryItemController.text = widget.initialDeliveryItem ?? '';
    _fromLocation = widget.initialFromCoords;
    _toLocation = widget.initialToCoords;

    if (_fromLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _fromLocation == null) return;
        _mapController.move(_fromLocation!, 17.0);
        if (_fromController.text.trim().isEmpty) {
          unawaited(_fillFromAddressForCoords(_fromLocation!));
        }
      });
    } else if (widget.enableAutoLocation) {
      _getUserLocation();
    }
    if (widget.intercityRoutesOverride != null) {
      _applyIntercityRoutes(widget.intercityRoutesOverride!);
    } else {
      _loadIntercityRoutes();
    }
    widget.onTestMapTapHandler?.call(_handleMapTap);
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _commentController.dispose();
    _deliveryItemController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationAccessMessage(
          'Включите геолокацию на устройстве и попробуйте снова',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationAccessMessage(
          kIsWeb
              ? 'Разрешите геолокацию в браузере. Если окно не появляется, откройте приложение через HTTPS или включите разрешение в настройках сайта.'
              : 'Разрешите геолокацию в настройках приложения',
        );
        return;
      }

      final position = await getSafeCurrentPosition(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      if (!mounted) return;
      final user = latlng.LatLng(position.latitude, position.longitude);
      setState(() {
        _userLocation = user;
        _fromLocation = user;
        _activeField = 'to';
      });
      widget.onFromCoordsChanged?.call(user);
      _mapController.move(user, 17.0);
      await _fillFromAddressForCoords(user);
    } catch (e) {
      debugPrint('Ошибка получения геолокации: $e');
      if (!mounted) return;
      setState(() {
        _userLocation = null;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fillFromAddressForCoords(latlng.LatLng coords) async {
    if (!mounted || !widget.enableRemoteGeocoding) return;
    final resolved = await _reverseGeocode(coords);
    if (!mounted || resolved.trim().isEmpty) return;
    final address = _serviceType == 'intercity'
        ? _formatIntercityFromAddress(resolved)
        : resolved;
    setState(() {
      _fromController.text = address;
      _activeField = 'to';
    });
    widget.onFromAddressChanged?.call(address);
    if (_serviceType == 'intercity') {
      _notifyNoRoutesFromCurrentCity(force: true);
      _resolveIntercityRoute();
    }
  }

  void _showLocationAccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _normalizeRouteKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^a-zа-яәіңғүұқөһёі0-9 ]'), '');
  }

  bool _addressContainsCity(String address, String city) {
    final addrNorm = _normalizeRouteKey(address);
    final cityNorm = _normalizeRouteKey(city);
    if (addrNorm.isEmpty || cityNorm.isEmpty) return false;
    return addrNorm.contains(cityNorm);
  }

  String _routeKey(String a, String b) {
    final first = _normalizeRouteKey(a);
    final second = _normalizeRouteKey(b);
    final pair = [first, second]..sort();
    return '${pair[0]}|${pair[1]}';
  }

  String _extractCityFromAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (_isCoordinateText(trimmed)) return '';
    final parts = trimmed.split(',');
    if (parts.isEmpty) return '';
    return parts.first.trim();
  }

  String _formatIntercityFromAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || _isCoordinateText(trimmed)) return trimmed;
    final parts = trimmed
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length < 2) return trimmed;

    final candidates = <String>[
      ..._intercityPoints,
      if ((widget.cityName ?? '').trim().isNotEmpty) widget.cityName!.trim(),
    ];
    String matchedCity = '';
    for (final candidate in candidates) {
      final cityNorm = _normalizeRouteKey(candidate);
      if (cityNorm.isEmpty) continue;
      if (parts.any((part) => _normalizeRouteKey(part) == cityNorm)) {
        matchedCity = candidate.trim();
        break;
      }
    }
    if (matchedCity.isEmpty) return trimmed;

    final cityNorm = _normalizeRouteKey(matchedCity);
    if (_normalizeRouteKey(parts.first) == cityNorm) return trimmed;
    final details = parts
        .where((part) => _normalizeRouteKey(part) != cityNorm)
        .where((part) {
      final norm = _normalizeRouteKey(part);
      return norm.isNotEmpty &&
          !norm.contains('казахстан') &&
          !norm.contains('область') &&
          !norm.contains('облысы') &&
          !norm.contains('ауданы') &&
          !norm.contains('район');
    }).toList();
    if (details.isEmpty) return matchedCity;
    return '$matchedCity, ${details.join(', ')}';
  }

  void _applyIntercityFromAddressFormat({bool notify = true}) {
    if (_serviceType != 'intercity') return;
    final formatted = _formatIntercityFromAddress(_fromController.text);
    if (formatted == _fromController.text.trim()) return;
    setState(() {
      _fromController.text = formatted;
    });
    if (notify) {
      widget.onFromAddressChanged?.call(formatted);
    }
  }

  int _nextSearchVersion(String field) {
    if (field == 'from') {
      _fromSearchVersion += 1;
      return _fromSearchVersion;
    }
    _toSearchVersion += 1;
    return _toSearchVersion;
  }

  bool _isCurrentSearchVersion(String field, int version) {
    return field == 'from'
        ? _fromSearchVersion == version
        : _toSearchVersion == version;
  }

  bool _hasIntercityRoutesForCity(String city) {
    final cityNorm = _normalizeRouteKey(city);
    if (cityNorm.isEmpty) return false;
    for (final route in _intercityRoutes) {
      final otNorm = _normalizeRouteKey(route.ot.trim());
      final kudaNorm = _normalizeRouteKey(route.kuda.trim());
      if (otNorm == cityNorm || kudaNorm == cityNorm) return true;
    }
    return false;
  }

  void _notifyNoRoutesFromCurrentCity({bool force = false}) {
    if (_serviceType != 'intercity' || !_intercityLoaded || !mounted) return;
    final fromCity = _extractCityFromAddress(_fromController.text);
    final cityNorm = _normalizeRouteKey(fromCity);
    if (cityNorm.isEmpty) return;
    if (_hasIntercityRoutesForCity(fromCity)) {
      _lastNoRoutesFromCityKey = '';
      return;
    }
    if (!force && _lastNoRoutesFromCityKey == cityNorm) return;
    _lastNoRoutesFromCityKey = cityNorm;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            'Из поселка "$fromCity" нет маршрутов',
            '"$fromCity" елді мекенінен маршруттар жоқ',
          ),
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _intercityToCityFromInput(String value) {
    final fromAddress = _extractCityFromAddress(value);
    if (fromAddress.isNotEmpty) return fromAddress;
    if (_selectedIntercityToCity.isNotEmpty) return _selectedIntercityToCity;
    return value.trim();
  }

  bool _isDetailedAddressInCity(String fullAddress, String city) {
    final address = fullAddress.trim();
    final cityTrimmed = city.trim();
    if (address.isEmpty || cityTrimmed.isEmpty) return false;
    if (!_addressContainsCity(address, cityTrimmed)) return false;
    final parts = address.split(',');
    if (parts.length < 2) return false;
    final details = parts.skip(1).join(',').trim();
    return details.length >= 3;
  }

  bool _fromFieldHasValue() {
    return _fromController.text.trim().isNotEmpty;
  }

  String _nextFieldAfterToSelection() {
    return 'to';
  }

  void _applyIntercityRoutes(List<IntercityRoute> routes) {
    final cleaned = routes
        .map((route) => IntercityRoute(
              ot: route.ot.trim(),
              kuda: route.kuda.trim(),
              price: route.price,
            ))
        .where((route) => route.ot.isNotEmpty && route.kuda.isNotEmpty)
        .toList();
    final points = <String>{};
    for (final route in cleaned) {
      points.add(route.ot);
      points.add(route.kuda);
    }
    if (!mounted) {
      _intercityRoutes = cleaned;
      _intercityPoints = points;
      _intercityLoaded = true;
    } else {
      setState(() {
        _intercityRoutes = cleaned;
        _intercityPoints = points;
        _intercityLoaded = true;
      });
    }
    if (_serviceType == 'intercity') {
      _validateIntercityDestination();
      _resolveIntercityRoute();
      _notifyNoRoutesFromCurrentCity();
    }
  }

  void _mergeIntercityRoute(
    Map<String, IntercityRoute> merged,
    IntercityRoute route, {
    bool overwrite = false,
  }) {
    final ot = route.ot.trim();
    final kuda = route.kuda.trim();
    if (ot.isEmpty || kuda.isEmpty) return;
    final key = _routeKey(ot, kuda);
    final normalized = IntercityRoute(ot: ot, kuda: kuda, price: route.price);
    if (overwrite) {
      merged[key] = normalized;
      return;
    }
    merged.putIfAbsent(key, () => normalized);
  }

  Future<void> _loadIntercityRoutes() async {
    final merged = <String, IntercityRoute>{};
    try {
      final response = await makeCloudCall('listIntercityRoutes', {});
      final rawRoutes = response['routes'];
      final routes = rawRoutes is List
          ? rawRoutes.whereType<Map>().map((data) {
              final price = data['tarif'] ?? data['price'] ?? data['cost'];
              return IntercityRoute(
                ot: (data['ot'] ?? data['from'] ?? data['otkuda'] ?? '')
                    .toString(),
                kuda: (data['kuda'] ?? data['to'] ?? '').toString(),
                price: price is num
                    ? price.toDouble()
                    : double.tryParse(price?.toString() ?? '') ?? 0.0,
              );
            }).toList()
          : <IntercityRoute>[];
      for (final route in routes) {
        _mergeIntercityRoute(merged, route, overwrite: true);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки межгорода из backend: $e');
    }
    _applyIntercityRoutes(merged.values.toList());
  }

  Future<String> _reverseGeocode(latlng.LatLng coords) async {
    if (!widget.enableRemoteGeocoding) {
      return _addressPendingLabel;
    }
    try {
      final response = await makeCloudCall(
        'reverseGeocodeLookup',
        {
          'lat': coords.latitude,
          'lng': coords.longitude,
          'language': 'ru',
        },
        timeout: const Duration(seconds: 8),
      );
      final address = (response['address']?.toString() ?? '').trim();
      if (response['success'] == true && address.isNotEmpty) {
        return address;
      }
    } catch (e) {
      debugPrint('Ошибка reverse geocoding через backend: $e');
    }

    return _addressPendingLabel;
  }

  Future<latlng.LatLng?> _forwardGeocode(
    String address, {
    bool forceCity = false,
    bool updateController = true,
    String? preferredCity,
    String? targetField,
  }) async {
    if (address.isEmpty) return null;
    if (!widget.enableRemoteGeocoding) return null;
    try {
      final city = (preferredCity ?? widget.cityName ?? '').trim();
      final useCity = city.isNotEmpty &&
          (forceCity || _serviceType != 'intercity') &&
          !_addressContainsCity(address, city);
      final query = useCity ? '$city, $address' : address;
      final response = await makeCloudCall(
        'forwardGeocodeLookup',
        {
          'query': query,
          'city': preferredCity ?? widget.cityName ?? '',
          'language': _languageCode,
        },
        timeout: const Duration(seconds: 8),
      );
      final lat = double.tryParse(response['lat']?.toString() ?? '');
      final lng = double.tryParse(response['lng']?.toString() ?? '');
      final formatted = (response['address']?.toString() ?? '').trim();
      if (response['success'] == true && lat != null && lng != null) {
        if (formatted.isNotEmpty && updateController) {
          final resolvedField = targetField ?? _activeField;
          if (resolvedField == 'from') {
            _fromController.text = formatted;
          } else if (resolvedField == 'to') {
            _toController.text = formatted;
          }
        }
        return latlng.LatLng(lat, lng);
      }
    } catch (e) {
      debugPrint('Ошибка поиска адреса через backend: $e');
    }

    return null;
  }

  Future<List<String>> _fetchSuggestions(
    String query, {
    bool forceCity = false,
  }) async {
    if (query.trim().length < 2) return [];
    if (!widget.enableRemoteGeocoding) return [];
    try {
      final city = (widget.cityName ?? '').trim();
      final useCity = city.isNotEmpty &&
          (forceCity || _serviceType != 'intercity') &&
          !_addressContainsCity(query, city);
      final search = useCity ? '$city, $query' : query;
      final response = await makeCloudCall(
        'suggestAddressesLookup',
        {
          'query': search,
          'city': widget.cityName ?? '',
          'limit': 5,
          'language': 'ru',
        },
        timeout: const Duration(seconds: 8),
      );
      final rawItems = response['items'];
      if (response['success'] == true && rawItems is List) {
        final rawResults = response['results'];
        if (rawResults is List) {
          for (final raw in rawResults) {
            if (raw is! Map) continue;
            final label = (raw['description'] ??
                    raw['formatted_address'] ??
                    raw['name'] ??
                    '')
                .toString()
                .trim();
            final lat = double.tryParse(raw['lat']?.toString() ?? '');
            final lng = double.tryParse(
              (raw['lng'] ?? raw['lon'])?.toString() ?? '',
            );
            if (label.isNotEmpty && lat != null && lng != null) {
              _suggestionCoords[_normalizeRouteKey(label)] =
                  latlng.LatLng(lat, lng);
            }
          }
        }
        return rawItems
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  void _onFromChanged(String value) {
    final previous = _fromController.text.trim();
    if (previous != value.trim()) {
      setState(() {
        _fromLocation = null;
        _routePoints = [];
        _routeDistance = 0.0;
        _routeDuration = 0;
      });
    }
    widget.onFromAddressChanged?.call(value);
    _fromDebounce?.cancel();
    _fromDebounce = Timer(const Duration(milliseconds: 350), () async {
      List<String> items;
      if (_serviceType == 'intercity') {
        if (!_intercityLoaded) {
          await _loadIntercityRoutes();
        }
        items = _getIntercityFromSuggestions(value);
      } else {
        items = await _fetchSuggestions(value);
      }
      if (!mounted) return;
      setState(() {
        _fromSuggestions = items;
      });
      if (_serviceType == 'intercity') {
        _resolveIntercityRoute();
      }
    });
  }

  void _onToChanged(String value) {
    final previous = _toController.text.trim();
    if (previous != value.trim()) {
      setState(() {
        _toLocation = null;
        _selectedIntercityRoute = null;
        _routePoints = [];
        _routeDistance = 0.0;
        _routeDuration = 0;
      });
      if (_serviceType == 'intercity') {
        widget.onIntercityPriceChanged?.call(null);
      }
    }
    widget.onToAddressChanged?.call(value);
    _toDebounce?.cancel();
    _toDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (_serviceType == 'intercity') {
        if (!_intercityLoaded) {
          await _loadIntercityRoutes();
        }
        final items = _getIntercityToSuggestions(value);
        final typedCity = _extractCityFromAddress(value).trim();
        final normalizedTyped = _normalizeRouteKey(
          typedCity.isNotEmpty ? typedCity : value,
        );
        if (normalizedTyped.isNotEmpty) {
          final exact = items.where((item) {
            return _normalizeRouteKey(item) == normalizedTyped;
          });
          if (exact.isNotEmpty) {
            _selectedIntercityToCity = exact.first;
          }
        }
        if (!mounted) return;
        setState(() {
          _toSuggestions = items;
        });
        _resolveIntercityRoute();
      } else {
        final items = await _fetchSuggestions(value);
        if (!mounted) return;
        setState(() {
          _toSuggestions = items;
        });
      }
    });
  }

  Future<void> _selectAddressSuggestion(
    String field,
    String item,
  ) async {
    final directCoords = _suggestionCoords[_normalizeRouteKey(item)];
    if (field == 'from') {
      setState(() {
        _fromController.text = item;
        _fromSuggestions = [];
        _toSuggestions = [];
        _activeField = 'from';
      });
      widget.onFromAddressChanged?.call(item);
    } else {
      setState(() {
        _toController.text = item;
        _toSuggestions = [];
        _fromSuggestions = [];
        _activeField = 'to';
      });
      widget.onToAddressChanged?.call(item);
    }
    if (directCoords != null) {
      await _applySuggestionCoords(field, item, directCoords);
      return;
    }
    await _searchAddress(item, field);
  }

  Future<void> _applySuggestionCoords(
    String field,
    String item,
    latlng.LatLng coords,
  ) async {
    if (!mounted) return;
    if (field == 'from') {
      setState(() {
        _fromLocation = coords;
        _activeField = 'to';
      });
      widget.onFromCoordsChanged?.call(coords);
      if (widget.enableRemoteGeocoding) {
        await _fillFromAddressForCoords(coords);
      }
    } else {
      setState(() {
        _toLocation = coords;
        _activeField = _nextFieldAfterToSelection();
      });
      widget.onToCoordsChanged?.call(coords);
      if (widget.enableRemoteGeocoding) {
        final resolved = await _reverseGeocode(coords);
        if (mounted && resolved.trim().isNotEmpty) {
          setState(() {
            _toController.text = resolved;
          });
          widget.onToAddressChanged?.call(resolved);
        }
      } else {
        widget.onToAddressChanged?.call(item);
      }
    }
    _mapController.move(coords, 17.0);
    setState(() {
      _currentZoom = 17.0;
    });
    if (_fromLocation != null && _toLocation != null) {
      await _fetchRoute(_fromLocation!, _toLocation!);
    }
    _unfocusAddressFields();
  }

  List<String> _getIntercityFromSuggestions(String query) {
    final cityPart = _extractCityFromAddress(query);
    final raw = cityPart.isNotEmpty ? cityPart : query.trim();
    final q = _normalizeRouteKey(raw);

    if (cityPart.isNotEmpty && query.contains(',')) {
      final details = query.split(',').skip(1).join(',').trim();
      final exactCityExists = _intercityPoints.any(
        (item) => _normalizeRouteKey(item) == _normalizeRouteKey(cityPart),
      );
      if (exactCityExists && details.isNotEmpty) {
        return [];
      }
    }

    final list = _intercityPoints.toList()..sort((a, b) => a.compareTo(b));
    if (q.isEmpty) return list;
    return list.where((item) => _normalizeRouteKey(item).contains(q)).toList();
  }

  List<String> _getIntercityToSuggestions(String query) {
    final selectedFrom = _extractCityFromAddress(_fromController.text);
    final q = _normalizeRouteKey(query);
    final options = <String>{};
    if (selectedFrom.isNotEmpty) {
      final fromNorm = _normalizeRouteKey(selectedFrom);
      for (final route in _intercityRoutes) {
        final ot = route.ot.trim();
        final kuda = route.kuda.trim();
        if (ot.isEmpty || kuda.isEmpty) continue;
        final otNorm = _normalizeRouteKey(ot);
        final kudaNorm = _normalizeRouteKey(kuda);
        if (otNorm == fromNorm) {
          options.add(kuda);
        } else if (kudaNorm == fromNorm) {
          options.add(ot);
        }
      }
    } else {
      for (final route in _intercityRoutes) {
        final kuda = route.kuda.trim();
        if (kuda.isNotEmpty) {
          options.add(kuda);
        }
      }
    }
    final list = options.toList()..sort((a, b) => a.compareTo(b));
    if (q.isEmpty) return list;
    return list.where((item) => _normalizeRouteKey(item).contains(q)).toList();
  }

  IntercityRoute? _findIntercityRoute(String fromCity, String to) {
    final toNorm = _normalizeRouteKey(to);
    if (toNorm.isEmpty) return null;
    final fromNorm = _normalizeRouteKey(fromCity);
    if (fromNorm.isNotEmpty) {
      for (final route in _intercityRoutes) {
        final ot = route.ot.trim();
        final kuda = route.kuda.trim();
        if (ot.isEmpty || kuda.isEmpty) continue;
        final otNorm = _normalizeRouteKey(ot);
        final kudaNorm = _normalizeRouteKey(kuda);
        if (otNorm == fromNorm && kudaNorm == toNorm) return route;
        if (kudaNorm == fromNorm && otNorm == toNorm) return route;
      }
    }
    for (final route in _intercityRoutes) {
      final kudaNorm = _normalizeRouteKey(route.kuda.trim());
      if (kudaNorm == toNorm) return route;
    }
    for (final route in _intercityRoutes) {
      final otNorm = _normalizeRouteKey(route.ot.trim());
      if (otNorm == toNorm) return route;
    }
    return null;
  }

  void _resolveIntercityRoute() {
    if (_serviceType != 'intercity') return;
    final to = _toController.text.trim();
    if (to.isEmpty) {
      _selectedIntercityRoute = null;
      widget.onIntercityPriceChanged?.call(null);
      return;
    }
    final fromCity = _extractCityFromAddress(_fromController.text);
    final toCity = _intercityToCityFromInput(to);
    final route = _findIntercityRoute(fromCity, toCity);
    _selectedIntercityRoute = route;
    final price = (route != null && route.price > 0) ? route.price : null;
    widget.onIntercityPriceChanged?.call(price);
    _syncIntercityMapRoute();
  }

  Future<void> _syncIntercityMapRoute() async {
    if (_serviceType != 'intercity') return;
    if (_fromLocation == null || _selectedIntercityRoute == null) return;
    final toCity = _intercityToCityFromInput(_toController.text);
    if (toCity.isEmpty) return;

    latlng.LatLng? target = _toLocation;
    final currentToNorm =
        _normalizeRouteKey(_extractCityFromAddress(_toController.text));
    final targetNorm = _normalizeRouteKey(toCity);
    final markerNorm = _normalizeRouteKey(_selectedIntercityToCity);
    final markerMatches = markerNorm.isNotEmpty && markerNorm == targetNorm;
    final typedMatches =
        currentToNorm.isNotEmpty && currentToNorm == targetNorm;
    if (target == null || (!typedMatches && !markerMatches)) {
      target = await _forwardGeocode(
        toCity,
        updateController: false,
        preferredCity: toCity,
      );
      if (!mounted) return;
      if (target == null) return;
      setState(() {
        _toLocation = target;
      });
      widget.onToCoordsChanged?.call(target);
    }

    await _fetchRoute(_fromLocation!, target);
  }

  Future<void> _openIntercityToOptions() async {
    if (_serviceType != 'intercity') return;
    if (!mounted) return;
    setState(() {
      _activeField = 'to';
    });
    if (!_intercityLoaded) {
      await _loadIntercityRoutes();
    }
    if (!mounted) return;
    final items = _getIntercityToSuggestions(_toController.text);
    setState(() {
      _toSuggestions = items;
    });
    if (items.isEmpty) {
      final fromCity = _extractCityFromAddress(_fromController.text);
      if (fromCity.isNotEmpty && !_hasIntercityRoutesForCity(fromCity)) {
        _notifyNoRoutesFromCurrentCity(force: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr('Маршруты межгород не найдены',
                  'Қалааралық маршруттар табылмады'),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _validateIntercityDestination() {
    if (_serviceType != 'intercity') return;
    final current = _toController.text.trim();
    if (current.isEmpty) return;
    final options = _getIntercityToSuggestions('');
    final currentNorm = _normalizeRouteKey(_intercityToCityFromInput(current));
    final allowed =
        options.any((item) => _normalizeRouteKey(item) == currentNorm);
    if (!allowed) {
      setState(() {
        _toController.clear();
        _toLocation = null;
        _selectedIntercityToCity = '';
        _routePoints = [];
        _routeDistance = 0.0;
        _routeDuration = 0;
      });
      widget.onToAddressChanged?.call('');
      _selectedIntercityRoute = null;
      widget.onIntercityPriceChanged?.call(null);
    }
  }

  Future<void> _selectIntercityDestination(String value) async {
    if (!mounted) return;
    setState(() {
      _selectedIntercityToCity = value;
      _toController.text = value;
      _toSuggestions = [];
      _activeField = _nextFieldAfterToSelection();
      _toLocation = null;
    });
    widget.onToAddressChanged?.call(value);
    _unfocusAddressFields();
    _resolveIntercityRoute();
    await _syncIntercityMapRoute();
  }

  Future<void> _fetchRoute(latlng.LatLng from, latlng.LatLng to) async {
    if (!widget.enableRemoteGeocoding) return;
    if (from == to) {
      if (!mounted) return;
      setState(() {
        _routePoints = [];
        _routeDistance = 0.0;
        _routeDuration = 0;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isRouteLoading = true;
    });

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
        final routePoints = coordinates.map<latlng.LatLng>((coord) {
          return latlng.LatLng(
            (coord[1] as num).toDouble(),
            (coord[0] as num).toDouble(),
          );
        }).toList();
        final distance =
            double.tryParse(response['distanceKm']?.toString() ?? '') ?? 0;
        final duration =
            int.tryParse(response['durationMinutes']?.toString() ?? '') ?? 0;

        if (!mounted) return;
        setState(() {
          _routePoints = routePoints;
          _routeDistance = distance;
          _routeDuration = duration;
        });
        widget.onDistanceChanged?.call(distance);

        _centerMapOnRoute(routePoints);
      } else {
        debugPrint('Ошибка получения маршрута: ${response['error']}');
        if (!mounted) return;
        setState(() {
          _routePoints = [];
          _routeDistance = 0.0;
          _routeDuration = 0;
        });
      }
    } catch (e) {
      debugPrint('Ошибка получения маршрута: $e');
      if (!mounted) return;
      setState(() {
        _routePoints = [];
        _routeDistance = 0.0;
        _routeDuration = 0;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isRouteLoading = false;
      });
    }
  }

  void _centerMapOnRoute(List<latlng.LatLng> routePoints) {
    if (routePoints.isEmpty) return;

    double minLat = routePoints.first.latitude;
    double maxLat = routePoints.first.latitude;
    double minLng = routePoints.first.longitude;
    double maxLng = routePoints.first.longitude;

    for (final point in routePoints) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final center = latlng.LatLng(centerLat, centerLng);

    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    double zoom = 14.0;

    if (latDiff > 0.5 || lngDiff > 0.5) zoom = 12.0;
    if (latDiff > 1.0 || lngDiff > 1.0) zoom = 10.0;
    if (latDiff > 2.0 || lngDiff > 2.0) zoom = 8.0;
    if (latDiff > 5.0 || lngDiff > 5.0) zoom = 6.0;
    if (latDiff > 10.0 || lngDiff > 10.0) zoom = 4.0;
    if (latDiff > 20.0 || lngDiff > 20.0) zoom = 2.0;
    if (latDiff > 40.0 || lngDiff > 40.0) zoom = 1.0;

    _mapController.move(center, zoom);
    setState(() {
      _currentZoom = zoom;
    });
  }

  void _unfocusAddressFields() {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _handleMapTap(latlng.LatLng coords) async {
    if (!mounted) return;
    final tappedField = _activeField;
    if (_serviceType == 'intercity' && tappedField == 'to') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Пункт "Куда" выбирается из списка маршрутов',
              '"Қайда" тармағы маршруттар тізімінен таңдалады',
            ),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      if (tappedField == 'from') {
        setState(() {
          _fromLocation = coords;
          _activeField = 'to';
        });

        widget.onFromCoordsChanged?.call(coords);
        _unfocusAddressFields();
        if (_serviceType == 'intercity') {
          _notifyNoRoutesFromCurrentCity(force: true);
          _resolveIntercityRoute();
        }

        _mapController.move(coords, _currentZoom);
      } else if (tappedField == 'to') {
        setState(() {
          _toLocation = coords;
          _activeField = _nextFieldAfterToSelection();
        });

        widget.onToCoordsChanged?.call(coords);
        _unfocusAddressFields();
      }

      if (widget.enableRemoteGeocoding) {
        final resolvedAddress = await _reverseGeocode(coords);
        if (!mounted) return;
        if (tappedField == 'from' &&
            _fromLocation?.latitude == coords.latitude &&
            _fromLocation?.longitude == coords.longitude) {
          final fromAddress = _serviceType == 'intercity'
              ? _formatIntercityFromAddress(resolvedAddress)
              : resolvedAddress;
          setState(() {
            _fromController.text = fromAddress;
          });
          widget.onFromAddressChanged?.call(fromAddress);
        } else if (tappedField == 'to' &&
            _toLocation?.latitude == coords.latitude &&
            _toLocation?.longitude == coords.longitude) {
          setState(() {
            _toController.text = resolvedAddress;
          });
          widget.onToAddressChanged?.call(resolvedAddress);
        }
      }

      if (_fromLocation != null && _toLocation != null) {
        unawaited(_fetchRoute(_fromLocation!, _toLocation!));
      }
    } catch (e) {
      debugPrint('Ошибка: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_tr('Ошибка', 'Қате')}: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchAddress(String address, String field) async {
    if (address.isEmpty) return;
    if (_serviceType == 'intercity' && field == 'to') return;
    final searchVersion = _nextSearchVersion(field);

    if (_serviceType == 'intercity' && field == 'from') {
      final fromCity = _extractCityFromAddress(address);
      if (!_isDetailedAddressInCity(address, fromCity)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                'Для межгорода в "Откуда" укажите полный адрес',
                'Қалааралық бағыт үшін "Қайдан" өрісіне толық мекенжайды көрсетіңіз',
              ),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      if (!_hasIntercityRoutesForCity(fromCity)) {
        if (!mounted) return;
        _notifyNoRoutesFromCurrentCity(force: true);
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final coords = await _forwardGeocode(
        address,
        forceCity: _serviceType == 'intercity' && field == 'from',
        preferredCity: _serviceType == 'intercity' && field == 'from'
            ? _extractCityFromAddress(address)
            : null,
        targetField: field,
      );
      if (!mounted) return;
      if (!_isCurrentSearchVersion(field, searchVersion)) {
        return;
      }

      if (coords != null) {
        if (field == 'from') {
          setState(() {
            _fromLocation = coords;
            _activeField = 'to';
          });
          widget.onFromCoordsChanged?.call(coords);
        } else if (field == 'to') {
          setState(() {
            _toLocation = coords;
            _activeField = _nextFieldAfterToSelection();
          });
          widget.onToCoordsChanged?.call(coords);
        }

        _mapController.move(coords, 14);
        setState(() {
          _currentZoom = 14;
        });

        if (_fromLocation != null && _toLocation != null) {
          await _fetchRoute(_fromLocation!, _toLocation!);
        }
        _unfocusAddressFields();
      } else {
        if (!mounted) return;
        if (!_isCurrentSearchVersion(field, searchVersion)) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr('Адрес сохранен как текст',
                  'Мекенжай мәтін ретінде сақталды'),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
        _unfocusAddressFields();
      }
      if (_serviceType == 'intercity') {
        if (field == 'from') {
          _notifyNoRoutesFromCurrentCity(force: true);
        }
        _resolveIntercityRoute();
      }
    } catch (e) {
      debugPrint('Ошибка поиска: $e');
      if (!mounted) return;
      if (!_isCurrentSearchVersion(field, searchVersion)) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('Ошибка поиска адреса', 'Мекенжайды іздеу қатесі'),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearRoute() {
    setState(() {
      _routePoints = [];
      _routeDistance = 0.0;
      _routeDuration = 0;
    });
  }

  void _clearToField() {
    setState(() {
      _toLocation = null;
      _toController.clear();
      _selectedIntercityToCity = '';
      _routePoints = [];
      _routeDistance = 0.0;
      _routeDuration = 0;
    });

    if (widget.onToAddressChanged != null) {
      widget.onToAddressChanged!('');
    }
  }

  void _clearFromField() {
    setState(() {
      _fromLocation = null;
      _fromController.clear();
      _lastNoRoutesFromCityKey = '';
      _routePoints = [];
      _routeDistance = 0.0;
      _routeDuration = 0;
    });

    if (widget.onFromAddressChanged != null) {
      widget.onFromAddressChanged!('');
    }
  }

  void _changeServiceType(String type) {
    if (type == 'intercity' && !widget.intercityEnabled) return;
    setState(() {
      _serviceType = type;
      if (type != 'intercity') {
        _selectedIntercityToCity = '';
        _lastNoRoutesFromCityKey = '';
      }
    });
    if (type == 'intercity' && !_intercityLoaded) {
      _loadIntercityRoutes();
    }
    if (type == 'intercity') {
      _applyIntercityFromAddressFormat();
      if (widget.enableAutoLocation &&
          _fromLocation == null &&
          _fromController.text.trim().isEmpty) {
        _getUserLocation();
      }
      if (_intercityLoaded) {
        _validateIntercityDestination();
        _resolveIntercityRoute();
        _notifyNoRoutesFromCurrentCity(force: true);
      }
    }

    if (widget.onServiceTypeChanged != null) {
      widget.onServiceTypeChanged!(type);
    }
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(0.5, 18.0);
    });
    _mapController.move(_mapController.center, _currentZoom);
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(0.5, 18.0);
    });
    _mapController.move(_mapController.center, _currentZoom);
  }

  void _returnToWorldView() {
    _mapController.move(_userLocation ?? _fromLocation ?? _defaultCenter, 13.0);
    if (!mounted) return;
    setState(() {
      _currentZoom = 13.0;
    });
  }

  void _goToRandomLocation() {
    final random = Random();
    final lat = (random.nextDouble() * 160) - 80; // от -80 до 80
    final lng = (random.nextDouble() * 360) - 180; // от -180 до 180
    final randomLocation = latlng.LatLng(lat, lng);

    _mapController.move(randomLocation, 10);
    if (!mounted) return;
    setState(() {
      _currentZoom = 10;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr('Переход к случайной точке мира', 'Кездейсоқ әлем нүктесіне өту'),
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getTaxiColor() {
    return _serviceType == 'taxi'
        ? const Color(0xFF28D8C6)
        : const Color(0xFF9AA3AF);
  }

  Color _getDeliveryColor() {
    return _serviceType == 'delivery'
        ? const Color(0xFF28D8C6)
        : const Color(0xFF9AA3AF);
  }

  Color _getIntercityColor() {
    return _serviceType == 'intercity'
        ? const Color(0xFF28D8C6)
        : const Color(0xFF9AA3AF);
  }

  String _formatShortAddress(Map<String, dynamic>? address) {
    if (address == null) return '';
    final town = address['town'] ??
        address['village'] ??
        address['city'] ??
        address['hamlet'] ??
        address['municipality'] ??
        address['suburb'] ??
        address['neighbourhood'] ??
        '';
    final road = address['road'] ??
        address['pedestrian'] ??
        address['footway'] ??
        address['path'] ??
        address['residential'] ??
        '';
    final house = address['house_number'] ?? '';
    final streetAndHouse = [
      if (road.toString().isNotEmpty) road.toString(),
      if (house.toString().isNotEmpty) house.toString(),
    ].join(' ');
    final parts = [
      if (streetAndHouse.isNotEmpty) streetAndHouse,
      if (town.toString().isNotEmpty) town.toString(),
    ];
    return parts.join(', ').trim();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the existing, administratively gated intercity flow intact.
    if (_serviceType == 'intercity') return _buildLegacy(context);
    final suggestions =
        _activeField == 'from' ? _fromSuggestions : _toSuggestions;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final scheme = Theme.of(context).colorScheme;
    Widget map = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _fromLocation ?? _defaultCenter,
        initialZoom: _currentZoom,
        minZoom: 5,
        maxZoom: 18,
        interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        onTap: (_, point) => _handleMapTap(point),
      ),
      children: [
        if (widget.enableTileLayer)
          TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.mtaxi.app',
              maxZoom: 19),
        if (_routePoints.isNotEmpty)
          PolylineLayer(polylines: [
            Polyline(
                points: _routePoints, color: MTaxiDesign.teal, strokeWidth: 5)
          ]),
        MarkerLayer(markers: [
          if (_userLocation != null)
            Marker(
                point: _userLocation!,
                width: 36,
                height: 36,
                child: const Icon(Icons.my_location, color: MTaxiDesign.teal)),
          if (_fromLocation != null)
            Marker(
                point: _fromLocation!,
                width: 44,
                height: 44,
                child: const Icon(Icons.location_on,
                    color: MTaxiDesign.ink, size: 40)),
          if (_toLocation != null)
            Marker(
                point: _toLocation!,
                width: 44,
                height: 44,
                child: const Icon(Icons.location_on,
                    color: MTaxiDesign.teal, size: 40)),
        ]),
        const MTaxiMapAttribution(),
      ],
    );
    if (widget.enableTestMapTap)
      map = GestureDetector(
          key: const ValueKey('test_map_tap'),
          onTapDown: (_) =>
              _handleMapTap(widget.testMapTapPoint ?? _defaultCenter),
          child: map);
    return Column(children: [
      if (!keyboard)
        Expanded(
            child: Stack(children: [
          Positioned.fill(child: map),
          const Positioned(top: 30, left: 22, child: MTaxiBrand()),
          if (_isLoading || _isRouteLoading)
            const Positioned(
                top: 90, left: 22, right: 22, child: LinearProgressIndicator()),
          if (_editorOpen)
            Positioned(
                bottom: 12,
                left: 22,
                right: 22,
                child: MTaxiCard(
                    padding: const EdgeInsets.all(12),
                    child: Text(_activeField == 'from'
                        ? _tr('Выберите место посадки на карте',
                            'Картадан отыру орнын таңдаңыз')
                        : _tr('Выберите пункт назначения на карте',
                            'Картадан баратын жерді таңдаңыз')))),
        ])),
      Flexible(
          flex: keyboard ? 1 : 0,
          child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height *
                      (keyboard ? .75 : .55)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(_tr('Куда поедем?', 'Қайда барамыз?'),
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700))),
                        if (_editorOpen)
                          IconButton(
                              tooltip: _tr('Готово', 'Дайын'),
                              onPressed: () {
                                _unfocusAddressFields();
                                setState(() => _editorOpen = false);
                              },
                              icon: const Icon(Icons.check))
                      ]),
                      const SizedBox(height: 12),
                      ServiceTypeCards(
                        value: _serviceType,
                        onChanged: _changeServiceType,
                        taxiLabel: _tr('Такси', 'Такси'),
                        deliveryLabel: _tr('Доставка', 'Жеткізу'),
                        taxiDescription:
                            _tr('Поездки по посёлку', 'Ауыл ішіндегі сапарлар'),
                        deliveryDescription: _tr('Посылки и покупки',
                            'Сәлемдемелер мен сатып алулар'),
                      ),
                      if (widget.intercityEnabled)
                        Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _changeServiceType('intercity'),
                              icon: const Icon(Icons.alt_route),
                              label: Text(_tr('Межгород', 'Қалааралық')),
                            )),
                      const SizedBox(height: 10),
                      Container(
                        key: const ValueKey('passenger_route_fields'),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? scheme.surface
                              : MTaxiDesign.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color:
                                  scheme.outlineVariant.withValues(alpha: .45)),
                        ),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          TextField(
                              controller: _fromController,
                              decoration: InputDecoration(
                                  labelText: _tr('Откуда', 'Қайдан'),
                                  hintText: _tr(
                                      'Адрес отправления', 'Жөнелту мекенжайы'),
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.always,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  prefixIconConstraints: const BoxConstraints(
                                      minWidth: 40, minHeight: 40),
                                  suffixIconConstraints: const BoxConstraints(
                                      minWidth: 40, minHeight: 40),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  prefixIcon:
                                      const Icon(Icons.radio_button_checked),
                                  suffixIcon: IconButton(
                                      tooltip:
                                          _tr('Найти адрес', 'Мекенжайды табу'),
                                      icon: const Icon(Icons.search),
                                      onPressed: () {
                                        setState(() {
                                          _editorOpen = true;
                                          _activeField = 'from';
                                        });
                                        _searchAddress(
                                            _fromController.text, 'from');
                                      })),
                              onTap: () => setState(() {
                                    _editorOpen = true;
                                    _activeField = 'from';
                                  }),
                              onChanged: _onFromChanged,
                              onSubmitted: (value) =>
                                  _searchAddress(value, 'from')),
                          Divider(
                              height: 1,
                              indent: 48,
                              endIndent: 16,
                              color: scheme.outlineVariant),
                          TextField(
                              controller: _toController,
                              decoration: InputDecoration(
                                  labelText: _tr('Куда', 'Қайда'),
                                  hintText: _tr(
                                      'Адрес назначения', 'Баратын мекенжай'),
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.always,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  prefixIconConstraints: const BoxConstraints(
                                      minWidth: 40, minHeight: 40),
                                  suffixIconConstraints: const BoxConstraints(
                                      minWidth: 40, minHeight: 40),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  prefixIcon:
                                      const Icon(Icons.location_on_outlined),
                                  suffixIcon: IconButton(
                                      tooltip:
                                          _tr('Найти адрес', 'Мекенжайды табу'),
                                      icon: const Icon(Icons.search),
                                      onPressed: () {
                                        setState(() {
                                          _editorOpen = true;
                                          _activeField = 'to';
                                        });
                                        _searchAddress(
                                            _toController.text, 'to');
                                      })),
                              onTap: () => setState(() {
                                    _editorOpen = true;
                                    _activeField = 'to';
                                  }),
                              onChanged: _onToChanged,
                              onSubmitted: (value) =>
                                  _searchAddress(value, 'to')),
                        ]),
                      ),
                      if (_editorOpen) ...[
                        if (suggestions.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          for (final item in suggestions)
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.location_on_outlined),
                                title: Text(item),
                                onTap: () => _selectAddressSuggestion(
                                    _activeField, item))
                        ],
                        const SizedBox(height: 10),
                        TextField(
                            controller: _serviceType == 'delivery'
                                ? _deliveryItemController
                                : _commentController,
                            decoration: InputDecoration(
                                labelText: _serviceType == 'delivery'
                                    ? _tr('Что доставить?', 'Не жеткізу керек?')
                                    : _tr('Комментарий водителю',
                                        'Жүргізушіге түсініктеме')),
                            onChanged: (value) {
                              if (_serviceType == 'delivery') {
                                widget.onDeliveryItemChanged?.call(value);
                              } else {
                                widget.onCommentChanged?.call(value);
                              }
                            }),
                      ],
                      if (_editorOpen && _fromLocation != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: FilledButton(
                                onPressed: () {
                                  _unfocusAddressFields();
                                  setState(() {
                                    _editorOpen = false;
                                    _activeField = 'to';
                                  });
                                },
                                child: Text(_tr('Забрать отсюда',
                                    'Осы жерден алып кету')))),
                    ]),
              ))),
    ]);
  }

  Widget _buildLegacy(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final suggestionMaxHeight = keyboardInset > 0 ? 260.0 : 220.0;
    final compactMapHeight = _serviceType == 'intercity' ? 180.0 : 220.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFEFF2F6);
    final shellBg = pageBg;
    final darkSurface =
        isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    const mintColor = Color(0xFF28D8C6);
    final fieldText = isDark ? Colors.white : const Color(0xFF17111D);
    final fieldMuted =
        isDark ? const Color(0xFF9EA8B0) : const Color(0xFF8A8392);
    final fieldBorder =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8EDF1);
    final overlaySurface =
        isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final overlayText = isDark ? Colors.white : const Color(0xFF17111D);
    final mapControlBg =
        isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final mapControlFg = isDark ? Colors.white : const Color(0xFF17111D);
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 600,
      child: Column(
        children: [
          const SizedBox.shrink(),
          // Панель выбора типа услуги
          Container(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            color: shellBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox.shrink(),
                Row(children: [
                  // Иконка такси
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _changeServiceType('taxi'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: darkSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _serviceType == 'taxi'
                                ? mintColor
                                : fieldBorder,
                            width: _serviceType == 'taxi' ? 1.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.local_taxi,
                                  color: _serviceType == 'taxi'
                                      ? mintColor
                                      : _getTaxiColor(),
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _tr('Такси', 'Такси'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _serviceType == 'taxi'
                                        ? mintColor
                                        : _getTaxiColor(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Иконка доставки
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _changeServiceType('delivery'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _serviceType == 'delivery'
                              ? darkSurface
                              : darkSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _serviceType == 'delivery'
                                ? mintColor
                                : fieldBorder,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.work_outline,
                                  color: _serviceType == 'delivery'
                                      ? mintColor
                                      : _getDeliveryColor(),
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _tr('Доставка', 'Жеткізу'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _serviceType == 'delivery'
                                        ? mintColor
                                        : _getDeliveryColor(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.intercityEnabled) const SizedBox(width: 8),
                  // Межгород
                  if (widget.intercityEnabled)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _changeServiceType('intercity'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _serviceType == 'intercity'
                                ? darkSurface
                                : darkSurface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _serviceType == 'intercity'
                                  ? mintColor
                                  : fieldBorder,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.alt_route,
                                    color: _serviceType == 'intercity'
                                        ? mintColor
                                        : _getIntercityColor(),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _tr('Межгород', 'Қалааралық'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _serviceType == 'intercity'
                                          ? mintColor
                                          : _getIntercityColor(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
              ],
            ),
          ),

          // Поля ввода адресов
          Container(
            padding: const EdgeInsets.all(12),
            color: shellBg,
            child: Column(
              children: [
                // Поле "Откуда"
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    setState(() {
                      _activeField = 'from';
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: darkSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _activeField == 'from' ? mintColor : fieldBorder,
                        width: _activeField == 'from' ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _activeField = 'from';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              Icons.circle,
                              color: _activeField == 'from'
                                  ? mintColor
                                  : fieldMuted,
                              size: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _fromController,
                            style: TextStyle(color: fieldText),
                            readOnly: false,
                            decoration: InputDecoration(
                              hintText: _tr('Откуда', 'Қайдан'),
                              hintStyle: TextStyle(
                                color: fieldMuted,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _activeField = 'from';
                              });
                              if (_serviceType == 'intercity') {
                                _onFromChanged(_fromController.text);
                              }
                            },
                            onChanged: (value) {
                              _onFromChanged(value);
                            },
                            onSubmitted: (value) {
                              setState(() {
                                _activeField = 'from';
                              });
                              _searchAddress(value, 'from');
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search, color: mintColor),
                          onPressed: () {
                            setState(() {
                              _activeField = 'from';
                            });
                            _searchAddress(_fromController.text, 'from');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (_fromSuggestions.isNotEmpty && _activeField == 'from')
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: overlaySurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: fieldBorder),
                    ),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(maxHeight: suggestionMaxHeight),
                      child: ListView.builder(
                        shrinkWrap: true,
                        primary: false,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.manual,
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: _fromSuggestions.length,
                        itemBuilder: (context, index) {
                          final item = _fromSuggestions[index];
                          return Material(
                            color: overlaySurface,
                            child: ListTile(
                              dense: true,
                              title: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: overlayText,
                                ),
                              ),
                              onTap: () {
                                if (_serviceType == 'intercity') {
                                  setState(() {
                                    _fromController.text = '$item, ';
                                    _fromLocation = null;
                                    _fromSuggestions = [];
                                    _activeField = 'to';
                                  });
                                  _fromController.selection =
                                      TextSelection.collapsed(
                                    offset: _fromController.text.length,
                                  );
                                  widget.onFromAddressChanged
                                      ?.call(_fromController.text);
                                  _unfocusAddressFields();
                                  _validateIntercityDestination();
                                  _resolveIntercityRoute();
                                  unawaited(_openIntercityToOptions());
                                } else {
                                  _selectAddressSuggestion('from', item);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                // Поле "Куда"
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (_serviceType == 'intercity') {
                      _openIntercityToOptions();
                      return;
                    }
                    setState(() {
                      _activeField = 'to';
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: darkSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _activeField == 'to' ? mintColor : fieldBorder,
                        width: _activeField == 'to' ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _activeField = 'to';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              Icons.location_on,
                              color:
                                  _activeField == 'to' ? mintColor : fieldMuted,
                              size: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _toController,
                            style: TextStyle(color: fieldText),
                            readOnly: false,
                            decoration: InputDecoration(
                              hintText: _serviceType == 'intercity'
                                  ? _tr(
                                      'Куда (выбор маршрута)',
                                      'Қайда (маршрут таңдау)',
                                    )
                                  : _tr('Куда', 'Қайда'),
                              hintStyle: TextStyle(
                                color: fieldMuted,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                            onTap: () {
                              if (_serviceType == 'intercity') {
                                _openIntercityToOptions();
                              } else {
                                setState(() {
                                  _activeField = 'to';
                                });
                              }
                            },
                            onChanged: (value) {
                              if (_serviceType == 'intercity' && mounted) {
                                setState(() {});
                              }
                              _onToChanged(value);
                            },
                            onSubmitted: (value) {
                              if (_serviceType != 'intercity') {
                                setState(() {
                                  _activeField = 'to';
                                });
                                _searchAddress(value, 'to');
                              }
                            },
                          ),
                        ),
                        if (_serviceType == 'intercity' &&
                            _toController.text.trim().isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _toController.clear();
                                _toSuggestions = [];
                                _toLocation = null;
                                _selectedIntercityToCity = '';
                                _selectedIntercityRoute = null;
                                _routePoints = [];
                                _routeDistance = 0.0;
                                _routeDuration = 0;
                                _activeField = 'to';
                              });
                              widget.onToAddressChanged?.call('');
                              widget.onIntercityPriceChanged?.call(null);
                            },
                          ),
                        IconButton(
                          icon: Icon(
                            _serviceType == 'intercity'
                                ? Icons.arrow_drop_down
                                : Icons.search,
                            color: mintColor,
                          ),
                          onPressed: _serviceType == 'intercity'
                              ? _openIntercityToOptions
                              : () {
                                  setState(() {
                                    _activeField = 'to';
                                  });
                                  _searchAddress(_toController.text, 'to');
                                },
                        ),
                      ],
                    ),
                  ),
                ),
                if (_toSuggestions.isNotEmpty && _activeField == 'to')
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: overlaySurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: fieldBorder),
                    ),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(maxHeight: suggestionMaxHeight),
                      child: ListView.builder(
                        shrinkWrap: true,
                        primary: false,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.manual,
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: _toSuggestions.length,
                        itemBuilder: (context, index) {
                          final item = _toSuggestions[index];
                          return Material(
                            color: overlaySurface,
                            child: ListTile(
                              dense: true,
                              title: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: overlayText,
                                ),
                              ),
                              onTap: () {
                                if (_serviceType == 'intercity') {
                                  _selectIntercityDestination(item);
                                } else {
                                  _selectAddressSuggestion('to', item);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: darkSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: fieldBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 7, 12, 2),
                        child: Text(
                          _serviceType == 'delivery'
                              ? _tr('Что доставить', 'Не жеткізу керек')
                              : _tr(
                                  'Комментарий для водителя',
                                  'Жүргізушіге түсініктеме',
                                ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: fieldMuted,
                          ),
                        ),
                      ),
                      TextField(
                        controller: _serviceType == 'delivery'
                            ? _deliveryItemController
                            : _commentController,
                        style: TextStyle(color: fieldText),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: _serviceType == 'delivery'
                              ? _tr(
                                  'Например: документы, еда, посылка',
                                  'Мысалы: құжаттар, тамақ, сәлемдеме',
                                )
                              : _tr(
                                  'Например: подъехать с заднего входа',
                                  'Мысалы: артқы кіреберіске келіңіз',
                                ),
                          hintStyle: TextStyle(
                            color: fieldMuted,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            8,
                          ),
                        ),
                        minLines: 1,
                        maxLines: 1,
                        onChanged: (value) {
                          if (_serviceType != 'delivery' &&
                              widget.onCommentChanged != null) {
                            widget.onCommentChanged!(value);
                          } else if (_serviceType == 'delivery' &&
                              widget.onDeliveryItemChanged != null) {
                            widget.onDeliveryItemChanged!(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Карта
          (keyboardInset > 0
              ? SizedBox(
                  height: compactMapHeight,
                  child: Stack(
                    children: [
                      // Основная карта
                      Builder(
                        builder: (context) {
                          Widget map = FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _defaultCenter,
                              initialZoom: _currentZoom,
                              minZoom: 5,
                              maxZoom: 18,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all &
                                    ~InteractiveFlag.rotate,
                              ),
                              onTap: (tapPosition, point) {
                                _handleMapTap(point);
                              },
                              onMapReady: () {
                                _mapController.mapEventStream.listen((event) {
                                  if (event is MapEventMoveEnd) {
                                    setState(() {
                                      _currentZoom = _mapController.zoom;
                                    });
                                  }
                                });
                              },
                            ),
                            children: [
                              if (widget.enableTileLayer)
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  tileSize: 256,
                                  maxZoom: 19,
                                  userAgentPackageName: 'com.mtaxi.app',
                                ),
                              if (_routePoints.isNotEmpty)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: _routePoints,
                                      color: Colors.blue.withOpacity(0.8),
                                      strokeWidth: 4,
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  if (_userLocation != null)
                                    Marker(
                                      point: _userLocation!,
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.person_pin_circle,
                                        color: Colors.blue,
                                        size: 40,
                                      ),
                                    ),
                                  if (_fromLocation != null)
                                    Marker(
                                      point: _fromLocation!,
                                      width: 40,
                                      height: 40,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.circle,
                                          color: Colors.green,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                  if (_toLocation != null)
                                    Marker(
                                      point: _toLocation!,
                                      width: 40,
                                      height: 40,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.red,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          );

                          if (widget.enableTestMapTap) {
                            map = GestureDetector(
                              key: const ValueKey('test_map_tap'),
                              behavior: HitTestBehavior.translucent,
                              onTapDown: (_) {
                                final tapPoint =
                                    widget.testMapTapPoint ?? _defaultCenter;
                                _handleMapTap(tapPoint);
                              },
                              child: map,
                            );
                          }

                          return map;
                        },
                      ),
                      if (_isLoading || _isRouteLoading)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.3),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : Expanded(
                  child: Stack(
                    children: [
                      // Основная карта
                      Builder(
                        builder: (context) {
                          Widget map = FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _defaultCenter,
                              initialZoom: _currentZoom,
                              minZoom: 5,
                              maxZoom: 18,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all &
                                    ~InteractiveFlag.rotate,
                              ),
                              onTap: (tapPosition, point) {
                                _handleMapTap(point);
                              },
                              onMapReady: () {
                                _mapController.mapEventStream.listen((event) {
                                  if (event is MapEventMoveEnd) {
                                    setState(() {
                                      _currentZoom = _mapController.zoom;
                                    });
                                  }
                                });
                              },
                            ),
                            children: [
                              // OpenStreetMap слой - ВЕСЬ МИР
                              if (widget.enableTileLayer)
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  tileSize: 256,
                                  maxZoom: 19,
                                  userAgentPackageName: 'com.mtaxi.app',
                                ),

                              // Маршрут
                              if (_routePoints.isNotEmpty)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: _routePoints,
                                      color: Colors.blue.withOpacity(0.8),
                                      strokeWidth: 4,
                                    ),
                                  ],
                                ),

                              // Маркеры
                              MarkerLayer(
                                markers: [
                                  // Местоположение пользователя
                                  if (_userLocation != null)
                                    Marker(
                                      point: _userLocation!,
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.person_pin_circle,
                                        color: Colors.blue,
                                        size: 40,
                                      ),
                                    ),
                                  // Точка "Откуда"
                                  if (_fromLocation != null)
                                    Marker(
                                      point: _fromLocation!,
                                      width: 40,
                                      height: 40,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.circle,
                                          color: Colors.green,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                  // Точка "Куда"
                                  if (_toLocation != null)
                                    Marker(
                                      point: _toLocation!,
                                      width: 40,
                                      height: 40,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.location_on,
                                          color: Colors.red,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          );

                          if (widget.enableTestMapTap) {
                            map = GestureDetector(
                              key: const ValueKey('test_map_tap'),
                              behavior: HitTestBehavior.translucent,
                              onTapDown: (_) {
                                final tapPoint =
                                    widget.testMapTapPoint ?? _defaultCenter;
                                _handleMapTap(tapPoint);
                              },
                              child: map,
                            );
                          }

                          return map;
                        },
                      ),

                      // Панель управления
                      Positioned(
                        right: 16,
                        top: 16,
                        child: Column(
                          children: [
                            // Увеличение масштаба
                            FloatingActionButton.small(
                              onPressed: _zoomIn,
                              heroTag: 'zoomIn',
                              child: const Icon(Icons.add),
                              backgroundColor: mapControlBg,
                              foregroundColor: mapControlFg,
                            ),
                            const SizedBox(height: 8),
                            // Уменьшение масштаба
                            FloatingActionButton.small(
                              onPressed: _zoomOut,
                              heroTag: 'zoomOut',
                              child: const Icon(Icons.remove),
                              backgroundColor: mapControlBg,
                              foregroundColor: mapControlFg,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),

                      // Индикатор загрузки
                      if (_isLoading || _isRouteLoading)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.3),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),

                      // Информация о маршруте
                      if (_routePoints.isNotEmpty && _routeDistance > 0)
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 80,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: overlaySurface.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _tr('Маршрут построен', 'Маршрут құрылды'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: mintColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (_serviceType != 'intercity')
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _tr('Расстояние:', 'Қашықтық:'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: fieldMuted,
                                            ),
                                          ),
                                          Text(
                                            '${_routeDistance.toStringAsFixed(1)} км',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _tr('Время:', 'Уақыт:'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: fieldMuted,
                                            ),
                                          ),
                                          Text(
                                            '$_routeDuration ${_tr('мин', 'мин')}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                if (((widget.priceText ?? '').isNotEmpty) ||
                                    (_serviceType == 'intercity' &&
                                        (_selectedIntercityRoute?.price ?? 0) >
                                            0)) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_tr('Стоимость', 'Бағасы')}: ${_displayPriceText()}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: overlayText,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                      // Индикатор активного поля
                      if (!_isRouteLoading)
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: overlaySurface.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _activeField == 'from'
                                  ? _tr(
                                      'Выберите точку "Откуда" на карте',
                                      'Картадан "Қайдан" нүктесін таңдаңыз',
                                    )
                                  : _serviceType == 'intercity'
                                      ? _tr(
                                          'Выберите пункт "Куда" из списка',
                                          'Тізімнен "Қайда" тармағын таңдаңыз',
                                        )
                                      : _tr(
                                          'Выберите точку "Куда" на карте',
                                          'Картадан "Қайда" нүктесін таңдаңыз',
                                        ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: overlayText,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
