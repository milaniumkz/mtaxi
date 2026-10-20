import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/backend_record_util.dart';
import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class BidRecord extends BackendRecord {
  BidRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "idOrder" field.
  DocumentReference? _idOrder;
  DocumentReference? get idOrder => _idOrder;
  bool hasIdOrder() => _idOrder != null;

  // "idDriver" field.
  DocumentReference? _idDriver;
  DocumentReference? get idDriver => _idDriver;
  bool hasIdDriver() => _idDriver != null;

  // "price" field.
  double? _price;
  double get price => _price ?? 0.0;
  bool hasPrice() => _price != null;

  // "date" field.
  DateTime? _date;
  DateTime? get date => _date;
  bool hasDate() => _date != null;

  // "status" field.
  int? _status;
  int get status => _status ?? 0;
  bool hasStatus() => _status != null;

  void _initializeFields() {
    _idOrder = snapshotData['idOrder'] as DocumentReference?;
    _idDriver = snapshotData['idDriver'] as DocumentReference?;
    _price = castToType<double>(snapshotData['price']);
    _date = snapshotData['date'] as DateTime?;
    _status = castToType<int>(snapshotData['status']);
  }

  static CollectionReference get collection =>
      BackendRefs.instance.collection('bid');

  static Stream<BidRecord> getDocument(DocumentReference ref) =>
      Stream.value(BidRecord.getDocumentFromData(const {}, ref));

  static Future<BidRecord> getDocumentOnce(DocumentReference ref) =>
      Future.value(BidRecord.getDocumentFromData(const {}, ref));

  static BidRecord fromSnapshot(DocumentSnapshot snapshot) => BidRecord._(
        snapshot.reference,
        mapFromBackendData(snapshot.data() as Map<String, dynamic>),
      );

  static BidRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      BidRecord._(reference, mapFromBackendData(data));

  @override
  String toString() =>
      'BidRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is BidRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createBidRecordData({
  DocumentReference? idOrder,
  DocumentReference? idDriver,
  double? price,
  DateTime? date,
  int? status,
}) {
  final backendData = mapToBackendData(
    <String, dynamic>{
      'idOrder': idOrder,
      'idDriver': idDriver,
      'price': price,
      'date': date,
      'status': status,
    }.withoutNulls,
  );

  return backendData;
}

class BidRecordDocumentEquality implements Equality<BidRecord> {
  const BidRecordDocumentEquality();

  @override
  bool equals(BidRecord? e1, BidRecord? e2) {
    return e1?.idOrder == e2?.idOrder &&
        e1?.idDriver == e2?.idDriver &&
        e1?.price == e2?.price &&
        e1?.date == e2?.date &&
        e1?.status == e2?.status;
  }

  @override
  int hash(BidRecord? e) => const ListEquality()
      .hash([e?.idOrder, e?.idDriver, e?.price, e?.date, e?.status]);

  @override
  bool isValidKey(Object? o) => o is BidRecord;
}
