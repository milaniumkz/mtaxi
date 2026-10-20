import '/backend/backend.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/flutter_flow/flutter_flow_util.dart';

DateTime? _parseBackendDate(dynamic value) {
  if (value is DateTime) return value;
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

double? _parseBackendDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.').trim() ?? '');
}

LatLng? _parseBackendPoint(dynamic value) {
  if (value is! Map) return null;
  final latitude = _parseBackendDouble(value['latitude'] ?? value['lat']);
  final longitude =
      _parseBackendDouble(value['longitude'] ?? value['lng'] ?? value['lon']);
  if (latitude == null || longitude == null) return null;
  return LatLng(latitude, longitude);
}

DocumentReference? _backendUserRef(dynamic userId) {
  final id = userId?.toString().trim() ?? '';
  if (id.isEmpty) return null;
  return BackendRefs.instance
      .doc(id.startsWith('users/') ? id : 'users/$id');
}

OrderRecord orderRecordFromBackendJson(Map<String, dynamic> json) {
  final orderDocPath = (json['orderDocPath'] ?? '').toString().trim();
  final id = (json['id'] ?? '').toString().trim();
  final path = orderDocPath.isNotEmpty ? orderDocPath : 'order/$id';
  final date = _parseBackendDate(json['createdAt'] ?? json['date']);
  final fromPoint = _parseBackendPoint(json['fromPoint']);
  final toPoint = _parseBackendPoint(json['toPoint']);
  final data = <String, dynamic>{
    'backendSource': true,
    'idUser': _backendUserRef(json['passengerId']),
    'idDriver': _backendUserRef(json['driverId']),
    'status': castToType<int>(json['status']) ?? 0,
    'type': (json['type'] ?? 'taxi').toString(),
    'ot': (json['ot'] ?? '').toString(),
    'kuda': (json['kuda'] ?? '').toString(),
    'city': (json['city'] ?? '').toString(),
    'date': date,
    'dateCreate': date,
    'created_at': date,
    'comment': (json['comment'] ?? '').toString(),
    'deliveryItem': (json['deliveryItem'] ?? '').toString(),
    'price': _parseBackendDouble(json['price']) ?? 0.0,
    'distanceKm': _parseBackendDouble(json['distanceKm']),
    'otCoords': fromPoint,
    'kudaCoords': toPoint,
    'customerName': (json['customerName'] ?? '').toString(),
    'customerPhone': (json['customerPhone'] ?? '').toString(),
    'driverName': (json['driverName'] ?? '').toString(),
    'driverPhone': (json['driverPhone'] ?? '').toString(),
  }.withoutNulls;
  return OrderRecord.getDocumentFromData(
    data,
    BackendRefs.instance.doc(path),
  );
}

Future<List<OrderRecord>> loadAvailableDriverOrdersFromBackend({
  LatLng? driverLocation,
  double radiusKm = 10,
  int limit = 100,
}) async {
  final response = await makeCloudCall('listAvailableDriverOrders', {
    if (driverLocation != null) ...{
      'driverLatitude': driverLocation.latitude,
      'driverLongitude': driverLocation.longitude,
    },
    'radiusKm': radiusKm,
    'limit': limit,
  });
  if (response['success'] != true) return const [];
  final rawOrders = response['orders'];
  if (rawOrders is! List) return const [];
  return rawOrders
      .whereType<Map>()
      .map((item) => orderRecordFromBackendJson(
            Map<String, dynamic>.from(item),
          ))
      .toList();
}

Future<OrderRecord?> loadOrderDetailsFromBackend(String orderDocPath) async {
  final path = orderDocPath.trim();
  if (path.isEmpty) return null;
  final response = await makeCloudCall('getOrderDetails', {
    'orderDocPath': path,
  });
  if (response['success'] != true) return null;
  final rawOrder = response['order'];
  if (rawOrder is! Map) return null;
  return orderRecordFromBackendJson(Map<String, dynamic>.from(rawOrder));
}

Stream<OrderRecord> orderDetailsStreamFromBackend(String orderDocPath) async* {
  while (true) {
    try {
      final order = await loadOrderDetailsFromBackend(orderDocPath);
      if (order != null) {
        yield order;
      }
    } catch (_) {}
    await Future<void>.delayed(const Duration(seconds: 2));
  }
}

Stream<List<OrderRecord>> availableDriverOrdersStreamFromBackend({
  LatLng? Function()? driverLocation,
  double radiusKm = 10,
}) async* {
  while (true) {
    try {
      yield await loadAvailableDriverOrdersFromBackend(
        driverLocation: driverLocation?.call(),
        radiusKm: radiusKm,
      );
    } catch (_) {
      yield const [];
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
}
