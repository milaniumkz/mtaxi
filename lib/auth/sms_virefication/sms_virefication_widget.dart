import '/auth/backend_auth/auth_util.dart';
import '/auth/backend_auth/backend_user_provider.dart';
import '/backend/backend.dart';
import '/backend/backend_session.dart';
import '/backend/backend_user_adapter.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/component/set_role/set_role_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import '/index.dart';
import '/admin/admin_utils.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
import 'sms_virefication_model.dart';
export 'sms_virefication_model.dart';

class SmsVireficationWidget extends StatefulWidget {
  const SmsVireficationWidget({super.key});

  static String routeName = 'smsVirefication';
  static String routePath = '/smsVirefication';

  @override
  State<SmsVireficationWidget> createState() => _SmsVireficationWidgetState();
}

class _SmsVireficationWidgetState extends State<SmsVireficationWidget> {
  late SmsVireficationModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _codeFieldKey = GlobalKey();
  final GlobalKey _adminPasswordFieldKey = GlobalKey();
  bool _isSubmitting = false;
  bool _isResendingCode = false;
  String _statusMessage = '';
  bool _statusIsError = false;
  String _lastTokenRequestError = '';

  String _codeDigits(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  String get _expectedSmsCode => _codeDigits(FFAppState().smsKod.toString());

  String get _enteredSmsCode =>
      _codeDigits(_model.pinCodeController?.text ?? '');

  Future<UsersRecord?> _findExistingUserByPhone(String normalizedPhone) async {
    final response = await backendLookupUserByPhone(phone: normalizedPhone)
        .timeout(const Duration(seconds: 6));
    final user = response['user'];
    if (response['success'] == true && user is Map) {
      return usersRecordFromBackendUser(Map<String, dynamic>.from(user));
    }
    return null;
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
      await _showMessageDialog('Неверный пароль');
    }
    return ok ? controller.text.trim() : null;
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
          timeout: const Duration(seconds: 12),
        );
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

