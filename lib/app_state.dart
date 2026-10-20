import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {
    prefs = await SharedPreferences.getInstance();
    _safeInit(() {
      _smsKod = prefs.getInt('ff_smsKod') ?? _smsKod;
    });
    _safeInit(() {
      _phone = prefs.getString('ff_phone') ?? _phone;
    });
    _safeInit(() {
      _type = prefs.getInt('ff_type') ?? _type;
    });
    _safeInit(() {
      _otkkudaString = prefs.getString('ff_otkkudaString') ?? _otkkudaString;
    });
    _safeInit(() {
      _otkudaCoord =
          latLngFromString(prefs.getString('ff_otkudaCoord')) ?? _otkudaCoord;
    });
    _safeInit(() {
      _kudaString = prefs.getString('ff_kudaString') ?? _kudaString;
    });
    _safeInit(() {
      _kudaCoords =
          latLngFromString(prefs.getString('ff_kudaCoords')) ?? _kudaCoords;
    });
    _safeInit(() {
      _price = prefs.getString('ff_price') ?? _price;
    });
    _safeInit(() {
      _tarif = prefs.getString('ff_tarif') ?? _tarif;
    });
    _safeInit(() {
      _comment = prefs.getString('ff_comment') ?? _comment;
    });
    _safeInit(() {
      _deliveryItem = prefs.getString('ff_deliveryItem') ?? _deliveryItem;
    });
    _safeInit(() {
      _CityCountry = prefs.getString('ff_CityCountry') ?? _CityCountry;
    });
    _safeInit(() {
      _sms = prefs.getString('ff_sms') ?? _sms;
    });
    _safeInit(() {
      final path = prefs.getString('ff_idOrder');
      if (path != null && !path.contains('dsfsgfdgdfgfd')) {
        _idOrder = path.ref;
      } else {
        _idOrder = null;
        prefs.remove('ff_idOrder');
      }
    });
    _safeInit(() {
      final path = prefs.getString('ff_idOrderDriver');
      if (path != null && !path.contains('ffgdfhjgsdhgksdgsfdkg')) {
        _idOrderDriver = path.ref;
      } else {
        _idOrderDriver = null;
        prefs.remove('ff_idOrderDriver');
      }
    });
    _safeInit(() {
      _soundEnabled = prefs.getBool('ff_soundEnabled') ?? _soundEnabled;
    });
    _safeInit(() {
      _serviceType = prefs.getString('ff_serviceType') ?? _serviceType;
    });
    _safeInit(() {
      _pendingRegistrationRole =
          prefs.getString('ff_pendingRegistrationRole') ??
              _pendingRegistrationRole;
    });
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  Future<void> clearPersistedState() async {
    await prefs.remove('ff_smsKod');
    await prefs.remove('ff_phone');
    await prefs.remove('ff_type');
    await prefs.remove('ff_otkkudaString');
    await prefs.remove('ff_otkudaCoord');
    await prefs.remove('ff_kudaString');
    await prefs.remove('ff_kudaCoords');
    await prefs.remove('ff_price');
    await prefs.remove('ff_tarif');
    await prefs.remove('ff_comment');
    await prefs.remove('ff_deliveryItem');
    await prefs.remove('ff_CityCountry');
    await prefs.remove('ff_sms');
    await prefs.remove('ff_idOrder');
    await prefs.remove('ff_idOrderDriver');
    await prefs.remove('ff_soundEnabled');
    await prefs.remove('ff_serviceType');
    await prefs.remove('ff_pendingRegistrationRole');

    _smsKod = 0;
    _phone = '';
    _type = 0;
    _otkkudaString = '';
    _otkudaCoord = LatLng(52.2475822, 76.9759095);
    _kudaString = '';
    _kudaCoords = null;
    _price = '';
    _tarif = '';
    _comment = '';
    _deliveryItem = '';
    _CityCountry = '';
    _sms = '';
    _idOrder = null;
    _idOrderDriver = null;
    _soundEnabled = true;
    _serviceType = 'taxi';
    _pendingRegistrationRole = '';
    _selectedAddress = '';
    _selectedCoordinates = '';
    _taxi = false;
    _delivery = false;

    notifyListeners();
  }

  Future<void> clearTransientAuthFlowState({
    bool notify = true,
  }) async {
    await prefs.remove('ff_smsKod');
    await prefs.remove('ff_phone');
    await prefs.remove('ff_sms');
    await prefs.remove('ff_pendingRegistrationRole');

    _smsKod = 0;
    _phone = '';
    _sms = '';
    _pendingRegistrationRole = '';

    if (notify) {
      notifyListeners();
    }
  }

  late SharedPreferences prefs;

  int _smsKod = 0;
  int get smsKod => _smsKod;
  set smsKod(int value) {
    _smsKod = value;
    prefs.setInt('ff_smsKod', value);
  }

  String _phone = '';
  String get phone => _phone;
  set phone(String value) {
    _phone = value;
    prefs.setString('ff_phone', value);
  }

  int _type = 0;
  int get type => _type;
  set type(int value) {
    _type = value;
    prefs.setInt('ff_type', value);
  }

  // Legacy field. Do not use as source of truth for role or mode.
  bool _driver = false;
  bool get driver => _driver;
  set driver(bool value) {
    _driver = value;
  }

  // Legacy field. Do not use as source of truth for role or mode.
  bool _passenger = false;
  bool get passenger => _passenger;
  set passenger(bool value) {
    _passenger = value;
  }

  String _otkkudaString = '';
  String get otkkudaString => _otkkudaString;
  set otkkudaString(String value) {
    _otkkudaString = value;
    prefs.setString('ff_otkkudaString', value);
  }

  LatLng? _otkudaCoord = LatLng(52.2475822, 76.9759095);
  LatLng? get otkudaCoord => _otkudaCoord;
  set otkudaCoord(LatLng? value) {
    _otkudaCoord = value;
    value != null
        ? prefs.setString('ff_otkudaCoord', value.serialize())
        : prefs.remove('ff_otkudaCoord');
  }

  String _kudaString = '';
  String get kudaString => _kudaString;
  set kudaString(String value) {
    _kudaString = value;
    prefs.setString('ff_kudaString', value);
  }

  LatLng? _kudaCoords;
  LatLng? get kudaCoords => _kudaCoords;
  set kudaCoords(LatLng? value) {
    _kudaCoords = value;
    value != null
        ? prefs.setString('ff_kudaCoords', value.serialize())
        : prefs.remove('ff_kudaCoords');
  }

  String _price = '';
  String get price => _price;
  set price(String value) {
    _price = value;
    prefs.setString('ff_price', value);
  }

  String _tarif = '';
  String get tarif => _tarif;
  set tarif(String value) {
    _tarif = value;
    prefs.setString('ff_tarif', value);
  }

  String _comment = '';
  String get comment => _comment;
  set comment(String value) {
    _comment = value;
    prefs.setString('ff_comment', value);
  }

  String _deliveryItem = '';
  String get deliveryItem => _deliveryItem;
  set deliveryItem(String value) {
    _deliveryItem = value;
    prefs.setString('ff_deliveryItem', value);
  }

  String _CityCountry = '';
  String get CityCountry => _CityCountry;
  set CityCountry(String value) {
    _CityCountry = value;
    prefs.setString('ff_CityCountry', value);
  }

  String _sms = '';
  String get sms => _sms;
  set sms(String value) {
    _sms = value;
    prefs.setString('ff_sms', value);
  }

  // Legacy passenger active-order mirror for older client flows.
  // Backend user document is the authoritative source.
  DocumentReference? _idOrder;
  DocumentReference? get idOrder => _idOrder;
  set idOrder(DocumentReference? value) {
    _idOrder = value;
    value != null
        ? prefs.setString('ff_idOrder', value.path)
        : prefs.remove('ff_idOrder');
  }

  // Legacy driver active-order mirror for older client flows.
  // Backend user document is the authoritative source.
  DocumentReference? _idOrderDriver;
  DocumentReference? get idOrderDriver => _idOrderDriver;
  set idOrderDriver(DocumentReference? value) {
    _idOrderDriver = value;
    value != null
        ? prefs.setString('ff_idOrderDriver', value.path)
        : prefs.remove('ff_idOrderDriver');
  }

  void syncLegacyOrderRefs({
    DocumentReference? passengerOrderRef,
    DocumentReference? driverOrderRef,
  }) {
    // Keep legacy local mirrors in sync with backend-authoritative user refs
    // during the rollout compatibility window.
    _idOrder = passengerOrderRef;
    _idOrderDriver = driverOrderRef;
    passengerOrderRef != null
        ? prefs.setString('ff_idOrder', passengerOrderRef.path)
        : prefs.remove('ff_idOrder');
    driverOrderRef != null
        ? prefs.setString('ff_idOrderDriver', driverOrderRef.path)
        : prefs.remove('ff_idOrderDriver');
  }

  void clearLegacyOrderRefs() {
    syncLegacyOrderRefs(
      passengerOrderRef: null,
      driverOrderRef: null,
    );
  }

  String _selectedAddress = '';
  String get selectedAddress => _selectedAddress;
  set selectedAddress(String value) {
    _selectedAddress = value;
  }

  String _selectedCoordinates = '';
  String get selectedCoordinates => _selectedCoordinates;
  set selectedCoordinates(String value) {
    _selectedCoordinates = value;
  }

  bool _taxi = false;
  bool get taxi => _taxi;
  set taxi(bool value) {
    _taxi = value;
  }

  bool _delivery = false;
  bool get delivery => _delivery;
  set delivery(bool value) {
    _delivery = value;
  }

  String _serviceType = 'taxi';
  String get serviceType => _serviceType;
  set serviceType(String value) {
    _serviceType = value;
    prefs.setString('ff_serviceType', value);
  }

  String _pendingRegistrationRole = '';
  String get pendingRegistrationRole => _pendingRegistrationRole;
  set pendingRegistrationRole(String value) {
    _pendingRegistrationRole = value;
    if (value.trim().isEmpty) {
      prefs.remove('ff_pendingRegistrationRole');
    } else {
      prefs.setString('ff_pendingRegistrationRole', value);
    }
  }

  bool _soundEnabled = true;
  bool get soundEnabled => _soundEnabled;
  set soundEnabled(bool value) {
    _soundEnabled = value;
    prefs.setBool('ff_soundEnabled', value);
  }

  String? _ignoredPassengerOrderPath;
  DateTime? _ignoredPassengerOrderUntil;
  String? _ignoredDriverOrderPath;
  DateTime? _ignoredDriverOrderUntil;
  String? _preferredDriverActiveOrderPath;
  DateTime? _preferredDriverActiveOrderUntil;
  String? _preferredDriverUserDocPath;
  String? _preferredPassengerWaitingOrderPath;
  DateTime? _preferredPassengerWaitingUntil;

  void markPassengerOrderCancelledLocally(
    DocumentReference? orderRef, {
    Duration duration = const Duration(minutes: 1),
  }) {
    final path = orderRef?.path;
    if (path == null || path.trim().isEmpty) {
      return;
    }
    _ignoredPassengerOrderPath = path;
    _ignoredPassengerOrderUntil = DateTime.now().add(duration);
    clearPassengerWaitingScreenPreference(path);
  }

  bool shouldIgnorePassengerOrderRef(DocumentReference? orderRef) {
    final path = orderRef?.path;
    final ignoredPath = _ignoredPassengerOrderPath;
    final ignoredUntil = _ignoredPassengerOrderUntil;
    if (path == null ||
        path.trim().isEmpty ||
        ignoredPath == null ||
        ignoredUntil == null) {
      return false;
    }
    if (DateTime.now().isAfter(ignoredUntil)) {
      clearIgnoredPassengerOrderRef();
      return false;
    }
    return path == ignoredPath;
  }

  void clearIgnoredPassengerOrderRef([String? path]) {
    if (path != null &&
        _ignoredPassengerOrderPath != null &&
        _ignoredPassengerOrderPath != path) {
      return;
    }
    _ignoredPassengerOrderPath = null;
    _ignoredPassengerOrderUntil = null;
  }

  void allowPassengerWaitingScreen(
    DocumentReference? orderRef, {
    Duration duration = const Duration(minutes: 2),
  }) {
    final path = orderRef?.path;
    if (path == null || path.trim().isEmpty) {
      return;
    }
    _preferredPassengerWaitingOrderPath = path;
    _preferredPassengerWaitingUntil = DateTime.now().add(duration);
  }

  bool shouldShowPassengerWaitingScreen(DocumentReference? orderRef) {
    final path = orderRef?.path;
    final preferredPath = _preferredPassengerWaitingOrderPath;
    final preferredUntil = _preferredPassengerWaitingUntil;
    if (path == null ||
        path.trim().isEmpty ||
        preferredPath == null ||
        preferredUntil == null) {
      return false;
    }
    if (DateTime.now().isAfter(preferredUntil)) {
      clearPassengerWaitingScreenPreference();
      return false;
    }
    return path == preferredPath;
  }

  void clearPassengerWaitingScreenPreference([String? path]) {
    if (path != null &&
        _preferredPassengerWaitingOrderPath != null &&
        _preferredPassengerWaitingOrderPath != path) {
      return;
    }
    _preferredPassengerWaitingOrderPath = null;
    _preferredPassengerWaitingUntil = null;
  }

  void markDriverOrderClosedLocally(
    DocumentReference? orderRef, {
    Duration duration = const Duration(minutes: 1),
  }) {
    final path = orderRef?.path;
    if (path == null || path.trim().isEmpty) {
      return;
    }
    _ignoredDriverOrderPath = path;
    _ignoredDriverOrderUntil = DateTime.now().add(duration);
  }

  bool shouldIgnoreDriverOrderRef(DocumentReference? orderRef) {
    final path = orderRef?.path;
    final ignoredPath = _ignoredDriverOrderPath;
    final ignoredUntil = _ignoredDriverOrderUntil;
    if (path == null ||
        path.trim().isEmpty ||
        ignoredPath == null ||
        ignoredUntil == null) {
      return false;
    }
    if (DateTime.now().isAfter(ignoredUntil)) {
      clearIgnoredDriverOrderRef();
      return false;
    }
    return path == ignoredPath;
  }

  bool shouldSuppressDriverOrderRecovery() {
    final ignoredPath = _ignoredDriverOrderPath;
    final ignoredUntil = _ignoredDriverOrderUntil;
    if (ignoredPath == null || ignoredUntil == null) {
      return false;
    }
    if (DateTime.now().isAfter(ignoredUntil)) {
      clearIgnoredDriverOrderRef();
      return false;
    }
    return true;
  }

  void markDriverOrderAcceptedLocally(
    DocumentReference? orderRef, {
    String? driverDocPath,
    Duration duration = const Duration(seconds: 25),
  }) {
    final path = orderRef?.path;
    if (path == null || path.trim().isEmpty) {
      return;
    }
    _preferredDriverActiveOrderPath = path;
    _preferredDriverActiveOrderUntil = DateTime.now().add(duration);
    final normalizedDriverDocPath = driverDocPath?.trim();
    if (normalizedDriverDocPath != null && normalizedDriverDocPath.isNotEmpty) {
      _preferredDriverUserDocPath = normalizedDriverDocPath;
    }
  }

  bool shouldPreferOptimisticDriverOrder(DocumentReference? orderRef) {
    final path = orderRef?.path;
    final preferredPath = _preferredDriverActiveOrderPath;
    final preferredUntil = _preferredDriverActiveOrderUntil;
    if (path == null ||
        path.trim().isEmpty ||
        preferredPath == null ||
        preferredUntil == null) {
      return false;
    }
    if (DateTime.now().isAfter(preferredUntil)) {
      clearPreferredDriverActiveOrder();
      return false;
    }
    return path == preferredPath;
  }

  bool shouldSuppressDriverOrderAuthoritativeRecovery() {
    final preferredPath = _preferredDriverActiveOrderPath;
    final preferredUntil = _preferredDriverActiveOrderUntil;
    if (preferredPath == null || preferredUntil == null) {
      return false;
    }
    if (DateTime.now().isAfter(preferredUntil)) {
      clearPreferredDriverActiveOrder();
      return false;
    }
    return true;
  }

  String? preferredDriverUserDocPath() {
    final preferredUntil = _preferredDriverActiveOrderUntil;
    final preferredDriverPath = _preferredDriverUserDocPath;
    if (preferredUntil == null || preferredDriverPath == null) {
      return null;
    }
    if (DateTime.now().isAfter(preferredUntil)) {
      clearPreferredDriverActiveOrder();
      return null;
    }
    return preferredDriverPath;
  }

  void clearPreferredDriverActiveOrder([String? path]) {
    if (path != null &&
        _preferredDriverActiveOrderPath != null &&
        _preferredDriverActiveOrderPath != path) {
      return;
    }
    _preferredDriverActiveOrderPath = null;
    _preferredDriverActiveOrderUntil = null;
    _preferredDriverUserDocPath = null;
  }

  void clearIgnoredDriverOrderRef([String? path]) {
    if (path != null &&
        _ignoredDriverOrderPath != null &&
        _ignoredDriverOrderPath != path) {
      return;
    }
    _ignoredDriverOrderPath = null;
    _ignoredDriverOrderUntil = null;
  }

  bool _passengerOrderCreationInFlight = false;
  bool get passengerOrderCreationInFlight => _passengerOrderCreationInFlight;

  String _passengerOrderCreationError = '';
  String get passengerOrderCreationError => _passengerOrderCreationError;

  DateTime? _forcePassengerModeUntil;
  bool get isPassengerModeForced =>
      _forcePassengerModeUntil?.isAfter(DateTime.now()) ?? false;

  void forcePassengerMode({
    Duration duration = const Duration(minutes: 2),
  }) {
    _forcePassengerModeUntil = DateTime.now().add(duration);
  }

  void clearForcedPassengerMode() {
    _forcePassengerModeUntil = null;
  }

  void beginPassengerOrderCreation() {
    _passengerOrderCreationInFlight = true;
    _passengerOrderCreationError = '';
    notifyListeners();
  }

  void completePassengerOrderCreation({
    String error = '',
  }) {
    _passengerOrderCreationInFlight = false;
    _passengerOrderCreationError = error;
    notifyListeners();
  }

  void clearPassengerOrderCreationState() {
    _passengerOrderCreationInFlight = false;
    _passengerOrderCreationError = '';
    notifyListeners();
  }
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (_) {}
}
