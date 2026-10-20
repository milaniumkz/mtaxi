import '/backend/backend.dart';
import '/backend/backend_session.dart';
import '/backend/backend_user_adapter.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/auth/backend_auth/backend_user_provider.dart';
import '/component/set_role/set_role_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import '/flutter_flow/permissions_util.dart';
import '/index.dart';
import '/web_host_mode.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
import 'login_model.dart';
export 'login_model.dart';
import '/auth/backend_auth/auth_util.dart';
import '/admin/admin_utils.dart';

class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});

  static String routeName = 'login';
  static String routePath = '/login';

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> with WidgetsBindingObserver {
  late LoginModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _phoneFieldKey = GlobalKey();
  bool _isNormalizingPhoneInput = false;
  bool _isSubmitting = false;
  String _loginStatusMessage = '';
  bool _loginStatusIsError = false;
  String _loginButtonMessage = '';
  String _lastTokenRequestError = '';
  bool _showPhoneLogin = true;

  Future<void> _ensurePhoneFieldVisible() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) {
      return;
    }
    final fieldContext = _phoneFieldKey.currentContext;
    if (fieldContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      fieldContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: 0.08,
    );
  }

  void _handlePhoneFieldFocusChange() {
    if (!(_model.textFieldFocusNode?.hasFocus ?? false)) {
      return;
    }
    unawaited(_ensurePhoneFieldVisible());
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) {
      return;
    }
    if (_model.textFieldFocusNode?.hasFocus ?? false) {
      unawaited(_ensurePhoneFieldVisible());
    }
  }

  String _localPhoneDigits(String rawValue) {
    var digits = normalizePhoneDigits(rawValue);
    if (digits.length >= 11 &&
        (digits.startsWith('7') || digits.startsWith('8'))) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }
    return digits;
  }

  String? _normalizedPhone(String rawValue) {
    final localDigits = _localPhoneDigits(rawValue);
    if (localDigits.length != 10) {
      return null;
    }
    return '+7$localDigits';
  }

  String _maskedPhone(String rawValue) {
    final localDigits = _localPhoneDigits(rawValue);
    _model.textFieldMask.updateMask(mask: '(###) ###-##-##');
    _model.textFieldMask.maskText(localDigits);
    return _model.textFieldMask.getMaskedText();
  }

  void _normalizePhoneInput() {
    if (_isNormalizingPhoneInput) {
      return;
    }
    final controller = _model.textController;
    if (controller == null) {
      return;
    }
    final maskedValue = _maskedPhone(controller.text);
    if (controller.text == maskedValue) {
      return;
    }
    _isNormalizingPhoneInput = true;
    controller.value = TextEditingValue(
      text: maskedValue,
      selection: TextSelection.collapsed(offset: maskedValue.length),
    );
    _isNormalizingPhoneInput = false;
  }

  void _setLoginStatus(
    String message, {
    bool isError = false,
    String? buttonMessage,
  }) {
    if (!mounted) return;
    setState(() {
      _loginStatusMessage = message;
      _loginStatusIsError = isError;
      _loginButtonMessage = buttonMessage ?? message;
    });
  }

  void _restorePhoneInput(String normalizedPhone) {
    final controller = _model.textController;
    if (controller == null) return;
    final maskedValue = _maskedPhone(normalizedPhone);
    if (maskedValue.isEmpty || controller.text == maskedValue) return;
    _isNormalizingPhoneInput = true;
    controller.value = TextEditingValue(
      text: maskedValue,
      selection: TextSelection.collapsed(offset: maskedValue.length),
    );
    _isNormalizingPhoneInput = false;
  }

  Future<String?> _requestCustomTokenForUid(
    String uid, {
    String driverPassword = '',
  }) async {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      return null;
    }
    _lastTokenRequestError = '';
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await makeCloudCall(
            'passwordLogin',
            {
              'uid': trimmedUid,
              if (driverPassword.trim().isNotEmpty)
                'driverPassword': driverPassword.trim(),
            },
            timeout: const Duration(seconds: 12));
        final token = (response['token'] ?? '').toString().trim();
        if (response['success'] == true && token.isNotEmpty) {
          _lastTokenRequestError = '';
          return token;
        }
        final serverError = (response['error'] ?? '').toString().trim();
        if (serverError.isNotEmpty) {
          _lastTokenRequestError = serverError;
        }
      } on TimeoutException {
        _lastTokenRequestError = 'Сервер долго отвечает. Попробуйте еще раз.';
      } catch (_) {}
      if (attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }

    if (_lastTokenRequestError.trim().isEmpty) {
      _lastTokenRequestError =
          'Не удалось подготовить вход. Попробуйте еще раз.';
    }
    return null;
  }

  List<String> _authUidCandidates({
    UsersRecord? existingUser,
    String? fallbackPhone,
  }) {
    final candidates = <String>{
      existingUser?.uid.trim() ?? '',
      existingUser?.reference.id.trim() ?? '',
      (fallbackPhone ?? '').trim(),
    };
    return candidates.where((candidate) => candidate.isNotEmpty).toList();
  }

  Future<String?> _requestCustomToken({
    UsersRecord? existingUser,
    String? fallbackPhone,
    String driverPassword = '',
  }) async {
    final candidates = _authUidCandidates(
      existingUser: existingUser,
      fallbackPhone: fallbackPhone,
    );
    for (final candidate in candidates) {
      final token = await _requestCustomTokenForUid(
        candidate,
        driverPassword: driverPassword,
      );
      if (token != null && token.isNotEmpty) {
        return token;
      }
    }
    return null;
  }

  Future<UsersRecord?> _findExistingUserByPhone(String normalizedPhone) async {
    final response = await backendLookupUserByPhone(
      phone: normalizedPhone,
    ).timeout(const Duration(seconds: 6));
    final user = response['user'];
    if (response['success'] == true && user is Map) {
      return usersRecordFromBackendUser(Map<String, dynamic>.from(user));
    }
    return null;
  }

  bool _isPreviouslyRegisteredUser(UsersRecord user) {
    if (hasCompletedPassengerProfile(user)) {
      return true;
    }
    if (userHasApprovedDriverAccess(user)) {
      return true;
    }
    if (isDriverRegistrationPendingReview(user)) {
      return true;
    }
    return false;
  }

  Future<void> _showLoginRetryDialog({String? message}) async {
    if (!mounted) return;
    final text = message ??
        FFLocalizations.of(context).getVariableText(
          ruText: 'Ошибка сети. Проверьте интернет и попробуйте ещё раз.',
          kkText: 'Желі қатесі. Интернетті тексеріп, қайталап көріңіз.',
        );
    _setLoginStatus(text, isError: true);
    await showDialog(
      context: context,
      builder: (alertDialogContext) {
        return WebViewAware(
          child: AlertDialog(
            backgroundColor: Colors.white,
            content: Text(text, style: const TextStyle(color: Colors.black)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(alertDialogContext),
                child: Text(
                  FFLocalizations.of(
                    context,
                  ).getVariableText(ruText: 'Повторить', kkText: 'Қайталау'),
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openRoleOnboardingSheet() async {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }
    final router = GoRouter.of(context);
    router.clearRedirectLocation();
    router.prepareAuthEvent(true);
    final selectedRole = await showModalBottomSheet<String>(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      context: context,
      builder: (context) {
        return WebViewAware(
          child: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height,
              child: SetRoleWidget(),
            ),
          ),
        );
      },
    );

    if (!mounted || selectedRole == null) {
      return;
    }
    FFAppState().pendingRegistrationRole = selectedRole;
    FFAppState().update(() {});
    final targetRoute = selectedRole == 'driver'
        ? SetProfileDriverWidget.routeName
        : SetProfileWidget.routeName;
    context.goNamedAuth(
      targetRoute,
      context.mounted,
      ignoreRedirect: true,
      extra: <String, dynamic>{
        kTransitionInfoKey: TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.scale,
          alignment: Alignment.bottomCenter,
        ),
      },
    );
  }

  Future<void> _routeSignedInUser({
    required UsersRecord? user,
    required bool signedInAsAdmin,
  }) async {
    final router = GoRouter.of(context);
    router.clearRedirectLocation();
    router.prepareAuthEvent(true);
    if (signedInAsAdmin) {
      await FFAppState().clearTransientAuthFlowState(notify: false);
      context.goNamedAuth(
        AdminHomeWidget.routeName,
        context.mounted,
        ignoreRedirect: true,
        extra: <String, dynamic>{
          kTransitionInfoKey: TransitionInfo(
            hasTransition: true,
            transitionType: PageTransitionType.scale,
            alignment: Alignment.bottomCenter,
          ),
        },
      );
      return;
    }

    final resolvedUser = user;
    if (resolvedUser != null) {
      currentUserDocument = resolvedUser;
    }
    final hasProfile = hasCompletedPassengerProfile(resolvedUser);
    final needsDriverFlow = needsDriverRegistration(resolvedUser);
    final driverPendingReview = isDriverRegistrationPendingReview(resolvedUser);
    final pendingRole =
        FFAppState().pendingRegistrationRole.trim().toLowerCase();
    if (hasProfile && !needsDriverFlow && pendingRole.isNotEmpty) {
      FFAppState().pendingRegistrationRole = '';
      FFAppState().update(() {});
    }
    if (driverPendingReview) {
      await FFAppState().clearTransientAuthFlowState(notify: false);
      context.goNamedAuth(
        ProfileWidget.routeName,
        context.mounted,
        ignoreRedirect: true,
        extra: <String, dynamic>{
          kTransitionInfoKey: TransitionInfo(
            hasTransition: true,
            transitionType: PageTransitionType.scale,
            alignment: Alignment.bottomCenter,
          ),
        },
      );
      return;
    }

    if (hasProfile && !needsDriverFlow) {
      await FFAppState().clearTransientAuthFlowState(notify: false);
      if (UserModeResolver.canOpenDriverScreens(resolvedUser)) {
        context.goNamedAuth(
          HomeDriverWidget.routeName,
          context.mounted,
          ignoreRedirect: true,
          extra: <String, dynamic>{
            kTransitionInfoKey: TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.scale,
              alignment: Alignment.bottomCenter,
            ),
          },
        );
      } else {
        context.goNamedAuth(
          HomePageWidget.routeName,
          context.mounted,
          ignoreRedirect: true,
          extra: <String, dynamic>{
            kTransitionInfoKey: TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.scale,
              alignment: Alignment.bottomCenter,
            ),
          },
        );
      }
      return;
    }

    if (pendingRole.isEmpty) {
      await _openRoleOnboardingSheet();
      return;
    }

    if (pendingRole == 'driver' || needsDriverFlow) {
      context.goNamedAuth(
        SetProfileDriverWidget.routeName,
        context.mounted,
        ignoreRedirect: true,
        extra: <String, dynamic>{
          kTransitionInfoKey: TransitionInfo(
            hasTransition: true,
            transitionType: PageTransitionType.scale,
            alignment: Alignment.bottomCenter,
          ),
        },
      );
      return;
    }

    if (pendingRole == 'passenger' ||
        needsPassengerRegistration(resolvedUser)) {
      context.goNamedAuth(
        SetProfileWidget.routeName,
        context.mounted,
        ignoreRedirect: true,
        extra: <String, dynamic>{
          kTransitionInfoKey: TransitionInfo(
            hasTransition: true,
            transitionType: PageTransitionType.scale,
            alignment: Alignment.bottomCenter,
          ),
        },
      );
      return;
    }

    if (isDriverRegistrationPendingReview(resolvedUser)) {
      context.goNamedAuth(
        ProfileWidget.routeName,
        context.mounted,
        ignoreRedirect: true,
        extra: <String, dynamic>{
          kTransitionInfoKey: TransitionInfo(
            hasTransition: true,
            transitionType: PageTransitionType.scale,
            alignment: Alignment.bottomCenter,
          ),
        },
      );
      return;
    }

    if (needsRoleSelection(resolvedUser)) {
      await _openRoleOnboardingSheet();
      return;
    }

    await _openRoleOnboardingSheet();
  }

  Future<void> _showWebAdminOnlyDialog() async {
    await showDialog(
      context: context,
      builder: (alertDialogContext) {
        return WebViewAware(
          child: AlertDialog(
            backgroundColor: Colors.white,
            content: Text(
              FFLocalizations.of(context).getVariableText(
                ruText:
                    'Веб-версия доступна только администратору. Для пассажиров и водителей используйте мобильное приложение.',
                kkText:
                    'Веб-нұсқа тек әкімшіге арналған. Жолаушылар мен жүргізушілер мобильді қолданбаны пайдалануы керек.',
              ),
              style: const TextStyle(color: Colors.black),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(alertDialogContext),
                child: Text(
                  FFLocalizations.of(
                    context,
                  ).getVariableText(ruText: 'Закрыть', kkText: 'Жабу'),
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showInvalidAdminPasswordDialog() async {
    await showDialog(
      context: context,
      builder: (alertDialogContext) {
        return WebViewAware(
          child: AlertDialog(
            backgroundColor: Colors.white,
            content: const Text(
              'Неверный пароль администратора',
              style: TextStyle(color: Colors.black),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(alertDialogContext),
                child: const Text('Ok', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _verifySavedPasswordIfNeeded(UsersRecord? user) async {
    final expectedPassword = ((user?.password ?? '').isNotEmpty
                ? user?.password
                : user?.snapshotData['password'])
            ?.toString()
            .trim() ??
        '';
    if (expectedPassword.isEmpty) {
      return '';
    }
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return WebViewAware(
              child: AlertDialog(
                backgroundColor: Colors.white,
                title: const Text(
                  'Пароль',
                  style: TextStyle(color: Colors.black),
                ),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Введите пароль',
                  ),
                  onSubmitted: (_) => Navigator.pop(dialogContext, true),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Отмена'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Войти'),
                  ),
                ],
              ),
            );
          },
        ) ??
        false;
    final ok = confirmed && controller.text.trim() == expectedPassword;
    controller.dispose();
    if (!ok) {
      _setLoginStatus('Неверный пароль', isError: true);
    }
    return ok ? controller.text.trim() : null;
  }

  Future<String?> _requestBackendPassword() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return WebViewAware(
              child: AlertDialog(
                backgroundColor: Colors.white,
                title: const Text(
                  'Пароль',
                  style: TextStyle(color: Colors.black),
                ),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Введите пароль',
                  ),
                  onSubmitted: (_) => Navigator.pop(dialogContext, true),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Отмена'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Войти'),
                  ),
                ],
              ),
            );
          },
        ) ??
        false;
    final password = confirmed ? controller.text.trim() : null;
    controller.dispose();
    return password?.isNotEmpty == true ? password : null;
  }

  Future<bool> _signInWithBackendPassword(String normalizedPhone) async {
    final password = await _requestBackendPassword();
    if (password == null) {
      return true;
    }
    _setLoginStatus(
      'Пользователь найден. Выполняем вход...',
      buttonMessage: 'Входим...',
    );
    final result = await backendPasswordLogin(
      phone: normalizedPhone,
      password: password,
    );
    if (result['success'] != true) {
      _setLoginStatus(
        result['error']?.toString().trim().isNotEmpty == true
            ? result['error'].toString()
            : 'Не удалось войти. Проверьте пароль.',
        isError: true,
      );
      return false;
    }

    final userPayload = result['user'];
    final backendUser = activateBackendUser(
      userPayload is Map ? Map<String, dynamic>.from(userPayload) : null,
    );
    AppStateNotifier.instance.updateNotifyOnAuthChange(false);
    AppStateNotifier.instance.update(backendUser);
    FFAppState().smsKod = 0;
    FFAppState().pendingRegistrationRole = '';
    FFAppState().phone = normalizedPhone;
    await FFAppState().clearTransientAuthFlowState(notify: false);
    FFAppState().update(() {});

    final user =
        userPayload is Map ? Map<String, dynamic>.from(userPayload) : {};
    final isApprovedDriver = user['isDriver'] == true &&
        user['statusDriver']?.toString().toLowerCase() == 'approved';
    final roleState = user['roleState']?.toString().toUpperCase() ?? '';
    final targetRoute = isApprovedDriver && roleState.contains('DRIVER')
        ? HomeDriverWidget.routeName
        : HomePageWidget.routeName;

    final router = GoRouter.of(context);
    router.clearRedirectLocation();
    router.prepareAuthEvent(true);
    context.goNamedAuth(
      targetRoute,
      context.mounted,
      ignoreRedirect: true,
      extra: <String, dynamic>{
        kTransitionInfoKey: TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.scale,
          alignment: Alignment.bottomCenter,
        ),
      },
    );
    return true;
  }

  Future<void> _showInvalidPhoneDialog() async {
    _setLoginStatus('Неверный номер телефона', isError: true);
    await showDialog(
      context: context,
      builder: (alertDialogContext) {
        return WebViewAware(
          child: AlertDialog(
            backgroundColor: Colors.white,
            content: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Неверный номер телефона',
                kkText: 'Телефон нөмірі қате',
              ),
              style: const TextStyle(color: Colors.black),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(alertDialogContext),
                child: Text(
                  FFLocalizations.of(
                    context,
                  ).getVariableText(ruText: 'Закрыть', kkText: 'Жабу'),
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleContinue() async {
    if (_isSubmitting) {
      return;
    }
    if (!(_model.checkboxListTileValue ?? false)) {
      _setLoginStatus('Примите пользовательское соглашение', isError: true);
      return;
    }

    String? normalizedPhoneForRestore;
    setState(() {
      _isSubmitting = true;
      _loginStatusMessage = '';
      _loginStatusIsError = false;
      _loginButtonMessage = 'Проверяем номер...';
    });
    try {
      if (loggedIn || currentUserUid.trim().isNotEmpty) {
        await authManager.prepareForFreshSignIn();
      }

      final normalizedPhone = _normalizedPhone(_model.textController.text);
      if (normalizedPhone == null) {
        await _showInvalidPhoneDialog();
        return;
      }
      normalizedPhoneForRestore = normalizedPhone;
      _restorePhoneInput(normalizedPhone);

      final previousPhone = FFAppState().phone.trim();
      if (previousPhone.isNotEmpty && previousPhone != normalizedPhone) {
        FFAppState().pendingRegistrationRole = '';
        FFAppState().smsKod = 0;
        FFAppState().syncLegacyOrderRefs(
          passengerOrderRef: null,
          driverOrderRef: null,
        );
        FFAppState().clearPassengerOrderCreationState();
      }

      FFAppState().phone = normalizedPhone;
      FFAppState().update(() {});
      _setLoginStatus(
        'Проверяем номер...',
        buttonMessage: 'Проверяем номер...',
      );

      if (isAdminPhone(FFAppState().phone)) {
        final adminPasswordValue =
            (_model.adminPasswordController?.text ?? '').trim();
        if (adminPasswordValue.isEmpty) {
          _setLoginStatus('Неверный пароль администратора', isError: true);
          await _showInvalidAdminPasswordDialog();
          return;
        }
        _setLoginStatus('Выполняем вход...', buttonMessage: 'Входим...');
        final result = await backendPasswordLogin(
          phone: FFAppState().phone,
          password: adminPasswordValue,
        );
        if (result['success'] != true) {
          _setLoginStatus(
            (result['error'] ?? 'Неверный пароль администратора').toString(),
            isError: true,
          );
          _restorePhoneInput(normalizedPhone);
          await _showInvalidAdminPasswordDialog();
          return;
        }
        final userPayload = result['user'];
        final userMap = userPayload is Map
            ? Map<String, dynamic>.from(userPayload)
            : <String, dynamic>{};
        final backendUser = activateBackendUser(userMap);
        AppStateNotifier.instance.updateNotifyOnAuthChange(false);
        AppStateNotifier.instance.update(backendUser);
        FFAppState().smsKod = 0;
        FFAppState().pendingRegistrationRole = '';
        FFAppState().update(() {});
        final resolvedUser = usersRecordFromBackendUser(userMap);
        await _routeSignedInUser(user: resolvedUser, signedInAsAdmin: true);
        return;
      }

      if (kIsWeb && isWebAdminHost() && !isAdminPhone(normalizedPhone)) {
        _setLoginStatus(
          'Веб-версия доступна только администратору.',
          isError: true,
        );
        await _showWebAdminOnlyDialog();
        return;
      }

      if (isMTaxiBackendEnabled) {
        final existingUser = await _findExistingUserByPhone(normalizedPhone);
        if (existingUser != null &&
            _isPreviouslyRegisteredUser(existingUser) &&
            !needsPasswordSetup(existingUser)) {
          final handled = await _signInWithBackendPassword(normalizedPhone);
          if (handled) {
            return;
          }
          _restorePhoneInput(normalizedPhone);
          return;
        }
      }

      final existingUser = await _findExistingUserByPhone(normalizedPhone);
      if (existingUser != null && _isPreviouslyRegisteredUser(existingUser)) {
        final savedPassword = await _verifySavedPasswordIfNeeded(existingUser);
        if (savedPassword == null) {
          return;
        }
        _setLoginStatus(
          'Пользователь найден. Выполняем вход...',
          buttonMessage: 'Входим...',
        );
        final token = await _requestCustomToken(
          existingUser: existingUser,
          fallbackPhone: normalizedPhone,
          driverPassword: savedPassword,
        );
        if (token == null || token.trim().isEmpty) {
          _restorePhoneInput(normalizedPhone);
          await _showLoginRetryDialog(
            message: _lastTokenRequestError.trim().isNotEmpty
                ? _lastTokenRequestError
                : 'Не удалось подготовить вход. Попробуйте еще раз.',
          );
          return;
        }
        await authManager.prepareForFreshSignIn();
        GoRouter.of(context).prepareAuthEvent();
        final user = await authManager
            .signInWithJwtToken(context, token)
            .timeout(const Duration(seconds: 12));
        if (user == null) {
          _restorePhoneInput(normalizedPhone);
          await _showLoginRetryDialog(
            message: 'Ошибка сети. Не удалось войти.',
          );
          return;
        }
        FFAppState().smsKod = 0;
        FFAppState().update(() {});
        final resolvedUser = await resolveSignedInUserRecord(
          preferredUser: existingUser,
          fallbackUid: user.uid,
        );
        await _routeSignedInUser(
          user: resolvedUser ?? existingUser,
          signedInAsAdmin: false,
        );
        return;
      }

      FFAppState().pendingRegistrationRole = '';
      _setLoginStatus(
        'Отправляем SMS-код...',
        buttonMessage: 'Отправляем код...',
      );
      final smsResult = await backendRequestSmsCode(
        phone: normalizedPhone,
      ).timeout(const Duration(seconds: 12));
      final smsCode = int.tryParse(
        (smsResult['smsCode'] ?? smsResult['devCode'] ?? '').toString(),
      );
      if (smsResult['success'] != true) {
        _restorePhoneInput(normalizedPhone);
        await _showLoginRetryDialog(
          message: (smsResult['error'] ??
                  'Код не отправлен. Проверьте номер телефона или попробуйте позже.')
              .toString(),
        );
        return;
      }
      FFAppState().smsKod = smsCode ?? 0;
      FFAppState().update(() {});
      _setLoginStatus('SMS-код отправлен.', buttonMessage: 'Код отправлен');
      final router = GoRouter.of(context);
      router.clearRedirectLocation();
      router.prepareAuthEvent(true);
      context.goNamedAuth(
        SmsVireficationWidget.routeName,
        context.mounted,
        ignoreRedirect: true,
        extra: <String, dynamic>{
          kTransitionInfoKey: TransitionInfo(
            hasTransition: true,
            transitionType: PageTransitionType.scale,
            alignment: Alignment.bottomCenter,
          ),
        },
      );
    } on TimeoutException {
      if (normalizedPhoneForRestore != null) {
        _restorePhoneInput(normalizedPhoneForRestore);
      }
      await _showLoginRetryDialog(
        message: 'Ошибка сети. Сервер долго не отвечает.',
      );
    } catch (e) {
      if (normalizedPhoneForRestore != null) {
        _restorePhoneInput(normalizedPhoneForRestore);
      }
      await _showLoginRetryDialog(
        message: 'Ошибка сети. Не удалось продолжить вход.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _loginButtonMessage = '';
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _model = createModel(context, () => LoginModel());
    authManager.resetTransientAuthState();

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await _requestStartupPermissions();
    });

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();
    _model.textFieldFocusNode!.addListener(_handlePhoneFieldFocusChange);
    _model.adminPasswordController ??= TextEditingController();
    _model.adminPasswordFocusNode ??= FocusNode();

    _model.textFieldMask = MaskTextInputFormatter(mask: '(###) ###-##-##');
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _model.textFieldFocusNode?.removeListener(_handlePhoneFieldFocusChange);
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    if (!_showPhoneLogin) {
      return _buildWelcomeScreen(context);
    }
    final enteredPhone = _normalizedPhone(_model.textController.text);
    final isAdminInput = enteredPhone != null && isAdminPhone(enteredPhone);
    final hasValidPhone = enteredPhone != null;
    final canContinue = hasValidPhone && !_isSubmitting;
    final disabledReason = _isSubmitting
        ? ''
        : !hasValidPhone
            ? 'Введите корректный номер телефона'
            : '';
    final compactLayout = MediaQuery.sizeOf(context).height < 520.0;
    final showThemeToggle = MediaQuery.sizeOf(context).width >= 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const mintColor = Color(0xFF28D8C6);
    const orangeColor = Color(0xFFFF6B00);
    const darkPageBg = Color(0xFF1B2528);
    const lightPageBg = Color(0xFFEFF2F6);
    final effectivePageBg = isDark ? darkPageBg : lightPageBg;
    final effectiveSurface = isDark ? const Color(0xFF13191D) : Colors.white;
    final effectiveSurfaceAlt =
        isDark ? const Color(0xFF243437) : const Color(0xFFF7F3F8);
    final effectivePrimaryText =
        isDark ? Colors.white : const Color(0xFF172126);
    final effectiveSecondaryText =
        isDark ? const Color(0xFF9EA8B0) : const Color(0xFF5A6670);
    final effectiveBorder =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFD8DEE6);
    final effectiveCtaColor = isDark ? mintColor : orangeColor;
    final agreementBlock = const SizedBox.shrink();
    final disabledReasonText = disabledReason.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              disabledReason,
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.readexPro(
                      fontWeight: FontWeight.w500,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w500,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
            ),
          );

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: effectivePageBg,
        appBar: AppBar(
          backgroundColor: effectivePageBg,
          toolbarHeight: 0.0,
          automaticallyImplyLeading: false,
          centerTitle: true,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(color: effectivePageBg),
            child: Align(
              alignment: AlignmentDirectional(0.0, -1.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        24.0,
                        compactLayout ? 20.0 : 70.0,
                        24.0,
                        MediaQuery.viewInsetsOf(context).bottom + 24.0,
                      ),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 390.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 96.0,
                                height: 96.0,
                                decoration: const BoxDecoration(
                                  color: mintColor,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18.0),
                                  child: Image.asset(
                                    'assets/images/app_launcher_icon.png',
                                    width: 58.0,
                                    height: 58.0,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                0.0,
                                compactLayout ? 22.0 : 28.0,
                                0.0,
                                0.0,
                              ),
                              child: Text(
                                'Қош келдіңіздер! Добро пожаловать!',
                                textAlign: TextAlign.center,
                                style: FlutterFlowTheme.of(context)
                                    .headlineSmall
                                    .override(
                                      font: GoogleFonts.readexPro(
                                        fontWeight: FontWeight.w800,
                                      ),
                                      color: effectivePrimaryText,
                                      fontSize: compactLayout ? 13.0 : 14.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            Padding(
                              key: _phoneFieldKey,
                              padding: EdgeInsetsDirectional.fromSTEB(
                                0.0,
                                compactLayout ? 20.0 : 26.0,
                                0.0,
                                0.0,
                              ),
                              child: TextFormField(
                                controller: _model.textController,
                                focusNode: _model.textFieldFocusNode,
                                autofocus: false,
                                obscureText: false,
                                onTap: _ensurePhoneFieldVisible,
                                onChanged: (_) {
                                  _normalizePhoneInput();
                                  safeSetState(() {});
                                },
                                onFieldSubmitted: (_) {
                                  if (_isSubmitting) {
                                    return;
                                  }
                                  if (canContinue) {
                                    _handleContinue();
                                  } else if (!hasValidPhone) {
                                    _setLoginStatus(
                                      'Введите корректный номер телефона',
                                      isError: true,
                                    );
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: FFLocalizations.of(
                                    context,
                                  ).getText('mfjd8bcg' /* Номер телефона */),
                                  labelStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.readexPro(
                                          fontWeight: FontWeight.normal,
                                          fontStyle: FlutterFlowTheme.of(
                                            context,
                                          ).bodyMedium.fontStyle,
                                        ),
                                        color: effectiveSecondaryText,
                                        fontSize: compactLayout ? 12.0 : 14.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.normal,
                                        fontStyle: FlutterFlowTheme.of(
                                          context,
                                        ).bodyMedium.fontStyle,
                                      ),
                                  prefixText: '+7 ',
                                  prefixStyle: FlutterFlowTheme.of(context)
                                      .bodyLarge
                                      .override(
                                        font: GoogleFonts.readexPro(),
                                        color: effectivePrimaryText,
                                        fontSize: 16.0,
                                        letterSpacing: 0.0,
                                      ),
                                  hintText: '(___) ___-__-__',
                                  hintStyle: FlutterFlowTheme.of(context)
                                      .bodyLarge
                                      .override(
                                        font: GoogleFonts.readexPro(
                                          fontWeight: FontWeight.normal,
                                          fontStyle: FlutterFlowTheme.of(
                                            context,
                                          ).bodyLarge.fontStyle,
                                        ),
                                        color: effectiveSecondaryText
                                            .withValues(alpha: 0.78),
                                        fontSize: 16.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.normal,
                                        fontStyle: FlutterFlowTheme.of(
                                          context,
                                        ).bodyLarge.fontStyle,
                                      ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: effectiveBorder,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(6.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: effectiveBorder,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(6.0),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: effectiveBorder,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(6.0),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: effectiveBorder,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(6.0),
                                  ),
                                  filled: true,
                                  fillColor: effectiveSurface,
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.readexPro(
                                        fontWeight: FontWeight.normal,
                                        fontStyle: FlutterFlowTheme.of(
                                          context,
                                        ).bodyMedium.fontStyle,
                                      ),
                                      color: effectivePrimaryText,
                                      fontSize: 14.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.normal,
                                      fontStyle: FlutterFlowTheme.of(
                                        context,
                                      ).bodyMedium.fontStyle,
                                    ),
                                keyboardType: TextInputType.phone,
                                validator: _model.textControllerValidator
                                    .asValidator(context),
                                inputFormatters: [_model.textFieldMask],
                              ),
                            ),
                            if (_loginStatusMessage.isNotEmpty)
                              Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                  16.0,
                                  8.0,
                                  16.0,
                                  0.0,
                                ),
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    _loginStatusMessage,
                                    style: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .override(
                                          font: GoogleFonts.readexPro(
                                            fontWeight: FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(
                                              context,
                                            ).bodySmall.fontStyle,
                                          ),
                                          color: _loginStatusIsError
                                              ? FlutterFlowTheme.of(
                                                  context,
                                                ).error
                                              : FlutterFlowTheme.of(
                                                  context,
                                                ).secondaryText,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w500,
                                          fontStyle: FlutterFlowTheme.of(
                                            context,
                                          ).bodySmall.fontStyle,
                                        ),
                                  ),
                                ),
                              ),
                            if (isAdminInput)
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                  16.0,
                                  10.0,
                                  16.0,
                                  0.0,
                                ),
                                child: TextFormField(
                                  controller: _model.adminPasswordController,
                                  focusNode: _model.adminPasswordFocusNode,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: 'Пароль администратора',
                                    labelStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.readexPro(
                                            fontWeight: FontWeight.normal,
                                            fontStyle: FlutterFlowTheme.of(
                                              context,
                                            ).bodyMedium.fontStyle,
                                          ),
                                          color: effectiveSecondaryText,
                                          fontSize: 14.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.normal,
                                          fontStyle: FlutterFlowTheme.of(
                                            context,
                                          ).bodyMedium.fontStyle,
                                        ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: mintColor,
                                        width: 2.0,
                                      ),
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: mintColor,
                                        width: 2.0,
                                      ),
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    filled: true,
                                  ),
                                ),
                              ),
                            agreementBlock,
                            disabledReasonText,
                            Padding(
                              padding: const EdgeInsets.only(top: 18.0),
                              child: FFButtonWidget(
                                onPressed: canContinue ? _handleContinue : null,
                                text: _isSubmitting
                                    ? (_loginButtonMessage.isNotEmpty
                                        ? _loginButtonMessage
                                        : 'Проверяем номер...')
                                    : 'Получить SMS-код',
                                options: FFButtonOptions(
                                  width: double.infinity,
                                  height: 48.0,
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                    0.0,
                                    0.0,
                                    0.0,
                                    0.0,
                                  ),
                                  iconPadding:
                                      const EdgeInsetsDirectional.fromSTEB(
                                    0.0,
                                    0.0,
                                    0.0,
                                    0.0,
                                  ),
                                  color: effectiveCtaColor,
                                  textStyle: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .override(
                                        font: GoogleFonts.readexPro(
                                          fontWeight: FontWeight.w700,
                                        ),
                                        color: Colors.white,
                                        fontSize: 15.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w700,
                                      ),
                                  elevation: 0.0,
                                  borderRadius: BorderRadius.circular(8.0),
                                  disabledColor: effectiveCtaColor,
                                  disabledTextColor: Colors.white,
                                ),
                              ),
                            ),
                            if (showThemeToggle && !compactLayout)
                              Padding(
                                padding: const EdgeInsets.only(top: 20.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                        0.0,
                                        0.0,
                                        5.0,
                                        0.0,
                                      ),
                                      child: Text(
                                        FFLocalizations.of(
                                          context,
                                        ).getText('wa85e8cz' /* Темная тема */),
                                        style: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .override(
                                              font: GoogleFonts.readexPro(),
                                              color: effectiveSecondaryText,
                                              fontSize: 12.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                    Transform.scale(
                                      scale: 0.82,
                                      child: Switch.adaptive(
                                        value: _model.switchValue ??= !isDark,
                                        onChanged: (newValue) async {
                                          safeSetState(
                                            () => _model.switchValue = newValue,
                                          );
                                          if (newValue) {
                                            setDarkModeSetting(
                                              context,
                                              ThemeMode.light,
                                            );
                                          } else {
                                            setDarkModeSetting(
                                              context,
                                              ThemeMode.dark,
                                            );
                                          }
                                        },
                                        activeThumbColor: mintColor,
                                        activeTrackColor: mintColor,
                                        inactiveTrackColor: effectiveSurfaceAlt,
                                        inactiveThumbColor: isDark
                                            ? Colors.white
                                            : const Color(0xFF172126),
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                        5.0,
                                        0.0,
                                        0.0,
                                        0.0,
                                      ),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          't1j6apn9' /* Светлая тема */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .override(
                                              font: GoogleFonts.readexPro(),
                                              color: effectiveSecondaryText,
                                              fontSize: 12.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
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

  Future<void> _requestStartupPermissions() async {
    await requestPermission(notificationsPermission);
  }

  Widget _buildWelcomeScreen(BuildContext context) {
    const pageBg = Color(0xFF16071F);
    const mintColor = Color(0xFF28D8C6);
    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/app_launcher_icon.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'MTaxi',
                    style: GoogleFonts.readexPro(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 54),
              Text(
                'Ваше такси. Без\nлишнего.',
                style: GoogleFonts.readexPro(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Фиксированная цена до заказа. Понятно пассажиру и водителю.',
                style: GoogleFonts.readexPro(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const _MTaxiWelcomeCar(),
              const Spacer(),
              Container(
                height: 48,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Қазақша',
                  style: GoogleFonts.readexPro(
                    color: const Color(0xFFC8C0CD),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => safeSetState(() => _showPhoneLogin = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mintColor,
                    foregroundColor: const Color(0xFF063733),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Начать',
                    style: GoogleFonts.readexPro(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'MTaxi',
                  style: GoogleFonts.readexPro(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MTaxiWelcomeCar extends StatelessWidget {
  const _MTaxiWelcomeCar();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 232,
        height: 118,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: const CustomPaint(painter: _MTaxiCarPainter()),
      ),
    );
  }
}

class _MTaxiCarPainter extends CustomPainter {
  const _MTaxiCarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()..color = const Color(0xFF28D8C6);
    final roofPaint = Paint()..color = const Color(0xFFD8BB72);
    final darkPaint = Paint()..color = const Color(0xFF2A1234);
    final wheelInnerPaint = Paint()..color = Colors.white;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.16,
        size.height * 0.42,
        size.width * 0.68,
        size.height * 0.30,
      ),
      Radius.circular(size.height * 0.14),
    );
    canvas.drawRRect(body, bodyPaint);
    final roofPath = Path()
      ..moveTo(size.width * 0.40, size.height * 0.42)
      ..lineTo(size.width * 0.50, size.height * 0.20)
      ..lineTo(size.width * 0.66, size.height * 0.42)
      ..close();
    canvas.drawPath(roofPath, roofPaint);
    for (final centerX in [size.width * 0.30, size.width * 0.70]) {
      final center = Offset(centerX, size.height * 0.72);
      canvas.drawCircle(center, size.height * 0.16, darkPaint);
      canvas.drawCircle(center, size.height * 0.07, wheelInnerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
