import 'package:flutter_test/flutter_test.dart';
import 'package:mtaxi/auth/backend_auth/auth_util.dart';
import 'package:mtaxi/backend/backend_user_adapter.dart';

void main() {
  test(
      'setting a password at signup does not skip passenger profile completion',
      () {
    final user = usersRecordFromBackendUser({
      'id': 'new-phone-password-user',
      'phone': '+77019990011',
      'displayName': '',
      'city': '',
      'role': 'passenger',
      'roleState': 'PASSENGER',
      'hasPassword': true,
      'profileCompleted': false,
      'registrationDraft': false,
      'isDriver': false,
    });
    expect(hasCompletedPassengerProfile(user), isFalse);
    expect(needsPassengerRegistration(user), isTrue);
    expect(needsPasswordSetup(user), isFalse);
    expect(user!.snapshotData['hasPassword'], isTrue);
  });
}
