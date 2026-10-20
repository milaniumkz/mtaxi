import 'dart:async';

import '/auth/backend_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/backend_support_chat.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/backend/uploads/storage.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/upload_data.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/admin/admin_utils.dart';
import 'admin_support_chat_model.dart';
export 'admin_support_chat_model.dart';

const _mtaxiPageBg = Color(0xFF12051B);
const _mtaxiSurface = Color(0xFFFFFFFF);
const _mtaxiMint = Color(0xFF28D8C6);

class _PendingAdminSupportMessage {
  const _PendingAdminSupportMessage({
    required this.id,
    required this.text,
    this.imageUrl,
    required this.createdAt,
    this.messagePath,
    this.failed = false,
  });

  final String id;
  final String text;
  final String? imageUrl;
  final DateTime createdAt;
  final String? messagePath;
  final bool failed;

  _PendingAdminSupportMessage copyWith({
    String? messagePath,
    bool? failed,
  }) {
    return _PendingAdminSupportMessage(
      id: id,
      text: text,
      imageUrl: imageUrl,
      createdAt: createdAt,
      messagePath: messagePath ?? this.messagePath,
      failed: failed ?? this.failed,
    );
  }
}

class AdminSupportChatWidget extends StatefulWidget {
  const AdminSupportChatWidget({
    super.key,
    required this.chatRef,
    this.chatDocPath,
    this.userRef,
    this.userDocPath,
    this.supportChatKey,
  });

  final DocumentReference? chatRef;
  final String? chatDocPath;
  final DocumentReference? userRef;
  final String? userDocPath;
  final String? supportChatKey;

  static String routeName = 'adminSupportChat';
  static String routePath = '/admin/support/chat';

  @override
  State<AdminSupportChatWidget> createState() => _AdminSupportChatWidgetState();
}

class _AdminSupportChatWidgetState extends State<AdminSupportChatWidget> {
  late AdminSupportChatModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  bool _isUploadingImage = false;
  bool _isMarkingChatRead = false;
  DocumentReference? _activeChatRef;
  DocumentReference? _targetUserRef;
  Stream<List<ChatMessagesRecord>>? _messagesStream;
  final List<_PendingAdminSupportMessage> _pendingMessages = [];
  List<ChatMessagesRecord> _lastStableMessages = [];
  int _pendingMessageSeq = 0;
  final List<DocumentReference> _knownChatRefs = [];
  String? _supportChatKey;
  bool _canonicalRefreshScheduled = false;

