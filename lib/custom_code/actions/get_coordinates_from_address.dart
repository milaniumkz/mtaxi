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

Future<LatLng?> getCoordinatesFromAddress(String address) async {
  final response = await makeCloudCall(
    'forwardGeocodeLookup',
    {
      'query': address,
    },
    timeout: const Duration(seconds: 8),
  );
  final lat = double.tryParse(response['lat']?.toString() ?? '');
  final lng = double.tryParse(response['lng']?.toString() ?? '');
  if (response['success'] == true && lat != null && lng != null) {
    return LatLng(lat, lng);
  }
  return null;
}
