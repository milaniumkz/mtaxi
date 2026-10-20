import 'dart:convert';
import 'dart:typed_data';

import '/backend/backend_session.dart';
import 'package:mime_type/mime_type.dart';

String? _fallbackMimeFromPath(String path) {
  final normalized = path.toLowerCase();
  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (normalized.endsWith('.png')) {
    return 'image/png';
  }
  if (normalized.endsWith('.gif')) {
    return 'image/gif';
  }
  if (normalized.endsWith('.heic')) {
    return 'image/heic';
  }
  if (normalized.endsWith('.heif')) {
    return 'image/heif';
  }
  if (normalized.endsWith('.webp')) {
    return 'image/webp';
  }
  if (normalized.endsWith('.mp4')) {
    return 'video/mp4';
  }
  return null;
}

Future<String?> uploadData(String path, Uint8List data) async {
  final response = await mtaxiBackendCall(
    'uploadFile',
    {
      'path': path,
      'contentType': mime(path) ?? _fallbackMimeFromPath(path),
      'base64': base64Encode(data),
    },
    timeout: const Duration(seconds: 30),
  );
  if (response['success'] == true) {
    return response['url']?.toString();
  }
  throw Exception(
    response['error']?.toString().trim().isNotEmpty == true
        ? response['error'].toString().trim()
        : 'Backend upload failed',
  );
}
