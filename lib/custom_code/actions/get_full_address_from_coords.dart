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

import '/flutter_flow/lat_lng.dart';
import '/backend/backend_calls/backend_calls.dart';

/// Получает полный адрес одной строкой по координатам
Future<String> getFullAddressFromCoords(LatLng coords) async {
  final response = await makeCloudCall(
    'reverseGeocodeLookup',
    {
      'lat': coords.latitude,
      'lng': coords.longitude,
    },
    timeout: const Duration(seconds: 8),
  );
  final address = (response['address']?.toString() ?? '').trim();
  if (response['success'] == true && address.isNotEmpty) {
    return address;
  }
  return 'Адрес уточняется';
}
