import '/backend/backend.dart';
import '/backend/backend_user_adapter.dart';
import '/backend/backend_calls/backend_calls.dart';

Future<List<UsersRecord>> loadAdminUsersFromBackend({
  String query = '',
  String role = '',
  int limit = 400,
}) async {
  final response = await makeCloudCall(
    'adminListUsers',
    {
      'query': query.trim(),
      'role': role.trim(),
      'limit': limit,
    },
  );
  if (response['success'] != true || response['users'] is! Iterable) {
    return const [];
  }
  return (response['users'] as Iterable)
      .whereType<Map>()
      .map(
          (item) => usersRecordFromBackendUser(Map<String, dynamic>.from(item)))
      .whereType<UsersRecord>()
      .toList(growable: false);
}
