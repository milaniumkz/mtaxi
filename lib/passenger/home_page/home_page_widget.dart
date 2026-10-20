import '/auth/backend_auth/auth_util.dart';
import '/backend/app_city_tariffs/app_city_tariffs.dart';
import '/backend/app_settings/app_settings.dart';
import '/backend/backend.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/backend/order_state_compat.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:provider/provider.dart';
import 'home_page_model.dart';
export 'home_page_model.dart';
import '/flutter_flow/custom_functions.dart' as functions;

class _LocalCityTariffCacheEntry {
  const _LocalCityTariffCacheEntry({
    required this.dayPrice,
    required this.nightPrice,
    required this.deliveryPrice,
    required this.expiresAt,
  });

  final double? dayPrice;
  final double? nightPrice;
  final double? deliveryPrice;
  final DateTime expiresAt;
}

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  static String routeName = 'HomePage';
  static String routePath = '/homePage';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  static const LatLng _fallbackPassengerLocation = LatLng(
    52.3231,
    77.1282,
  );
  late HomePageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  LatLng? currentUserLocationValue;
  double? _intercityFixedPrice;
  double? _routeDistanceKm;
  bool _creatingOrder = false;
  bool _navigatingToOrderSearch = false;
  bool _entryOrderCheckDone = false;
  DocumentReference? _entryActiveOrderRef;
  int _quoteRequestId = 0;
  Timer? _localPriceDebounce;

  bool get _shouldPreservePassengerOrderState {
    final activeOrderRef = getEffectivePassengerOrderRef(currentUserDocument);
    return (activeOrderRef != null &&
            !FFAppState().shouldIgnorePassengerOrderRef(activeOrderRef)) ||
        FFAppState().passengerOrderCreationInFlight ||
        FFAppState().passengerOrderCreationError.trim().isNotEmpty;
  }

  Future<_LocalCityTariffCacheEntry?> _getCityTariff(String cityName) async {
    final normalizedCity = cityName.trim();
    if (normalizedCity.isEmpty) {
      return null;
    }
    final tariff = await findAppCityTariff(normalizedCity);
    if (tariff == null) {
      return null;
    }
    return _LocalCityTariffCacheEntry(
      dayPrice: tariff.dayPrice,
      nightPrice: tariff.nightPrice,
      deliveryPrice: tariff.deliveryPrice,
      expiresAt: DateTime.now(),
    );
  }

  void _scheduleLocalPriceUpdate() {
    _localPriceDebounce?.cancel();
    _localPriceDebounce = Timer(
      const Duration(milliseconds: 250),
      _updateLocalPrice,
    );
  }

  String get _effectiveCity {
    final selectedCity = FFAppState().CityCountry.trim();
    if (selectedCity.isNotEmpty) {
      return selectedCity;
    }
    return valueOrDefault(currentUserDocument?.city, '').trim();
  }

  Future<void> _updateLocalPrice() async {
    final requestId = ++_quoteRequestId;
    final settings = await getAppRuntimeSettings();
    final serviceType =
        FFAppState().serviceType == 'delivery' ? 'delivery' : 'taxi';
    final quoteResponse = await makeCloudCall(
      'getOrderQuote',
      {
        'type': serviceType,
        'city': _effectiveCity,
      },
    );
    if (quoteResponse['success'] == true) {
      final quotePrice = double.tryParse(
        quoteResponse['price']?.toString() ?? '',
      );
      if (quotePrice != null && requestId == _quoteRequestId) {
        FFAppState().price = quotePrice.toStringAsFixed(0);
        if (mounted) {
          FFAppState().update(() {});
        }
        return;
      }
    }
    final cityName = _effectiveCity;
    double? cityDayPrice;
    double? cityNightPrice;
    double? cityDeliveryPrice;
    if (cityName.isNotEmpty) {
      final cityTariff = await _getCityTariff(cityName);
      if (cityTariff != null) {
        cityDayPrice = cityTariff.dayPrice;
        cityNightPrice = cityTariff.nightPrice;
        cityDeliveryPrice = cityTariff.deliveryPrice;
      }
    }
    final isDelivery = FFAppState().delivery == true;
    final isNight = functions.isNightTariff();
    final effectiveDeliveryExtra = isNight
        ? (settings.deliveryExtraNight ?? settings.deliveryExtra)
        : settings.deliveryExtra;
    double price;
    if (isDelivery && (cityDeliveryPrice ?? 0) > 0) {
      price = functions.applyNightMultiplier(
        cityDeliveryPrice!,
        isNight,
        nightMultiplier: settings.nightMultiplier,
      );
    } else {
      price = functions.calcLocalPrice(
        isDelivery: isDelivery,
        cityDayPrice: cityDayPrice,
        cityNightPrice: cityNightPrice,
        fallbackTaxiPrice: settings.fallbackTaxiPrice,
        fallbackDeliveryPrice: settings.fallbackDeliveryPrice,
        deliveryExtra: effectiveDeliveryExtra,
        nightMultiplier: settings.nightMultiplier,
      );
    }
    FFAppState().price = price.toStringAsFixed(0);
    if (mounted) {
      FFAppState().update(() {});
    }
  }

  void _setIntercityPrice(double? value) {
    _intercityFixedPrice = value;
    if (value == null || value <= 0) {
      FFAppState().price = '';
    } else {
      FFAppState().price = value.toStringAsFixed(0);
    }
    FFAppState().update(() {});
  }

  void _resetLocalOrderQuote() {
    FFAppState().price = '';
    FFAppState().update(() {});
  }

  Map<String, dynamic>? _serializeCoords(LatLng? value) {
    if (value == null) return null;
    return {
      'lat': value.latitude,
      'lng': value.longitude,
    };
  }

  bool _isMeaningfulOrderAddress(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    final compact = normalized
        .replaceFirst(
          RegExp(r'^(координаты|coordinates)\s*:\s*', caseSensitive: false),
          '',
        )
        .trim();
    if (RegExp(
      r'^[-+]?\d{1,2}(?:\.\d+)?\s*,\s*[-+]?\d{1,3}(?:\.\d+)?$',
    ).hasMatch(compact)) {
      return false;
    }
    const invalidValues = {
      'не указано',
      'не выбрано',
      'без адреса',
      'выберите точку куда на карте',
      'выберите точку "куда" на карте',
      'выберите точку откуда на карте',
      'выберите точку "откуда" на карте',
      'маршрут уточняется',
      'маршрут не найден',
      'undefined',
      'null',
      '-',
    };
    return !invalidValues.contains(normalized);
  }

  String _orderCreationErrorMessage(dynamic responseError) {
    final error = (responseError ?? '').toString().trim();
    if (error.isNotEmpty) {
      return error;
    }
    return 'Не удалось создать заказ';
  }

  DocumentReference? _orderRefFromPath(String? orderDocPath) {
    final path = orderDocPath?.trim() ?? '';
    if (path.isEmpty) return null;
    return BackendRefs.instance.doc(path);
  }

  void _pinPassengerModeForOrdering() {
    UserModeResolver.setTransientRoleState('PASSENGER');
    unawaited(
      makeCloudCall(
        'updateUserPreferences',
        {
          'userDocPath': currentUserDocument?.reference.path,
          'targetRoleState': 'PASSENGER',
        },
        timeout: const Duration(seconds: 8),
      ),
    );
  }

  Future<String?> _openExistingOrCreatedOrder({
    required Map<String, dynamic> response,
    bool navigate = true,
  }) async {
    final orderRef = _orderRefFromPath(response['orderDocPath']?.toString()) ??
        await recoverActivePassengerOrderRefFromServer();
    if (orderRef == null) {
      return 'Не удалось открыть заказ';
    }
    FFAppState().clearIgnoredPassengerOrderRef(orderRef.path);
    FFAppState().allowPassengerWaitingScreen(orderRef);
    FFAppState().syncLegacyOrderRefs(
      passengerOrderRef: orderRef,
      driverOrderRef: getEffectiveDriverLegacyOrderRef(),
    );
    FFAppState().completePassengerOrderCreation();
    FFAppState().comment = '';
    FFAppState().deliveryItem = '';
    if (!navigate || !mounted) return null;
    _navigatingToOrderSearch = true;
    context.goNamed(
      SeachDriverWidget.routeName,
      queryParameters: {
        'orderDocPath': orderRef.path,
      },
    );
    return null;
  }

  Future<void> _resolveActivePassengerOrderOnEntry() async {
    if (!mounted) {
      return;
    }
    DocumentReference? orderRef;
    try {
      orderRef = await recoverActivePassengerOrderRefFromServer().timeout(
        const Duration(seconds: 6),
      );
    } catch (_) {
      orderRef = null;
    }
    if (!mounted) {
      return;
    }
    if (orderRef != null &&
        FFAppState().shouldIgnorePassengerOrderRef(orderRef)) {
      orderRef = null;
    }
    if (orderRef != null) {
      FFAppState().clearIgnoredPassengerOrderRef(orderRef.path);
      FFAppState().allowPassengerWaitingScreen(orderRef);
      FFAppState().syncLegacyOrderRefs(
        passengerOrderRef: orderRef,
        driverOrderRef: getEffectiveDriverLegacyOrderRef(),
      );
      FFAppState().clearPassengerOrderCreationState();
      FFAppState().update(() {});
    }
    safeSetState(() {
      _entryActiveOrderRef = orderRef;
      _entryOrderCheckDone = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomePageModel());

    getCurrentUserLocation(
      defaultLocation: _fallbackPassengerLocation,
      cached: true,
    )
        .timeout(
          const Duration(seconds: 6),
          onTimeout: () => _fallbackPassengerLocation,
        )
        .then(
          (loc) => safeSetState(
            () => currentUserLocationValue = loc,
          ),
        )
        .catchError((_) {
      safeSetState(() => currentUserLocationValue = _fallbackPassengerLocation);
    });
    _model.commentTextController ??= TextEditingController();
    _model.commentFocusNode ??= FocusNode();
    _model.commentFocusNode!.addListener(() => safeSetState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      safeSetState(() {});
      unawaited(_resolveActivePassengerOrderOnEntry());
    });
    final userCity = valueOrDefault(currentUserDocument?.city, '').trim();
    if (FFAppState().CityCountry.trim().isEmpty && userCity.isNotEmpty) {
      FFAppState().CityCountry = userCity;
    }
    if (!_shouldPreservePassengerOrderState) {
      FFAppState().kudaString = '';
      FFAppState().kudaCoords = null;
      FFAppState().comment = '';
      FFAppState().deliveryItem = '';
    }
  }

  @override
  void dispose() {
    _localPriceDebounce?.cancel();
    _model.dispose();

    super.dispose();
  }

  String get _currentServiceType {
    return FFAppState().serviceType.isNotEmpty
        ? FFAppState().serviceType
        : (FFAppState().delivery == true ? 'delivery' : 'taxi');
  }

  bool get _hasDestinationSelected {
    final serviceType = _currentServiceType;
    final toText = FFAppState().kudaString.trim();
    if (serviceType == 'intercity') {
      return _isMeaningfulOrderAddress(toText) &&
          _intercityFixedPrice != null &&
          _intercityFixedPrice! > 0;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFEFF2F6);
    final ctaColor = isDark ? const Color(0xFF28D8C6) : const Color(0xFFFF6B00);
    final ctaTextColor = isDark ? const Color(0xFF071718) : Colors.white;
    final entryActiveOrderRef = _entryActiveOrderRef ??
        getEffectivePassengerOrderRef(currentUserDocument);
    if (!_entryOrderCheckDone) {
      return Container(
        color: pageBg,
        child: Center(
          child: SizedBox(
            width: 50.0,
            height: 50.0,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(ctaColor),
            ),
          ),
        ),
      );
    }
    if (entryActiveOrderRef != null &&
        !FFAppState().shouldIgnorePassengerOrderRef(entryActiveOrderRef)) {
      return SeachDriverWidget(orderDocPath: entryActiveOrderRef.path);
    }
    if (currentUserLocationValue == null) {
      return Container(
        color: pageBg,
        child: Center(
          child: SizedBox(
            width: 50.0,
            height: 50.0,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(ctaColor),
            ),
          ),
        ),
      );
    }

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;
    final canSubmitOrder = !_creatingOrder;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: pageBg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          top: true,
          bottom: false,
          child: custom_widgets.DeliveryTaxiMap(
            key: ValueKey('delivery_taxi_map_${FFAppState().serviceType}'),
            width: MediaQuery.sizeOf(context).width * 1.0,
            height: MediaQuery.sizeOf(context).height,
            priceText: FFAppState().price,
            initialServiceType: FFAppState().serviceType,
            cityName: _effectiveCity,
            initialFromCoords: currentUserLocationValue == null
                ? null
                : latlng.LatLng(
                    currentUserLocationValue!.latitude,
                    currentUserLocationValue!.longitude,
                  ),
            initialToCoords: FFAppState().kudaCoords == null
                ? null
                : latlng.LatLng(
                    FFAppState().kudaCoords!.latitude,
                    FFAppState().kudaCoords!.longitude,
                  ),
            onFromAddressChanged: (value) {
              FFAppState().otkkudaString = value;
              _resetLocalOrderQuote();
              FFAppState().update(() {});
              if (FFAppState().serviceType != 'intercity') {
                _scheduleLocalPriceUpdate();
              }
            },
            onToAddressChanged: (value) {
              FFAppState().kudaString = value;
              if (FFAppState().serviceType != 'intercity') {
                _resetLocalOrderQuote();
              }
              FFAppState().update(() {});
              if (FFAppState().serviceType != 'intercity') {
                _scheduleLocalPriceUpdate();
              }
            },
            onFromCoordsChanged: (value) {
              FFAppState().otkudaCoord =
                  LatLng(value.latitude, value.longitude);
              FFAppState().update(() {});
              if (FFAppState().serviceType != 'intercity') {
                _scheduleLocalPriceUpdate();
              }
            },
            onToCoordsChanged: (value) {
              FFAppState().kudaCoords = LatLng(value.latitude, value.longitude);
              FFAppState().update(() {});
              if (FFAppState().serviceType != 'intercity') {
                _scheduleLocalPriceUpdate();
              }
            },
            onServiceTypeChanged: (value) {
              final previousType = FFAppState().serviceType;
              FFAppState().serviceType = value;
              if (value == 'delivery') {
                FFAppState().delivery = true;
                FFAppState().taxi = false;
                FFAppState().comment = '';
              } else if (value == 'intercity') {
                FFAppState().delivery = false;
                FFAppState().taxi = false;
                _setIntercityPrice(null);
              } else {
                FFAppState().delivery = false;
                FFAppState().taxi = true;
              }
              if (previousType == 'intercity' && value != 'intercity') {
                FFAppState().kudaString = '';
                FFAppState().kudaCoords = null;
              }
              FFAppState().update(() {});
              if (value != 'intercity') {
                _scheduleLocalPriceUpdate();
              }
            },
            onDistanceChanged: (value) {
              _routeDistanceKm = value > 0 ? value : null;
            },
            onIntercityPriceChanged: (value) {
              if (FFAppState().serviceType == 'intercity') {
                _setIntercityPrice(value);
              }
            },
            onCommentChanged: (value) {
              FFAppState().comment = value;
              FFAppState().update(() {});
            },
            onDeliveryItemChanged: (value) {
              FFAppState().deliveryItem = value;
              FFAppState().update(() {});
            },
          ),
        ),
        bottomNavigationBar: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(
            16.0,
            8.0,
            16.0,
            keyboardInset > 0
                ? keyboardInset + 8.0
                : bottomSafeInset + kBottomNavigationBarHeight + 28.0,
          ),
          child: FFButtonWidget(
            onPressed: canSubmitOrder
                ? () async {
                    if (_creatingOrder) {
                      return;
                    }
                    _pinPassengerModeForOrdering();
                    final serviceType = _currentServiceType;
                    if (serviceType == 'intercity' &&
                        !_hasDestinationSelected) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Укажите корректную точку "Куда"'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    final isDelivery = serviceType == 'delivery';
                    final currentPrice = double.tryParse(FFAppState().price);
                    if (serviceType != 'intercity' &&
                        (currentPrice == null || currentPrice <= 0)) {
                      await _updateLocalPrice();
                    }
                    if (serviceType == 'intercity' &&
                        (FFAppState().price.isEmpty ||
                            _intercityFixedPrice == null ||
                            _intercityFixedPrice! <= 0)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Маршрут не найден'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    final price = double.tryParse(FFAppState().price);
                    final orderType = serviceType;
                    final orderComment =
                        isDelivery ? '' : FFAppState().comment.trim();
                    final deliveryItem =
                        isDelivery ? FFAppState().deliveryItem.trim() : '';
                    final cityFromText = () {
                      final raw = FFAppState().otkkudaString.trim();
                      if (!_isMeaningfulOrderAddress(raw)) {
                        return '';
                      }
                      if (raw.contains(',')) {
                        return raw.split(',').first.trim();
                      }
                      return '';
                    }();
                    final activePassengerOrderRef =
                        await recoverActivePassengerOrderRefFromServer();
                    if (activePassengerOrderRef != null) {
                      FFAppState().clearIgnoredPassengerOrderRef(
                        activePassengerOrderRef.path,
                      );
                      FFAppState().allowPassengerWaitingScreen(
                        activePassengerOrderRef,
                      );
                      FFAppState().syncLegacyOrderRefs(
                        passengerOrderRef: activePassengerOrderRef,
                        driverOrderRef: getEffectiveDriverLegacyOrderRef(),
                      );
                      FFAppState().clearPassengerOrderCreationState();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('У вас уже есть активный заказ'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        context.goNamed(
                          SeachDriverWidget.routeName,
                          queryParameters: {
                            'orderDocPath': activePassengerOrderRef.path,
                          },
                        );
                      }
                      return;
                    }
                    setState(() {
                      _creatingOrder = true;
                    });
                    FFAppState().syncLegacyOrderRefs(
                      passengerOrderRef: null,
                      driverOrderRef: null,
                    );
                    FFAppState().beginPassengerOrderCreation();
                    _navigatingToOrderSearch = true;
                    context.goNamed(SeachDriverWidget.routeName);
                    try {
                      final response = await makeCloudCall(
                        'createPassengerOrder',
                        {
                          'type': orderType,
                          'ot': FFAppState().otkkudaString,
                          'kuda': FFAppState().kudaString,
                          'city': () {
                            final fromCity = cityFromText;
                            return fromCity.isNotEmpty
                                ? fromCity
                                : _effectiveCity;
                          }(),
                          if (price != null) 'price': price,
                          'comment': orderComment,
                          'deliveryItem': deliveryItem,
                          'replaceExistingActiveOrder': false,
                          if (_routeDistanceKm != null)
                            'distanceKm': _routeDistanceKm,
                          'otCoords':
                              _serializeCoords(FFAppState().otkudaCoord),
                          'kudaCoords':
                              _serializeCoords(FFAppState().kudaCoords),
                        },
                        timeout: const Duration(seconds: 12),
                      );
                      final success = response['success'] == true;
                      if (!success) {
                        final recoveredOrderRef =
                            await recoverActivePassengerOrderRefFromServer();
                        if (recoveredOrderRef != null) {
                          FFAppState().syncLegacyOrderRefs(
                            passengerOrderRef: recoveredOrderRef,
                            driverOrderRef: getEffectiveDriverLegacyOrderRef(),
                          );
                          FFAppState().completePassengerOrderCreation();
                          return;
                        }
                        FFAppState().completePassengerOrderCreation(
                          error: _orderCreationErrorMessage(
                            response['error'],
                          ),
                        );
                        return;
                      }
                      if (response['existing'] == true && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('У вас уже есть активный заказ'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                      final serverPrice = double.tryParse(
                        response['price']?.toString() ?? '',
                      );
                      if (serverPrice != null && serverPrice > 0) {
                        FFAppState().price = serverPrice.toStringAsFixed(0);
                        FFAppState().update(() {});
                      }
                      final openError = await _openExistingOrCreatedOrder(
                        response: response,
                        navigate: false,
                      );
                      if (openError != null) {
                        FFAppState()
                            .completePassengerOrderCreation(error: openError);
                      } else {
                        final createdOrderRef = _orderRefFromPath(
                              response['orderDocPath']?.toString(),
                            ) ??
                            getEffectivePassengerOrderRef(currentUserDocument);
                        if (createdOrderRef != null && mounted) {
                          context.goNamed(
                            SeachDriverWidget.routeName,
                            queryParameters: {
                              'orderDocPath': createdOrderRef.path,
                            },
                          );
                        }
                      }
                    } on TimeoutException {
                      FFAppState().completePassengerOrderCreation(
                        error: 'Сервер долго не отвечает. Попробуйте еще раз.',
                      );
                    } catch (_) {
                      FFAppState().completePassengerOrderCreation(
                        error:
                            'Не удалось создать заказ. Проверьте интернет и попробуйте еще раз.',
                      );
                    } finally {
                      if (mounted && !_navigatingToOrderSearch) {
                        setState(() {
                          _creatingOrder = false;
                        });
                      }
                    }
                  }
                : null,
            text: _creatingOrder
                ? 'Создаем заказ...'
                : (_currentServiceType == 'intercity' &&
                        !_hasDestinationSelected)
                    ? 'Выберите куда'
                    : FFLocalizations.of(context).getText(
                        '0kzx86tp' /* Заказать */,
                      ),
            options: FFButtonOptions(
              height: 48.0,
              padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
              iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
              color: ctaColor,
              disabledColor: ctaColor.withValues(alpha: 0.55),
              disabledTextColor: ctaTextColor.withValues(alpha: 0.75),
              textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                    font: GoogleFonts.readexPro(
                      fontWeight: FontWeight.w800,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleSmall.fontStyle,
                    ),
                    color: ctaTextColor,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w800,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleSmall.fontStyle,
                  ),
              elevation: 0.0,
              borderSide: BorderSide(
                color: Colors.transparent,
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ),
    );
  }
}
