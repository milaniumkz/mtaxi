// ignore_for_file: unused_import

// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/backend_calls/backend_calls.dart';

String _appLanguageCode() {
  final locale = FFLocalizations.getStoredLocale()?.languageCode.toLowerCase();
  return locale != null && locale.startsWith('kk') ? 'kk' : 'ru';
}

Future<List<String>> getAddressSuggestions(
  String query,
  String cityRegionCountry,
) async {
  if (query.isEmpty) {
    return [];
  }

  if (cityRegionCountry.isEmpty) {
    return [];
  }

  try {
    final languageCode = _appLanguageCode();
    final response = await makeCloudCall(
      'suggestAddressesLookup',
      {
        'query': query,
        'city': cityRegionCountry,
        'limit': 10,
        'language': languageCode,
      },
      timeout: const Duration(seconds: 8),
    );
    final rawItems = response['items'];
    if (response['success'] == true && rawItems is List) {
      return rawItems
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  } catch (e) {
    print('💥 Критическая ошибка: $e');
    return [];
  }
}
