import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/backend_record_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ChatMessagesRecord extends BackendRecord {
  ChatMessagesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "user" field.
  DocumentReference? _user;
  DocumentReference? get user => _user;
  bool hasUser() => _user != null;

  // "chat" field.
  DocumentReference? _chat;
  DocumentReference? get chat => _chat;
  bool hasChat() => _chat != null;

  // "text" field.
  String? _text;
  String get text => _text ?? '';
  bool hasText() => _text != null;

  // "image" field.
  String? _image;
  String get image => _image ?? '';
  bool hasImage() => _image != null;

  // "timestamp" field.
  DateTime? _timestamp;
  DateTime? get timestamp => _timestamp;
  bool hasTimestamp() => _timestamp != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "delivered_to" field.
  List<DocumentReference>? _deliveredTo;
  List<DocumentReference> get deliveredTo => _deliveredTo ?? const [];
  bool hasDeliveredTo() => _deliveredTo != null;

  // "read_by" field.
  List<DocumentReference>? _readBy;
  List<DocumentReference> get readBy => _readBy ?? const [];
  bool hasReadBy() => _readBy != null;

  void _initializeFields() {
    _user = snapshotData['user'] as DocumentReference?;
    _chat = snapshotData['chat'] as DocumentReference?;
    _text = snapshotData['text'] as String?;
    _image = snapshotData['image'] as String?;
    _timestamp = snapshotData['timestamp'] as DateTime?;
    _status = snapshotData['status'] as String?;
    _deliveredTo = getDataList(snapshotData['delivered_to']);
    _readBy = getDataList(snapshotData['read_by']);
  }

  static CollectionReference get collection =>
      BackendRefs.instance.collection('chat_messages');

  static Stream<ChatMessagesRecord> getDocument(DocumentReference ref) =>
      Stream.value(ChatMessagesRecord.getDocumentFromData(const {}, ref));

  static Future<ChatMessagesRecord> getDocumentOnce(DocumentReference ref) =>
      Future.value(ChatMessagesRecord.getDocumentFromData(const {}, ref));

  static ChatMessagesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ChatMessagesRecord._(
        snapshot.reference,
        mapFromBackendData(snapshot.data() as Map<String, dynamic>),
      );

  static ChatMessagesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ChatMessagesRecord._(reference, mapFromBackendData(data));

  @override
  String toString() =>
      'ChatMessagesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ChatMessagesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createChatMessagesRecordData({
  DocumentReference? user,
  DocumentReference? chat,
  String? text,
  String? image,
  DateTime? timestamp,
  String? status,
}) {
  final backendData = mapToBackendData(
    <String, dynamic>{
      'user': user,
      'chat': chat,
      'text': text,
      'image': image,
      'timestamp': timestamp,
      'status': status,
    }.withoutNulls,
  );

  return backendData;
}

class ChatMessagesRecordDocumentEquality
    implements Equality<ChatMessagesRecord> {
  const ChatMessagesRecordDocumentEquality();

  @override
  bool equals(ChatMessagesRecord? e1, ChatMessagesRecord? e2) {
    return e1?.user == e2?.user &&
        e1?.chat == e2?.chat &&
        e1?.text == e2?.text &&
        e1?.image == e2?.image &&
        e1?.timestamp == e2?.timestamp &&
        e1?.status == e2?.status &&
        const ListEquality().equals(e1?.deliveredTo, e2?.deliveredTo) &&
        const ListEquality().equals(e1?.readBy, e2?.readBy);
  }

  @override
  int hash(ChatMessagesRecord? e) => const ListEquality().hash([
        e?.user,
        e?.chat,
        e?.text,
        e?.image,
        e?.timestamp,
        e?.status,
        e?.deliveredTo,
        e?.readBy
      ]);

  @override
  bool isValidKey(Object? o) => o is ChatMessagesRecord;
}
