import 'dart:async';

import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '/admin/admin_utils.dart';
import 'auth/backend_auth/backend_user_provider.dart';
import 'auth/backend_auth/auth_util.dart';

import 'backend/app_settings/app_settings.dart';
import 'backend/backend_session.dart';
import 'backend/backend_user_adapter.dart';
import 'backend/backend_orders.dart';
import 'backend/backend_calls/backend_calls.dart';
import 'backend/payment_session_guard.dart';
import 'backend/push_notifications/push_notification_inbox.dart';
import 'backend/push_notifications/push_notifications_util.dart';
import 'backend/order_state_compat.dart';
import 'backend/firebase/firebase_config.dart';
import 'backend/backend.dart';
import 'web_host_mode.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/flutter_flow_widgets.dart';
import 'flutter_flow/internationalization.dart';
import 'package:flutter/foundation.dart';
import 'package:floating_bottom_navigation_bar/floating_bottom_navigation_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'component/force_update_gate/force_update_gate_widget.dart';
import 'component/set_role/set_role_widget.dart';
import 'index.dart';
import 'flutter_flow/permissions_util.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  await persistPendingPushMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  await initFirebase();
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );
  }

  await FlutterFlowTheme.initialize();
  await FFLocalizations.initialize();

  final appState = FFAppState(); // Initialize FFAppState
  await appState.initializePersistedState();
  unawaited(primeAppRuntimeSettings());

  runApp(ChangeNotifierProvider(
    create: (context) => appState,
    child: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class MyAppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class RequiredPasswordSetupWidget extends StatefulWidget {
  const RequiredPasswordSetupWidget({super.key});

  @override
  State<RequiredPasswordSetupWidget> createState() =>
      _RequiredPasswordSetupWidgetState();
}

class _RequiredPasswordSetupWidgetState
    extends State<RequiredPasswordSetupWidget> {
  final _passwordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _repeatPasswordFocusNode = FocusNode();
  bool _passwordVisible = false;
  bool _repeatPasswordVisible = false;
  bool _saving = false;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    _passwordFocusNode.dispose();
    _repeatPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    final password = _passwordController.text.trim();
    final repeatPassword = _repeatPasswordController.text.trim();
    if (password.length < 4) {
      setState(() {
        _errorText = 'Пароль должен быть минимум 4 символа.';
      });
      return;
    }
    if (password != repeatPassword) {
      setState(() {
        _errorText = 'Пароли не совпадают.';
      });
      return;
    }
    final user = currentUserDocument;
    if (user == null) {
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      final response = await makeCloudCall(
        'setPassword',
        {'password': password},
        timeout: const Duration(seconds: 12),
      );
      if (response['success'] != true) {
        throw Exception(
          (response['error'] ?? 'Не удалось сохранить пароль').toString(),
        );
      }
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorText = 'Не удалось сохранить пароль. Попробуйте еще раз.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFEFF2F6);
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : const Color(0xFF171D22);
    final mutedColor =
        isDark ? const Color(0xFF9EA8B0) : const Color(0xFF5B6670);
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFD8DEE6);
    const orangeColor = Color(0xFFFF6B00);
    const mintColor = Color(0xFF28D8C6);
    final appBarBg = isDark ? mintColor : surface;
    final appBarText = isDark ? Colors.white : textColor;
    final ctaColor = isDark ? mintColor : orangeColor;
    final ctaTextColor = isDark ? const Color(0xFF071718) : Colors.white;
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0.0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          'Установка пароля',
          style: theme.titleLarge.override(
            color: appBarText,
            fontSize: 22.0,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.0,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24.0, 64.0, 24.0, 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Установите пароль',
                    textAlign: TextAlign.center,
                    style: theme.headlineSmall.override(
                      color: textColor,
                      fontSize: 25.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.0,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    'Пароль нужен для следующего входа без SMS-кода.',
                    textAlign: TextAlign.center,
                    style: theme.bodyMedium.override(
                      color: mutedColor,
                      fontSize: 14.0,
                      letterSpacing: 0.0,
                    ),
                  ),
                  const SizedBox(height: 58.0),
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: !_passwordVisible,
                    decoration: InputDecoration(
                      labelText: 'Придумайте пароль',
                      filled: true,
                      fillColor: surface,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: borderColor, width: 1.0),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: borderColor, width: 1.0),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _passwordVisible = !_passwordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    controller: _repeatPasswordController,
                    focusNode: _repeatPasswordFocusNode,
                    obscureText: !_repeatPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Повторите пароль',
                      filled: true,
                      fillColor: surface,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: borderColor, width: 1.0),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: borderColor, width: 1.0),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _repeatPasswordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _repeatPasswordVisible = !_repeatPasswordVisible;
                          });
                        },
                      ),
                    ),
                    onFieldSubmitted: (_) => _saving ? null : _savePassword(),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12.0),
                    Text(
                      _errorText!,
                      style: theme.bodyMedium.override(
                        color: theme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28.0),
                  FFButtonWidget(
                    onPressed: _saving ? null : _savePassword,
                    text: _saving ? 'Сохранение...' : 'Сохранить пароль',
                    options: FFButtonOptions(
                      height: 54.0,
                      color: ctaColor,
                      textStyle: theme.titleSmall.override(
                        color: ctaTextColor,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.0,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Locale? _locale;

  ThemeMode _themeMode = FlutterFlowTheme.themeMode;

  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  late Stream<BaseAuthUser> userStream;
  StreamSubscription<UsersRecord?>? _authUserSub;
  StreamSubscription<AppRuntimeSettings>? _runtimeSettingsSub;
  final fcmTokenSub = fcmTokenUserStream.listen((_) {});
  Timer? _activeTimer;
  bool _isSigningOutBlockedUser = false;
  bool _isSigningOutWebOnlyUser = false;
  bool _blockedUserActive = false;
  String? _lastReportedPushAppState;
  bool? _lastReportedOrderAlertsEnabled;
  bool _locationRequirementReady = false;
  bool _locationGateActive = false;
  bool _locationServiceEnabled = true;
  PermissionStatus? _locationPermissionStatus;
  bool _isCheckingLocationRequirement = false;
  bool _isEnforcingLocationRequirement = false;
  AppRuntimeSettings _runtimeSettings = AppRuntimeSettings.defaults;
  String? _bootstrappedSessionUid;
  Future<void>? _sessionBootstrapInFlight;
  String? _sessionBootstrapInFlightUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locale = FFLocalizations.getStoredLocale();

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
    _authUserSub = authenticatedUserStream.listen(_handleAuthenticatedUserDoc);
    _runtimeSettingsSub = watchAppRuntimeSettings().listen((settings) {
      _runtimeSettings = settings;
      _startActiveTimer();
    });
    _loadRuntimeSettings();
    userStream = mtaxiBackendUserStream()
      ..listen((user) {
        _appStateNotifier.update(user);
        if (user.loggedIn) {
          _updateLastActive();
          unawaited(
            _syncPushTokenState(
              appState: kFcmAppStateForeground,
              force: true,
            ),
          );
          unawaited(
            _enforceLocationRequirement(
              resetLoading: true,
            ),
          );
        } else {
          _lastReportedPushAppState = null;
          _lastReportedOrderAlertsEnabled = null;
          _resetLocationRequirement();
          unawaited(FFAppState().clearTransientAuthFlowState());
        }
      });
    jwtTokenStream.listen((_) {});
    Future.delayed(
      Duration(milliseconds: 2000),
      () => _appStateNotifier.stopShowingSplashImage(),
    );
    _startActiveTimer();
  }

  @override
  void dispose() {
    unawaited(
      _syncPushTokenState(
        appState: kFcmAppStateTerminated,
        force: true,
      ),
    );
    WidgetsBinding.instance.removeObserver(this);
    _activeTimer?.cancel();
    _authUserSub?.cancel();
    _runtimeSettingsSub?.cancel();
    fcmTokenSub.cancel();
    super.dispose();
  }

  Future<void> _handleAuthenticatedUserDoc(UsersRecord? user) async {
    if (user == null) {
      _isSigningOutBlockedUser = false;
      _isSigningOutWebOnlyUser = false;
      _bootstrappedSessionUid = null;
      _sessionBootstrapInFlight = null;
      _sessionBootstrapInFlightUid = null;
      unawaited(FFAppState().clearTransientAuthFlowState());
      if (_blockedUserActive && mounted) {
        safeSetState(() => _blockedUserActive = false);
      } else {
        _blockedUserActive = false;
      }
      return;
    }

    final authUid = currentUserUid.trim();
    if (authUid.isNotEmpty) {
      _ensureSessionBootstrap(authUid);
    }

    if (kIsWeb && isWebAdminHost() && !isAdminUser(user)) {
      if (_isSigningOutWebOnlyUser) {
        return;
      }
      _isSigningOutWebOnlyUser = true;
      try {
        await authManager.signOut();
      } finally {
        _isSigningOutWebOnlyUser = false;
      }
      return;
    }

    final roleState =
        (user.snapshotData['roleState'] ?? '').toString().trim().toUpperCase();
    final isBlocked = ((user.snapshotData['blocked'] as bool?) ?? false) ||
        roleState == 'BLOCKED';
    if (_blockedUserActive != isBlocked) {
      if (mounted) {
        safeSetState(() => _blockedUserActive = isBlocked);
      } else {
        _blockedUserActive = isBlocked;
      }
    }
    if (!isBlocked || _isSigningOutBlockedUser) {
      return;
    }

    _isSigningOutBlockedUser = true;
    try {
      final ctx = appNavigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              FFLocalizations.of(ctx).getVariableText(
                ruText:
                    'Ваш аккаунт заблокирован. Вход в приложение недоступен.',
                kkText: 'Тіркелгіңіз бұғатталған. Қолданбаға кіру қолжетімсіз.',
              ),
            ),
          ),
        );
      }
      await authManager.signOut();
    } finally {
      _isSigningOutBlockedUser = false;
    }
  }

  void _ensureSessionBootstrap(String uid) {
    if (_bootstrappedSessionUid == uid) {
      return;
    }
    final inFlight = _sessionBootstrapInFlight;
    if (inFlight != null && _sessionBootstrapInFlightUid == uid) {
      return;
    }
    final future = () async {
      try {
        final response = await makeCloudCall('getSessionBootstrap', const {});
        if (response['success'] == true && currentUserUid.trim() == uid) {
          final passengerOrderPath =
              (response['activePassengerOrderRef'] ?? '').toString().trim();
          final driverOrderPath =
              (response['activeDriverOrderRef'] ?? '').toString().trim();
          final roleState = (response['roleState'] ?? '').toString().trim();
          final backendUser = response['user'];
          if (backendUser is Map) {
            currentUserDocument = usersRecordFromBackendUser(
              Map<String, dynamic>.from(backendUser),
            );
            await saveBackendUserFromResponse(response);
          }
          FFAppState().syncLegacyOrderRefs(
            passengerOrderRef:
                passengerOrderPath.isNotEmpty ? passengerOrderPath.ref : null,
            driverOrderRef:
                driverOrderPath.isNotEmpty ? driverOrderPath.ref : null,
          );
          if (roleState.isNotEmpty) {
            UserModeResolver.setTransientRoleState(roleState, uid: uid);
          }
          FFAppState().update(() {});
          _bootstrappedSessionUid = uid;
        }
      } catch (_) {
        // Cloud call layer already logs normalized failures.
      }
    }();
    _sessionBootstrapInFlight = future;
    _sessionBootstrapInFlightUid = uid;
    future.whenComplete(() {
      if (identical(_sessionBootstrapInFlight, future)) {
        _sessionBootstrapInFlight = null;
        _sessionBootstrapInFlightUid = null;
      }
    });
  }

  void setLocale(String language) {
    safeSetState(() => _locale = createLocale(language));
    FFLocalizations.storeLocale(language);
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  bool _isLocationPermissionGranted(PermissionStatus? status) {
    return status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
  }

  bool _shouldEnforceLocationRequirement() {
    if (kIsWeb || !loggedIn) {
      return false;
    }
    final user = currentUserDocument;
    if (user == null) {
      return false;
    }
    if (FFAppState().pendingRegistrationRole.trim().isNotEmpty) {
      return false;
    }
    if (needsRoleSelection(user) ||
        needsPasswordSetup(user) ||
        needsPassengerRegistration(user) ||
        needsDriverRegistration(user)) {
      return false;
    }
    return hasCompletedPassengerProfile(user) ||
        UserModeResolver.userHasApprovedDriverAccess(user);
  }

  void _resetLocationRequirement() {
    if (mounted) {
      safeSetState(() {
        _locationRequirementReady = false;
        _locationGateActive = false;
        _locationServiceEnabled = true;
        _locationPermissionStatus = null;
      });
      return;
    }
    _locationRequirementReady = false;
    _locationGateActive = false;
    _locationServiceEnabled = true;
    _locationPermissionStatus = null;
  }

  Future<void> _refreshLocationRequirement({
    bool requestIfNeeded = false,
    bool resetLoading = false,
  }) async {
    if (!loggedIn) {
      _resetLocationRequirement();
      return;
    }
    if (kIsWeb) {
      if (mounted) {
        safeSetState(() {
          _locationRequirementReady = true;
          _locationGateActive = false;
          _locationServiceEnabled = true;
          _locationPermissionStatus = PermissionStatus.granted;
        });
      } else {
        _locationRequirementReady = true;
        _locationGateActive = false;
        _locationServiceEnabled = true;
        _locationPermissionStatus = PermissionStatus.granted;
      }
      return;
    }
    if (_isCheckingLocationRequirement) {
      return;
    }
    _isCheckingLocationRequirement = true;
    if (resetLoading && mounted) {
      safeSetState(() {
        _locationRequirementReady = false;
      });
    }
    try {
      var serviceEnabled = true;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (_) {}

      var permissionStatus = await locationPermission.status;

      if (serviceEnabled &&
          requestIfNeeded &&
          !_isLocationPermissionGranted(permissionStatus) &&
          permissionStatus != PermissionStatus.permanentlyDenied &&
          permissionStatus != PermissionStatus.restricted) {
        await requestPermission(locationPermission);
        permissionStatus = await locationPermission.status;
      }

      final gateActive =
          !serviceEnabled || !_isLocationPermissionGranted(permissionStatus);

      if (mounted) {
        safeSetState(() {
          _locationServiceEnabled = serviceEnabled;
          _locationPermissionStatus = permissionStatus;
          _locationGateActive = gateActive;
          _locationRequirementReady = true;
        });
      } else {
        _locationServiceEnabled = serviceEnabled;
        _locationPermissionStatus = permissionStatus;
        _locationGateActive = gateActive;
        _locationRequirementReady = true;
      }
    } catch (_) {
      if (mounted) {
        safeSetState(() {
          _locationGateActive = true;
          _locationRequirementReady = true;
        });
      } else {
        _locationGateActive = true;
        _locationRequirementReady = true;
      }
    } finally {
      _isCheckingLocationRequirement = false;
    }
  }

  Future<void> _enforceLocationRequirement({
    bool resetLoading = false,
  }) async {
    if (!_shouldEnforceLocationRequirement() ||
        _isEnforcingLocationRequirement) {
      return;
    }
    _isEnforcingLocationRequirement = true;
    try {
      await _refreshLocationRequirement(
        requestIfNeeded: true,
        resetLoading: resetLoading,
      );
    } finally {
      _isEnforcingLocationRequirement = false;
    }
  }

  Future<void> _openLocationRequirementSettings() async {
    if (!_locationServiceEnabled) {
      try {
        await Geolocator.openLocationSettings();
      } catch (_) {}
    } else {
      final status = _locationPermissionStatus;
      if (status == PermissionStatus.permanentlyDenied ||
          status == PermissionStatus.restricted) {
        await openAppSettings();
      } else {
        await requestPermission(locationPermission);
      }
    }
    await _enforceLocationRequirement(
      resetLoading: true,
    );
  }

  Widget _buildLocationRequirementGate(BuildContext context) {
    final l10n = FFLocalizations.of(context);
    final permissionDeniedForever =
        _locationPermissionStatus == PermissionStatus.permanentlyDenied ||
            _locationPermissionStatus == PermissionStatus.restricted;
    final title = !_locationServiceEnabled
        ? l10n.getVariableText(
            ruText: 'Включите геолокацию',
            kkText: 'Геолокацияны қосыңыз',
          )
        : l10n.getVariableText(
            ruText: 'Разрешите доступ к геолокации',
            kkText: 'Геолокацияға рұқсат беріңіз',
          );
    final message = !_locationServiceEnabled
        ? l10n.getVariableText(
            ruText:
                'Без включенной геолокации приложение не работает. Включите службы геолокации и вернитесь обратно.',
            kkText:
                'Геолокация қосылмаса, қолданба жұмыс істемейді. Геолокация қызметін қосып, қайта оралыңыз.',
          )
        : permissionDeniedForever
            ? l10n.getVariableText(
                ruText:
                    'Вы запретили доступ к геолокации. Откройте настройки приложения и разрешите доступ, иначе пользоваться приложением нельзя.',
                kkText:
                    'Сіз геолокацияға рұқсатты жауып тастадыңыз. Қолданба баптауларын ашып, рұқсат беріңіз, әйтпесе қолданбаны пайдалану мүмкін емес.',
              )
            : l10n.getVariableText(
                ruText:
                    'Без разрешения на геолокацию приложение не работает. Дайте доступ к местоположению, чтобы продолжить.',
                kkText:
                    'Геолокация рұқсатынсыз қолданба жұмыс істемейді. Жалғастыру үшін орналасқан жерге рұқсат беріңіз.',
              );
    final primaryLabel = !_locationServiceEnabled
        ? l10n.getVariableText(
            ruText: 'Открыть настройки геолокации',
            kkText: 'Геолокация баптауларын ашу',
          )
        : permissionDeniedForever
            ? l10n.getVariableText(
                ruText: 'Открыть настройки приложения',
                kkText: 'Қолданба баптауларын ашу',
              )
            : l10n.getVariableText(
                ruText: 'Разрешить геолокацию',
                kkText: 'Геолокацияға рұқсат беру',
              );

    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 72,
                    color: FlutterFlowTheme.of(context).error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: FlutterFlowTheme.of(context).headlineSmall.override(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: FlutterFlowTheme.of(context).bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  if (_isCheckingLocationRequirement)
                    const CircularProgressIndicator()
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FFButtonWidget(
                        onPressed: () async {
                          await _openLocationRequirementSettings();
                        },
                        text: primaryLabel,
                        options: FFButtonOptions(
                          height: 48,
                          color: FlutterFlowTheme.of(context).primary,
                          textStyle:
                              FlutterFlowTheme.of(context).titleSmall.override(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          await _refreshLocationRequirement(
                            requestIfNeeded: true,
                            resetLoading: true,
                          );
                        },
                        child: Text(
                          l10n.getVariableText(
                            ruText: 'Проверить снова',
                            kkText: 'Қайта тексеру',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async {
                        await authManager.signOut();
                      },
                      child: Text(
                        l10n.getVariableText(
                          ruText: 'Выйти из аккаунта',
                          kkText: 'Аккаунттан шығу',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _syncPushTokenState({
    String? appState,
    bool force = false,
  }) async {
    final orderAlertsEnabled = FFAppState().soundEnabled;
    if (!force &&
        _lastReportedPushAppState == appState &&
        _lastReportedOrderAlertsEnabled == orderAlertsEnabled) {
      return;
    }
    await syncCurrentFcmTokenState(
      appState: appState,
      orderAlertsEnabled: orderAlertsEnabled,
    );
    _lastReportedPushAppState = appState;
    _lastReportedOrderAlertsEnabled = orderAlertsEnabled;
  }

  Future<void> _updateLastActive() async {
    try {
      await makeCloudCall(
        'updateUserPreferences',
        {'lastActive': true},
        timeout: const Duration(seconds: 8),
      );
    } catch (_) {}
  }

  void _startActiveTimer() {
    _activeTimer?.cancel();
    _activeTimer = Timer.periodic(
        Duration(seconds: _runtimeSettings.driverLastActiveHeartbeatSec), (_) {
      _updateLastActive();
    });
  }

  Future<void> _loadRuntimeSettings({
    bool forceRefresh = false,
  }) async {
    final settings = await primeAppRuntimeSettings(
      forceRefresh: forceRefresh,
    );
    _runtimeSettings = settings;
    _startActiveTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadRuntimeSettings(forceRefresh: true));
      _updateLastActive();
      _startActiveTimer();
      if (PaymentSessionGuard.isPaymentActive) {
        return;
      }
      unawaited(
        _enforceLocationRequirement(
          resetLoading: true,
        ),
      );
      unawaited(
        _syncPushTokenState(appState: kFcmAppStateForeground),
      );
    } else if (state == AppLifecycleState.detached) {
      _activeTimer?.cancel();
      unawaited(
        _syncPushTokenState(
          appState: kFcmAppStateTerminated,
          force: true,
        ),
      );
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _activeTimer?.cancel();
      unawaited(
        _syncPushTokenState(appState: kFcmAppStateBackground),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MTaxi',
      scrollBehavior: MyAppScrollBehavior(),
      localizationsDelegates: [
        FFLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FallbackMaterialLocalizationDelegate(),
        FallbackCupertinoLocalizationDelegate(),
      ],
      locale: _locale,
      supportedLocales: const [
        Locale('ru'),
        Locale('kk'),
      ],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: false,
      ),
      themeMode: _themeMode,
      builder: (context, child) {
        final l10n = FFLocalizations.of(context);
        Widget content;
        if (!_blockedUserActive) {
          if (_shouldEnforceLocationRequirement() &&
              (!_locationRequirementReady || _locationGateActive)) {
            content = _buildLocationRequirementGate(context);
          } else {
            content = child ?? const SizedBox.shrink();
          }
        } else {
          content = Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.block,
                        size: 64,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.getVariableText(
                          ruText: 'Ваш аккаунт заблокирован',
                          kkText: 'Тіркелгіңіз бұғатталған',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.getVariableText(
                          ruText:
                              'Вход в приложение недоступен. Обратитесь в поддержку.',
                          kkText:
                              'Қолданбаға кіру қолжетімсіз. Қолдау қызметіне хабарласыңыз.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (_isSigningOutBlockedUser)
                        const CircularProgressIndicator()
                      else
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              await authManager.signOut();
                            } catch (_) {}
                          },
                          child: Text(
                            l10n.getVariableText(
                              ruText: 'Выйти',
                              kkText: 'Шығу',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return ForceUpdateGate(
          child: content,
        );
      },
      routerConfig: _router,
    );
  }
}

class NavBarPage extends StatefulWidget {
  NavBarPage({
    Key? key,
    this.initialPage,
    this.page,
    this.disableResizeToAvoidBottomInset = false,
  }) : super(key: key);

  final String? initialPage;
  final Widget? page;
  final bool disableResizeToAvoidBottomInset;

  @override
  _NavBarPageState createState() => _NavBarPageState();
}

/// This is the private State class that goes with NavBarPage.
class _NavBarPageState extends State<NavBarPage> {
  String _currentPageName = 'HomePage';
  late Widget? _currentPage;
  bool _checkedActiveOrder = false;
  String? _lastRestoredPassengerOrderPath;
  bool _restoringPassengerOrder = false;
  bool _restoringDriverOrder = false;

  @override
  void initState() {
    super.initState();
    _currentPageName = widget.initialPage ?? _currentPageName;
    _currentPage = widget.page;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _passengerOrderSyncScaffold() {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40.0,
                height: 40.0,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    FlutterFlowTheme.of(context).primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                FFLocalizations.of(context).getVariableText(
                  ruText: 'Открываем активный заказ...',
                  kkText: 'Белсенді тапсырыс ашылуда...',
                ),
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    return AuthUserStreamWidget(
      builder: (context) {
        if (currentUserDocument == null) {
          if (!loggedIn) {
            return LoginWidget();
          }
          return Scaffold(
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        FlutterFlowTheme.of(context).primary,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      FFLocalizations.of(context).getVariableText(
                        ruText: 'Загружаем профиль...',
                        kkText: 'Профиль жүктелуде...',
                      ),
                      style: FlutterFlowTheme.of(context).bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (needsPasswordSetup(currentUserDocument)) {
          return const RequiredPasswordSetupWidget();
        }

        final hasCompletedPassenger = hasCompletedPassengerProfile(
          currentUserDocument,
        );
        final needsDriverFlow = needsDriverRegistration(currentUserDocument);
        var pendingRegistrationRole =
            FFAppState().pendingRegistrationRole.trim().toLowerCase();
        final resolvedRoleState = UserModeResolver.resolve(
          currentUserDocument,
        );
        final passengerModeHasPriority = pendingRegistrationRole != 'driver' &&
            resolvedRoleState == 'PASSENGER';
        if (hasCompletedPassenger &&
            !needsDriverFlow &&
            pendingRegistrationRole.isNotEmpty) {
          FFAppState().pendingRegistrationRole = '';
          FFAppState().update(() {});
          pendingRegistrationRole = '';
        }

        final shouldOpenDriverRegistration =
            pendingRegistrationRole == 'driver' ||
                (!passengerModeHasPriority &&
                    !hasCompletedPassenger &&
                    needsDriverFlow);
        if (shouldOpenDriverRegistration) {
          return const SetProfileDriverWidget();
        }

        if (pendingRegistrationRole == 'passenger' ||
            needsPassengerRegistration(currentUserDocument)) {
          return const SetProfileWidget();
        }

        if (needsRoleSelection(currentUserDocument)) {
          return Scaffold(
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 24.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        FFLocalizations.of(context).getVariableText(
                          ruText: 'Выберите режим',
                          kkText: 'Режимді таңдаңыз',
                        ),
                        style: FlutterFlowTheme.of(context).headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16.0),
                      const SetRoleWidget(),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (isAdminUser(currentUserDocument)) {
          return const AdminHomeWidget();
        }

        final forcePassengerMode = FFAppState().isPassengerModeForced;
        final isDriverMode = !forcePassengerMode &&
            UserModeResolver.canOpenDriverScreens(currentUserDocument) &&
            !isAdminUser(currentUserDocument);
        final shouldHoldDriverOrderRoute = isDriverMode &&
            !isAdminUser(currentUserDocument) &&
            UserModeResolver.userHasApprovedDriverAccess(
              currentUserDocument,
            ) &&
            (getEffectiveDriverOrderRef(currentUserDocument) != null ||
                getEffectiveDriverLegacyOrderRef() != null);
        final activePassengerOrderRef =
            getEffectivePassengerOrderRef(currentUserDocument);
        final effectivePassengerOrderRef =
            FFAppState().shouldIgnorePassengerOrderRef(activePassengerOrderRef)
                ? null
                : activePassengerOrderRef;
        final currentLocation = GoRouterState.of(context).uri.toString().trim();
        final paymentIsActive = PaymentSessionGuard.isPaymentActive;
        final shouldHoldPassengerOrderRoute =
            !isAdminUser(currentUserDocument) &&
                !isDriverMode &&
                effectivePassengerOrderRef != null;
        final shouldTrackPassengerOrderInRealtime =
            currentLocation.contains(SeachDriverWidget.routePath) ||
                shouldHoldPassengerOrderRoute ||
                FFAppState().passengerOrderCreationInFlight ||
                FFAppState().shouldShowPassengerWaitingScreen(
                  effectivePassengerOrderRef,
                );
        final shouldRecoverPassengerOrderOnStartup = !paymentIsActive &&
            !isDriverMode &&
            !isAdminUser(currentUserDocument) &&
            !_checkedActiveOrder;

        if (paymentIsActive) {
          _checkedActiveOrder = true;
        } else if (isDriverMode || shouldHoldDriverOrderRoute) {
          _checkedActiveOrder = false;
          _lastRestoredPassengerOrderPath = null;
        } else if (shouldTrackPassengerOrderInRealtime ||
            shouldRecoverPassengerOrderOnStartup) {
          if (!_checkedActiveOrder) {
            _checkedActiveOrder = true;
            _lastRestoredPassengerOrderPath = effectivePassengerOrderRef?.path;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              unawaited(_restorePassengerOrder(context));
            });
          } else {
            final passengerOrderPath = effectivePassengerOrderRef?.path;
            if (passengerOrderPath != _lastRestoredPassengerOrderPath) {
              _lastRestoredPassengerOrderPath = passengerOrderPath;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                unawaited(_restorePassengerOrder(context));
              });
            }
          }
        } else {
          _checkedActiveOrder = true;
          _lastRestoredPassengerOrderPath = effectivePassengerOrderRef?.path;
        }

        if (isDriverMode &&
            !paymentIsActive &&
            getEffectiveDriverOrderRef(currentUserDocument) != null &&
            !currentLocation.contains(HomeDriverOrderWidget.routePath)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            unawaited(_restoreDriverOrder(context));
          });
        }
        if (!paymentIsActive &&
            !isDriverMode &&
            (shouldTrackPassengerOrderInRealtime ||
                shouldRecoverPassengerOrderOnStartup) &&
            (_restoringPassengerOrder ||
                shouldRecoverPassengerOrderOnStartup)) {
          return _passengerOrderSyncScaffold();
        }

        final tabs = isDriverMode
            ? {
                'driverOrders': HomeDriverWidget(
                  allowedTypes: const {'taxi', 'delivery', 'intercity'},
                  emptyText: FFLocalizations.of(context).getVariableText(
                    ruText: 'Нет заказов в радиусе 10 км',
                    kkText: '10 км радиуста тапсырыс жоқ',
                  ),
                ),
                'driverProfile': ProfileWidget(),
              }
            : {
                'HomePage': HomePageWidget(),
                'profile': ProfileWidget(),
              };

        if (!tabs.containsKey(_currentPageName)) {
          _currentPageName = tabs.keys.first;
          _currentPage = null;
        }

        final currentIndex = tabs.keys.toList().indexOf(_currentPageName);

        final MediaQueryData queryData = MediaQuery.of(context);
        final keyboardManagedPage =
            !isDriverMode && _currentPageName == 'HomePage';
        final pageMediaQuery = keyboardManagedPage
            ? queryData.removeViewPadding(removeBottom: true)
            : queryData
                .removeViewInsets(removeBottom: true)
                .removeViewPadding(removeBottom: true);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              return;
            }
            if (isDriverMode) {
              if (_currentPageName != 'driverOrders') {
                setState(() {
                  _currentPageName = 'driverOrders';
                  _currentPage = null;
                });
              }
              return;
            }

            if (_currentPageName == 'HomePage') {
              setState(() {
                _currentPageName = 'profile';
                _currentPage = null;
              });
              return;
            }

            if (_currentPageName != 'HomePage') {
              setState(() {
                _currentPageName = 'HomePage';
                _currentPage = null;
              });
            }
          },
          child: Scaffold(
            resizeToAvoidBottomInset:
                !widget.disableResizeToAvoidBottomInset && !keyboardManagedPage,
            body: MediaQuery(
                data: pageMediaQuery,
                child: _currentPage ?? tabs[_currentPageName]!),
            extendBody: true,
            bottomNavigationBar: FloatingNavbar(
              currentIndex: currentIndex,
              onTap: (i) => safeSetState(() {
                _currentPage = null;
                _currentPageName = tabs.keys.toList()[i];
              }),
              backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
              selectedItemColor: FlutterFlowTheme.of(context).primary,
              unselectedItemColor: FlutterFlowTheme.of(context).secondaryText,
              selectedBackgroundColor: Color(0x00000000),
              borderRadius: 8.0,
              itemBorderRadius: 8.0,
              margin: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
              width: MediaQuery.sizeOf(context).width * 1.0,
              elevation: 0.0,
              items: isDriverMode
                  ? [
                      FloatingNavbarItem(
                        customWidget: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.list_alt,
                              color: currentIndex == 0
                                  ? FlutterFlowTheme.of(context).primary
                                  : FlutterFlowTheme.of(context).secondaryText,
                              size: 24.0,
                            ),
                            Text(
                              FFLocalizations.of(context).getVariableText(
                                ruText: 'Заказы',
                                kkText: 'Тапсырыстар',
                              ),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: currentIndex == 0
                                    ? FlutterFlowTheme.of(context).primary
                                    : FlutterFlowTheme.of(context)
                                        .secondaryText,
                                fontSize: 11.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FloatingNavbarItem(
                        customWidget: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person,
                              color: currentIndex == 1
                                  ? FlutterFlowTheme.of(context).primary
                                  : FlutterFlowTheme.of(context).secondaryText,
                              size: 24.0,
                            ),
                            Text(
                              FFLocalizations.of(context).getVariableText(
                                ruText: 'Профиль',
                                kkText: 'Профиль',
                              ),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: currentIndex == 1
                                    ? FlutterFlowTheme.of(context).primary
                                    : FlutterFlowTheme.of(context)
                                        .secondaryText,
                                fontSize: 11.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                  : [
                      FloatingNavbarItem(
                        customWidget: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              color: currentIndex == 0
                                  ? FlutterFlowTheme.of(context).primary
                                  : FlutterFlowTheme.of(context).secondaryText,
                              size: 24.0,
                            ),
                            Text(
                              FFLocalizations.of(context).getVariableText(
                                ruText: 'Главная',
                                kkText: 'Басты',
                              ),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: currentIndex == 0
                                    ? FlutterFlowTheme.of(context).primary
                                    : FlutterFlowTheme.of(context)
                                        .secondaryText,
                                fontSize: 11.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FloatingNavbarItem(
                        customWidget: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person,
                              color: currentIndex == 1
                                  ? FlutterFlowTheme.of(context).primary
                                  : FlutterFlowTheme.of(context).secondaryText,
                              size: 24.0,
                            ),
                            Text(
                              FFLocalizations.of(context).getText(
                                'jfo9zw67' /* Профиль */,
                              ),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: currentIndex == 1
                                    ? FlutterFlowTheme.of(context).primary
                                    : FlutterFlowTheme.of(context)
                                        .secondaryText,
                                fontSize: 11.0,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
            ),
          ),
        );
      },
    );
  }

  bool _hasOrderCancellationMarker(Map<String, dynamic>? data) {
    final cancelledBy = (data?['cancelledBy'] ?? '').toString().trim();
    final cancelStage = (data?['cancelStage'] ?? '').toString().trim();
    final cancelledAt = data?['cancelledAt'];
    return cancelledBy.isNotEmpty ||
        cancelStage.isNotEmpty ||
        cancelledAt != null;
  }

  Future<void> _restorePassengerOrder(BuildContext context) async {
    if (_restoringPassengerOrder) {
      return;
    }
    _restoringPassengerOrder = true;
    if (mounted) {
      setState(() {});
    }
    try {
      DocumentReference? orderRef =
          getEffectivePassengerOrderRef(currentUserDocument);
      if (FFAppState().shouldIgnorePassengerOrderRef(orderRef)) {
        FFAppState().syncLegacyOrderRefs(
          passengerOrderRef: null,
          driverOrderRef: getEffectiveDriverLegacyOrderRef(),
        );
        FFAppState().update(() {});
        return;
      }
      if (orderRef == null) {
        orderRef = await recoverActivePassengerOrderRefFromServer().timeout(
          const Duration(seconds: 6),
          onTimeout: () => null,
        );
        if (FFAppState().shouldIgnorePassengerOrderRef(orderRef)) {
          FFAppState().syncLegacyOrderRefs(
            passengerOrderRef: null,
            driverOrderRef: getEffectiveDriverLegacyOrderRef(),
          );
          FFAppState().update(() {});
          return;
        }
        if (orderRef != null) {
          FFAppState().syncLegacyOrderRefs(
            passengerOrderRef: orderRef,
            driverOrderRef: getEffectiveDriverLegacyOrderRef(),
          );
          FFAppState().clearPassengerOrderCreationState();
          FFAppState().update(() {});
        }
      }
      if (currentUserDocument != null &&
          getEffectivePassengerLegacyOrderRef()?.path != orderRef?.path) {
        FFAppState().syncLegacyOrderRefs(
          passengerOrderRef: orderRef,
          driverOrderRef: getEffectiveDriverLegacyOrderRef(),
        );
        if (orderRef != null) {
          FFAppState().clearPassengerOrderCreationState();
        }
        FFAppState().update(() {});
      }
      if (orderRef == null) {
        FFAppState().clearPassengerOrderCreationState();
        return;
      }
      try {
        final order = await loadOrderDetailsFromBackend(orderRef.path);
        if (order == null) {
          final recoveredOrderRef =
              await recoverActivePassengerOrderRefFromServer();
          if (recoveredOrderRef != null &&
              recoveredOrderRef.path != orderRef.path) {
            FFAppState().syncLegacyOrderRefs(
              passengerOrderRef: recoveredOrderRef,
              driverOrderRef: getEffectiveDriverLegacyOrderRef(),
            );
            FFAppState().clearPassengerOrderCreationState();
            FFAppState().update(() {});
            if (!mounted) return;
            GoRouter.of(context).goNamed(
              SeachDriverWidget.routeName,
              queryParameters: {
                'orderDocPath': recoveredOrderRef.path,
              },
            );
            return;
          }
          FFAppState().syncLegacyOrderRefs(
            passengerOrderRef: null,
            driverOrderRef: getEffectiveDriverLegacyOrderRef(),
          );
          FFAppState().update(() {});
          return;
        }
        if (_hasOrderCancellationMarker(order.snapshotData)) {
          FFAppState()
              .clearPassengerWaitingScreenPreference(order.reference.path);
          FFAppState().syncLegacyOrderRefs(
            passengerOrderRef: null,
            driverOrderRef: getEffectiveDriverLegacyOrderRef(),
          );
          FFAppState().update(() {});
          return;
        }
        final isWaitingNoDriver = order.status == 0 && order.idDriver == null;
        if (isWaitingNoDriver) {
          Map<String, dynamic> response = const {};
          try {
            response = await makeCloudCall(
              'expirePendingOrderIfNeeded',
              {
                'orderDocPath': order.reference.path,
              },
              timeout: const Duration(seconds: 8),
            );
          } catch (_) {}
          final expired = response['expired'] == true;
          final status = int.tryParse(response['status']?.toString() ?? '');
          if (expired || (status != null && status >= 6)) {
            FFAppState().otkkudaString = order.ot;
            FFAppState().kudaString = order.kuda;
            FFAppState().otkudaCoord = order.otCoords;
            FFAppState().kudaCoords = order.kudaCoords;
            FFAppState().comment = order.comment;
            final orderType = (order.snapshotData['type'] as String?) ?? 'taxi';
            FFAppState().serviceType = orderType;
            if (orderType == 'delivery') {
              FFAppState().delivery = true;
              FFAppState().taxi = false;
            } else if (orderType == 'intercity') {
              FFAppState().delivery = false;
              FFAppState().taxi = false;
            } else {
              FFAppState().delivery = false;
              FFAppState().taxi = true;
            }
            FFAppState().syncLegacyOrderRefs(
              passengerOrderRef: null,
              driverOrderRef: getEffectiveDriverLegacyOrderRef(),
            );
            FFAppState().update(() {});
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Заказ отменен. Исполнитель не найден',
                    kkText: 'Тапсырыс болдырылмады. Орындаушы табылмады',
                  ),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
            return;
          }
        }

        if (order.status >= 6) {
          FFAppState()
              .clearPassengerWaitingScreenPreference(order.reference.path);
          FFAppState().syncLegacyOrderRefs(
            passengerOrderRef: null,
            driverOrderRef: getEffectiveDriverLegacyOrderRef(),
          );
          FFAppState().update(() {});
          return;
        }

        if (!mounted) return;
        FFAppState().clearIgnoredPassengerOrderRef(order.reference.path);
        FFAppState().clearPassengerOrderCreationState();
        final shouldOpenPassengerOrderScreen = order.status < 6;
        if (shouldOpenPassengerOrderScreen) {
          GoRouter.of(context).goNamed(
            SeachDriverWidget.routeName,
            queryParameters: {
              'orderDocPath': order.reference.path,
            },
          );
        }
      } catch (_) {
        final recoveredOrderRef =
            await recoverActivePassengerOrderRefFromServer();
        if (FFAppState().shouldIgnorePassengerOrderRef(recoveredOrderRef)) {
          FFAppState().syncLegacyOrderRefs(
            passengerOrderRef: null,
            driverOrderRef: getEffectiveDriverLegacyOrderRef(),
          );
          FFAppState().update(() {});
          return;
        }
        if (recoveredOrderRef != null && mounted) {
          FFAppState().syncLegacyOrderRefs(
            passengerOrderRef: recoveredOrderRef,
            driverOrderRef: getEffectiveDriverLegacyOrderRef(),
          );
          FFAppState().clearPassengerOrderCreationState();
          FFAppState().update(() {});
          GoRouter.of(context).goNamed(
            SeachDriverWidget.routeName,
            queryParameters: {
              'orderDocPath': recoveredOrderRef.path,
            },
          );
        } else {
          FFAppState().clearPassengerOrderCreationState();
          FFAppState().update(() {});
        }
      }
    } finally {
      _restoringPassengerOrder = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _restoreDriverOrder(BuildContext context) async {
    if (_restoringDriverOrder) {
      return;
    }
    _restoringDriverOrder = true;
    try {
      DocumentReference? orderRef = getEffectiveDriverOrderRef(
        currentUserDocument,
      );
      if (orderRef != null &&
          FFAppState().shouldPreferOptimisticDriverOrder(orderRef)) {
        if (!mounted) return;
        GoRouter.of(context).goNamed(
          HomeDriverOrderWidget.routeName,
          queryParameters: {
            'orderDocPath': orderRef.path,
          },
        );
        return;
      }
      if (orderRef == null) {
        if (FFAppState().shouldSuppressDriverOrderAuthoritativeRecovery()) {
          orderRef = getEffectiveDriverLegacyOrderRef();
          if (orderRef != null) {
            if (!mounted) return;
            GoRouter.of(context).goNamed(
              HomeDriverOrderWidget.routeName,
              queryParameters: {
                'orderDocPath': orderRef.path,
              },
            );
            return;
          }
        }
        orderRef = await recoverActiveDriverOrderRefFromServer();
        if (orderRef != null) {
          FFAppState().syncLegacyOrderRefs(
            passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
            driverOrderRef: orderRef,
          );
          FFAppState().update(() {});
        }
      }
      if (currentUserDocument != null &&
          getEffectiveDriverLegacyOrderRef()?.path != orderRef?.path) {
        FFAppState().syncLegacyOrderRefs(
          passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
          driverOrderRef: orderRef,
        );
        FFAppState().update(() {});
      }
      if (orderRef == null) {
        return;
      }
      if (FFAppState().shouldIgnoreDriverOrderRef(orderRef)) {
        FFAppState().syncLegacyOrderRefs(
          passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
          driverOrderRef: null,
        );
        FFAppState().update(() {});
        return;
      }
      try {
        final order = await loadOrderDetailsFromBackend(orderRef.path);
        if (order == null) {
          final recoveredOrderRef =
              await recoverActiveDriverOrderRefFromServer();
          if (recoveredOrderRef != null &&
              recoveredOrderRef.path != orderRef.path) {
            FFAppState().syncLegacyOrderRefs(
              passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
              driverOrderRef: recoveredOrderRef,
            );
            FFAppState().update(() {});
            if (!mounted) return;
            GoRouter.of(context).goNamed(
              HomeDriverOrderWidget.routeName,
              queryParameters: {
                'orderDocPath': recoveredOrderRef.path,
              },
            );
            return;
          }
          FFAppState().markDriverOrderClosedLocally(orderRef);
          FFAppState().clearPreferredDriverActiveOrder(orderRef.path);
          FFAppState().syncLegacyOrderRefs(
            passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
            driverOrderRef: null,
          );
          UserModeResolver.setTransientRoleState(
            ((currentUserDocument?.snapshotData['driverOnLine'] as bool?) ??
                    false)
                ? 'DRIVER_ONLINE'
                : 'DRIVER_OFFLINE',
          );
          FFAppState().update(() {});
          return;
        }
        if (_hasOrderCancellationMarker(order.snapshotData)) {
          FFAppState().markDriverOrderClosedLocally(order.reference);
          FFAppState().clearPreferredDriverActiveOrder(order.reference.path);
          FFAppState().syncLegacyOrderRefs(
            passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
            driverOrderRef: null,
          );
          UserModeResolver.setTransientRoleState(
            ((currentUserDocument?.snapshotData['driverOnLine'] as bool?) ??
                    false)
                ? 'DRIVER_ONLINE'
                : 'DRIVER_OFFLINE',
          );
          FFAppState().update(() {});
          return;
        }
        final driverRef = getAuthoritativeCurrentUserRef();
        final stillAssigned =
            driverRef != null && order.idDriver?.path == driverRef.path;
        final status = order.status;
        final isActiveDriverOrder = stillAssigned && status >= 0 && status < 5;
        if (!isActiveDriverOrder) {
          FFAppState().markDriverOrderClosedLocally(order.reference);
          FFAppState().clearPreferredDriverActiveOrder(order.reference.path);
          FFAppState().syncLegacyOrderRefs(
            passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
            driverOrderRef: null,
          );
          UserModeResolver.setTransientRoleState(
            ((currentUserDocument?.snapshotData['driverOnLine'] as bool?) ??
                    false)
                ? 'DRIVER_ONLINE'
                : 'DRIVER_OFFLINE',
          );
          FFAppState().update(() {});
          return;
        }

        if (!mounted) return;
        GoRouter.of(context).goNamed(
          HomeDriverOrderWidget.routeName,
          queryParameters: {
            'orderDocPath': order.reference.path,
          },
        );
      } catch (_) {
        final recoveredOrderRef = await recoverActiveDriverOrderRefFromServer();
        if (FFAppState().shouldIgnoreDriverOrderRef(recoveredOrderRef)) {
          FFAppState().syncLegacyOrderRefs(
            passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
            driverOrderRef: null,
          );
          UserModeResolver.setTransientRoleState(
            ((currentUserDocument?.snapshotData['driverOnLine'] as bool?) ??
                    false)
                ? 'DRIVER_ONLINE'
                : 'DRIVER_OFFLINE',
          );
          FFAppState().update(() {});
          return;
        }
        if (recoveredOrderRef != null && mounted) {
          FFAppState().syncLegacyOrderRefs(
            passengerOrderRef: getEffectivePassengerLegacyOrderRef(),
            driverOrderRef: recoveredOrderRef,
          );
          FFAppState().update(() {});
          GoRouter.of(context).goNamed(
            HomeDriverOrderWidget.routeName,
            queryParameters: {
              'orderDocPath': recoveredOrderRef.path,
            },
          );
        }
      }
    } finally {
      _restoringDriverOrder = false;
    }
  }
}
