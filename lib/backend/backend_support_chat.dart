import 'dart:async';

import '/backend/backend.dart';
import '/backend/backend_calls/backend_calls.dart';

DateTime? _parseBackendDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is int) {
    final isMillis = value.abs() > 100000000000;
    return DateTime.fromMillisecondsSinceEpoch(isMillis ? value : value * 1000);
  }
  if (value is String) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

DocumentReference? _docRefFromPath(dynamic value) {
  final path = (value ?? '').toString().trim();
  if (!path.contains('/') || path.split('/').length != 2) {
    return null;
  }
  return BackendRefs.instance.doc(path);
}

ChatMessagesRecord chatMessageRecordFromBackendJson(
  Map<String, dynamic> json,
) {
  final messagePath = (json['messagePath'] ?? '').toString().trim();
  final messageId = (json['id'] ?? '').toString().trim();
  final ref = messagePath.isNotEmpty
      ? BackendRefs.instance.doc(messagePath)
      : BackendRefs.instance.doc('chat_messages/$messageId');
  final userRef = _docRefFromPath(json['userPath']) ??
      _docRefFromPath(
          json['userId'] == null ? null : 'users/${json['userId']}');
  final chatRef = _docRefFromPath(json['chatPath']) ??
      _docRefFromPath(
          json['chatId'] == null ? null : 'chats/${json['chatId']}');
  final timestamp = _parseBackendDate(json['createdAt']) ?? DateTime.now();
  return ChatMessagesRecord.getDocumentFromData(
    {
      'user': userRef,
      'chat': chatRef,
      'text': (json['text'] ?? '').toString(),
      'image': (json['imageUrl'] ?? '').toString(),
      'timestamp': timestamp,
      'status': 'sent',
      'backendSource': true,
      'readByUser': json['readByUser'] == true,
      'readByAdmin': json['readByAdmin'] == true,
    },
    ref,
  );
}

ChatsRecord chatRecordFromBackendJson(Map<String, dynamic> json) {
  final chatPath = (json['chatPath'] ?? '').toString().trim();
  final chatId = (json['id'] ?? '').toString().trim();
  final ref = chatPath.isNotEmpty
      ? BackendRefs.instance.doc(chatPath)
      : BackendRefs.instance.doc('chats/$chatId');
  final userRef = _docRefFromPath(json['userPath']) ??
      _docRefFromPath(
          json['userId'] == null ? null : 'users/${json['userId']}');
  final adminRef = _docRefFromPath(json['adminPath']) ??
      _docRefFromPath(
          json['adminId'] == null ? null : 'users/${json['adminId']}');
  final user = json['user'] is Map
      ? Map<String, dynamic>.from(json['user'] as Map)
      : const <String, dynamic>{};
  final lastMessageTime = _parseBackendDate(json['lastMessageTime']) ??
      _parseBackendDate(json['updatedAt']) ??
      _parseBackendDate(json['createdAt']);
  return ChatsRecord.getDocumentFromData(
    {
      'users': [
        if (userRef != null) userRef,
        if (adminRef != null) adminRef,
      ],
      'user_a': userRef,
      'user_b': adminRef,
      'last_message': (json['lastMessage'] ?? '').toString(),
      'last_message_time': lastMessageTime,
      'last_message_sent_by': null,
      'last_message_seen_by': <DocumentReference>[],
      'support_chat_key': (json['supportChatKey'] ?? '').toString(),
      'updated_at': _parseBackendDate(json['updatedAt']),
      'created_at': _parseBackendDate(json['createdAt']),
      'unread_for_user': json['unreadForUser'] ?? 0,
      'unread_for_admin': json['unreadForAdmin'] ?? 0,
      'backend_user_name': (user['displayName'] ?? '').toString(),
      'backend_user_phone': (user['phone'] ?? '').toString(),
      'backend_user_city': (user['city'] ?? '').toString(),
      'backend_user_role': (user['role'] ?? '').toString(),
    },
    ref,
  );
}

Future<List<ChatsRecord>> loadSupportChatsFromBackend({
  int limit = 100,
}) async {
  final response = await makeCloudCall(
    'listSupportChats',
    {'limit': limit},
  );
  if (response['success'] != true) {
    return const [];
  }
  final items = response['chats'];
  if (items is! Iterable) {
    return const [];
  }
  final chats = items
      .whereType<Map>()
      .map((item) => chatRecordFromBackendJson(Map<String, dynamic>.from(item)))
      .toList(growable: true);
  chats.sort((a, b) {
    final aTime = a.lastMessageTime ??
        _parseBackendDate(a.snapshotData['updated_at']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.lastMessageTime ??
        _parseBackendDate(b.snapshotData['updated_at']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  });
  return List<ChatsRecord>.unmodifiable(chats);
}

Future<List<ChatsRecord>> loadMySupportChatFromBackend() async {
  final response = await makeCloudCall('getMySupportChat', {});
  if (response['success'] != true || response['chat'] is! Map) {
    return const [];
  }
  final chat = Map<String, dynamic>.from(response['chat'] as Map);
  chat['unreadForUser'] = response['unreadForUser'] ?? chat['unreadForUser'];
  chat['supportChatKey'] = response['supportChatKey'] ?? chat['supportChatKey'];
  chat['chatPath'] = response['chatPath'] ?? chat['chatPath'];
  return List<ChatsRecord>.unmodifiable([
    chatRecordFromBackendJson(chat),
  ]);
}

Stream<List<ChatsRecord>> mySupportChatStreamFromBackend({
  Duration interval = const Duration(seconds: 8),
}) async* {
  while (true) {
    yield await loadMySupportChatFromBackend();
    await Future<void>.delayed(interval);
  }
}

Stream<List<ChatsRecord>> supportChatsStreamFromBackend({
  Duration interval = const Duration(seconds: 3),
}) async* {
  while (true) {
    yield await loadSupportChatsFromBackend();
    await Future<void>.delayed(interval);
  }
}

Future<List<ChatMessagesRecord>> loadSupportChatMessagesFromBackend({
  String? chatDocPath,
  String? supportChatKey,
}) async {
  final response = await makeCloudCall(
    'getSupportChatMessages',
    {
      if ((chatDocPath ?? '').trim().isNotEmpty)
        'chatDocPath': chatDocPath!.trim(),
      if ((supportChatKey ?? '').trim().isNotEmpty)
        'supportChatKey': supportChatKey!.trim(),
    },
  );
  if (response['success'] != true) {
    return const [];
  }
  final items = response['messages'];
  if (items is! Iterable) {
    return const [];
  }
  final messages = items
      .whereType<Map>()
      .map((item) => chatMessageRecordFromBackendJson(
            Map<String, dynamic>.from(item),
          ))
      .toList(growable: true);
  messages.sort((a, b) {
    final byTime = (a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0));
    if (byTime != 0) return byTime;
    return a.reference.id.compareTo(b.reference.id);
  });
  return List<ChatMessagesRecord>.unmodifiable(messages);
}

Stream<List<ChatMessagesRecord>> supportChatMessagesStreamFromBackend({
  String? chatDocPath,
  String? supportChatKey,
  Duration interval = const Duration(seconds: 2),
}) async* {
  while (true) {
    yield await loadSupportChatMessagesFromBackend(
      chatDocPath: chatDocPath,
      supportChatKey: supportChatKey,
    );
    await Future<void>.delayed(interval);
  }
}
