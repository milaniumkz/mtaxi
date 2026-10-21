import '/auth/backend_auth/auth_util.dart';
import '/auth/backend_auth/backend_user_provider.dart';
import '/backend/backend.dart';
import '/backend/backend_session.dart';
import '/backend/backend_user_adapter.dart';
import '/component/set_role/set_role_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/web_host_mode.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webviewx_plus/webviewx_plus.dart';

class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});
  static String routeName = 'login';
  static String routePath = '/login';
  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  bool _accepted = false;
  String _error = '';
  bool get _adminHost => kIsWeb && isWebAdminHost();
  String _tr(String ru, String kk) =>
      FFLocalizations.of(context).getVariableText(ruText: ru, kkText: kk);
  String? _normalizedPhone() {
    var digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) digits = '7$digits';
    if (digits.length == 11 && digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    }
    return RegExp(r'^7\d{10}$').hasMatch(digits) ? '+$digits' : null;
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (_register && !_accepted) {
      setState(() => _error = _tr('Примите пользовательское соглашение',
          'Пайдаланушы келісімін қабылдаңыз'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await authManager.prepareForFreshSignIn();
      final phone = _normalizedPhone()!;
      final result = _register
          ? await backendRegisterWithPassword(
              phone: phone, password: _password.text)
          : await backendPasswordLogin(phone: phone, password: _password.text);
      if (!mounted) return;
      if (result['success'] != true || result['user'] is! Map) {
        setState(() => _error = result['error']?.toString() ??
            _tr('Не удалось войти', 'Кіру мүмкін болмады'));
        return;
      }
      final user = Map<String, dynamic>.from(result['user'] as Map);
      final admin = user['role'] == 'admin';
      if (_adminHost && !admin) {
        await authManager.prepareForFreshSignIn();
        if (mounted)
          setState(() => _error = 'Веб-версия доступна только администратору.');
        return;
      }
      final activeUser = activateBackendUser(user);
      AppStateNotifier.instance.updateNotifyOnAuthChange(false);
      AppStateNotifier.instance.update(activeUser);
      FFAppState().phone = phone;
      FFAppState().pendingRegistrationRole = '';
      FFAppState().smsKod = 0;
      FFAppState().update(() {});
      TextInput.finishAutofillContext();
      await _routeSignedInUser(
          user: usersRecordFromBackendUser(user), signedInAsAdmin: admin);
    } catch (_) {
      if (mounted)
        setState(() => _error = _tr(
            'Не удалось связаться с сервером. Попробуйте ещё раз.',
            'Серверге қосылу мүмкін болмады. Қайталап көріңіз.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recovery() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title:
                Text(_tr('Восстановление доступа', 'Кіруді қалпына келтіру')),
            content: Text(_tr(
                'Обратитесь к администратору MTaxi. После проверки личности он установит новый пароль. Если у вашего старого аккаунта ещё нет пароля, также обратитесь к администратору.',
                'MTaxi әкімшісіне хабарласыңыз. Жеке басыңызды тексергеннен кейін ол жаңа құпиясөз орнатады. Ескі аккаунтыңызда құпиясөз болмаса да, әкімшіге хабарласыңыз.')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'))
            ],
          ));

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

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF28D8C6)
        : const Color(0xFFFF6B00);
    return Scaffold(
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AutofillGroup(
              child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('MTaxi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: color)),
                      const SizedBox(height: 24),
                      Text(
                          _register
                              ? _tr('Регистрация', 'Тіркелу')
                              : _tr('Вход', 'Кіру'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 24),
                      TextFormField(
                          key: const ValueKey('login-phone'),
                          controller: _phone,
                          enabled: !_busy,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          decoration: InputDecoration(
                              labelText:
                                  _tr('Номер телефона', 'Телефон нөмірі'),
                              hintText: '+7 7XX XXX XX XX',
                              border: const OutlineInputBorder()),
                          validator: (_) => _normalizedPhone() == null
                              ? _tr('Введите номер +7 и 10 цифр',
                                  '+7 және 10 цифрды енгізіңіз')
                              : null),
                      const SizedBox(height: 16),
                      TextFormField(
                          key: const ValueKey('login-password'),
                          controller: _password,
                          enabled: !_busy,
                          obscureText: _obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          maxLength: 128,
                          autofillHints: [
                            _register
                                ? AutofillHints.newPassword
                                : AutofillHints.password
                          ],
                          textInputAction: _register
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!_register) _submit();
                          },
                          decoration: InputDecoration(
                              labelText: _tr('Пароль', 'Құпиясөз'),
                              helperText: _register
                                  ? _tr('От 8 до 128 символов', '8–128 таңба')
                                  : null,
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                  tooltip: _tr('Показать или скрыть пароль',
                                      'Құпиясөзді көрсету немесе жасыру'),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(_obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined))),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty)
                              return _tr(
                                  'Введите пароль', 'Құпиясөзді енгізіңіз');
                            if (_register && value.trim().length < 8)
                              return _tr(
                                  'Минимум 8 символов', 'Кемінде 8 таңба');
                            return null;
                          }),
                      if (_register) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                            key: const ValueKey('login-repeat-password'),
                            controller: _repeat,
                            enabled: !_busy,
                            obscureText: _obscure,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                                labelText: _tr('Повторите пароль',
                                    'Құпиясөзді қайталаңыз'),
                                border: const OutlineInputBorder()),
                            validator: (value) => value != _password.text
                                ? _tr('Пароли не совпадают',
                                    'Құпиясөздер сәйкес емес')
                                : null),
                        CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _accepted,
                            onChanged: _busy
                                ? null
                                : (value) =>
                                    setState(() => _accepted = value ?? false),
                            title: Text(_tr(
                                'Принимаю пользовательское соглашение',
                                'Пайдаланушы келісімін қабылдаймын'))),
                        TextButton(
                            onPressed: () =>
                                context.pushNamed(PolitikaWidget.routeName),
                            child: Text(_tr('Пользовательское соглашение',
                                'Пайдаланушы келісімі'))),
                      ],
                      if (_error.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Semantics(
                                liveRegion: true,
                                child: Text(_error,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)))),
                      FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: color,
                              minimumSize: const Size.fromHeight(52)),
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Text(_register
                                  ? _tr('Зарегистрироваться', 'Тіркелу')
                                  : _tr('Войти', 'Кіру'))),
                      if (!_register)
                        TextButton(
                            onPressed: _busy ? null : _recovery,
                            child: Text(_tr(
                                'Забыли пароль?', 'Құпиясөзді ұмыттыңыз ба?'))),
                      if (!_adminHost)
                        TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      _register = !_register;
                                      _error = '';
                                      _password.clear();
                                      _repeat.clear();
                                      _formKey.currentState?.reset();
                                    }),
                            child: Text(_register
                                ? _tr('Уже есть аккаунт? Войти',
                                    'Аккаунтыңыз бар ма? Кіру')
                                : _tr('Создать аккаунт', 'Аккаунт құру'))),
                    ],
                  ))),
        ),
      ))),
    );
  }
}
