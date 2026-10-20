import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/backend_record_util.dart';
import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CityRecord extends BackendRecord {
  CityRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "parent" field.
  String? _parent;
  String get parent => _parent ?? '';
  bool hasParent() => _parent != null;

  // "priceCity" field.
  double? _priceCity;
  double get priceCity => _priceCity ?? 0.0;
  bool hasPriceCity() => _priceCity != null;

  // "priceDay" field.
  double? _priceDay;
  double get priceDay => _priceDay ?? 0.0;
  bool hasPriceDay() => _priceDay != null;

  // "priceNight" field.
  double? _priceNight;
  double get priceNight => _priceNight ?? 0.0;
  bool hasPriceNight() => _priceNight != null;

  void _initializeFields() {
    _title = snapshotData['title'] as String?;
    _parent = snapshotData['parent'] as String?;
    _priceCity = castToType<double>(snapshotData['priceCity']);
    _priceDay = castToType<double>(snapshotData['priceDay']);
    _priceNight = castToType<double>(snapshotData['priceNight']);
  }

  static CollectionReference get collection =>
      BackendRefs.instance.collection('City');

  static Stream<CityRecord> getDocument(DocumentReference ref) =>
      Stream.value(CityRecord.getDocumentFromData(const {}, ref));

  static Future<CityRecord> getDocumentOnce(DocumentReference ref) =>
      Future.value(CityRecord.getDocumentFromData(const {}, ref));

  static CityRecord fromSnapshot(DocumentSnapshot snapshot) => CityRecord._(
        snapshot.reference,
        mapFromBackendData(snapshot.data() as Map<String, dynamic>),
      );

  static CityRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      CityRecord._(reference, mapFromBackendData(data));

  @override
  String toString() =>
      'CityRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is CityRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createCityRecordData({
  String? title,
  String? parent,
  double? priceCity,
  double? priceDay,
  double? priceNight,
}) {
  final backendData = mapToBackendData(
    <String, dynamic>{
      'title': title,
      'parent': parent,
      'priceCity': priceCity,
      'priceDay': priceDay,
      'priceNight': priceNight,
    }.withoutNulls,
  );

  return backendData;
}

class CityRecordDocumentEquality implements Equality<CityRecord> {
  const CityRecordDocumentEquality();

  @override
  bool equals(CityRecord? e1, CityRecord? e2) {
    return e1?.title == e2?.title &&
        e1?.parent == e2?.parent &&
        e1?.priceCity == e2?.priceCity &&
        e1?.priceDay == e2?.priceDay &&
        e1?.priceNight == e2?.priceNight;
  }

  @override
  int hash(CityRecord? e) => const ListEquality()
      .hash([e?.title, e?.parent, e?.priceCity, e?.priceDay, e?.priceNight]);

  @override
  bool isValidKey(Object? o) => o is CityRecord;
}
