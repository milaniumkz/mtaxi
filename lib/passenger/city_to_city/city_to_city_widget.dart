import '/auth/backend_auth/auth_util.dart';
import '/backend/app_settings/app_settings.dart';
import '/backend/backend.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/backend/order_state_compat.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/passenger/seach_driver/seach_driver_widget.dart';
import 'dart:async';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'city_to_city_model.dart';
export 'city_to_city_model.dart';

const _mtaxiMint = Color(0xFF28D8C6);
const _mtaxiText = Color(0xFF1E1525);
const _mtaxiMuted = Color(0xFF73677C);

class _IntercityTariffCacheEntry {
  const _IntercityTariffCacheEntry({
    required this.pricePerKm,
    required this.minPrice,
    required this.expiresAt,
  });

  final double pricePerKm;
  final double minPrice;
  final DateTime expiresAt;
}

const _intercityTariffCacheTtl = Duration(minutes: 10);
_IntercityTariffCacheEntry? _intercityTariffCache;
Future<_IntercityTariffCacheEntry>? _intercityTariffInFlight;

class CityToCityWidget extends StatefulWidget {
  const CityToCityWidget({super.key});

  static String routeName = 'cityToCity';
  static String routePath = '/cityToCity';

  @override
  State<CityToCityWidget> createState() => _CityToCityWidgetState();
}

