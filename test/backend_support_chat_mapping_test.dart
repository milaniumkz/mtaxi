import 'package:flutter_test/flutter_test.dart';
import 'package:mtaxi/backend/backend_support_chat.dart';

void main() {
  test('a sender reading their own message does not mark it read by support',
      () {
    final record = chatMessageRecordFromBackendJson({
      'id': 'message',
      'chatId': 'chat',
      'userId': 'passenger',
      'readByUser': true,
      'readByAdmin': false,
    });
    expect(record.snapshotData['readByUser'], isTrue);
    expect(record.snapshotData['readByAdmin'], isFalse);
    expect(record.readBy, isEmpty,
        reason: 'A chat document is not the identity of a reader');
  });

  test('admin and passenger read receipts remain independent', () {
    final record = chatMessageRecordFromBackendJson({
      'id': 'admin-message',
      'chatId': 'chat',
      'userId': 'admin',
      'readByUser': false,
      'readByAdmin': true,
    });
    expect(record.snapshotData['readByUser'], isFalse);
    expect(record.snapshotData['readByAdmin'], isTrue);
    expect(record.snapshotData['backendSource'], isTrue);
  });

  test('missing server read flags do not invent a read receipt', () {
    final record = chatMessageRecordFromBackendJson({'id': 'message'});
    expect(record.snapshotData['readByUser'], isFalse);
    expect(record.snapshotData['readByAdmin'], isFalse);
  });
}
