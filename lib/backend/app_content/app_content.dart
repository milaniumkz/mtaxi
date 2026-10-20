import '/backend/backend_calls/backend_calls.dart';

Future<Map<String, dynamic>> getBackendContentDocument(String collection) async {
  final response = await makeCloudCall('getContentDocument', {
    'collection': collection,
  });
  final document = response['document'];
  if (response['success'] == true && document is Map) {
    return Map<String, dynamic>.from(document);
  }
  return const <String, dynamic>{};
}
