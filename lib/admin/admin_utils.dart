import '/backend/schema/users_record.dart';

const String adminPhoneNumber = '+7 000 000 00 00';
const String adminPhoneDigits = '70000000000';
const String adminPassword = 'Dimapuparev19!';

const Set<String> protectedCollections = {
  // Add collection names here to полностью запретить удаление.
};

String normalizePhoneDigits(String? value) {
  if (value == null) {
    return '';
  }
  return value.replaceAll(RegExp(r'\D'), '');
}

bool isAdminPhone(String? phone) {
  final digits = normalizePhoneDigits(phone);
  return digits == adminPhoneDigits;
}

bool isAdminUser(UsersRecord? user) {
  if (user == null) {
    return false;
  }
  if (isAdminPhone(user.phoneNumber)) {
    return true;
  }
  return user.role == 'admin';
}

bool isProtectedDoc(
  String collectionName,
  Map<String, dynamic> data, {
  String? docId,
}) {
  if (protectedCollections.contains(collectionName)) {
    return true;
  }
  if (data['protected'] == true) {
    return true;
  }
  if (collectionName == 'users') {
    final phone = data['phone_number']?.toString();
    final role = data['role']?.toString();
    if (isAdminPhone(phone) || role == 'admin') {
      return true;
    }
  }
  return false;
}

bool canEditDoc(String collectionName, Map<String, dynamic> data) {
  return !isProtectedDoc(collectionName, data);
}

bool canDeleteDoc(String collectionName, Map<String, dynamic> data) {
  return !isProtectedDoc(collectionName, data);
}

String normalizeAdminText(dynamic rawValue) {
  if (rawValue is String) {
    final normalized = rawValue.trim();
    if (normalized.isEmpty) {
      return '';
    }
    final lowered = normalized.toLowerCase();
    if (lowered == '[object object]' || lowered == 'object') {
      return '';
    }
    return normalized;
  }
  if (rawValue is Map) {
    const candidateKeys = [
      'text',
      'name',
      'value',
      'firstName',
      'lastName',
      'display_name',
      'displayName',
      'phone',
      'phone_number',
      'phoneNumber',
      'uid',
      'title',
    ];
    for (final key in candidateKeys) {
      final candidate = normalizeAdminText(rawValue[key]);
      if (candidate.isNotEmpty) {
        return candidate;
      }
    }
    return '';
  }
  if (rawValue is Iterable) {
    for (final item in rawValue) {
      final candidate = normalizeAdminText(item);
      if (candidate.isNotEmpty) {
        return candidate;
      }
    }
    return '';
  }
  final fallback = rawValue?.toString().trim() ?? '';
  if (fallback.isEmpty) {
    return '';
  }
  final lowered = fallback.toLowerCase();
  if (lowered == '[object object]' || lowered == 'object') {
    return '';
  }
  return fallback;
}

String buildAdminUserName(Map<String, dynamic> data, {String fallback = ''}) {
  final firstName = normalizeAdminText(data['firstName']);
  final lastName = normalizeAdminText(data['lastName']);
  final compositeName =
      [firstName, lastName].where((part) => part.isNotEmpty).join(' ').trim();
  if (compositeName.isNotEmpty) {
    return compositeName;
  }

  final displayName = normalizeAdminText(
    data['display_name'] ?? data['displayName'],
  );
  if (displayName.isNotEmpty) {
    return displayName;
  }

  final normalizedFallback = normalizeAdminText(fallback);
  if (normalizedFallback.isNotEmpty) {
    return normalizedFallback;
  }

  final phone = normalizeAdminText(
    data['phone_number'] ?? data['phoneNumber'] ?? data['phone'],
  );
  if (phone.isNotEmpty) {
    return phone;
  }

  final uid = normalizeAdminText(data['uid']);
  if (uid.isNotEmpty) {
    return uid;
  }

  return '';
}
