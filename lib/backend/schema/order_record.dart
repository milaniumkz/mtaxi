import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/backend_record_util.dart';
import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class OrderRecord extends BackendRecord {
  OrderRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "idUser" field.
  DocumentReference? _idUser;
  DocumentReference? get idUser => _idUser;
  bool hasIdUser() => _idUser != null;

  // "status" field.
  int? _status;
  int get status => _status ?? 0;
  bool hasStatus() => _status != null;

  // "ot" field.
  String? _ot;
  String get ot => _ot ?? '';
  bool hasOt() => _ot != null;

  // "kuda" field.
  String? _kuda;
  String get kuda => _kuda ?? '';
  bool hasKuda() => _kuda != null;

  // "city" field.
  String? _city;
  String get city => _city ?? '';
  bool hasCity() => _city != null;

  // "date" field.
  DateTime? _date;
  DateTime? get date => _date;
  bool hasDate() => _date != null;

  // "comment" field.
  String? _comment;
  String get comment => _comment ?? '';
  bool hasComment() => _comment != null;

  // "idDriver" field.
  DocumentReference? _idDriver;
  DocumentReference? get idDriver => _idDriver;
  bool hasIdDriver() => _idDriver != null;

  // "price" field.
  double? _price;
  double get price => _price ?? 0.0;
  bool hasPrice() => _price != null;

  // "otCoords" field.
  LatLng? _otCoords;
  LatLng? get otCoords => _otCoords;
  bool hasOtCoords() => _otCoords != null;

  // "kudaCoords" field.
  LatLng? _kudaCoords;
  LatLng? get kudaCoords => _kudaCoords;
  bool hasKudaCoords() => _kudaCoords != null;

  LatLng? _readPoint(dynamic value) {
    if (value is LatLng) return value;
    if (value is! Map) return null;
    final latitudeRaw = value['latitude'] ?? value['lat'];
    final longitudeRaw = value['longitude'] ?? value['lng'] ?? value['lon'];
    final latitude = latitudeRaw is num
        ? latitudeRaw.toDouble()
        : double.tryParse(latitudeRaw?.toString() ?? '');
    final longitude = longitudeRaw is num
        ? longitudeRaw.toDouble()
        : double.tryParse(longitudeRaw?.toString() ?? '');
    if (latitude == null || longitude == null) return null;
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    if (latitude == 0 && longitude == 0) return null;
    return LatLng(latitude, longitude);
  }

  void _initializeFields() {
    _idUser = snapshotData['idUser'] as DocumentReference?;
    _status = castToType<int>(snapshotData['status']);
    _ot = snapshotData['ot'] as String?;
    _kuda = snapshotData['kuda'] as String?;
    _city = snapshotData['city'] as String?;
    _date = snapshotData['date'] as DateTime?;
    _comment = snapshotData['comment'] as String?;
    _idDriver = snapshotData['idDriver'] as DocumentReference?;
    _price = castToType<double>(snapshotData['price']);
    _otCoords = _readPoint(snapshotData['otCoords']) ??
        _readPoint(snapshotData['fromPoint']);
    _kudaCoords = _readPoint(snapshotData['kudaCoords']) ??
        _readPoint(snapshotData['toPoint']);
  }

  static CollectionReference get collection =>
      BackendRefs.instance.collection('order');

  static Stream<OrderRecord> getDocument(DocumentReference ref) =>
      Stream.value(OrderRecord.getDocumentFromData(const {}, ref));

  static Future<OrderRecord> getDocumentOnce(DocumentReference ref) =>
      Future.value(OrderRecord.getDocumentFromData(const {}, ref));

  static OrderRecord fromSnapshot(DocumentSnapshot snapshot) => OrderRecord._(
        snapshot.reference,
        mapFromBackendData(snapshot.data() as Map<String, dynamic>),
      );

  static OrderRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      OrderRecord._(reference, mapFromBackendData(data));

  @override
  String toString() =>
      'OrderRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is OrderRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createOrderRecordData({
  DocumentReference? idUser,
  int? status,
  String? ot,
  String? kuda,
  String? city,
  DateTime? date,
  String? comment,
  DocumentReference? idDriver,
  double? price,
  LatLng? otCoords,
  LatLng? kudaCoords,
}) {
  final backendData = mapToBackendData(
    <String, dynamic>{
      'idUser': idUser,
      'status': status,
      'ot': ot,
      'kuda': kuda,
      'city': city,
      'date': date,
      'comment': comment,
      'idDriver': idDriver,
      'price': price,
      'otCoords': otCoords,
      'kudaCoords': kudaCoords,
    }.withoutNulls,
  );

  return backendData;
}

class OrderRecordDocumentEquality implements Equality<OrderRecord> {
  const OrderRecordDocumentEquality();

  @override
  bool equals(OrderRecord? e1, OrderRecord? e2) {
    return e1?.idUser == e2?.idUser &&
        e1?.status == e2?.status &&
        e1?.ot == e2?.ot &&
        e1?.kuda == e2?.kuda &&
        e1?.city == e2?.city &&
        e1?.date == e2?.date &&
        e1?.comment == e2?.comment &&
        e1?.idDriver == e2?.idDriver &&
        e1?.price == e2?.price &&
        e1?.otCoords == e2?.otCoords &&
        e1?.kudaCoords == e2?.kudaCoords;
  }

  @override
  int hash(OrderRecord? e) => const ListEquality().hash([
        e?.idUser,
        e?.status,
        e?.ot,
        e?.kuda,
        e?.city,
        e?.date,
        e?.comment,
        e?.idDriver,
        e?.price,
        e?.otCoords,
        e?.kudaCoords
      ]);

  @override
  bool isValidKey(Object? o) => o is OrderRecord;
}
