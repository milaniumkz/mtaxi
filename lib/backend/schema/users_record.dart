import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/backend_record_util.dart';
import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class UsersRecord extends BackendRecord {
  UsersRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "email" field.
  String? _email;
  String get email => _email ?? '';
  bool hasEmail() => _email != null;

  // "display_name" field.
  String? _displayName;
  String get displayName => _displayName ?? '';
  bool hasDisplayName() => _displayName != null;

  // "photo_url" field.
  String? _photoUrl;
  String get photoUrl => _photoUrl ?? '';
  bool hasPhotoUrl() => _photoUrl != null;

  // "uid" field.
  String? _uid;
  String get uid => _uid ?? '';
  bool hasUid() => _uid != null;

  // "created_time" field.
  DateTime? _createdTime;
  DateTime? get createdTime => _createdTime;
  bool hasCreatedTime() => _createdTime != null;

  // "phone_number" field.
  String? _phoneNumber;
  String get phoneNumber => _phoneNumber ?? '';
  bool hasPhoneNumber() => _phoneNumber != null;

  // "status" field.
  int? _status;
  int get status => _status ?? 0;
  bool hasStatus() => _status != null;

  // "iin" field.
  int? _iin;
  int get iin => _iin ?? 0;
  bool hasIin() => _iin != null;

  // "dataRoj" field.
  DateTime? _dataRoj;
  DateTime? get dataRoj => _dataRoj;
  bool hasDataRoj() => _dataRoj != null;

  // "password" field.
  String? _password;
  String get password => _password ?? '';
  bool hasPassword() => _password != null;

  // "avtoImage" field.
  String? _avtoImage;
  String get avtoImage => _avtoImage ?? '';
  bool hasAvtoImage() => _avtoImage != null;

  // "techImage" field.
  String? _techImage;
  String get techImage => _techImage ?? '';
  bool hasTechImage() => _techImage != null;

  // "Marka" field.
  String? _marka;
  String get marka => _marka ?? '';
  bool hasMarka() => _marka != null;

  // "model" field.
  String? _model;
  String get model => _model ?? '';
  bool hasModel() => _model != null;

  // "yersSet" field.
  DateTime? _yersSet;
  DateTime? get yersSet => _yersSet;
  bool hasYersSet() => _yersSet != null;

  // "proverka" field.
  bool? _proverka;
  bool get proverka => _proverka ?? false;
  bool hasProverka() => _proverka != null;

  // "bonus" field.
  double? _bonus;
  double get bonus => _bonus ?? 0.0;
  bool hasBonus() => _bonus != null;

  // "balance" field.
  double? _balance;
  double get balance => _balance ?? 0.0;
  bool hasBalance() => _balance != null;

  // "ref" field.
  String? _ref;
  String get ref => _ref ?? '';
  bool hasRef() => _ref != null;

  // "colsRef" field.
  int? _colsRef;
  int get colsRef => _colsRef ?? 0;
  bool hasColsRef() => _colsRef != null;

  // "isDriver" field.
  bool? _isDriver;
  bool get isDriver => _isDriver ?? false;
  bool hasIsDriver() => _isDriver != null;

  // "city" field.
  String? _city;
  String get city => _city ?? '';
  bool hasCity() => _city != null;

  // "reiting" field.
  double? _reiting;
  double get reiting => _reiting ?? 0.0;
  bool hasReiting() => _reiting != null;

  // "coords" field.
  LatLng? _coords;
  LatLng? get coords => _coords;
  bool hasCoords() => _coords != null;

  // "gosNomer" field.
  String? _gosNomer;
  String get gosNomer => _gosNomer ?? '';
  bool hasGosNomer() => _gosNomer != null;

  // "color" field.
  String? _color;
  String get color => _color ?? '';
  bool hasColor() => _color != null;

  // "role" field.
  String? _role;
  String get role => _role ?? '';
  bool hasRole() => _role != null;

  // "statusDriver" field.
  String? _statusDriver;
  String get statusDriver => _statusDriver ?? '';
  bool hasStatusDriver() => _statusDriver != null;

  // "activeMode" field.
  // Legacy compatibility field. Do not use as source of truth for role/mode.
  String? _activeMode;
  String get activeMode => _activeMode ?? '';
  bool hasActiveMode() => _activeMode != null;

  // "roleState" field.
  String? _roleState;
  String get roleState => _roleState ?? '';
  bool hasRoleState() => _roleState != null;

  void _initializeFields() {
    _email = snapshotData['email'] as String?;
    _displayName = snapshotData['display_name'] as String?;
    _photoUrl = snapshotData['photo_url'] as String?;
    _uid = snapshotData['uid'] as String?;
    _createdTime = snapshotData['created_time'] as DateTime?;
    _phoneNumber = snapshotData['phone_number'] as String?;
    _status = castToType<int>(snapshotData['status']);
    _iin = castToType<int>(snapshotData['iin']);
    _dataRoj = snapshotData['dataRoj'] as DateTime?;
    _password = snapshotData['password'] as String?;
    _avtoImage = snapshotData['avtoImage'] as String?;
    _techImage = snapshotData['techImage'] as String?;
    _marka = snapshotData['Marka'] as String?;
    _model = snapshotData['model'] as String?;
    _yersSet = snapshotData['yersSet'] as DateTime?;
    _proverka = snapshotData['proverka'] as bool?;
    _bonus = castToType<double>(snapshotData['bonus']);
    _balance = castToType<double>(snapshotData['balance']);
    _ref = snapshotData['ref'] as String?;
    _colsRef = castToType<int>(snapshotData['colsRef']);
    _isDriver = snapshotData['isDriver'] as bool?;
    _city = snapshotData['city'] as String?;
    _reiting = castToType<double>(snapshotData['reiting']);
    _coords = snapshotData['coords'] as LatLng?;
    _gosNomer = snapshotData['gosNomer'] as String?;
    _color = snapshotData['color'] as String?;
    _role = snapshotData['role'] as String?;
    _statusDriver = snapshotData['statusDriver'] as String?;
    _activeMode = snapshotData['activeMode'] as String?;
    _roleState = snapshotData['roleState'] as String?;
  }

  static CollectionReference get collection =>
      BackendRefs.instance.collection('users');

  static Stream<UsersRecord> getDocument(DocumentReference ref) =>
      Stream.value(UsersRecord.getDocumentFromData(const {}, ref));

  static Future<UsersRecord> getDocumentOnce(DocumentReference ref) =>
      Future.value(UsersRecord.getDocumentFromData(const {}, ref));

  static UsersRecord fromSnapshot(DocumentSnapshot snapshot) => UsersRecord._(
        snapshot.reference,
        mapFromBackendData(snapshot.data() as Map<String, dynamic>),
      );

  static UsersRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      UsersRecord._(reference, mapFromBackendData(data));

  @override
  String toString() =>
      'UsersRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is UsersRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createUsersRecordData({
  String? email,
  String? displayName,
  String? photoUrl,
  String? uid,
  DateTime? createdTime,
  String? phoneNumber,
  int? status,
  int? iin,
  DateTime? dataRoj,
  String? password,
  String? avtoImage,
  String? techImage,
  String? marka,
  String? model,
  DateTime? yersSet,
  bool? proverka,
  double? bonus,
  double? balance,
  String? ref,
  int? colsRef,
  bool? isDriver,
  String? city,
  double? reiting,
  LatLng? coords,
  String? gosNomer,
  String? color,
  String? role,
  String? statusDriver,
  String? roleState,
}) {
  final backendData = mapToBackendData(
    <String, dynamic>{
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'uid': uid,
      'created_time': createdTime,
      'phone_number': phoneNumber,
      'status': status,
      'iin': iin,
      'dataRoj': dataRoj,
      'password': password,
      'avtoImage': avtoImage,
      'techImage': techImage,
      'Marka': marka,
      'model': model,
      'yersSet': yersSet,
      'proverka': proverka,
      'bonus': bonus,
      'balance': balance,
      'ref': ref,
      'colsRef': colsRef,
      'isDriver': isDriver,
      'city': city,
      'reiting': reiting,
      'coords': coords,
      'gosNomer': gosNomer,
      'color': color,
      'role': role,
      'statusDriver': statusDriver,
      'roleState': roleState,
    }.withoutNulls,
  );

  return backendData;
}

