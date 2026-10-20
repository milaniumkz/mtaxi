import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/backend_record_util.dart';
import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class OrderDriverAdminRecord extends BackendRecord {
  OrderDriverAdminRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "idDriver" field.
  DocumentReference? _idDriver;
  DocumentReference? get idDriver => _idDriver;
  bool hasIdDriver() => _idDriver != null;

  // "status" field.
  int? _status;
  int get status => _status ?? 0;
  bool hasStatus() => _status != null;

  // "Text" field.
  String? _text;
  String get text => _text ?? '';
  bool hasText() => _text != null;

  void _initializeFields() {
    _idDriver = snapshotData['idDriver'] as DocumentReference?;
    _status = castToType<int>(snapshotData['status']);
    _text = snapshotData['Text'] as String?;
  }

  static CollectionReference get collection =>
      BackendRefs.instance.collection('orderDriverAdmin');

  static Stream<OrderDriverAdminRecord> getDocument(DocumentReference ref) =>
      Stream.value(OrderDriverAdminRecord.getDocumentFromData(const {}, ref));

  static Future<OrderDriverAdminRecord> getDocumentOnce(
          DocumentReference ref) =>
      Future.value(OrderDriverAdminRecord.getDocumentFromData(const {}, ref));

  static OrderDriverAdminRecord fromSnapshot(DocumentSnapshot snapshot) =>
      OrderDriverAdminRecord._(
        snapshot.reference,
        mapFromBackendData(snapshot.data() as Map<String, dynamic>),
      );

  static OrderDriverAdminRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      OrderDriverAdminRecord._(reference, mapFromBackendData(data));

  @override
  String toString() =>
      'OrderDriverAdminRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is OrderDriverAdminRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createOrderDriverAdminRecordData({
  DocumentReference? idDriver,
  int? status,
  String? text,
}) {
  final backendData = mapToBackendData(
    <String, dynamic>{
      'idDriver': idDriver,
      'status': status,
      'Text': text,
    }.withoutNulls,
  );

  return backendData;
}

class OrderDriverAdminRecordDocumentEquality
    implements Equality<OrderDriverAdminRecord> {
  const OrderDriverAdminRecordDocumentEquality();

  @override
  bool equals(OrderDriverAdminRecord? e1, OrderDriverAdminRecord? e2) {
    return e1?.idDriver == e2?.idDriver &&
        e1?.status == e2?.status &&
        e1?.text == e2?.text;
  }

  @override
  int hash(OrderDriverAdminRecord? e) =>
      const ListEquality().hash([e?.idDriver, e?.status, e?.text]);

  @override
  bool isValidKey(Object? o) => o is OrderDriverAdminRecord;
}
