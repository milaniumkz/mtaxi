import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/backend_record_util.dart';
import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class RouterCityToCityRecord extends BackendRecord {
  RouterCityToCityRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "ot" field.
  String? _ot;
  String get ot => _ot ?? '';
  bool hasOt() => _ot != null;

  // "kuda" field.
  String? _kuda;
  String get kuda => _kuda ?? '';
  bool hasKuda() => _kuda != null;

  // "price" field.
  double? _price;
  double get price => _price ?? 0.0;
  bool hasPrice() => _price != null;

  // "com" field.
  double? _com;
  double get com => _com ?? 0.0;
  bool hasCom() => _com != null;

  void _initializeFields() {
    _ot = (snapshotData['ot'] ?? snapshotData['from']) as String?;
    _kuda = (snapshotData['kuda'] ?? snapshotData['to']) as String?;
    _price = castToType<double>(snapshotData['tarif'] ?? snapshotData['price']);
    _com = castToType<double>(snapshotData['com']);
  }

  static CollectionReference get collection =>
      BackendRefs.instance.collection('routerCityToCity');

  static Stream<RouterCityToCityRecord> getDocument(DocumentReference ref) =>
      Stream.value(RouterCityToCityRecord.getDocumentFromData(const {}, ref));

  static Future<RouterCityToCityRecord> getDocumentOnce(
          DocumentReference ref) =>
      Future.value(RouterCityToCityRecord.getDocumentFromData(const {}, ref));

  static RouterCityToCityRecord fromSnapshot(DocumentSnapshot snapshot) =>
      RouterCityToCityRecord._(
        snapshot.reference,
        mapFromBackendData(snapshot.data() as Map<String, dynamic>),
      );

  static RouterCityToCityRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      RouterCityToCityRecord._(reference, mapFromBackendData(data));

  @override
  String toString() =>
      'RouterCityToCityRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is RouterCityToCityRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createRouterCityToCityRecordData({
  String? ot,
  String? kuda,
  double? price,
  double? com,
}) {
  final backendData = mapToBackendData(
    <String, dynamic>{
      'ot': ot,
      'kuda': kuda,
      'price': price,
      'com': com,
    }.withoutNulls,
  );

  return backendData;
}

class RouterCityToCityRecordDocumentEquality
    implements Equality<RouterCityToCityRecord> {
  const RouterCityToCityRecordDocumentEquality();

  @override
  bool equals(RouterCityToCityRecord? e1, RouterCityToCityRecord? e2) {
    return e1?.ot == e2?.ot &&
        e1?.kuda == e2?.kuda &&
        e1?.price == e2?.price &&
        e1?.com == e2?.com;
  }

  @override
  int hash(RouterCityToCityRecord? e) =>
      const ListEquality().hash([e?.ot, e?.kuda, e?.price, e?.com]);

  @override
  bool isValidKey(Object? o) => o is RouterCityToCityRecord;
}