class UsersRecordDocumentEquality implements Equality<UsersRecord> {
  const UsersRecordDocumentEquality();

  @override
  bool equals(UsersRecord? e1, UsersRecord? e2) {
    return e1?.email == e2?.email &&
        e1?.displayName == e2?.displayName &&
        e1?.photoUrl == e2?.photoUrl &&
        e1?.uid == e2?.uid &&
        e1?.createdTime == e2?.createdTime &&
        e1?.phoneNumber == e2?.phoneNumber &&
        e1?.status == e2?.status &&
        e1?.iin == e2?.iin &&
        e1?.dataRoj == e2?.dataRoj &&
        e1?.password == e2?.password &&
        e1?.avtoImage == e2?.avtoImage &&
        e1?.techImage == e2?.techImage &&
        e1?.marka == e2?.marka &&
        e1?.model == e2?.model &&
        e1?.yersSet == e2?.yersSet &&
        e1?.proverka == e2?.proverka &&
        e1?.bonus == e2?.bonus &&
        e1?.balance == e2?.balance &&
        e1?.ref == e2?.ref &&
        e1?.colsRef == e2?.colsRef &&
        e1?.isDriver == e2?.isDriver &&
        e1?.city == e2?.city &&
        e1?.reiting == e2?.reiting &&
        e1?.coords == e2?.coords &&
        e1?.gosNomer == e2?.gosNomer &&
        e1?.color == e2?.color &&
        e1?.role == e2?.role &&
        e1?.statusDriver == e2?.statusDriver &&
        e1?.activeMode == e2?.activeMode &&
        e1?.roleState == e2?.roleState;
  }

  @override
  int hash(UsersRecord? e) => const ListEquality().hash([
        e?.email,
        e?.displayName,
        e?.photoUrl,
        e?.uid,
        e?.createdTime,
        e?.phoneNumber,
        e?.status,
        e?.iin,
        e?.dataRoj,
        e?.password,
        e?.avtoImage,
        e?.techImage,
        e?.marka,
        e?.model,
        e?.yersSet,
        e?.proverka,
        e?.bonus,
        e?.balance,
        e?.ref,
        e?.colsRef,
        e?.isDriver,
        e?.city,
        e?.reiting,
        e?.coords,
        e?.gosNomer,
        e?.color,
        e?.role,
        e?.statusDriver,
        e?.activeMode,
        e?.roleState
      ]);

  @override
  bool isValidKey(Object? o) => o is UsersRecord;
}
