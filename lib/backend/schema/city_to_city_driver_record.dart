import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/backend_record_util.dart';
import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CityToCityDriverRecord extends BackendRecord {
  CityToCityDriverRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "otkuda" field.
  String? _otkuda;
  String get otkuda => _otkuda ?? '';
  bool hasOtkuda() => _otkuda != null;

  // "kuda" field.
  String? _kuda;
  String get kuda => _kuda ?? '';
  bool hasKuda() => _kuda != null;

  // "price" field.
  double? _price;
  double get price => _price ?? 0.0;
  bool hasPrice() => _price != null;

  // "mesta" field.
  int? _mesta;
  int get mesta => _mesta ?? 0;
  bool hasMesta() => _mesta != null;

  // "date" field.
  DateTime? _date;
  DateTime? get date => _date;
  bool hasDate() => _date != null;

  // "idUser" field.
  DocumentReference? _idUser;
  DocumentReference? get idUser => _idUser;
  bool hasIdUser() => _idUser != null;

  // "idDriver" field.
  DocumentReference? _idDriver;
  DocumentReference? get idDriver => _idDriver;
  bool hasIdDriver() => _idDriver != null;

  // "dateCreate" field.
  DateTime? _dateCreate;
  DateTime? get dateCreate => _dateCreate;
  bool hasDateCreate() => _dateCreate != null;

  // "status" field.
  bool? _status;
  bool get status => _status ?? false;
  bool hasStatus() => _status != null;

  // "post" field.
  bool? _post;
  bool get post => _post ?? false;
  bool hasPost() => _post != null;

  // "passenger" field.
  bool? _passenger;
  bool get passenger => _passenger ?? false;
  bool hasPassenger() => _passenger != null;

  void _initializeFields() {
    _otkuda = snapshotData['otkuda'] as String?;
    _kuda = snapshotData['kuda'] as String?;
    _price = castToType<double>(snapshotData['price']);
    _mesta = castToType<int>(snapshotData['mesta']);
    _date = snapshotData['date'] as DateTime?;
    _idUser = snapshotData['idUser'] as DocumentReference?;
    _idDriver = snapshotData['idDriver'] as DocumentReference?;
    _dateCreate = snapshotData['dateCreate'] as DateTime?;
    _status = snapshotData['status'] as bool?;
    _post = snapshotData['post'] as bool?;
    _passenger = snapshotData['passenger'] as bool?;
  }

  static CollectionReference get collection =>
      BackendRefs.instance.collection('CityToCityDriver');

  static Stream<CityToCityDriverRecord> getDocument(DocumentReference ref) =>
      Stream.value(CityToCityDriverRecord.getDocumentFromData(const {}, ref));

  static Future<CityToCityDriverRecord> getDocumentOnce(
          DocumentReference ref) =>
      Future.value(CityToCityDriverRecord.getDocumentFromData(const {}, ref));

  static CityToCityDriverRecord fromSnapshot(DocumentSnapshot snapshot) =>
      CityToCityDriverRecord._(
        snapshot.reference,
        mapFromBackendData(snapshot.data() as Map<String, dynamic>),
      );

  static CityToCityDriverRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      CityToCityDriverRecord._(reference, mapFromBackendData(data));

  @override
  String toString() =>
      'CityToCityDriverRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is CityToCityDriverRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createCityToCityDriverRecordData({
  String? otkuda,
  String? kuda,
  double? price,
  int? mesta,
  DateTime? date,
  DocumentReference? idUser,
  DocumentReference? idDriver,
  DateTime? dateCreate,
  bool? status,
  bool? post,
  bool? passenger,
}) {
  final backendData = mapToBackendData(
    <String, dynamic>{
      'otkuda': otkuda,
      'kuda': kuda,
      'price': price,
      'mesta': mesta,
      'date': date,
      'idUser': idUser,
      'idDriver': idDriver,
      'dateCreate': dateCreate,
      'status': status,
      'post': post,
      'passenger': passenger,
    }.withoutNulls,
  );

  return backendData;
}

class CityToCityDriverRecordDocumentEquality
    implements Equality<CityToCityDriverRecord> {
  const CityToCityDriverRecordDocumentEquality();

  @override
  bool equals(CityToCityDriverRecord? e1, CityToCityDriverRecord? e2) {
    return e1?.otkuda == e2?.otkuda &&
        e1?.kuda == e2?.kuda &&
        e1?.price == e2?.price &&
        e1?.mesta == e2?.mesta &&
        e1?.date == e2?.date &&
        e1?.idUser == e2?.idUser &&
        e1?.idDriver == e2?.idDriver &&
        e1?.dateCreate == e2?.dateCreate &&
        e1?.status == e2?.status &&
        e1?.post == e2?.post &&
        e1?.passenger == e2?.passenger;
  }

  @override
  int hash(CityToCityDriverRecord? e) => const ListEquality().hash([
        e?.otkuda,
        e?.kuda,
        e?.price,
        e?.mesta,
        e?.date,
        e?.idUser,
        e?.idDriver,
        e?.dateCreate,
        e?.status,
        e?.post,
        e?.passenger
      ]);

  @override
  bool isValidKey(Object? o) => o is CityToCityDriverRecord;
}