  String get _currentAdminPath => currentUserDocument?.reference.path ?? '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminSupportChatModel());
    _activeChatRef = widget.chatRef ??
        _documentReferenceFromPath(widget.chatDocPath, 'chats');
    _targetUserRef = widget.userRef ??
        _documentReferenceFromPath(widget.userDocPath, 'users');
    _supportChatKey = (widget.supportChatKey ?? '').trim().isEmpty
        ? null
        : widget.supportChatKey!.trim();
    _bootstrapSupportChatKeyFromRefs();
    if (_activeChatRef != null) {
      _rememberChatRef(_activeChatRef);
      _messagesStream = _chatMessagesStream();
      unawaited(_bootstrapChatContext(_activeChatRef!));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markChatAsRead();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AdminSupportChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPath =
        (oldWidget.chatRef?.path ?? oldWidget.chatDocPath ?? '').trim();
    final newPath = (widget.chatRef?.path ?? widget.chatDocPath ?? '').trim();
    final oldUserPath = oldWidget.userRef?.path;
    final newUserPath = widget.userRef?.path;
    final oldSupportKey = (oldWidget.supportChatKey ?? '').trim();
    final newSupportKey = (widget.supportChatKey ?? '').trim();
    if (oldPath != newPath ||
        oldUserPath != newUserPath ||
        oldSupportKey != newSupportKey) {
      _lastMessageCount = 0;
      _activeChatRef = widget.chatRef ??
          _documentReferenceFromPath(widget.chatDocPath, 'chats');
      _targetUserRef = widget.userRef ??
          _documentReferenceFromPath(widget.userDocPath, 'users');
      _supportChatKey = newSupportKey.isEmpty ? null : newSupportKey;
      _bootstrapSupportChatKeyFromRefs();
      _rememberChatRef(_activeChatRef);
      _messagesStream = _activeChatRef == null ? null : _chatMessagesStream();
      if (_activeChatRef != null) {
        unawaited(_bootstrapChatContext(_activeChatRef!));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markChatAsRead();
      });
    }
  }

  DocumentReference? _documentReferenceFromPath(
    String? path,
    String expectedCollection,
  ) {
    final normalized = (path ?? '').trim();
    if (!normalized.startsWith('$expectedCollection/')) {
      return null;
    }
    if (normalized.split('/').length != 2) {
      return null;
    }
    return BackendRefs.instance.doc(normalized);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (currentUserUid.trim().isEmpty) return;
    if (_isUploadingImage) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final chatRef = _activeChatRef ?? widget.chatRef;
    if (chatRef == null) return;
    _messageController.clear();
    final pendingId = _addPendingMessage(text: text);
    String? messagePath;
    try {
      messagePath = await _sendSupportMessageDirectly(
        chatRef: chatRef,
        text: text,
      );
    } catch (e) {
      _markPendingMessageFailed(pendingId);
      _messageController.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось отправить сообщение: $e'),
          ),
        );
      }
      return;
    }

    _markPendingMessageSubmitted(pendingId, messagePath);
    if (mounted) {
      setState(() {});
    }
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    if (currentUserUid.trim().isEmpty) return;
    final chatRef = _activeChatRef ?? widget.chatRef;
    if (chatRef == null) return;

    final selectedMedia = await selectMediaWithSourceBottomSheet(
      context: context,
      allowPhoto: true,
      storageFolderPath: 'users/$currentUserUid/chats/${chatRef.id}',
    );
    if (selectedMedia == null ||
        !selectedMedia.every(
          (m) => validateFileFormat(m.storagePath, context),
        )) {
      return;
    }

    showUploadMessage(
      context,
      'Загружаем фото...',
      showLoading: true,
    );
    setState(() => _isUploadingImage = true);
    String? downloadUrl;
    String? uploadError;
    try {
      final downloadUrls = (await Future.wait(
        selectedMedia.map((m) => uploadData(m.storagePath, m.bytes)),
      ))
          .whereType<String>()
          .toList();
      if (downloadUrls.isNotEmpty) {
        downloadUrl = downloadUrls.first;
      }
    } catch (e) {
      uploadError = e.toString().replaceFirst('Exception: ', '').trim();
    } finally {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }

    if (downloadUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uploadError?.isNotEmpty == true
                  ? uploadError!
                  : 'Не удалось загрузить фото',
            ),
          ),
        );
      }
      return;
    }
    final text = _messageController.text.trim();
    _messageController.clear();
    final pendingId = _addPendingMessage(
      text: text,
      imageUrl: downloadUrl,
    );
    String? messagePath;
    try {
      messagePath = await _sendSupportMessageDirectly(
        chatRef: chatRef,
        text: text,
        imageUrl: downloadUrl,
      );
    } catch (e) {
      _markPendingMessageFailed(pendingId);
      _messageController.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось отправить сообщение: $e'),
          ),
        );
      }
      return;
    }

    _markPendingMessageSubmitted(pendingId, messagePath);
    if (mounted) {
      setState(() {});
    }
    _scrollToBottom();
  }

  Future<String> _sendSupportMessageDirectly({
    required DocumentReference chatRef,
    required String text,
    String? imageUrl,
  }) async {
    final response = await makeCloudCall('sendSupportChatMessage', {
      'text': text,
      if ((imageUrl ?? '').trim().isNotEmpty) 'imageUrl': imageUrl!.trim(),
      'chatDocPath': chatRef.path,
      if (_targetUserRef != null) 'targetUserDocPath': _targetUserRef!.path,
    });
    if (response['success'] != true) {
      throw Exception(
        (response['error'] ?? 'Не удалось отправить сообщение').toString(),
      );
    }

    _switchToReturnedChatPath((response['chatPath'] ?? '').toString());
    _rememberSupportChatKey(response['supportChatKey']);
    _rememberChatPaths(response['supportChatPaths']);

    final messagePath = (response['messagePath'] ?? '').toString().trim();
    if (messagePath.isEmpty) {
      throw Exception('Сервер не вернул путь сообщения');
    }
    return messagePath;
  }

  void _switchToReturnedChatPath(String chatPath) {
    final normalizedPath = chatPath.trim();
    if (normalizedPath.isEmpty || normalizedPath == _activeChatRef?.path) {
      return;
    }
    final nextChatRef = BackendRefs.instance.doc(normalizedPath);
    _rememberChatRef(nextChatRef);
    _lastMessageCount = 0;
    if (mounted) {
      setState(() {
        _activeChatRef = nextChatRef;
        _messagesStream = _chatMessagesStream();
      });
    } else {
      _activeChatRef = nextChatRef;
      _messagesStream = _chatMessagesStream();
    }
  }

  void _rememberChatRef(DocumentReference? chatRef) {
    final path = chatRef?.path ?? '';
    if (path.isEmpty) {
      return;
    }
    _knownChatRefs.removeWhere((ref) => ref.path == path);
    _knownChatRefs.insert(0, chatRef!);
    if (_knownChatRefs.length > 10) {
      _knownChatRefs.removeRange(10, _knownChatRefs.length);
    }
  }

  void _rememberChatPaths(dynamic value) {
    if (value is! Iterable) {
      return;
    }
    for (final item in value) {
      final path = item?.toString().trim() ?? '';
      if (path.startsWith('chats/') && path.split('/').length == 2) {
        _rememberChatRef(BackendRefs.instance.doc(path));
      }
    }
    if (mounted) {
      setState(() {
        _messagesStream = _chatMessagesStream();
      });
    } else {
      _messagesStream = _chatMessagesStream();
    }
  }

  void _rememberSupportChatKey(dynamic value) {
    final key = value?.toString().trim() ?? '';
    if (key.isEmpty || key == _supportChatKey) {
      return;
    }
    _supportChatKey = key;
    if (mounted) {
      setState(() {
        _messagesStream = _chatMessagesStream();
      });
    } else {
      _messagesStream = _chatMessagesStream();
    }
  }

  void _bootstrapSupportChatKeyFromRefs() {
    final userPath = _targetUserRef?.path ?? '';
    final adminPath = _currentAdminPath;
    if (userPath.isEmpty || adminPath.isEmpty) {
      return;
    }
    final key = '$userPath|$adminPath';
    if (key.isEmpty || key == _supportChatKey) {
      return;
    }
    _supportChatKey = key;
    if (mounted) {
      setState(() {
        _messagesStream = _chatMessagesStream();
      });
    } else {
      _messagesStream = _chatMessagesStream();
    }
  }

  Future<void> _bootstrapChatContext(DocumentReference chatRef) async {
    await _resolveTargetUserRefFromChat(chatRef);
    if (_canonicalRefreshScheduled) {
      return;
    }
    _canonicalRefreshScheduled = true;
    unawaited(() async {
      try {
        await Future.delayed(const Duration(milliseconds: 250));
        await _refreshCanonicalChatRefs(chatRef);
      } finally {
        _canonicalRefreshScheduled = false;
      }
    }());
  }

  Future<void> _resolveTargetUserRefFromChat(DocumentReference chatRef) async {
    if (currentUserUid.trim().isEmpty) {
      return;
    }
    try {
      final response = await makeCloudCall(
        'ensureSupportChat',
        {
          'chatDocPath': chatRef.path,
          if (_targetUserRef != null) 'targetUserDocPath': _targetUserRef!.path,
        },
      );
      if (response['success'] != true) {
        return;
      }
      _switchToReturnedChatPath((response['chatPath'] ?? '').toString());
      _rememberSupportChatKey(response['supportChatKey']);
      _rememberChatPaths(response['supportChatPaths']);
      if (_targetUserRef != null) {
        return;
      }
      final candidate = _documentReferenceFromPath(
        (response['userPath'] ?? '').toString(),
        'users',
      );
      if (candidate == null) {
        return;
      }
      if (mounted) {
        setState(() {
          _targetUserRef = candidate;
        });
      } else {
        _targetUserRef = candidate;
      }
      _bootstrapSupportChatKeyFromRefs();
    } catch (_) {}
  }

  Future<void> _refreshCanonicalChatRefs(DocumentReference chatRef) async {
    final response = await makeCloudCall(
      'ensureSupportChat',
      {
        'chatDocPath': chatRef.path,
        if (_targetUserRef != null) 'targetUserDocPath': _targetUserRef!.path,
      },
    );
    if (response['success'] != true) {
      return;
    }
    _switchToReturnedChatPath((response['chatPath'] ?? '').toString());
    _rememberSupportChatKey(response['supportChatKey']);
    _rememberChatPaths(response['supportChatPaths']);
  }

  void _openImagePreview(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (jump) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _scheduleScrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom(jump: jump);
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        _scrollToBottom(jump: jump);
      });
    });
  }

  String _nextPendingMessageId() {
    _pendingMessageSeq += 1;
    return '${DateTime.now().microsecondsSinceEpoch}_$_pendingMessageSeq';
  }

  String _addPendingMessage({
    required String text,
    String? imageUrl,
  }) {
    final pending = _PendingAdminSupportMessage(
      id: _nextPendingMessageId(),
      text: text,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
    );
    if (mounted) {
      setState(() {
        _pendingMessages.add(pending);
      });
    } else {
      _pendingMessages.add(pending);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
    return pending.id;
  }

  void _removePendingMessage(String id) {
    if (!mounted) {
      _pendingMessages.removeWhere((item) => item.id == id);
      return;
    }
    setState(() {
      _pendingMessages.removeWhere((item) => item.id == id);
    });
  }

  void _markPendingMessageSubmitted(String id, String? messagePath) {
    final normalizedPath = (messagePath ?? '').trim();
    final index = _pendingMessages.indexWhere((item) => item.id == id);
    if (index < 0) return;
    if (normalizedPath.isEmpty) {
      _removePendingMessage(id);
      return;
    }
    final updated = _pendingMessages[index].copyWith(
      messagePath: normalizedPath,
    );
    if (!mounted) {
      _pendingMessages[index] = updated;
      return;
    }
    setState(() {
      _pendingMessages[index] = updated;
    });
  }

  void _markPendingMessageFailed(String id) {
    final index = _pendingMessages.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final updated = _pendingMessages[index].copyWith(failed: true);
    if (!mounted) {
      _pendingMessages[index] = updated;
      return;
    }
    setState(() {
      _pendingMessages[index] = updated;
    });
  }

  void _pruneDeliveredPendingMessages(List<ChatMessagesRecord> messages) {
    if (_pendingMessages.isEmpty || !mounted) return;
    final deliveredPaths = messages.map((msg) => msg.reference.path).toSet();
    final pendingIdsToRemove = _pendingMessages
        .where((item) =>
            item.messagePath != null &&
            deliveredPaths.contains(item.messagePath))
        .map((item) => item.id)
        .toList(growable: false);
    if (pendingIdsToRemove.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _pendingMessages
            .removeWhere((item) => pendingIdsToRemove.contains(item.id));
      });
    });
  }

  void _handleMessageUpdates(List<ChatMessagesRecord> messages) {
    _pruneDeliveredPendingMessages(messages);
    if (messages.isEmpty) {
      _lastMessageCount = 0;
      return;
    }
    _markChatAsRead();
    final shouldScroll =
        _lastMessageCount == 0 || messages.length > _lastMessageCount;
    _lastMessageCount = messages.length;
    if (!shouldScroll) return;
    _scheduleScrollToBottom(jump: _lastMessageCount <= 1);
  }

  Future<void> _markChatAsRead() async {
    final chatRef = _activeChatRef ?? widget.chatRef;
    if (_currentAdminPath.isEmpty || chatRef == null || _isMarkingChatRead) {
      return;
    }
    _isMarkingChatRead = true;
    try {
      final response = await makeCloudCall(
        'markSupportChatRead',
        {
          'chatDocPath': chatRef.path,
          if (_targetUserRef != null) 'targetUserDocPath': _targetUserRef!.path,
        },
      );
      if (response['success'] != true) {
        debugPrint(
          'markSupportChatRead returned error for admin: ${response['error'] ?? response}',
        );
      }
    } catch (e) {
      debugPrint('markSupportChatRead failed for admin: $e');
    }

    _isMarkingChatRead = false;
  }

  bool _refsContainPath(List<DocumentReference> refs, String targetPath) {
    if (targetPath.isEmpty) return false;
    return refs.any((ref) => ref.path == targetPath);
  }

  String _messageStatusLabel({
    ChatMessagesRecord? message,
    required bool isMine,
    bool pending = false,
    bool failed = false,
  }) {
    if (failed) return 'Ошибка';
    if (pending) return 'Ожидает';
    if (message == null) return '';
    if (!isMine) return 'Получено';
    final currentPath = _currentAdminPath;
    if (message.readBy.any((ref) => ref.path != currentPath)) {
      return 'Прочитано';
    }
    if (message.deliveredTo.any((ref) => ref.path != currentPath)) {
      return 'Доставлено';
    }
    final normalizedStatus = message.status.trim().toLowerCase();
    if (normalizedStatus == 'failed' || normalizedStatus == 'error') {
      return 'Ошибка';
    }
    return _refsContainPath(message.deliveredTo, currentPath) ||
            normalizedStatus == 'sent'
        ? 'Отправлено'
        : 'Ожидает';
  }

  DateTime _messageTimestampValue(ChatMessagesRecord msg) {
    DateTime? parseDynamicDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) {
        final isMilliseconds = value.abs() > 100000000000;
        return DateTime.fromMillisecondsSinceEpoch(
          isMilliseconds ? value : value * 1000,
        );
      }
      if (value is double) {
        final intValue = value.round();
        final isMilliseconds = intValue.abs() > 100000000000;
        return DateTime.fromMillisecondsSinceEpoch(
          isMilliseconds ? intValue : intValue * 1000,
        );
      }
      if (value is Map) {
        final seconds = value['_seconds'] ?? value['seconds'];
        final nanoseconds = value['_nanoseconds'] ?? value['nanoseconds'] ?? 0;
        if (seconds is num) {
          final millis = (seconds * 1000).round() +
              ((nanoseconds as num?) ?? 0).round() ~/ 1000000;
          return DateTime.fromMillisecondsSinceEpoch(millis);
        }
      }
      if (value is String) {
        final normalized = value.trim();
        if (normalized.isEmpty) return null;
        final numeric = num.tryParse(normalized);
        if (numeric != null) {
          final intValue = numeric.round();
          final isMilliseconds = intValue.abs() > 100000000000;
          return DateTime.fromMillisecondsSinceEpoch(
            isMilliseconds ? intValue : intValue * 1000,
          );
        }
        return DateTime.tryParse(normalized);
      }
      return null;
    }

    final raw = msg.snapshotData['timestamp'];
    final parsedRaw = parseDynamicDate(raw);
    if (parsedRaw != null) return parsedRaw;
    final createdAt = msg.snapshotData['created_at'];
    final parsedCreatedAt = parseDynamicDate(createdAt);
    if (parsedCreatedAt != null) return parsedCreatedAt;
    final fallbackCreatedAt = msg.snapshotData['createdAt'];
    final parsedFallbackCreatedAt = parseDynamicDate(fallbackCreatedAt);
    if (parsedFallbackCreatedAt != null) return parsedFallbackCreatedAt;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Widget _buildMessageBubble({
    required bool isMine,
    required String text,
    String? imageUrl,
    ChatMessagesRecord? message,
    bool pending = false,
    bool failed = false,
    DateTime? timestamp,
  }) {
    final normalizedImageUrl = (imageUrl ?? '').trim();
    final bubbleColor =
        isMine ? FlutterFlowTheme.of(context).primary : _mtaxiSurface;
    final textColor =
        isMine ? Colors.white : FlutterFlowTheme.of(context).primaryText;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Opacity(
        opacity: pending ? 0.78 : 1.0,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.7,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
            border: isMine
                ? null
                : Border.all(
                    color: FlutterFlowTheme.of(context).alternate,
                  ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (normalizedImageUrl.isNotEmpty)
                GestureDetector(
                  onTap: () => _openImagePreview(normalizedImageUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      normalizedImageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              if (text.isNotEmpty) ...[
                if (normalizedImageUrl.isNotEmpty) const SizedBox(height: 6),
                Text(
                  text,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        color: textColor,
                      ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                '${_formatMessageTime(timestamp ?? DateTime.now())} • ${_messageStatusLabel(
                  message: message,
                  isMine: isMine,
                  pending: pending,
                  failed: failed,
                )}',
                style: FlutterFlowTheme.of(context).labelSmall.override(
                      color: failed
                          ? const Color(0xFFFFD1D1)
                          : (isMine
                              ? Colors.white70
                              : FlutterFlowTheme.of(context).secondaryText),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList({
    required List<ChatMessagesRecord> messages,
    required bool refreshing,
  }) {
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length + _pendingMessages.length,
          itemBuilder: (context, index) {
            if (index >= messages.length) {
              final pending = _pendingMessages[index - messages.length];
              return _buildMessageBubble(
                isMine: true,
                text: pending.text,
                imageUrl: pending.imageUrl,
                pending: true,
                failed: pending.failed,
              );
            }
            final msg = messages[index];
            final timestamp = _messageTimestampValue(msg);
            final showDayHeader = index == 0 ||
                !_isSameDay(
                  timestamp,
                  _messageTimestampValue(messages[index - 1]),
                );
            final isAdminMessage = msg.user?.path == _currentAdminPath;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showDayHeader)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 6,
                      bottom: 12,
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _mtaxiPageBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                          ),
                        ),
                        child: Text(
                          _formatMessageDay(timestamp),
                          style: FlutterFlowTheme.of(context).labelSmall,
                        ),
                      ),
                    ),
                  ),
                _buildMessageBubble(
                  isMine: isAdminMessage,
                  text: msg.text,
                  imageUrl: msg.image,
                  message: msg,
                  timestamp: timestamp,
                ),
              ],
            );
          },
        ),
        if (refreshing)
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  FlutterFlowTheme.of(context).primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatMessageDay(DateTime value) {
    return dateTimeFormat(
      'd MMMM y',
      value,
      locale: FFLocalizations.of(context).languageCode,
    );
  }

  String _formatMessageTime(DateTime value) {
    return dateTimeFormat(
      'HH:mm',
      value,
      locale: FFLocalizations.of(context).languageCode,
    );
  }

  Stream<List<ChatMessagesRecord>> _chatMessagesStream() {
    return supportChatMessagesStreamFromBackend(
      chatDocPath: (_activeChatRef ?? widget.chatRef)?.path,
      supportChatKey: _supportChatKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = isAdminUser(currentUserDocument);

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: _mtaxiSurface,
      appBar: AppBar(
        backgroundColor: _mtaxiPageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Назад',
          onPressed: () {
            context.goNamed('adminSupportChats');
          },
        ),
        title: Text(
          'Диалог с пользователем',
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                font: GoogleFonts.readexPro(
                  fontWeight: FontWeight.w600,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
                letterSpacing: 0.0,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontStyle:
                    FlutterFlowTheme.of(context).headlineMedium.fontStyle,
              ),
        ),
      ),
      body: AuthUserStreamWidget(
        builder: (context) => SafeArea(
          child: !isAdmin
              ? Center(
                  child: Text(
                    'Доступ только для администратора',
                    style: FlutterFlowTheme.of(context).bodyLarge,
                  ),
                )
              : (_activeChatRef ?? widget.chatRef) == null
                  ? Center(
                      child: Text(
                        'Чат не найден',
                        style: FlutterFlowTheme.of(context).bodyLarge,
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: StreamBuilder<List<ChatMessagesRecord>>(
                            key: ValueKey(
                              '${(_activeChatRef ?? widget.chatRef)?.path ?? 'chat'}::${_supportChatKey ?? ''}',
                            ),
                            stream: _messagesStream ?? _chatMessagesStream(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                if (_lastStableMessages.isNotEmpty ||
                                    _pendingMessages.isNotEmpty) {
                                  return _buildMessagesList(
                                    messages: _lastStableMessages,
                                    refreshing: true,
                                  );
                                }
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Ошибка загрузки чата',
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        onPressed: () => setState(() {}),
                                        child: const Text('Повторить'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              if (!snapshot.hasData) {
                                if (_lastStableMessages.isNotEmpty ||
                                    _pendingMessages.isNotEmpty) {
                                  return _buildMessagesList(
                                    messages: _lastStableMessages,
                                    refreshing: true,
                                  );
                                }
                                return Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      FlutterFlowTheme.of(context).primary,
                                    ),
                                  ),
                                );
                              }
                              final liveMessages = snapshot.data ?? [];
                              final isTemporaryEmpty = liveMessages.isEmpty &&
                                  _lastStableMessages.isNotEmpty;
                              final isTransientShrink =
                                  liveMessages.isNotEmpty &&
                                      _lastStableMessages.isNotEmpty &&
                                      liveMessages.length <
                                          _lastStableMessages.length &&
                                      snapshot.connectionState !=
                                          ConnectionState.done;
                              final messages =
                                  (isTemporaryEmpty || isTransientShrink)
                                      ? _lastStableMessages
                                      : liveMessages;
                              if (!isTransientShrink &&
                                  liveMessages.isNotEmpty) {
                                _lastStableMessages = liveMessages;
                              }
                              _handleMessageUpdates(messages);
                              return _buildMessagesList(
                                messages: messages,
                                refreshing: isTemporaryEmpty ||
                                    isTransientShrink ||
                                    snapshot.connectionState ==
                                        ConnectionState.waiting,
                              );
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          child: Row(
                            children: [
                              IconButton(
                                onPressed:
                                    _isUploadingImage ? null : _sendImage,
                                icon: _isUploadingImage
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            FlutterFlowTheme.of(context)
                                                .primary,
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.photo),
                                color: _mtaxiMint,
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  minLines: 1,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    hintText: 'Введите сообщение...',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _sendMessage,
                                icon: const Icon(Icons.send),
                                color: _mtaxiMint,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