  Future<void> _showMessageDialog(String message) async {
    if (mounted) {
      setState(() {
        _statusMessage = message;
        _statusIsError = true;
      });
    }
    await showDialog(
      context: context,
      builder: (alertDialogContext) {
        return WebViewAware(
          child: AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(alertDialogContext),
                child: const Text('Ok'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resendSmsCode() async {
    if (_isResendingCode || _isSubmitting) {
      return;
    }
    final phone = FFAppState().phone.trim();
    if (phone.isEmpty) {
      await _showMessageDialog('Номер телефона не найден. Вернитесь назад.');
      return;
    }

    if (mounted) {
      setState(() {
        _isResendingCode = true;
        _statusMessage = 'Отправляем новый код...';
        _statusIsError = false;
      });
    }
    try {
      bool codeSent = false;
      final result = await backendRequestSmsCode(
        phone: phone,
      ).timeout(const Duration(seconds: 12));
      final smsCode = int.tryParse(
        (result['smsCode'] ?? result['devCode'] ?? '').toString(),
      );
      if (result['success'] == true) {
        FFAppState().smsKod = smsCode ?? 0;
        FFAppState().update(() {});
        codeSent = true;
      }

      if (!mounted) {
        return;
      }

      if (codeSent) {
        setState(() {
          _statusMessage = 'Новый код отправлен';
          _statusIsError = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Новый код отправлен на $phone'),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      await _showMessageDialog('Не удалось отправить код. Проверьте интернет.');
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _statusMessage = 'Сервер долго не отвечает. Попробуйте еще раз.';
          _statusIsError = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage =
              'Не удалось отправить код. Проверьте интернет и попробуйте еще раз.';
          _statusIsError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResendingCode = false;
        });
      }
    }
  }

  Future<void> _dismissKeyboard() async {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  Future<String?> _chooseRegistrationRole() async {
    await _dismissKeyboard();
    if (!mounted) {
      return null;
    }
    final router = GoRouter.of(context);
    router.clearRedirectLocation();
    router.prepareAuthEvent(true);
    return showModalBottomSheet<String>(
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
  }

  Future<void> _applyRegistrationRole(String role) async {
    FFAppState().pendingRegistrationRole = role;
    FFAppState().update(() {});
  }

  void _goToRegistrationRole(String role) {
    final router = GoRouter.of(context);
    router.clearRedirectLocation();
    router.prepareAuthEvent(true);
    final targetRoute = role == 'driver'
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

  Future<void> _openRoleOnboardingSheet() async {
    final selectedRole = await _chooseRegistrationRole();
    if (!mounted || selectedRole == null) {
      return;
    }
    await _applyRegistrationRole(selectedRole);
    if (!mounted) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) {
      return;
    }
    _goToRegistrationRole(selectedRole);
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

  Future<bool> _continueWithBackendSmsSession({
    required bool signedInAsAdmin,
  }) async {
    final response = await makeCloudCall(
      'createSmsSession',
      {'phone': FFAppState().phone.trim()},
      timeout: const Duration(seconds: 10),
    );
    final token = (response['token'] ?? '').toString().trim();
    final userPayload = response['user'];
    if (response['success'] != true || token.isEmpty || userPayload is! Map) {
      if (mounted) {
        setState(() {
          _statusMessage =
              (response['error'] ?? 'Не удалось войти.').toString().trim();
          _statusIsError = true;
        });
      }
      return false;
    }

    final userMap = Map<String, dynamic>.from(userPayload);
    await saveBackendSession(token: token, user: userMap);
    final backendUser = activateBackendUser(userMap);
    AppStateNotifier.instance.updateNotifyOnAuthChange(false);
    AppStateNotifier.instance.update(backendUser);
    FFAppState().smsKod = 0;
    FFAppState().update(() {});
    final record = usersRecordFromBackendUser(userMap);
    await _routeSignedInUser(
      user: record,
      signedInAsAdmin: signedInAsAdmin,
    );
    return true;
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SmsVireficationModel());
    authManager.resetTransientAuthState();
    FFAppState().pendingRegistrationRole = '';

    _model.pinCodeFocusNode ??= FocusNode();
    _model.adminPasswordFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final isAdminPhoneValue = isAdminPhone(FFAppState().phone);
    final canContinue = !_isSubmitting &&
        (isAdminPhoneValue
            ? ((_model.adminPasswordController?.text ?? '').trim().isNotEmpty)
            : _enteredSmsCode.length == 4);
    final disabledReason = _isSubmitting
        ? ''
        : isAdminPhoneValue
            ? ((_model.adminPasswordController?.text ?? '').trim().isEmpty
                ? 'Введите пароль администратора'
                : '')
            : _enteredSmsCode.length != 4
                ? 'Введите 4-значный SMS-код'
                : '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const darkSurface = Colors.transparent;
    const mintColor = Color(0xFF28D8C6);
    const orangeColor = Color(0xFFFF6B00);
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFEFF2F6);
    final formText = isDark ? Colors.white : const Color(0xFF1E1525);
    final formMuted =
        isDark ? const Color(0xFF9EA8B0) : const Color(0xFF5B6670);
    final formFieldBg =
        isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final formBorder =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFD8DEE6);
    final ctaColor = isDark ? mintColor : orangeColor;
    final ctaTextColor = isDark ? const Color(0xFF071718) : Colors.white;
    final appBarBg = isDark ? mintColor : formFieldBg;
    final appBarText = isDark ? Colors.white : formText;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: pageBg,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: appBarBg,
          elevation: 0.0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: appBarText),
            onPressed: () => context.safePop(),
          ),
          title: Text(
            isAdminPhoneValue ? 'Пароль администратора' : 'Введите SMS-код',
            style: GoogleFonts.readexPro(
              color: appBarText,
              fontSize: 22.0,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(color: pageBg),
            child: Align(
              alignment: AlignmentDirectional(0.0, -1.0),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24.0, 50.0, 24.0, 120.0),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 390.0),
                  padding: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: darkSurface,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isAdminPhoneValue)
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 46.0),
                          child: Column(
                            children: [
                              Text(
                                'Код отправлен на номер',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.readexPro(
                                  color: formMuted,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 12.0),
                              Text(
                                FFAppState().phone.replaceFirst('+7', '+7 '),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.readexPro(
                                  color: formText,
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!isAdminPhoneValue)
                        Padding(
                          key: _codeFieldKey,
                          padding: EdgeInsets.zero,
                          child: PinCodeTextField(
                            autoDisposeControllers: false,
                            appContext: context,
                            length: 4,
                            textStyle:
                                FlutterFlowTheme.of(context).bodyLarge.override(
                                      font: GoogleFonts.readexPro(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyLarge
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyLarge
                                            .fontStyle,
                                      ),
                                      color: formText,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyLarge
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyLarge
                                          .fontStyle,
                                    ),
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            enableActiveFill: true,
                            autoFocus: false,
                            focusNode: _model.pinCodeFocusNode,
                            enablePinAutofill: false,
                            errorTextSpace: 16.0,
                            showCursor: true,
                            cursorColor: mintColor,
                            obscureText: false,
                            hintCharacter: '-',
                            keyboardType: TextInputType.number,
                            pinTheme: PinTheme(
                              fieldHeight: 49.0,
                              fieldWidth: 42.0,
                              borderWidth: 1.0,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12.0),
                                bottomRight: Radius.circular(12.0),
                                topLeft: Radius.circular(12.0),
                                topRight: Radius.circular(12.0),
                              ),
                              shape: PinCodeFieldShape.box,
                              activeColor: formBorder,
                              inactiveColor: formBorder,
                              selectedColor: formBorder,
                              activeFillColor: formFieldBg,
                              inactiveFillColor: formFieldBg,
                              selectedFillColor: formFieldBg,
                            ),
                            controller: _model.pinCodeController,
                            onChanged: (_) {
                              if (_statusMessage.isNotEmpty && mounted) {
                                setState(() {
                                  _statusMessage = '';
                                  _statusIsError = false;
                                });
                              }
                            },
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: _model.pinCodeControllerValidator
                                .asValidator(context),
                          ),
                        ),
                      if (isAdminPhoneValue)
                        Padding(
                          key: _adminPasswordFieldKey,
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 12.0, 0.0, 0.0),
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
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
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
                            onChanged: (_) {
                              if (_statusMessage.isNotEmpty && mounted) {
                                setState(() {
                                  _statusMessage = '';
                                  _statusIsError = false;
                                });
                              }
                            },
                          ),
                        ),
                      if (_statusMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              16.0, 12.0, 16.0, 0.0),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              _statusMessage,
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    font: GoogleFonts.readexPro(
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                    ),
                                    color: _statusIsError
                                        ? FlutterFlowTheme.of(context).error
                                        : formMuted,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .fontStyle,
                                  ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(
              16.0,
              8.0,
              16.0,
              12.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (disabledReason.isNotEmpty) const SizedBox(height: 0.0),
                FFButtonWidget(
                  onPressed: (!canContinue || _isSubmitting)
                      ? null
                      : () async {
                          if (_isSubmitting) {
                            return;
                          }
                          setState(() {
                            _isSubmitting = true;
                            _statusMessage = '';
                            _statusIsError = false;
                          });
                          try {
                            if (!isAdminPhoneValue) {
                              if (_enteredSmsCode.length != 4) {
                                await _showMessageDialog(
                                  'Введите 4-значный SMS-код',
                                );
                                return;
                              }
                              if (isMTaxiBackendEnabled) {
                                final verifyResult = await backendVerifySmsCode(
                                  phone: FFAppState().phone.trim(),
                                  smsCode: _enteredSmsCode,
                                ).timeout(const Duration(seconds: 10));
                                if (verifyResult['success'] != true) {
                                  await _showMessageDialog(
                                    (verifyResult['error'] ??
                                            'Неверный SMS-код')
                                        .toString(),
                                  );
                                  return;
                                }
                              } else {
                                if (_enteredSmsCode != _expectedSmsCode) {
                                  await _showMessageDialog('Неверный SMS-код');
                                  return;
                                }
                              }
                            }

                            if (isMTaxiBackendEnabled) {
                              if (isAdminPhoneValue) {
                                final password =
                                    (_model.adminPasswordController?.text ?? '')
                                        .trim();
                                final result = await backendPasswordLogin(
                                  phone: FFAppState().phone.trim(),
                                  password: password,
                                ).timeout(const Duration(seconds: 10));
                                if (result['success'] != true) {
                                  await _showMessageDialog(
                                    (result['error'] ??
                                            'Неверный пароль администратора')
                                        .toString(),
                                  );
                                  return;
                                }
                                final userPayload = result['user'];
                                final userMap = userPayload is Map
                                    ? Map<String, dynamic>.from(userPayload)
                                    : <String, dynamic>{};
                                final backendUser =
                                    activateBackendUser(userMap);
                                AppStateNotifier.instance
                                    .updateNotifyOnAuthChange(false);
                                AppStateNotifier.instance.update(backendUser);
                                FFAppState().smsKod = 0;
                                FFAppState().update(() {});
                                await _routeSignedInUser(
                                  user: usersRecordFromBackendUser(userMap),
                                  signedInAsAdmin: true,
                                );
                                return;
                              }
                              await _continueWithBackendSmsSession(
                                signedInAsAdmin: isAdminPhoneValue,
                              );
                              return;
                            }

                            if (isAdminPhoneValue &&
                                ((_model.adminPasswordController?.text ?? '')
                                        .trim() !=
                                    adminPassword)) {
                              await _showMessageDialog(
                                'Неверный пароль администратора',
                              );
                              return;
                            }

                            final existingUser = await _findExistingUserByPhone(
                              FFAppState().phone,
                            );
                            final savedPassword =
                                await _verifySavedPasswordIfNeeded(
                              existingUser,
                            );
                            if (savedPassword == null) {
                              return;
                            }
                            final token = await _requestCustomToken(
                              existingUser: existingUser,
                              fallbackPhone: FFAppState().phone.trim(),
                              driverPassword: savedPassword,
                            );

                            if (token == null || token.isEmpty) {
                              if (mounted) {
                                setState(() {
                                  _statusMessage = _lastTokenRequestError
                                          .trim()
                                          .isNotEmpty
                                      ? _lastTokenRequestError
                                      : 'Не удалось войти. Попробуйте еще раз.';
                                  _statusIsError = true;
                                });
                              }
                              return;
                            }

                            await authManager.prepareForFreshSignIn();
                            final router = GoRouter.of(context);
                            router.clearRedirectLocation();
                            router.prepareAuthEvent(true);
                            final user = await authManager.signInWithJwtToken(
                              context,
                              token,
                            );
                            if (user == null) {
                              if (mounted) {
                                setState(() {
                                  _statusMessage =
                                      'Не удалось войти. Попробуйте ещё раз.';
                                  _statusIsError = true;
                                });
                              }
                              return;
                            }
                            FFAppState().smsKod = 0;
                            FFAppState().update(() {});
                            final signedInAsAdmin = isAdminPhoneValue ||
                                isAdminUser(currentUserDocument);
                            final resolvedUser =
                                await resolveSignedInUserRecord(
                              preferredUser: existingUser,
                              fallbackUid: user.uid,
                            );
                            await _routeSignedInUser(
                              user: resolvedUser,
                              signedInAsAdmin: signedInAsAdmin,
                            );

                            safeSetState(() {});
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isSubmitting = false;
                              });
                            }
                          }
                        },
                  text: _isSubmitting
                      ? 'Проверяем код...'
                      : FFLocalizations.of(context).getText(
                          'zrzm2hrb' /* Продолжить */,
                        ),
                  options: FFButtonOptions(
                    width: double.infinity,
                    height: 54.0,
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        0.0, 0.0, 0.0, 0.0),
                    iconPadding: const EdgeInsetsDirectional.fromSTEB(
                        0.0, 0.0, 0.0, 0.0),
                    color: ctaColor,
                    textStyle:
                        FlutterFlowTheme.of(context).titleMedium.override(
                              font: GoogleFonts.readexPro(
                                fontWeight: FontWeight.w700,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .fontStyle,
                              ),
                              color: ctaTextColor,
                              fontSize: 16.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w700,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .fontStyle,
                            ),
                    elevation: 0.0,
                    borderRadius: BorderRadius.circular(8.0),
                    disabledColor: ctaColor.withValues(alpha: 0.55),
                    disabledTextColor: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                if (!isAdminPhoneValue)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        0.0, 10.0, 0.0, 0.0),
                    child: TextButton(
                      onPressed: (_isSubmitting || _isResendingCode)
                          ? null
                          : _resendSmsCode,
                      child: Text(
                        _isResendingCode
                            ? 'Отправляем код...'
                            : 'Отправить код повторно',
                        style: TextStyle(
                          color: mintColor,
                          fontWeight: FontWeight.w600,
                        ),
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
}
