import '/backend/backend.dart';
import '/backend/backend_session.dart';

LatLng? _backendLatLng(dynamic value) {
  if (value is LatLng) {
    return value;
  }
  if (value is! Map) {
    return null;
  }
  final latRaw = value['latitude'] ?? value['lat'];
  final lngRaw = value['longitude'] ?? value['lng'];
  final lat = latRaw is num ? latRaw.toDouble() : double.tryParse('$latRaw');
  final lng = lngRaw is num ? lngRaw.toDouble() : double.tryParse('$lngRaw');
  if (lat == null || lng == null) {
    return null;
  }
  return LatLng(lat, lng);
}

DocumentReference? _backendOrderRef(dynamic value) {
  final path = (value ?? '').toString().trim();
  if (!path.startsWith('order/') || path.split('/').length != 2) {
    return null;
  }
  return BackendRefs.instance.doc(path);
}

UsersRecord? usersRecordFromBackendUser(Map<String, dynamic>? user) {
  if (user == null) {
    return null;
  }
  final id = (user['id'] ?? user['uid']).toString().trim();
  if (id.isEmpty) {
    return null;
  }
  final hasPassword = user['hasPassword'] == true;
  final activePassengerOrderRef =
      _backendOrderRef(user['activePassengerOrderRef']) ??
          _backendOrderRef(user['activePassengerOrderId'] == null
              ? null
              : 'order/${user['activePassengerOrderId']}');
  final activeDriverOrderRef = _backendOrderRef(user['activeDriverOrderRef']) ??
      _backendOrderRef(user['activeDriverOrderId'] == null
          ? null
          : 'order/${user['activeDriverOrderId']}');
  final data = <String, dynamic>{
    'email': user['email'],
    'display_name': user['displayName'] ?? user['name'],
    'photo_url': user['photoUrl'],
    'uid': id,
    'phone_number': user['phone'] ?? user['phoneNumber'],
    'password': hasPassword ? '__backend_password_set__' : '',
    'avtoImage': user['avtoImage'],
    'techImage': user['techImage'],
    'Marka': user['marka'] ?? user['Marka'],
    'model': user['model'],
    'bonus': user['bonus'],
    'balance': user['balance'],
    'bonusBalance': user['bonusBalance'],
    'isDriver': user['isDriver'],
    'city': user['city'],
    'coords': _backendLatLng(user['coords']),
    'gosNomer': user['gosNomer'],
    'color': user['color'],
    'role': user['role'],
    'statusDriver': user['statusDriver'],
    'roleState': user['roleState'],
    'activeMode': user['activeMode'],
    'driverRegistrationStatus': user['driverRegistrationStatus'],
    'profileCompleted': user['profileCompleted'],
    'registrationDraft': user['registrationDraft'],
    'blocked': user['blocked'],
    'hasPassword': hasPassword,
    'hasActivePassengerOrder': user['hasActivePassengerOrder'],
    'hasActiveDriverOrder': user['hasActiveDriverOrder'],
    'activePassengerOrderRef': activePassengerOrderRef,
    'activeOrderRef': activeDriverOrderRef,
    'idOrder': activePassengerOrderRef,
    'idOrderDriver': activeDriverOrderRef,
  };
  data.removeWhere((_, value) => value == null);
  return UsersRecord.getDocumentFromData(
    data,
    BackendRefs.instance.doc('users/$id'),
  );
}

Future<UsersRecord?> applyBackendUserResponse(
  Map<String, dynamic> response,
) async {
  await saveBackendUserFromResponse(response);
  final user = response['user'];
  if (user is! Map) {
    return null;
  }
  return usersRecordFromBackendUser(Map<String, dynamic>.from(user));
}
