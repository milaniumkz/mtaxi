import '/app_state.dart';
import '/auth/backend_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/backend_calls/backend_calls.dart';

// Compatibility-only helpers for the rollout window.
// Prefer backend user-document refs first and fall back to local legacy mirrors
// only for older mobile flows that may still depend on them.

DocumentReference? getEffectivePassengerOrderRef([UsersRecord? user]) {
  final effectiveUser = user ?? currentUserDocument;
  final localRef = FFAppState().idOrder;
  if (effectiveUser != null) {
    if (effectiveUser.snapshotData['hasActivePassengerOrder'] == false) {
      return null;
    }
    final backendRef = getUserPassengerActiveOrderRef(effectiveUser);
    if (backendRef != null) {
      return backendRef;
    }
    if (localRef != null) {
      return localRef;
    }
    return null;
  }
  return localRef;
}

DocumentReference? getEffectiveDriverOrderRef([UsersRecord? user]) {
  final effectiveUser = user ?? currentUserDocument;
  if (effectiveUser != null) {
    final backendRef = getUserDriverActiveOrderRef(effectiveUser);
    if (FFAppState().shouldIgnoreDriverOrderRef(backendRef)) {
      return null;
    }
    if (backendRef != null) {
      return backendRef;
    }
    final localRef = FFAppState().idOrderDriver;
    if (FFAppState().shouldIgnoreDriverOrderRef(localRef)) {
      return null;
    }
    final roleState = getUserRoleState(effectiveUser);
    if (localRef != null && roleState == 'DRIVER_ON_TRIP') {
      return localRef;
    }
    return null;
  }
  final localRef = FFAppState().idOrderDriver;
  if (FFAppState().shouldIgnoreDriverOrderRef(localRef)) {
    return null;
  }
  return localRef;
}

DocumentReference? getEffectivePassengerLegacyOrderRef() {
  return FFAppState().idOrder;
}

DocumentReference? getEffectiveDriverLegacyOrderRef() {
  return FFAppState().idOrderDriver;
}

DocumentReference? getAuthoritativeCurrentUserRef() {
  final existingRef = currentUserDocument?.reference;
  if (existingRef != null) {
    return existingRef;
  }
  final authUid = currentUserUid.trim();
  return authUid.isEmpty ? null : UsersRecord.collection.doc(authUid);
}

final Map<String, DateTime> _recentOrderStatusAnnouncementExpirations = {};
final Map<String, DateTime> _recentDriverAvailableOrderAnnouncementExpirations =
    {};

bool shouldAnnounceDriverAvailableOrderOnce(
  DocumentReference? orderRef, {
  Duration ttl = const Duration(seconds: 45),
}) {
  final orderPath = orderRef?.path.trim() ?? '';
  if (orderPath.isEmpty) {
    return true;
  }
  final now = DateTime.now();
  _recentDriverAvailableOrderAnnouncementExpirations.removeWhere(
    (_, expiresAt) => !expiresAt.isAfter(now),
  );
  final expiresAt =
      _recentDriverAvailableOrderAnnouncementExpirations[orderPath];
  if (expiresAt != null && expiresAt.isAfter(now)) {
    return false;
  }
  _recentDriverAvailableOrderAnnouncementExpirations[orderPath] = now.add(ttl);
  return true;
}

bool shouldAnnounceOrderStatusOnce({
  required String audience,
  required DocumentReference? orderRef,
  required int status,
  Duration ttl = const Duration(seconds: 20),
}) {
  final orderPath = orderRef?.path.trim() ?? '';
  final normalizedAudience = audience.trim().toLowerCase();
  if (normalizedAudience.isEmpty || orderPath.isEmpty) {
    return true;
  }
  final now = DateTime.now();
  _recentOrderStatusAnnouncementExpirations.removeWhere(
    (_, expiresAt) => !expiresAt.isAfter(now),
  );
  final key = '$normalizedAudience|$orderPath|$status';
  final expiresAt = _recentOrderStatusAnnouncementExpirations[key];
  if (expiresAt != null && expiresAt.isAfter(now)) {
    return false;
  }
  _recentOrderStatusAnnouncementExpirations[key] = now.add(ttl);
  return true;
}

Future<DocumentReference?> _recoverPassengerOrderRefFromBootstrap() async {
  try {
    final response = await makeCloudCall(
      'getSessionBootstrap',
      const {},
      timeout: const Duration(seconds: 8),
    );
    if (response['success'] != true) {
      return null;
    }
    final orderPath =
        (response['activePassengerOrderRef'] ?? '').toString().trim();
    if (!orderPath.startsWith('order/') || orderPath.split('/').length != 2) {
      return null;
    }
    final orderRef = BackendRefs.instance.doc(orderPath);
    return orderRef;
  } catch (e) {
    print('recoverActivePassengerOrderRefFromServer:bootstrap $e');
  }
  return null;
}

Future<DocumentReference?> _recoverDriverOrderRefFromBootstrap() async {
  try {
    final response = await makeCloudCall(
      'getSessionBootstrap',
      const {},
      timeout: const Duration(seconds: 8),
    );
    if (response['success'] != true) {
      return null;
    }
    final orderPath =
        (response['activeDriverOrderRef'] ?? '').toString().trim();
    if (!orderPath.startsWith('order/') || orderPath.split('/').length != 2) {
      return null;
    }
    final orderRef = BackendRefs.instance.doc(orderPath);
    if (FFAppState().shouldIgnoreDriverOrderRef(orderRef)) {
      return null;
    }
    return orderRef;
  } catch (e) {
    print('recoverActiveDriverOrderRefFromServer:bootstrap $e');
  }
  return null;
}

Future<DocumentReference?> recoverActivePassengerOrderRefFromServer() async {
  return _recoverPassengerOrderRefFromBootstrap();
}

Future<DocumentReference?> recoverActiveDriverOrderRefFromServer() async {
  return _recoverDriverOrderRefFromBootstrap();
}
