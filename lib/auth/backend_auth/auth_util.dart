import 'dart:async';

import 'package:flutter/material.dart';

import '/admin/admin_utils.dart';
import '/backend/backend.dart';
import '/backend/backend_session.dart';
import '/backend/backend_user_adapter.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'backend_auth_manager.dart';

export 'backend_auth_manager.dart';

final _authManager = BackendAuthManager();
BackendAuthManager get authManager => _authManager;

String get currentUserEmail =>
    currentUserDocument?.email ?? currentUser?.email ?? '';

String get currentUserUid => currentUser?.uid ?? '';

String get currentUserDisplayName =>
    currentUserDocument?.displayName ?? currentUser?.displayName ?? '';

String get currentUserPhoto =>
    currentUserDocument?.photoUrl ?? currentUser?.photoUrl ?? '';

String get currentPhoneNumber =>
    currentUserDocument?.phoneNumber ?? currentUser?.phoneNumber ?? '';

String get currentJwtToken => _currentJwtToken ?? '';

bool get currentUserEmailVerified => currentUser?.emailVerified ?? false;

String? _currentJwtToken;
final jwtTokenStream = Stream<String?>.value(null).asBroadcastStream();

DocumentReference? get currentUserReference {
  if (!loggedIn && currentUserDocument == null) {
    return null;
  }
  final existingRef = currentUserDocument?.reference;
  if (existingRef != null) {
    return existingRef;
  }
  final uid = currentUser?.uid?.trim() ?? '';
  return uid.isEmpty ? null : UsersRecord.collection.doc(uid);
}

UsersRecord? currentUserDocument;
String? _transientRoleStateUid;
String? _transientRoleState;

Future<UsersRecord?> resolveSignedInUserRecord({
  UsersRecord? preferredUser,
  String? fallbackUid,
}) async {
  bool isHydrated(UsersRecord? record) =>
      record != null && record.snapshotData.isNotEmpty;

  if (isHydrated(preferredUser)) {
    return preferredUser;
  }

  final token = await getStoredBackendAccessToken();
  if (token.isEmpty) {
    currentUserDocument = null;
    return null;
  }
  try {
    final bootstrap = await mtaxiBackendCall(
      'getSessionBootstrap',
      const {},
      timeout: const Duration(seconds: 8),
    );
    final record = await applyBackendUserResponse(bootstrap);
    if (record != null) {
      currentUserDocument = record;
      return record;
    }
  } catch (_) {}
  final storedUser = await getStoredBackendUser();
  final storedRecord = usersRecordFromBackendUser(storedUser);
  if (storedRecord != null) {
    currentUserDocument = storedRecord;
    return storedRecord;
  }
  return isHydrated(currentUserDocument) ? currentUserDocument : null;
}

Stream<UsersRecord?> _backendAuthenticatedUserStream() async* {
  yield await resolveSignedInUserRecord();
}

final authenticatedUserStream = _backendAuthenticatedUserStream().map((user) {
  currentUserDocument = user;
  final currentUid = user?.reference.id ?? '';
  if (_transientRoleStateUid != null &&
      (_transientRoleStateUid != currentUid || currentUid.isEmpty)) {
    _transientRoleStateUid = null;
    _transientRoleState = null;
  }
  return currentUserDocument;
}).asBroadcastStream();

String _normalizeUserModeValue(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  if (normalized == 'driver') return 'driver';
  if (normalized == 'passenger') return 'passenger';
  return '';
}

String _normalizeRoleStateValue(String? value) {
  final normalized = (value ?? '').trim().toUpperCase();
  switch (normalized) {
    case 'ADMIN':
    case 'BLOCKED':
    case 'PASSENGER':
    case 'DRIVER_PENDING':
    case 'DRIVER_PENDING_REVIEW':
    case 'DRIVER_OFFLINE':
    case 'DRIVER_ONLINE':
    case 'DRIVER_ON_TRIP':
      return normalized == 'DRIVER_PENDING_REVIEW'
          ? 'DRIVER_PENDING'
          : normalized;
    default:
      return '';
  }
}

DocumentReference? _documentReferenceFromSnapshotValue(dynamic value) {
  if (value is DocumentReference) {
    return value;
  }
  return null;
}

