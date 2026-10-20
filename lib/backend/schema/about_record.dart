import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/backend_record_util.dart';
import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class AboutRecord extends BackendRecord {
  AboutRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  void _initializeFields() {
    _title = snapshotData['title'] as String?;
  }

  static CollectionReference get collection =>
      BackendRefs.instance.collection('about');

  static Stream<AboutRecord> getDocument(DocumentReference ref) =>
      Stream.value(AboutRecord.getDocumentFromData(const {}, ref));

  static Future<AboutRecord> getDocumentOnce(DocumentReference ref) =>
      Future.value(AboutRecord.getDocumentFromData(const {}, ref));

  static AboutRecord fromSnapshot(DocumentSnapshot snapshot) => AboutRecord._(
        snapshot.reference,
        mapFromBackendData(snapshot.data() as Map<String, dynamic>),
      );

  static AboutRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      AboutRecord._(reference, mapFromBackendData(data));

  @override
  String toString() =>
      'AboutRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is AboutRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createAboutRecordData({
  String? title,
}) {
  final backendData = mapToBackendData(
    <String, dynamic>{
      'title': title,
    }.withoutNulls,
  );

  return backendData;
}

class AboutRecordDocumentEquality implements Equality<AboutRecord> {
  const AboutRecordDocumentEquality();

  @override
  bool equals(AboutRecord? e1, AboutRecord? e2) {
    return e1?.title == e2?.title;
  }

  @override
  int hash(AboutRecord? e) => const ListEquality().hash([e?.title]);

  @override
  bool isValidKey(Object? o) => o is AboutRecord;
}
