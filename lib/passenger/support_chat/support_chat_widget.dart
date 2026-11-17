import '/backend/uploads/mtaxi_network_image.dart';
import 'dart:async';

import '/auth/backend_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/app_content/app_content.dart';
import '/backend/backend_support_chat.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/backend/uploads/storage.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/upload_data.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:url_launcher/url_launcher.dart';
import 'support_chat_model.dart';
export 'support_chat_model.dart';

const _mtaxiMint = Color(0xFF126E68);
const _mtaxiOrange = Color(0xFFE6BD63);
const _mtaxiText = Color(0xFF1B242B);
const _mtaxiMuted = Color(0xFF5C6862);

class _PendingSupportMessage {
  const _PendingSupportMessage({
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

  _PendingSupportMessage copyWith({
    String? messagePath,
    bool? failed,
  }) {
    return _PendingSupportMessage(
      id: id,
      text: text,
      imageUrl: imageUrl,
      createdAt: createdAt,
      messagePath: messagePath ?? this.messagePath,
      failed: failed ?? this.failed,
    );
  }
}

class SupportChatWidget extends StatefulWidget {
  const SupportChatWidget({super.key});

  static String routeName = 'supportChat';
  static String routePath = '/supportChat';

  @override
  State<SupportChatWidget> createState() => _SupportChatWidgetState();
}

class _SupportChatWidgetState extends State<SupportChatWidget> {
  late SupportChatModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  StreamSubscription<UsersRecord?>? _userSub;
  bool _isEnsuringChat = false;
  bool _isUploadingImage = false;
  bool _isMarkingChatSeen = false;

  DocumentReference? _chatRef;
  bool _loading = true;
  DocumentReference? _adminRef;
  bool _retryEnsureChatScheduled = false;
  final List<_PendingSupportMessage> _pendingMessages = [];
  List<ChatMessagesRecord> _lastStableMessages = [];
  int _pendingMessageSeq = 0;
  final List<DocumentReference> _knownChatRefs = [];
  String? _supportChatKey;
  Stream<List<ChatMessagesRecord>>? _messagesStream;

  String _digitsOnlyPhone(String value) => value.replaceAll(RegExp(r'\D'), '');

  String get _currentUserPath => currentUserDocument?.reference.path ?? '';

  String _formatPhone(String value) {
    final digits = _digitsOnlyPhone(value);
    if (digits.isEmpty) return value.trim();
    final normalizedDigits = digits.startsWith('8') && digits.length == 11
        ? '7${digits.substring(1)}'
        : digits;
    if (normalizedDigits.startsWith('7') && normalizedDigits.length == 11) {
      return '+7 ${normalizedDigits.substring(1, 4)} '
          '${normalizedDigits.substring(4, 7)} '
          '${normalizedDigits.substring(7, 9)} '
          '${normalizedDigits.substring(9, 11)}';
    }
    if (normalizedDigits.length == 10) {
      return '+7 ${normalizedDigits.substring(0, 3)} '
          '${normalizedDigits.substring(3, 6)} '
          '${normalizedDigits.substring(6, 8)} '
          '${normalizedDigits.substring(8, 10)}';
    }
    return '+$normalizedDigits';
  }

  Future<void> _openWhatsApp(String phone) async {
    final digits = _digitsOnlyPhone(phone);
    if (digits.isEmpty) return;
    await launchUrl(
      Uri.parse('https://wa.me/$digits'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _callSupportPhone(String phone) async {
    final digits = _digitsOnlyPhone(phone);
    if (digits.isEmpty) return;
    await launchUrl(Uri.parse('tel:+$digits'));
  }

  Widget _buildSupportContactsPanel(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final surface2 = isDark ? const Color(0xFF243437) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : _mtaxiText;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8EBE5);
    final whatsAppPhone = (data['whatsAppPhone'] ?? '').toString().trim();
    final callPhone = (data['callPhone'] ?? '').toString().trim();
    if (whatsAppPhone.isEmpty && callPhone.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Связаться со службой поддержки',
              style: FlutterFlowTheme.of(context).titleSmall.override(
                    font: TextStyle(
                      fontFamily: 'Noto Sans',
                      fontWeight:
                          FlutterFlowTheme.of(context).titleSmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleSmall.fontStyle,
                    ),
                    color: textColor,
                    fontWeight:
                        FlutterFlowTheme.of(context).titleSmall.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleSmall.fontStyle,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (whatsAppPhone.isNotEmpty)
                  Expanded(
                    child: InkWell(
                      onTap: () => _openWhatsApp(whatsAppPhone),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366)
                                  .withValues(alpha: 0.22),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const FaIcon(
                              FontAwesomeIcons.whatsapp,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Написать в WhatsApp',
                                overflow: TextOverflow.ellipsis,
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (whatsAppPhone.isNotEmpty) const SizedBox(width: 8),
                if (callPhone.isNotEmpty)
                  Expanded(
                    child: InkWell(
                      onTap: () => _callSupportPhone(callPhone),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: borderColor,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.call,
                              size: 16,
                              color: _mtaxiMint,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Позвонить',
                                overflow: TextOverflow.ellipsis,
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(color: _mtaxiText),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (whatsAppPhone.isNotEmpty)
              Text(
                'WhatsApp: ${_formatPhone(whatsAppPhone)}',
                style: FlutterFlowTheme.of(context)
                    .bodySmall
                    .override(color: _mtaxiMuted),
              ),
            if (callPhone.isNotEmpty)
              Text(
                'Телефон: ${_formatPhone(callPhone)}',
                style: FlutterFlowTheme.of(context)
                    .bodySmall
                    .override(color: _mtaxiMuted),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SupportChatModel());
    _hydrateCachedChatRefsFromUser();
    if (_chatRef != null) {
      _messagesStream = _chatMessagesStream();
    }
    _loading = _chatRef == null;
    _ensureChat(silent: _chatRef != null);
    _userSub = authenticatedUserStream.listen((user) {
      final hasUpdatedRefs = _hydrateCachedChatRefsFromUser(user);
      if (hasUpdatedRefs && mounted) {
        setState(() {
          _loading = _chatRef == null && _pendingMessages.isEmpty;
        });
      }
      if (user == null) return;
      if (_chatRef != null && !hasUpdatedRefs) return;
      if (_isEnsuringChat) return;
      _ensureChat(silent: _chatRef != null);
    });
  }

  void _refreshMessagesStream({bool triggerSetState = true}) {
    final nextStream = _chatMessagesStream();
    if (!mounted || !triggerSetState) {
      _messagesStream = nextStream;
      return;
    }
    setState(() {
      _messagesStream = nextStream;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _userSub?.cancel();
    _model.dispose();
    super.dispose();
  }

  DocumentReference? _documentReferenceFromValue(dynamic value) {
    if (value is DocumentReference) {
      return value;
    }
    return null;
  }

  bool _hydrateCachedChatRefsFromUser([UsersRecord? user]) {
    final data = (user ?? currentUserDocument)?.snapshotData ?? const {};
    final nextChatRef = _documentReferenceFromValue(data['supportChatRef']);
    final nextAdminRef = _documentReferenceFromValue(data['supportAdminRef']);
    final supportChatRefs = data['supportChatRefs'];

    var changed = false;
    if (nextChatRef?.path.isNotEmpty == true &&
        nextChatRef?.path != _chatRef?.path) {
      _chatRef = nextChatRef;
      _rememberChatRef(nextChatRef);
      _refreshMessagesStream(triggerSetState: false);
      changed = true;
    }
    if (nextAdminRef?.path.isNotEmpty == true &&
        nextAdminRef?.path != _adminRef?.path) {
      _adminRef = nextAdminRef;
      _bootstrapSupportChatKeyFromRefs();
      changed = true;
    }
    if (supportChatRefs is Iterable) {
      for (final value in supportChatRefs) {
        final ref = _documentReferenceFromValue(value);
        if (ref?.path.isNotEmpty == true &&
            !_knownChatRefs.any((item) => item.path == ref!.path)) {
          _rememberChatRef(ref);
          changed = true;
        }
      }
    }
    return changed;
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
    var changed = false;
    for (final item in value) {
      final path = item?.toString().trim() ?? '';
      if (path.startsWith('chats/') && path.split('/').length == 2) {
        final alreadyKnown = _knownChatRefs.any((ref) => ref.path == path);
        _rememberChatRef(BackendRefs.instance.doc(path));
        changed = changed || !alreadyKnown;
      }
    }
    if (changed) {
      _refreshMessagesStream();
    }
  }

  void _rememberSupportChatKey(dynamic value) {
    final key = value?.toString().trim() ?? '';
    if (key.isEmpty || key == _supportChatKey) {
      return;
    }
    _supportChatKey = key;
    _refreshMessagesStream();
  }

  void _bootstrapSupportChatKeyFromRefs() {
    final userPath = _currentUserPath;
    final adminPath = _adminRef?.path ?? '';
    if (userPath.isEmpty || adminPath.isEmpty) {
      return;
    }
    final key = '$userPath|$adminPath';
    if (key.isEmpty || key == _supportChatKey) {
      return;
    }
    _supportChatKey = key;
    _refreshMessagesStream();
  }

  String _nextPendingMessageId() {
    _pendingMessageSeq += 1;
    return '${DateTime.now().microsecondsSinceEpoch}_$_pendingMessageSeq';
  }

  String _addPendingMessage({
    required String text,
    String? imageUrl,
  }) {
    final pending = _PendingSupportMessage(
      id: _nextPendingMessageId(),
      text: text,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
    );
    setState(() {
      _pendingMessages.add(pending);
      _loading = false;
    });
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
    if (_pendingMessages.isEmpty) return;
    final deliveredPaths = messages.map((msg) => msg.reference.path).toSet();
    final pendingIdsToRemove = _pendingMessages
        .where((item) =>
            item.messagePath != null &&
            deliveredPaths.contains(item.messagePath))
        .map((item) => item.id)
        .toList(growable: false);
    if (pendingIdsToRemove.isEmpty || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _pendingMessages
            .removeWhere((item) => pendingIdsToRemove.contains(item.id));
      });
    });
  }

  Future<void> _ensureChat({bool silent = false}) async {
    if (_isEnsuringChat) return;
    _isEnsuringChat = true;
    if (_currentUserPath.isEmpty) {
      _isEnsuringChat = false;
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    if (!silent && mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final response = await makeCloudCall('ensureSupportChat', {});
      if (response['success'] == true) {
        final chatPath = (response['chatPath'] ?? '').toString().trim();
        final adminPath = (response['adminPath'] ?? '').toString().trim();
        if (chatPath.isNotEmpty) {
          final nextChatRef = BackendRefs.instance.doc(chatPath);
          _chatRef = nextChatRef;
          _rememberChatRef(nextChatRef);
          _refreshMessagesStream(triggerSetState: false);
          unawaited(_markChatSeen());
        }
        _rememberSupportChatKey(response['supportChatKey']);
        _rememberChatPaths(response['supportChatPaths']);
        if (adminPath.isNotEmpty) {
          _adminRef = BackendRefs.instance.doc(adminPath);
          _bootstrapSupportChatKeyFromRefs();
        }
      }
    } catch (e) {
      debugPrint('ensureSupportChat failed: $e');
    }

    _isEnsuringChat = false;
    _retryEnsureChatScheduled = false;
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  void _scheduleEnsureChatRetry() {
    if (_retryEnsureChatScheduled || _isEnsuringChat || _chatRef != null)
      return;
    if (_currentUserPath.isEmpty) return;
    _retryEnsureChatScheduled = true;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (_chatRef != null || _isEnsuringChat) {
        _retryEnsureChatScheduled = false;
        return;
      }
      _ensureChat();
    });
  }

  Future<void> _sendMessage() async {
    if (_currentUserPath.isEmpty) return;
    if (_isUploadingImage) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (_chatRef == null) {
      await _ensureChat(silent: true);
    }
    if (_chatRef == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть чат поддержки')),
        );
      }
      return;
    }
    _messageController.clear();
    final pendingId = _addPendingMessage(text: text);
    String? messagePath;
    try {
      messagePath = await _sendSupportMessageDirectly(text: text);
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

    await Future.delayed(const Duration(milliseconds: 100));
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    if (_currentUserPath.isEmpty) return;
    final selectedMedia = await selectMediaWithSourceBottomSheet(
      context: context,
      allowPhoto: true,
      storageFolderPath:
          'users/$currentUserUid/chats/${_chatRef?.id ?? 'pending'}',
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
    if (_chatRef == null) {
      await _ensureChat(silent: true);
    }
    if (_chatRef == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть чат поддержки')),
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

    await Future.delayed(const Duration(milliseconds: 100));
    _scrollToBottom();
  }

  Future<String> _sendSupportMessageDirectly({
    required String text,
    String? imageUrl,
  }) async {
    final chatRef = _chatRef;
    if (_currentUserPath.isEmpty || chatRef == null) {
      throw Exception('чат не готов');
    }
    final response = await makeCloudCall('sendSupportChatMessage', {
      'text': text,
      if ((imageUrl ?? '').trim().isNotEmpty) 'imageUrl': imageUrl!.trim(),
      'chatDocPath': chatRef.path,
    });
    if (response['success'] != true) {
      throw Exception(
        (response['error'] ?? 'Не удалось отправить сообщение').toString(),
      );
    }

    final chatPath = (response['chatPath'] ?? '').toString().trim();
    if (chatPath.isNotEmpty) {
      final nextChatRef = BackendRefs.instance.doc(chatPath);
      _chatRef = nextChatRef;
      _rememberChatRef(nextChatRef);
    }
    _rememberSupportChatKey(response['supportChatKey']);
    _rememberChatPaths(response['supportChatPaths']);

    final messagePath = (response['messagePath'] ?? '').toString().trim();
    if (messagePath.isEmpty) {
      throw Exception('Сервер не вернул путь сообщения');
    }
    return messagePath;
  }

  void _openImagePreview(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: MTaxiNetworkImage(url, fit: BoxFit.contain),
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

  void _handleMessageUpdates(List<ChatMessagesRecord> messages) {
    _pruneDeliveredPendingMessages(messages);
    _markChatSeen();
    if (messages.isEmpty) {
      _lastMessageCount = 0;
      return;
    }
    final shouldScroll =
        _lastMessageCount == 0 || messages.length > _lastMessageCount;
    _lastMessageCount = messages.length;
    if (!shouldScroll) return;
    _scheduleScrollToBottom(jump: _lastMessageCount <= 1);
  }

  Future<void> _markChatSeen() async {
    final chatRef = _chatRef;
    if (chatRef == null || _currentUserPath.isEmpty || _isMarkingChatSeen) {
      return;
    }
    _isMarkingChatSeen = true;
    var marked = false;
    try {
      final response = await makeCloudCall(
        'markSupportChatRead',
        {'chatDocPath': chatRef.path},
      );
      if (response['success'] == true) {
        marked = true;
      }
      if (!marked) {
        debugPrint(
          'markSupportChatRead returned error: ${response['error'] ?? response}',
        );
      }
    } catch (e) {
      debugPrint('markSupportChatRead failed: $e');
    }

    _isMarkingChatSeen = false;
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
    if (failed) {
      return 'Ошибка';
    }
    if (pending) {
      return 'Ожидает';
    }
    if (message == null) {
      return '';
    }
    if (!isMine) {
      return 'Получено';
    }
    if (message.snapshotData['backendSource'] == true) {
      return message.snapshotData['readByAdmin'] == true
          ? 'Прочитано'
          : 'Отправлено';
    }
    final currentPath = _currentUserPath;
    final readByOther = message.readBy.any((ref) => ref.path != currentPath);
    if (readByOther) {
      return 'Прочитано';
    }
    final deliveredToOther =
        message.deliveredTo.any((ref) => ref.path != currentPath);
    if (deliveredToOther) {
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

  Widget _buildMessageBubble({
    required bool isMine,
    required String text,
    String? imageUrl,
    ChatMessagesRecord? message,
    bool pending = false,
    bool failed = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normalizedImageUrl = (imageUrl ?? '').trim();
    final bubbleColor = isMine
        ? _mtaxiOrange
        : (isDark ? const Color(0xFF13191D) : const Color(0xFFF0F3EC));
    final textColor =
        isMine ? const Color(0xFF1B242B) : (isDark ? Colors.white : _mtaxiText);
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8EBE5);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Opacity(
        opacity: pending ? 0.78 : 1.0,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.7,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(14),
            border: isMine
                ? Border.all(color: _mtaxiOrange.withValues(alpha: 0.3))
                : Border.all(
                    color: borderColor,
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
                    child: MTaxiNetworkImage(
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
                _messageStatusLabel(
                  message: message,
                  isMine: isMine,
                  pending: pending,
                  failed: failed,
                ),
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      color: failed
                          ? const Color(0xFF993F32)
                          : (isMine ? const Color(0xFF1B242B) : mutedColor),
                    ),
              ),
              if (failed) ...[
                const SizedBox(height: 6),
                Text(
                  'Проверьте интернет и отправьте ещё раз',
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        color: isMine ? const Color(0xFF1B242B) : mutedColor,
                      ),
                ),
              ],
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
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          itemCount: messages.length + _pendingMessages.length,
          itemBuilder: (context, index) {
            if (index < messages.length) {
              final msg = messages[index];
              return _buildMessageBubble(
                isMine: msg.user?.path == _currentUserPath,
                text: msg.text,
                imageUrl: msg.image,
                message: msg,
              );
            }
            final pending = _pendingMessages[index - messages.length];
            return _buildMessageBubble(
              isMine: true,
              text: pending.text,
              imageUrl: pending.imageUrl,
              pending: true,
              failed: pending.failed,
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
                  _mtaxiMint,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Stream<List<ChatMessagesRecord>> _chatMessagesStream() {
    return supportChatMessagesStreamFromBackend(
      chatDocPath: _chatRef?.path,
      supportChatKey: _supportChatKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFFCFCFA);
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : _mtaxiText;
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8EBE5);
    if (!_loading && _chatRef == null) {
      _scheduleEnsureChatRetry();
    }
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: surface,
          iconTheme: IconThemeData(color: textColor),
          automaticallyImplyLeading: true,
          title: Text(
            'Служба поддержки',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: TextStyle(
                    fontFamily: 'Noto Sans',
                    fontWeight:
                        FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  color: textColor,
                  fontSize: 22.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w700,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          centerTitle: false,
          elevation: 0.0,
        ),
        body: AuthUserStreamWidget(
          builder: (context) => SafeArea(
            top: true,
            child: Column(
              children: [
                FutureBuilder<Map<String, dynamic>>(
                  future: getBackendContentDocument('supportContacts'),
                  builder: (context, snapshot) => _buildSupportContactsPanel(
                    context,
                    snapshot.data ?? const <String, dynamic>{},
                  ),
                ),
                Expanded(
                  child: _chatRef == null
                      ? (_pendingMessages.isNotEmpty
                          ? ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _pendingMessages.length,
                              itemBuilder: (context, index) {
                                final pending = _pendingMessages[index];
                                return _buildMessageBubble(
                                  isMine: true,
                                  text: pending.text,
                                  imageUrl: pending.imageUrl,
                                  pending: true,
                                );
                              },
                            )
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.asset(
                                      'assets/images/app_launcher_icon.png',
                                      width: 52,
                                      height: 52,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (_loading)
                                    CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _mtaxiMint,
                                      ),
                                    ),
                                  if (_loading) const SizedBox(height: 12),
                                  Text(
                                    _loading
                                        ? 'Подключаем чат поддержки...'
                                        : 'Не удалось открыть чат',
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(color: mutedColor),
                                  ),
                                ],
                              ),
                            ))
                      : StreamBuilder<List<ChatMessagesRecord>>(
                          key: ValueKey(
                            '${_chatRef?.path ?? 'chat'}::${_supportChatKey ?? ''}',
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
                                          .bodyMedium
                                          .override(color: textColor),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {});
                                        _scheduleEnsureChatRetry();
                                      },
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
                                    _mtaxiMint,
                                  ),
                                ),
                              );
                            }
                            final liveMessages = snapshot.data ?? [];
                            final isTemporaryEmpty = liveMessages.isEmpty &&
                                _lastStableMessages.isNotEmpty;
                            final isTransientShrink = liveMessages.isNotEmpty &&
                                _lastStableMessages.isNotEmpty &&
                                liveMessages.length <
                                    _lastStableMessages.length &&
                                snapshot.connectionState !=
                                    ConnectionState.done;
                            final messages =
                                (isTemporaryEmpty || isTransientShrink)
                                    ? _lastStableMessages
                                    : liveMessages;
                            if (!isTransientShrink && liveMessages.isNotEmpty) {
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  color: pageBg,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: FFLocalizations.of(context).getVariableText(
                            ruText: 'Прикрепить фото', kkText: 'Фото тіркеу'),
                        onPressed: _isUploadingImage ? null : _sendImage,
                        icon: _isUploadingImage
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _mtaxiMint,
                                  ),
                                ),
                              )
                            : const Icon(Icons.photo_outlined, size: 18),
                        color: _mtaxiOrange,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          minLines: 1,
                          maxLines: 4,
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(color: textColor),
                          decoration: InputDecoration(
                            hintText: FFLocalizations.of(context)
                                .getVariableText(
                                    ruText: 'Сообщение', kkText: 'Хабарлама'),
                            hintStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(color: mutedColor),
                            filled: true,
                            fillColor: surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: borderColor,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: _mtaxiOrange,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: FFLocalizations.of(context).getVariableText(
                            ruText: 'Отправить сообщение',
                            kkText: 'Хабарлама жіберу'),
                        onPressed: _isUploadingImage ? null : _sendMessage,
                        icon: const Icon(Icons.send, size: 18),
                        color: _mtaxiOrange,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