class _CityToCityWidgetState extends State<CityToCityWidget>
    with TickerProviderStateMixin {
  static const double _kBottomActionHeight = 88.0;
  late CityToCityModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  double _pricePerKm = 0.0;
  double _minPrice = 0.0;
  bool _creatingOrder = false;
  bool _navigatingToOrderSearch = false;
  Timer? _quoteDebounce;
  double? _lastDistanceKm;

  String _tr({
    required String ru,
    required String kk,
  }) {
    return FFLocalizations.of(context).getVariableText(
      ruText: ru,
      kkText: kk,
    );
  }

  String get _effectiveCity {
    final selectedCity = FFAppState().CityCountry.trim();
    if (selectedCity.isNotEmpty) {
      return selectedCity;
    }
    return valueOrDefault(currentUserDocument?.city, '').trim();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CityToCityModel());

    // TabBar удален

    _model.textController1 ??= TextEditingController();
    _model.textFieldFocusNode1 ??= FocusNode();

    _model.textController2 ??= TextEditingController();
    _model.textFieldFocusNode2 ??= FocusNode();

    _model.textController3 ??= TextEditingController();
    _model.textFieldFocusNode3 ??= FocusNode();
    _model.textControllerDistance ??= TextEditingController();
    _model.textFieldFocusNodeDistance ??= FocusNode();

    _loadTariff();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      safeSetState(() {});
    });
  }

  Future<_IntercityTariffCacheEntry> _fetchIntercityTariff() {
    final cached = _intercityTariffCache;
    final now = DateTime.now();
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return Future.value(cached);
    }
    final inFlight = _intercityTariffInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = () async {
      final settings = await getAppRuntimeSettings();
      final entry = _IntercityTariffCacheEntry(
        pricePerKm: settings.intercityPricePerKm,
        minPrice: settings.intercityMinPrice,
        expiresAt: now.add(_intercityTariffCacheTtl),
      );
      _intercityTariffCache = entry;
      return entry;
    }();
    _intercityTariffInFlight = future;
    future.whenComplete(() {
      if (identical(_intercityTariffInFlight, future)) {
        _intercityTariffInFlight = null;
      }
    });
    return future;
  }

  Future<void> _loadTariff() async {
    final tariff = await _fetchIntercityTariff();
    _pricePerKm = tariff.pricePerKm;
    _minPrice = tariff.minPrice;
    if (!mounted) return;
    setState(() {});
  }

  void _updatePriceFromDistance(double distanceKm) {
    _lastDistanceKm = distanceKm;
    _model.textControllerDistance.text = distanceKm.toStringAsFixed(1);
    if (_pricePerKm > 0) {
      final raw = distanceKm * _pricePerKm;
      final price = raw < _minPrice ? _minPrice : raw;
      _model.textController3.text = price.toStringAsFixed(0);
    } else {
      _model.textController3.text = '';
    }
    _quoteDebounce?.cancel();
    _quoteDebounce = Timer(const Duration(milliseconds: 350), () async {
      final response = await makeCloudCall(
        'getOrderQuote',
        {
          'type': 'intercity',
          'city': _effectiveCity,
          'distanceKm': distanceKm,
        },
      );
      if (!mounted) return;
      if (_lastDistanceKm != distanceKm) return;
      if (response['success'] != true) {
        return;
      }
      final serverPrice = double.tryParse(response['price']?.toString() ?? '');
      if (serverPrice == null || serverPrice <= 0) {
        return;
      }
      _model.textController3.text = serverPrice.toStringAsFixed(0);
      setState(() {});
    });
  }

  void _resetIntercityRouteQuote() {
    _lastDistanceKm = null;
    _model.textControllerDistance.text = '';
    _model.textController3.text = '';
    setState(() {});
  }

  DocumentReference? _orderRefFromPath(String? orderDocPath) {
    final path = orderDocPath?.trim() ?? '';
    if (path.isEmpty) return null;
    return BackendRefs.instance.doc(path);
  }

  Map<String, dynamic>? _serializeCoords(LatLng? value) {
    if (value == null) return null;
    return {
      'lat': value.latitude,
      'lng': value.longitude,
    };
  }

  String _orderCreationErrorMessage(dynamic responseError) {
    final error = (responseError ?? '').toString().trim();
    if (error.isNotEmpty) {
      return error;
    }
    return 'Не удалось создать заказ';
  }

  bool _isMeaningfulOrderAddress(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
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
      'бағыт нақтылануда',
      'бағыт табылмады',
      'маршрут табылмады',
      'undefined',
      'null',
      '-',
    };
    return !invalidValues.contains(normalized);
  }

  bool get _canSubmitIntercityOrder {
    return !_creatingOrder &&
        _isMeaningfulOrderAddress(_model.textController1.text) &&
        _isMeaningfulOrderAddress(_model.textController2.text) &&
        FFAppState().kudaCoords != null &&
        _model.textController3.text.trim().isNotEmpty;
  }

  String get _intercitySubmitLabel {
    if (_creatingOrder) {
      return _tr(
        ru: 'Создаем заказ...',
        kk: 'Тапсырыс жасалып жатыр...',
      );
    }
    if (!_isMeaningfulOrderAddress(_model.textController1.text)) {
      return _tr(
        ru: 'Выберите откуда',
        kk: 'Қайдан екенін таңдаңыз',
      );
    }
    if (!_isMeaningfulOrderAddress(_model.textController2.text) ||
        FFAppState().kudaCoords == null) {
      return _tr(
        ru: 'Выберите куда',
        kk: 'Қайда екенін таңдаңыз',
      );
    }
    if (_model.textController3.text.trim().isEmpty) {
      return _tr(
        ru: 'Маршрут не найден',
        kk: 'Бағыт табылмады',
      );
    }
    return FFLocalizations.of(context).getText(
      'tpz0l4p2' /* Подать заявку */,
    );
  }

  @override
  void dispose() {
    _quoteDebounce?.cancel();
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFEFF2F6);
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : _mtaxiText;
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8E2EC);

    Future<void> submitOrder() async {
      if (!_isMeaningfulOrderAddress(_model.textController1.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                ru: 'Введите откуда',
                kk: 'Қайдан екенін енгізіңіз',
              ),
              style: TextStyle(
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),
            duration: Duration(milliseconds: 4000),
            backgroundColor: FlutterFlowTheme.of(context).secondary,
          ),
        );
        return;
      }
      if (!_isMeaningfulOrderAddress(_model.textController2.text) ||
          FFAppState().kudaCoords == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                ru: 'Укажите корректную точку "Куда"',
                kk: '"Қайда" нүктесін дұрыс көрсетіңіз',
              ),
              style: TextStyle(
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),
            duration: Duration(milliseconds: 4000),
            backgroundColor: FlutterFlowTheme.of(context).secondary,
          ),
        );
        return;
      }
      if (_model.textController3.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                ru: 'Стоимость не рассчитана',
                kk: 'Құны есептелмеді',
              ),
              style: TextStyle(
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),
            duration: Duration(milliseconds: 4000),
            backgroundColor: FlutterFlowTheme.of(context).secondary,
          ),
        );
        return;
      }
      if (_creatingOrder) {
        return;
      }
      setState(() {
        _creatingOrder = true;
      });
      final stalePassengerOrderRef =
          getEffectivePassengerOrderRef(currentUserDocument);
      if (stalePassengerOrderRef != null) {
        FFAppState().markPassengerOrderCancelledLocally(
          stalePassengerOrderRef,
          duration: const Duration(minutes: 1),
        );
      }
      FFAppState().syncLegacyOrderRefs(
        passengerOrderRef: null,
        driverOrderRef: getEffectiveDriverLegacyOrderRef(),
      );
      FFAppState().beginPassengerOrderCreation();
      _navigatingToOrderSearch = true;
      context.goNamed(SeachDriverWidget.routeName);
      try {
        final response = await makeCloudCall(
          'createPassengerOrder',
          {
            'type': 'intercity',
            'ot': _model.textController1.text.trim(),
            'kuda': _model.textController2.text.trim(),
            'city': _effectiveCity,
            'price': double.tryParse(
              _model.textController3.text,
            ),
            'distanceKm': _lastDistanceKm,
            'replaceExistingActiveOrder': true,
            if (stalePassengerOrderRef != null)
              'previousOrderDocPath': stalePassengerOrderRef.path,
            'otCoords': _serializeCoords(FFAppState().otkudaCoord),
            'kudaCoords': _serializeCoords(FFAppState().kudaCoords),
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
            error: _orderCreationErrorMessage(response['error']),
          );
          return;
        }
        final orderRef =
            _orderRefFromPath(response['orderDocPath']?.toString()) ??
                await recoverActivePassengerOrderRefFromServer();
        if (orderRef == null) {
          FFAppState().completePassengerOrderCreation(
            error: _tr(
              ru: 'Не удалось открыть заказ',
              kk: 'Тапсырысты ашу мүмкін болмады',
            ),
          );
          return;
        }
        if (response['existing'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _tr(
                  ru: 'У вас уже есть активный заказ',
                  kk: 'Сізде белсенді тапсырыс бар',
                ),
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
        final serverPrice = double.tryParse(
          response['price']?.toString() ?? '',
        );
        if (serverPrice != null && serverPrice > 0) {
          _model.textController3.text = serverPrice.toStringAsFixed(0);
        }
        FFAppState().syncLegacyOrderRefs(
          passengerOrderRef: orderRef,
          driverOrderRef: getEffectiveDriverLegacyOrderRef(),
        );
        FFAppState().allowPassengerWaitingScreen(orderRef);
        FFAppState().completePassengerOrderCreation();
        if (mounted) {
          context.goNamed(
            SeachDriverWidget.routeName,
            queryParameters: {
              'orderDocPath': orderRef.path,
            },
          );
        }
      } on TimeoutException {
        FFAppState().completePassengerOrderCreation(
          error: _tr(
            ru: 'Сервер долго не отвечает. Попробуйте еще раз.',
            kk: 'Сервер ұзақ жауап бермей жатыр. Қайталап көріңіз.',
          ),
        );
      } catch (_) {
        FFAppState().completePassengerOrderCreation(
          error: _tr(
            ru: 'Не удалось создать заказ. Проверьте интернет и попробуйте еще раз.',
            kk: 'Тапсырыс жасау мүмкін болмады. Интернетті тексеріп, қайталап көріңіз.',
          ),
        );
      } finally {
        if (mounted && !_navigatingToOrderSearch) {
          setState(() {
            _creatingOrder = false;
          });
        }
      }
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: pageBg,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: surface,
          iconTheme: IconThemeData(color: textColor),
          automaticallyImplyLeading: true,
          centerTitle: true,
          elevation: 0,
          title: Text(
            'Межгород',
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  font: GoogleFonts.outfit(fontWeight: FontWeight.w800),
                  color: textColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        body: SafeArea(
          top: true,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: pageBg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    primary: false,
                    padding: EdgeInsets.only(
                      bottom: _kBottomActionHeight + keyboardInset + 24.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              16.0, 10.0, 16.0, 0.0),
                          child: TextFormField(
                            controller: _model.textController1,
                            focusNode: _model.textFieldFocusNode1,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: FFLocalizations.of(context)
                                  .getText('qd4bkhxk' /* Откуда */),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: _mtaxiMint,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: _mtaxiMint,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              filled: true,
                              fillColor: surface,
                              labelStyle: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(color: mutedColor),
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(color: textColor),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              16.0, 10.0, 16.0, 0.0),
                          child: TextFormField(
                            controller: _model.textController2,
                            focusNode: _model.textFieldFocusNode2,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: FFLocalizations.of(context)
                                  .getText('4agems80' /* Куда */),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: _mtaxiMint,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: _mtaxiMint,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              filled: true,
                              fillColor: surface,
                              labelStyle: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(color: mutedColor),
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(color: textColor),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              16.0, 10.0, 16.0, 0.0),
                          child: TextFormField(
                            controller: _model.textController3,
                            focusNode: _model.textFieldFocusNode3,
                            autofocus: false,
                            obscureText: false,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: FFLocalizations.of(context).getText(
                                'xfmzhxdr' /* Цена */,
                              ),
                              labelStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.readexPro(
                                      fontWeight: FontWeight.normal,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: mutedColor,
                                    fontSize: 14.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                              hintText: FFLocalizations.of(context).getText(
                                '86tekkvp' /* Цена */,
                              ),
                              hintStyle: FlutterFlowTheme.of(context)
                                  .bodyLarge
                                  .override(
                                    font: GoogleFonts.readexPro(
                                      fontWeight: FontWeight.normal,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyLarge
                                          .fontStyle,
                                    ),
                                    color: mutedColor,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyLarge
                                        .fontStyle,
                                  ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: _mtaxiMint,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: _mtaxiMint,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: _mtaxiMint,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: _mtaxiMint,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              filled: true,
                              fillColor: surface,
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.readexPro(
                                    fontWeight: FontWeight.normal,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color: textColor,
                                  fontSize: 14.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.normal,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                            keyboardType: TextInputType.number,
                            validator: _model.textController3Validator
                                .asValidator(context),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              16.0, 16.0, 16.0, 0.0),
                          child: SizedBox(
                            height: keyboardInset > 0 ? 240 : 460,
                            child: custom_widgets.IntercityMap(
                              width: MediaQuery.sizeOf(context).width,
                              height: keyboardInset > 0 ? 240 : 460,
                              onFromAddressChanged: (value) {
                                _model.textController1.text = value;
                                FFAppState().update(() {});
                                _resetIntercityRouteQuote();
                                setState(() {});
                              },
                              onToAddressChanged: (value) {
                                _model.textController2.text = value;
                                FFAppState().update(() {});
                                _resetIntercityRouteQuote();
                                setState(() {});
                              },
                              onFromCoordsChanged: (value) {
                                FFAppState().otkudaCoord =
                                    LatLng(value.latitude, value.longitude);
                                FFAppState().update(() {});
                              },
                              onToCoordsChanged: (value) {
                                FFAppState().kudaCoords =
                                    LatLng(value.latitude, value.longitude);
                                FFAppState().update(() {});
                              },
                              onDistanceChanged: (value) {
                                _updatePriceFromDistance(value);
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 0.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 12.0,
                            ),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(14.0),
                              border: Border.all(
                                color: borderColor,
                              ),
                            ),
                            child: Text(
                              _tr(
                                ru: 'Время поездки укажите в комментарии',
                                kk: 'Жол жүру уақытын пікірде көрсетіңіз',
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.readexPro(),
                                    color: mutedColor,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(
              16.0,
              8.0,
              16.0,
              MediaQuery.viewInsetsOf(context).bottom + 10.0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FFButtonWidget(
                onPressed: _canSubmitIntercityOrder ? submitOrder : null,
                text: _intercitySubmitLabel,
                options: FFButtonOptions(
                  height: 48.0,
                  padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                  iconPadding:
                      EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                  color: _mtaxiMint,
                  disabledColor: surface,
                  disabledTextColor: mutedColor,
                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                        font: GoogleFonts.readexPro(
                          fontWeight: FlutterFlowTheme.of(context)
                              .titleSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).titleSmall.fontStyle,
                        ),
                        color: isDark
                            ? const Color(0xFF13191D)
                            : const Color(0xFFEFF2F6),
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w800,
                        fontStyle:
                            FlutterFlowTheme.of(context).titleSmall.fontStyle,
                      ),
                  elevation: 0.0,
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