DocumentReference? _resolveOrderRefFromSnapshotData(
  Map<String, dynamic> snapshotData,
  String primaryKey,
  String legacyKey,
) {
  return _documentReferenceFromSnapshotValue(snapshotData[primaryKey]) ??
      _documentReferenceFromSnapshotValue(snapshotData[legacyKey]);
}

class UserModeResolver {
  const UserModeResolver._();

  static void setTransientRoleState(String roleState, {String? uid}) {
    final normalized = _normalizeRoleStateValue(roleState);
    final effectiveUid = (uid ?? currentUserUid).trim();
    if (normalized.isEmpty || effectiveUid.isEmpty) return;
    _transientRoleStateUid = effectiveUid;
    _transientRoleState = normalized;
  }

  static void clearTransientRoleState({String? uid}) {
    final effectiveUid = (uid ?? currentUserUid).trim();
    if (_transientRoleStateUid == null) return;
    if (effectiveUid.isEmpty || _transientRoleStateUid == effectiveUid) {
      _transientRoleStateUid = null;
      _transientRoleState = null;
    }
  }

  static String _resolveAuthoritative([UsersRecord? user]) {
    final current = user ?? currentUserDocument;
    if (current == null) return 'PASSENGER';
    if (isAdminUser(current)) return 'ADMIN';
    if (current.snapshotData['blocked'] == true) return 'BLOCKED';

    final roleState = _normalizeRoleStateValue(
      current.snapshotData['roleState']?.toString(),
    );
    if (roleState.isNotEmpty) {
      final preferredClientMode = _normalizeUserModeValue(
        current.snapshotData['preferredClientMode']?.toString(),
      );
      final activeMode = _normalizeUserModeValue(
        current.snapshotData['activeMode']?.toString(),
      );
      final driverRegistrationStatus =
          (current.snapshotData['driverRegistrationStatus'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
      if (roleState == 'DRIVER_PENDING' &&
          userHasDriverAccount(current) &&
          driverRegistrationStatus == 'pending_review' &&
          (preferredClientMode == 'passenger' || activeMode == 'passenger')) {
        return 'PASSENGER';
      }
      if ((roleState == 'DRIVER_ONLINE' || roleState == 'DRIVER_OFFLINE') &&
          userHasApprovedDriverAccess(current) &&
          getDriverActiveOrderRef(current) == null &&
          (preferredClientMode == 'passenger' || activeMode == 'passenger')) {
        return 'PASSENGER';
      }
      // Older records can have stale roleState=PASSENGER while the backend
      // driver fields already say the user is an approved driver in driver
      // mode. Do not let that stale value force a driver into passenger UI.
      if (roleState == 'PASSENGER' &&
          userHasApprovedDriverAccess(current) &&
          _normalizeUserModeValue(
                current.snapshotData['activeMode']?.toString(),
              ) ==
              'driver' &&
          _normalizeUserModeValue(
                current.snapshotData['preferredClientMode']?.toString(),
              ) !=
              'passenger') {
        final hasActiveDriverOrder = getDriverActiveOrderRef(current) != null;
        if (hasActiveDriverOrder) {
          return 'DRIVER_ON_TRIP';
        }
        final driverOnLine = current.snapshotData['driverOnLine'];
        final isOnline = driverOnLine is bool ? driverOnLine : false;
        return isOnline ? 'DRIVER_ONLINE' : 'DRIVER_OFFLINE';
      }
      return roleState;
    }

    final preferredClientMode = _normalizeUserModeValue(
      current.snapshotData['preferredClientMode']?.toString(),
    );
    final activeMode = _normalizeUserModeValue(
      current.snapshotData['activeMode']?.toString(),
    );
    final driverRegistrationStatus =
        (current.snapshotData['driverRegistrationStatus'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (userHasDriverAccount(current) &&
        driverRegistrationStatus == 'pending_review' &&
        (preferredClientMode == 'passenger' || activeMode == 'passenger')) {
      return 'PASSENGER';
    }

    if (userHasDriverAccount(current) &&
        current.statusDriver.trim().toLowerCase().isNotEmpty &&
        current.statusDriver.trim().toLowerCase() != 'approved') {
      return 'DRIVER_PENDING';
    }

    if (userHasApprovedDriverAccess(current)) {
      final hasActiveDriverOrder = getDriverActiveOrderRef(current) != null;
      if (!hasActiveDriverOrder &&
          (preferredClientMode == 'passenger' || activeMode == 'passenger')) {
        return 'PASSENGER';
      }
      if (!hasActiveDriverOrder &&
          preferredClientMode != 'driver' &&
          activeMode != 'driver') {
        return 'PASSENGER';
      }
      if (hasActiveDriverOrder) {
        return 'DRIVER_ON_TRIP';
      }
      final driverOnLine = current.snapshotData['driverOnLine'];
      final isOnline = driverOnLine is bool ? driverOnLine : true;
      return isOnline ? 'DRIVER_ONLINE' : 'DRIVER_OFFLINE';
    }

    return 'PASSENGER';
  }

  static bool userHasDriverAccount([UsersRecord? user]) {
    final current = user ?? currentUserDocument;
    if (current == null) return false;
    final role = _normalizeUserModeValue(current.role);
    final statusDriver = current.statusDriver.trim().toLowerCase();
    final driverRegistrationStatus =
        (current.snapshotData['driverRegistrationStatus'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    return current.isDriver ||
        role == 'driver' ||
        statusDriver.isNotEmpty ||
        driverRegistrationStatus.isNotEmpty;
  }

  static bool userHasApprovedDriverAccess([UsersRecord? user]) {
    final current = user ?? currentUserDocument;
    if (current == null) return false;
    final driverRegistrationStatus =
        (current.snapshotData['driverRegistrationStatus'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    return userHasDriverAccount(current) &&
        (current.statusDriver.trim().toLowerCase() == 'approved' ||
            driverRegistrationStatus == 'approved');
  }

  static DocumentReference? getDriverActiveOrderRef([UsersRecord? user]) {
    final current = user ?? currentUserDocument;
    if (current == null) return null;
    return _resolveOrderRefFromSnapshotData(
      current.snapshotData,
      'activeOrderRef',
      'idOrderDriver',
    );
  }

  static DocumentReference? getPassengerActiveOrderRef([UsersRecord? user]) {
    final current = user ?? currentUserDocument;
    if (current == null) return null;
    return _resolveOrderRefFromSnapshotData(
      current.snapshotData,
      'activePassengerOrderRef',
      'idOrder',
    );
  }

  static String resolve([UsersRecord? user]) {
    final current = user ?? currentUserDocument;
    final authoritativeRoleState = _resolveAuthoritative(current);
    if (authoritativeRoleState == 'BLOCKED' ||
        authoritativeRoleState == 'ADMIN') {
      final effectiveUid = current?.reference.id ?? currentUserUid;
      clearTransientRoleState(uid: effectiveUid);
      return authoritativeRoleState;
    }
    final effectiveUid = current?.reference.id ?? currentUserUid;
    if (_transientRoleStateUid != null &&
        _transientRoleState != null &&
        effectiveUid.isNotEmpty &&
        _transientRoleStateUid == effectiveUid) {
      if (_transientRoleState == authoritativeRoleState) {
        clearTransientRoleState(uid: effectiveUid);
        return authoritativeRoleState;
      }
      final preferredClientMode = _normalizeUserModeValue(
        current?.snapshotData['preferredClientMode']?.toString(),
      );
      final activeMode = _normalizeUserModeValue(
        current?.snapshotData['activeMode']?.toString(),
      );
      if (authoritativeRoleState == 'PASSENGER' &&
          (preferredClientMode == 'passenger' || activeMode == 'passenger')) {
        clearTransientRoleState(uid: effectiveUid);
        return authoritativeRoleState;
      }
      return _transientRoleState!;
    }
    return authoritativeRoleState;
  }

  static String resolveActiveMode([UsersRecord? user]) {
    switch (resolve(user)) {
      case 'ADMIN':
        return 'admin';
      case 'DRIVER_OFFLINE':
      case 'DRIVER_ONLINE':
      case 'DRIVER_ON_TRIP':
        return 'driver';
      default:
        return 'passenger';
    }
  }

  static bool canOpenDriverScreens([UsersRecord? user]) {
    switch (resolve(user)) {
      case 'DRIVER_OFFLINE':
      case 'DRIVER_ONLINE':
      case 'DRIVER_ON_TRIP':
        return true;
      default:
        return false;
    }
  }

  static bool canOpenPassengerScreens([UsersRecord? user]) {
    switch (resolve(user)) {
      case 'ADMIN':
      case 'BLOCKED':
      case 'DRIVER_PENDING':
        return false;
      default:
        return true;
    }
  }

  static bool canOpenOrder(
    OrderRecord? order, [
    UsersRecord? user,
  ]) {
    final current = user ?? currentUserDocument;
    if (current == null || order == null) return false;
    final roleState = resolve(current);
    if (roleState == 'BLOCKED') return false;

    if (canOpenDriverScreens(current)) {
      final driverOrderRef = getDriverActiveOrderRef(current);
      if (driverOrderRef != null &&
          driverOrderRef.path == order.reference.path) {
        return true;
      }
      if (order.idDriver == current.reference) {
        return true;
      }
    }

    if (resolve(current) == 'DRIVER_PENDING') {
      final driverOrderRef = getDriverActiveOrderRef(current);
      if (driverOrderRef != null &&
          driverOrderRef.path == order.reference.path) {
        return true;
      }
      if (order.idDriver == current.reference) {
        return true;
      }
    }

    if (canOpenPassengerScreens(current)) {
      final passengerOrderRef = getPassengerActiveOrderRef(current);
      if (passengerOrderRef != null &&
          passengerOrderRef.path == order.reference.path) {
        return true;
      }
      if (order.idUser == current.reference) {
        return true;
      }
    }

    return false;
  }
}

bool hasCompletedPassengerProfile([UsersRecord? user]) {
  final current = user ?? currentUserDocument;
  if (current == null) {
    return false;
  }
  final displayName = _resolvedUserDisplayName(current);
  final city = current.city.trim();
  final role = current.role.trim().toLowerCase();
  final roleState =
      (current.snapshotData['roleState'] ?? '').toString().trim().toUpperCase();
  final profileCompleted = current.snapshotData['profileCompleted'];
  final registrationDraft = current.snapshotData['registrationDraft'] == true;
  final hasPassengerRoleMarkers =
      role == 'passenger' || roleState == 'PASSENGER';
  final hasLegacyCompletedProfile = displayName.isNotEmpty &&
      (city.isNotEmpty || hasPassengerRoleMarkers || profileCompleted == true);

  if (registrationDraft) {
    return hasPassengerRoleMarkers && hasLegacyCompletedProfile;
  }

  if (profileCompleted == true) {
    return displayName.isNotEmpty || city.isNotEmpty || hasPassengerRoleMarkers;
  }
  if (profileCompleted == null) {
    return hasLegacyCompletedProfile;
  }
  return false;
}

String _resolvedUserDisplayName([UsersRecord? user]) {
  final current = user ?? currentUserDocument;
  if (current == null) {
    return '';
  }
  return buildDisplayNameFromData(
    current.snapshotData,
    fallback: current.displayName,
  );
}

bool _looksLikeDriverRegistrationDraft([UsersRecord? user]) {
  final current = user ?? currentUserDocument;
  if (current == null) {
    return false;
  }
  final snapshot = current.snapshotData;
  final role = current.role.trim().toLowerCase();
  final registrationStatus = (snapshot['driverRegistrationStatus'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  final statusDriver = current.statusDriver.trim().toLowerCase();
  final hasDriverMarkers = role == 'driver' ||
      current.isDriver ||
      registrationStatus.isNotEmpty ||
      statusDriver.isNotEmpty;
  if (registrationStatus == 'approved' || statusDriver == 'approved') {
    return false;
  }
  if (registrationStatus == 'pending_review') {
    return false;
  }
  if (registrationStatus == 'incomplete' ||
      registrationStatus == 'draft' ||
      registrationStatus == 'rejected') {
    return true;
  }
  if (snapshot['registrationDraft'] == true && hasDriverMarkers) {
    return true;
  }
  final hasDriverSpecificDraftData = [
    current.avtoImage,
    current.snapshotData['techImage'],
    current.gosNomer,
    current.color,
    current.snapshotData['Marka'],
    current.snapshotData['model'],
    current.snapshotData['dataRoj'],
    current.snapshotData['iin'],
  ].any((value) => (value ?? '').toString().trim().isNotEmpty);
  return hasDriverMarkers &&
      (current.city.trim().isNotEmpty || hasDriverSpecificDraftData);
}

bool isDriverRegistrationPendingReview([UsersRecord? user]) {
  final current = user ?? currentUserDocument;
  if (current == null) {
    return false;
  }
  final registrationStatus =
      (current.snapshotData['driverRegistrationStatus'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
  return registrationStatus == 'pending_review' &&
      !_looksLikeDriverRegistrationDraft(current);
}

bool needsDriverRegistration([UsersRecord? user]) {
  final current = user ?? currentUserDocument;
  if (current == null) {
    return false;
  }
  final activeMode = (current.snapshotData['activeMode'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  final preferredClientMode =
      (current.snapshotData['preferredClientMode'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
  final roleState =
      (current.snapshotData['roleState'] ?? '').toString().trim().toUpperCase();
  if ((activeMode == 'passenger' ||
          preferredClientMode == 'passenger' ||
          roleState == 'PASSENGER') &&
      hasCompletedPassengerProfile(current) &&
      !isDriverRegistrationPendingReview(current)) {
    return false;
  }
  if (isDriverRegistrationPendingReview(current)) {
    return false;
  }
  return _looksLikeDriverRegistrationDraft(current) ||
      (UserModeResolver.userHasDriverAccount(current) &&
          !UserModeResolver.userHasApprovedDriverAccess(current));
}

bool needsPassengerRegistration([UsersRecord? user]) {
  final current = user ?? currentUserDocument;
  if (current == null) {
    return false;
  }
  if (isDriverRegistrationPendingReview(current)) {
    return false;
  }
  if (hasCompletedPassengerProfile(current)) {
    return false;
  }
  final role = (current.role).trim().toLowerCase();
  final roleState =
      (current.snapshotData['roleState'] ?? '').toString().trim().toUpperCase();
  return !hasCompletedPassengerProfile(current) &&
      !needsDriverRegistration(current) &&
      (role == 'passenger' ||
          roleState == 'PASSENGER' ||
          _resolvedUserDisplayName(current).isNotEmpty ||
          current.city.trim().isNotEmpty ||
          current.snapshotData['profileCompleted'] == false);
}

bool needsPasswordSetup([UsersRecord? user]) {
  final current = user ?? currentUserDocument;
  if (current == null || isAdminUser(current)) {
    return false;
  }
  final password = ((current.password.isNotEmpty
              ? current.password
              : current.snapshotData['password']) ??
          '')
      .toString()
      .trim();
  if (password.isNotEmpty) {
    return false;
  }
  if (needsRoleSelection(current) ||
      needsPassengerRegistration(current) ||
      needsDriverRegistration(current)) {
    return false;
  }
  return hasCompletedPassengerProfile(current) ||
      UserModeResolver.userHasDriverAccount(current) ||
      current.snapshotData['profileCompleted'] == true;
}

bool needsRoleSelection([UsersRecord? user]) {
  final current = user ?? currentUserDocument;
  if (current == null) {
    return false;
  }
  if (isDriverRegistrationPendingReview(current)) {
    return false;
  }
  final role = current.role.trim().toLowerCase();
  final roleState =
      (current.snapshotData['roleState'] ?? '').toString().trim().toUpperCase();
  final registrationStatus =
      (current.snapshotData['driverRegistrationStatus'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
  return !hasCompletedPassengerProfile(current) &&
      !needsDriverRegistration(current) &&
      !needsPassengerRegistration(current) &&
      !UserModeResolver.userHasDriverAccount(current) &&
      current.snapshotData['registrationDraft'] != true &&
      role.isEmpty &&
      roleState.isEmpty &&
      registrationStatus.isEmpty;
}

bool userHasDriverAccount([UsersRecord? user]) =>
    UserModeResolver.userHasDriverAccount(user);

bool userHasApprovedDriverAccess([UsersRecord? user]) =>
    UserModeResolver.userHasApprovedDriverAccess(user);

DocumentReference? getUserDriverActiveOrderRef([UsersRecord? user]) =>
    UserModeResolver.getDriverActiveOrderRef(user);

DocumentReference? getUserPassengerActiveOrderRef([UsersRecord? user]) =>
    UserModeResolver.getPassengerActiveOrderRef(user);

String getUserRoleState([UsersRecord? user]) => UserModeResolver.resolve(user);

// Legacy compatibility projection. Prefer UserModeResolver capability checks
// and roleState-driven routing instead of depending on this string mode.
String getUserActiveMode([UsersRecord? user]) =>
    UserModeResolver.resolveActiveMode(user);

class AuthUserStreamWidget extends StatelessWidget {
  const AuthUserStreamWidget({Key? key, required this.builder})
      : super(key: key);

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => StreamBuilder(
        stream: authenticatedUserStream,
        builder: (context, _) => builder(context),
      );
}
