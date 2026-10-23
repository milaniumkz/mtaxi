import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/backend/app_settings/app_settings.dart';
import '/backend/backend_session.dart';

final Map<String, Future<Map<String, dynamic>>> _inFlightDedupedCalls = {};
Map<String, String>? _clientRuntimeContextCache;
Future<Map<String, String>>? _clientRuntimeContextInFlight;
const Set<String> _dedupedCallNames = {
  'getOrderQuote',
  'expirePendingOrderIfNeeded',
  'ensureSupportChat',
  'getSessionBootstrap',
};
const Set<String> _criticalOrderCallNames = {
  'acceptOrder',
  'respondOrderOffer',
  'submitOrderOffer',
  'createPassengerTopUpPayment',
  'createPassengerOrder',
  'advanceDriverOrderStatus',
  'cancelPassengerOrder',
  'updateUserPreferences',
  'getSessionBootstrap',
};

String _buildCloudCallCacheKey(String callName, Map<String, dynamic> input) {
  final sortedEntries = input.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return '$callName:${jsonEncode(Map<String, dynamic>.fromEntries(sortedEntries))}';
}

String currentClientPlatform() {
  if (kIsWeb) {
    return 'web';
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
  }
}

Future<Map<String, String>> getClientRuntimeContext() async {
  final cached = _clientRuntimeContextCache;
  if (cached != null) {
    return cached;
  }
  final inFlight = _clientRuntimeContextInFlight;
  if (inFlight != null) {
    return inFlight;
  }

  final future = () async {
    try {
      final info = await PackageInfo.fromPlatform();
      final context = <String, String>{
        'platform': currentClientPlatform(),
        'appVersion': info.version,
        'buildNumber': info.buildNumber,
      };
      _clientRuntimeContextCache = context;
      return context;
    } catch (_) {
      final fallback = <String, String>{
        'platform': currentClientPlatform(),
        'appVersion': '',
        'buildNumber': '',
      };
      _clientRuntimeContextCache = fallback;
      return fallback;
    }
  }();

  _clientRuntimeContextInFlight = future;
  future.whenComplete(() {
    if (identical(_clientRuntimeContextInFlight, future)) {
      _clientRuntimeContextInFlight = null;
    }
  });
  return future;
}

Future<Map<String, dynamic>> makeCloudCall(
  String callName,
  Map<String, dynamic> input, {
  Duration? timeout,
}) async {
  final configuredTimeoutSec = currentAppRuntimeSettings.cloudCallTimeoutSec;
  final effectiveTimeout = timeout ??
      Duration(
        seconds: _criticalOrderCallNames.contains(callName)
            ? (configuredTimeoutSec < 10 ? 10 : configuredTimeoutSec)
            : configuredTimeoutSec,
      );
  final shouldDedupe = _dedupedCallNames.contains(callName);
  final dedupeKey =
      shouldDedupe ? _buildCloudCallCacheKey(callName, input) : null;

  Future<Map<String, dynamic>> executeCall() async {
    try {
      unawaited(getAppRuntimeSettings());
      return await _makeExternalBackendCall(
        callName,
        input,
        effectiveTimeout,
      );
    } on TimeoutException {
      print('Cloud call timeout:$callName');
      return {
        'success': false,
        'accepted': false,
        'timeout': true,
        'error': 'Сервер долго отвечает. Попробуйте еще раз.',
      };
    } catch (e) {
      print('Cloud call error:${callName} $e');
      return {
        'success': false,
        'accepted': false,
        'error': 'Сервис временно недоступен. Попробуйте еще раз.',
      };
    }
  }

  if (!shouldDedupe || dedupeKey == null) {
    return executeCall();
  }

  final inFlight = _inFlightDedupedCalls[dedupeKey];
  if (inFlight != null) {
    return inFlight;
  }

  final future = executeCall();
  _inFlightDedupedCalls[dedupeKey] = future;
  future.whenComplete(() {
    if (identical(_inFlightDedupedCalls[dedupeKey], future)) {
      _inFlightDedupedCalls.remove(dedupeKey);
    }
  });
  return future;
}

Future<Map<String, dynamic>> _makeExternalBackendCall(
  String callName,
  Map<String, dynamic> input,
  Duration timeout,
) async {
  ensureMTaxiBackendUrlAllowed();
  final baseUrl = mtaxiBackendCallBasePath;
  final runtimeContext = await getClientRuntimeContext();
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'X-MTaxi-Platform': runtimeContext['platform'] ?? '',
    'X-MTaxi-App-Version': runtimeContext['appVersion'] ?? '',
    'X-MTaxi-Build-Number': runtimeContext['buildNumber'] ?? '',
  };
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(mtaxiBackendAccessTokenPrefsKey)?.trim() ?? '';
  if (token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  }

  final response = await http
      .post(
        Uri.parse('$baseUrl/call/$callName'),
        headers: headers,
        body: jsonEncode(input),
      )
      .timeout(timeout);
  final decoded = response.body.trim().isEmpty
      ? <String, dynamic>{}
      : jsonDecode(response.body);
  if (decoded is Map) {
    final result = Map<String, dynamic>.from(decoded);
    if (result['success'] == true) {
      await saveBackendUserFromResponse(result);
    }
    return result;
  }
  return {
    'success': false,
    'accepted': false,
    'error': 'Сервис временно недоступен. Попробуйте еще раз.',
  };
}
