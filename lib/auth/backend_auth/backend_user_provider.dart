import 'dart:async';

import '/auth/backend_auth/auth_util.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/backend/backend_session.dart';
import '/backend/backend_user_adapter.dart';

class MTaxiBackendUser extends BaseAuthUser {
  MTaxiBackendUser(this.userData);

  final Map<String, dynamic>? userData;

  @override
  bool get loggedIn => userData != null;

  @override
  bool get emailVerified => true;

  @override
  AuthUserInfo get authUserInfo {
    final data = userData;
    return AuthUserInfo(
      uid: data?['id']?.toString(),
      displayName: data?['name']?.toString(),
      photoUrl: data?['photoUrl']?.toString(),
      phoneNumber: data?['phone']?.toString(),
    );
  }

  @override
  Future? delete() => null;

  @override
  Future? updateEmail(String email) => null;

  @override
  Future? updatePassword(String newPassword) => null;

  @override
  Future? sendEmailVerification() => null;
}

BaseAuthUser activateBackendUser(Map<String, dynamic>? user) {
  currentUserDocument = usersRecordFromBackendUser(user);
  currentUser = MTaxiBackendUser(user);
  return currentUser!;
}

Future<Map<String, dynamic>?> _loadCurrentBackendUser() async {
  final token = await getStoredBackendAccessToken();
  if (token.isNotEmpty) {
    try {
      final response = await makeCloudCall(
        'getSessionBootstrap',
        const {},
        timeout: const Duration(seconds: 8),
      );
      await saveBackendUserFromResponse(response);
      final user = response['user'];
      if (response['success'] == true && user is Map) {
        return Map<String, dynamic>.from(user);
      }
      await clearBackendSession();
      return null;
    } catch (_) {
      final storedUser = await getStoredBackendUser();
      if (storedUser != null && storedUser.isNotEmpty) {
        return storedUser;
      }
      await clearBackendSession();
      return null;
    }
  }
  return getStoredBackendUser();
}

Stream<BaseAuthUser> mtaxiBackendUserStream() {
  return Stream<Map<String, dynamic>?>.fromFuture(_loadCurrentBackendUser())
      .map(activateBackendUser);
}
