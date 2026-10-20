import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String mtaxiBackendBaseUrl = String.fromEnvironment(
  'MTAXI_BACKEND_URL',
  defaultValue: 'http://localhost:8080',
);
const bool mtaxiRequireRemoteBackend = bool.fromEnvironment(
  'MTAXI_REQUIRE_REMOTE_BACKEND',
  defaultValue: false,
);
const String mtaxiBackendAccessTokenPrefsKey = 'mtaxi_backend_access_token';
const String mtaxiBackendUserPrefsKey = 'mtaxi_backend_user_json';

bool get isMTaxiBackendEnabled => true;

String get _normalizedBaseUrl =>
    mtaxiBackendBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

String get mtaxiBackendCallBasePath =>
    _normalizedBaseUrl.isEmpty ? '' : _normalizedBaseUrl;

bool _hostHasSecondOctetInRange(
  String host,
  String firstOctet,
  int min,
  int max,
) {
  final parts = host.split('.');
  if (parts.length < 2 || parts.first != firstOctet) {
    return false;
  }
  final second = int.tryParse(parts[1]);
  return second != null && second >= min && second <= max;
}

bool isLocalMTaxiBackendUrl(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  final uri = Uri.tryParse(normalized);
  final host = uri?.host.isNotEmpty == true ? uri!.host : normalized;
  return host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '0.0.0.0' ||
      host == '10.0.2.2' ||
      host == '::1' ||
      host.startsWith('fc') ||
      host.startsWith('fd') ||
      host.startsWith('fe8') ||
      host.startsWith('fe9') ||
      host.startsWith('fea') ||
      host.startsWith('feb') ||
      host.startsWith('192.168.') ||
      host.startsWith('169.254.') ||
      host.startsWith('10.') ||
      _hostHasSecondOctetInRange(host, '100', 64, 127) ||
      _hostHasSecondOctetInRange(host, '172', 16, 31);
}

void ensureMTaxiBackendUrlAllowed() {
  if (!mtaxiRequireRemoteBackend) {
    return;
  }
  final uri = Uri.tryParse(mtaxiBackendBaseUrl.trim());
  if (uri?.scheme.toLowerCase() != 'https') {
    throw StateError(
      'MTAXI_BACKEND_URL must use https when '
      'MTAXI_REQUIRE_REMOTE_BACKEND=true',
    );
  }
  if (isLocalMTaxiBackendUrl(mtaxiBackendBaseUrl)) {
    throw StateError(
      'MTAXI_BACKEND_URL must be a public backend URL when '
      'MTAXI_REQUIRE_REMOTE_BACKEND=true',
    );
  }
}

Future<Map<String, dynamic>> mtaxiBackendCall(
  String name,
  Map<String, dynamic> data, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  ensureMTaxiBackendUrlAllowed();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(mtaxiBackendAccessTokenPrefsKey)?.trim() ?? '';
  final headers = <String, String>{
    'Content-Type': 'application/json',
  };
  if (token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  }

  final response = await http
      .post(
        Uri.parse('$mtaxiBackendCallBasePath/call/$name'),
        headers: headers,
        body: jsonEncode(data),
      )
      .timeout(timeout);
  final decoded = response.body.trim().isEmpty
      ? <String, dynamic>{}
      : jsonDecode(response.body);
  return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
}

Future<Map<String, dynamic>?> getStoredBackendUser() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(mtaxiBackendUserPrefsKey)?.trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }
  final decoded = jsonDecode(raw);
  return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
}

Future<void> saveBackendUserFromResponse(Map<String, dynamic> response) async {
  final user = response['user'];
  if (user is! Map) {
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    mtaxiBackendUserPrefsKey,
    jsonEncode(Map<String, dynamic>.from(user)),
  );
}

Future<String> getStoredBackendAccessToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(mtaxiBackendAccessTokenPrefsKey)?.trim() ?? '';
}

Future<void> saveBackendSession({
  required String token,
  required Map<String, dynamic> user,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(mtaxiBackendAccessTokenPrefsKey, token);
  await prefs.setString(mtaxiBackendUserPrefsKey, jsonEncode(user));
}

Future<void> saveBackendAccessToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(mtaxiBackendAccessTokenPrefsKey, token.trim());
}

Future<void> clearBackendSession() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(mtaxiBackendAccessTokenPrefsKey);
  await prefs.remove(mtaxiBackendUserPrefsKey);
}

Future<Map<String, dynamic>> backendPasswordLogin({
  required String phone,
  required String password,
}) async {
  final result = await mtaxiBackendCall(
    'passwordLogin',
    {
      'phone': phone,
      'password': password,
    },
  );
  if (result['success'] == true) {
    final token = result['token']?.toString() ?? '';
    final user = result['user'];
    if (token.isNotEmpty && user is Map) {
      await saveBackendSession(
        token: token,
        user: Map<String, dynamic>.from(user),
      );
    }
  }
  await saveBackendUserFromResponse(result);
  return result;
}

Future<Map<String, dynamic>> backendLookupUserByPhone({
  required String phone,
}) async {
  final result = await mtaxiBackendCall(
    'lookupUserByPhone',
    {'phone': phone},
  );
  return result;
}

Future<Map<String, dynamic>> backendRequestSmsCode({
  required String phone,
}) async {
  final result = await mtaxiBackendCall(
    'requestSmsCode',
    {'phone': phone},
  );
  return result;
}

Future<Map<String, dynamic>> backendVerifySmsCode({
  required String phone,
  required String smsCode,
}) async {
  final result = await mtaxiBackendCall(
    'verifySmsCode',
    {
      'phone': phone,
      'smsCode': smsCode,
    },
  );
  return result;
}
