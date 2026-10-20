import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/backend_record_util.dart';
import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class PaymentsRecord extends BackendRecord {
  PaymentsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "amount" field.
  double? _amount;
  double get amount => _amount ?? 0.0;
  bool hasAmount() => _amount != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "paid_at" field.
  DateTime? _paidAt;
  DateTime? get paidAt => _paidAt;
  bool hasPaidAt() => _paidAt != null;

  // "payment_id" field.
  String? _paymentId;
  String get paymentId => _paymentId ?? '';
  bool hasPaymentId() => _paymentId != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "user_id" field.
  String? _userId;
  String get userId => _userId ?? '';
  bool hasUserId() => _userId != null;

  void _initializeFields() {
    _amount = castToType<double>(snapshotData['amount']);
    _createdAt = snapshotData['created_at'] as DateTime?;
    _paidAt = snapshotData['paid_at'] as DateTime?;
    _paymentId = snapshotData['payment_id'] as String?;
    _status = snapshotData['status'] as String?;
    _userId = snapshotData['user_id'] as String?;
  }

  static CollectionReference get collection =>
      BackendRefs.instance.collection('payments');

  static Stream<PaymentsRecord> getDocument(DocumentReference ref) =>
      Stream.value(PaymentsRecord.getDocumentFromData(const {}, ref));

  static Future<PaymentsRecord> getDocumentOnce(DocumentReference ref) =>
      Future.value(PaymentsRecord.getDocumentFromData(const {}, ref));

  static PaymentsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      PaymentsRecord._(
        snapshot.reference,
        mapFromBackendData(snapshot.data() as Map<String, dynamic>),
      );

  static PaymentsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      PaymentsRecord._(reference, mapFromBackendData(data));

  @override
  String toString() =>
      'PaymentsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is PaymentsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createPaymentsRecordData({
  double? amount,
  DateTime? createdAt,
  DateTime? paidAt,
  String? paymentId,
  String? status,
  String? userId,
}) {
  final backendData = mapToBackendData(
    <String, dynamic>{
      'amount': amount,
      'created_at': createdAt,
      'paid_at': paidAt,
      'payment_id': paymentId,
      'status': status,
      'user_id': userId,
    }.withoutNulls,
  );

  return backendData;
}

class PaymentsRecordDocumentEquality implements Equality<PaymentsRecord> {
  const PaymentsRecordDocumentEquality();

  @override
  bool equals(PaymentsRecord? e1, PaymentsRecord? e2) {
    return e1?.amount == e2?.amount &&
        e1?.createdAt == e2?.createdAt &&
        e1?.paidAt == e2?.paidAt &&
        e1?.paymentId == e2?.paymentId &&
        e1?.status == e2?.status &&
        e1?.userId == e2?.userId;
  }

  @override
  int hash(PaymentsRecord? e) => const ListEquality().hash(
      [e?.amount, e?.createdAt, e?.paidAt, e?.paymentId, e?.status, e?.userId]);

  @override
  bool isValidKey(Object? o) => o is PaymentsRecord;
}
