import 'dart:async';

import 'package:flutter/material.dart';

import '../auth_manager.dart';

import '/backend/backend_session.dart';
import '/backend/backend_user_adapter.dart';
import '../../backend/push_notifications/push_notifications_state.dart';
import '../../flutter_flow/flutter_flow_util.dart';
import 'auth_util.dart';

export '../base_auth_user_provider.dart';

class _MTaxiBackendSignedInUser extends BaseAuthUser {
  _MTaxiBackendSignedInUser(this.userData);

  final Map<String, dynamic> userData;

  @override
  bool get loggedIn => true;

  @override
  bool get emailVerified => true;

  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(
        uid: (userData['id'] ?? userData['uid'])?.toString(),
        email: userData['email']?.toString(),
        displayName: (userData['displayName'] ?? userData['name'])?.toString(),
        photoUrl: userData['photoUrl']?.toString(),
        phoneNumber: (userData['phone'] ?? userData['phoneNumber'])?.toString(),
      );

  @override
  Future? delete() => null;

  @override
  Future? updateEmail(String email) => null;

  @override
  Future? updatePassword(String newPassword) => null;

  @override
  Future? sendEmailVerification() => null;
}

class BackendPhoneAuthManager extends ChangeNotifier {
  bool? _triggerOnCodeSent;
  String? phoneAuthErrorMessage;
  String? phoneAuthVerificationCode;
  void Function(BuildContext)? _onCodeSent;

  bool get triggerOnCodeSent => _triggerOnCodeSent ?? false;
  set triggerOnCodeSent(bool val) => _triggerOnCodeSent = val;

  void Function(BuildContext) get onCodeSent =>
      _onCodeSent == null ? (_) {} : _onCodeSent!;
  set onCodeSent(void Function(BuildContext) func) => _onCodeSent = func;

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }
}

class BackendAuthManager extends AuthManager {
  BackendPhoneAuthManager phoneAuthManager = BackendPhoneAuthManager();

  void _resetTransientAuthState() {
    phoneAuthManager.update(() {
      phoneAuthManager.triggerOnCodeSent = false;
      phoneAuthManager.phoneAuthErrorMessage = null;
      phoneAuthManager.phoneAuthVerificationCode = null;
    });
  }

  void resetTransientAuthState() {
    _resetTransientAuthState();
  }

  Future<void> prepareForFreshSignIn() async {
    _resetTransientAuthState();
    await clearBackendSession();
    currentUser = null;
    currentUserDocument = null;
    UserModeResolver.clearTransientRoleState(uid: '');
    FFAppState().clearLegacyOrderRefs();
    FFAppState().clearPassengerOrderCreationState();
    FFAppState().pendingRegistrationRole = '';
    FFAppState().smsKod = 0;
  }

  @override
  Future signOut() async {
    final userPath = currentUserDocument?.reference.path;
    if (userPath != null && userPath.isNotEmpty) {
      unawaited(
        syncFcmTokenStateForUserPath(
          userDocPath: userPath,
          appState: kFcmAppStateTerminated,
        ),
      );
    }
    FFAppState().clearLegacyOrderRefs();
    FFAppState().clearPassengerOrderCreationState();
    FFAppState().pendingRegistrationRole = '';
    FFAppState().smsKod = 0;
    await clearBackendSession();
    try {
      await FFAppState()
          .clearPersistedState()
          .timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Do not block logout forever if local persistence stalls on web.
    } catch (_) {}
    _resetTransientAuthState();
    currentUser = null;
    currentUserDocument = null;
    UserModeResolver.clearTransientRoleState(uid: userPath ?? '');
    return null;
  }

  @override
  Future deleteUser(BuildContext context) async {
    await makeBackendDeleteCurrentAccount(context);
  }

  Future<void> makeBackendDeleteCurrentAccount(BuildContext context) async {
    final response = await mtaxiBackendCall(
      'deleteCurrentAccountDeep',
      const {},
      timeout: const Duration(seconds: 12),
    );
    if (response['success'] == true) {
      await signOut();
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['error']?.toString().trim().isNotEmpty == true
                ? response['error'].toString()
                : 'Не удалось удалить аккаунт',
          ),
        ),
      );
    }
    throw Exception(
      response['error']?.toString().trim().isNotEmpty == true
          ? response['error'].toString()
          : 'Не удалось удалить аккаунт',
    );
  }

  @override
  Future updateEmail({
    required String email,
    required BuildContext context,
  }) async {
    return null;
  }

  Future updatePassword({
    required String newPassword,
    required BuildContext context,
  }) async {
    final response = await mtaxiBackendCall(
      'setPassword',
      {'password': newPassword},
      timeout: const Duration(seconds: 10),
    );
    if (response['success'] != true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['error']?.toString().trim().isNotEmpty == true
                ? response['error'].toString()
                : 'Не удалось сохранить пароль',
          ),
        ),
      );
    }
  }

  @override
  Future resetPassword({
    required String email,
    required BuildContext context,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Восстановление пароля идет через backend')),
    );
  }

  Future<BaseAuthUser?> signInWithEmail(
    BuildContext context,
    String email,
    String password,
  ) async =>
      null;

  Future<BaseAuthUser?> createAccountWithEmail(
    BuildContext context,
    String email,
    String password,
  ) async =>
      null;

  Future<BaseAuthUser?> signInAnonymously(BuildContext context) async => null;

  Future<BaseAuthUser?> signInWithGithub(BuildContext context) async => null;

  Future<BaseAuthUser?> signInWithJwtToken(
    BuildContext context,
    String jwtToken,
  ) async {
    final token = jwtToken.trim();
    if (token.isEmpty) {
      return null;
    }
    await saveBackendAccessToken(token);
    final bootstrap = await mtaxiBackendCall(
      'getSessionBootstrap',
      const {},
      timeout: const Duration(seconds: 8),
    );
    final userPayload = bootstrap['user'];
    if (bootstrap['success'] != true || userPayload is! Map) {
      await clearBackendSession();
      return null;
    }
    final userMap = Map<String, dynamic>.from(userPayload);
    await saveBackendSession(token: token, user: userMap);
    currentUserDocument = usersRecordFromBackendUser(userMap);
    currentUser = _MTaxiBackendSignedInUser(userMap);
    return currentUser;
  }

  void handlePhoneAuthStateChanges(BuildContext context) {
    phoneAuthManager.addListener(() {
      if (!context.mounted) {
        return;
      }

      if (phoneAuthManager.triggerOnCodeSent) {
        phoneAuthManager.onCodeSent(context);
        phoneAuthManager
            .update(() => phoneAuthManager.triggerOnCodeSent = false);
      } else if (phoneAuthManager.phoneAuthErrorMessage != null) {
        final message = phoneAuthManager.phoneAuthErrorMessage!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $message')),
        );
        phoneAuthManager
            .update(() => phoneAuthManager.phoneAuthErrorMessage = null);
      }
    });
  }

  Future beginPhoneAuth({
    required BuildContext context,
    required String phoneNumber,
    required void Function(BuildContext) onCodeSent,
  }) async {
    _resetTransientAuthState();
    phoneAuthManager.update(() {
      phoneAuthManager.onCodeSent = onCodeSent;
      phoneAuthManager.triggerOnCodeSent = true;
    });
  }

  Future verifySmsCode({
    required BuildContext context,
    required String smsCode,
  }) async =>
      null;
}
