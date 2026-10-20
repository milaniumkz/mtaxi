import '/auth/backend_auth/auth_util.dart';
import '/backend/backend_admin_users.dart';
import '/backend/backend.dart';
import '/backend/backend_support_chat.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/admin/admin_utils.dart';
import 'admin_support_chats_model.dart';
export 'admin_support_chats_model.dart';

const _mtaxiPageBg = Color(0xFF12051B);
const _mtaxiSurface = Color(0xFFFFFFFF);

class AdminSupportChatsWidget extends StatefulWidget {
  const AdminSupportChatsWidget({super.key});

  static String routeName = 'adminSupportChats';
  static String routePath = '/admin/support';

  @override
  State<AdminSupportChatsWidget> createState() =>
      _AdminSupportChatsWidgetState();
}

class _AdminSupportChatsWidgetState extends State<AdminSupportChatsWidget> {
  late AdminSupportChatsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  String get _currentAdminPath => currentUserDocument?.reference.path ?? '';

  String _userTitle(UsersRecord user) {
    final name =
        buildAdminUserName(user.snapshotData, fallback: user.displayName);
    if (name.isNotEmpty) {
      return name;
    }
    return normalizeAdminText(user.phoneNumber).isNotEmpty
        ? normalizeAdminText(user.phoneNumber)
        : 'Пользователь';
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminSupportChatsModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  DocumentReference? _getUserRef(ChatsRecord chat) {
    final adminPath = _currentAdminPath;
    if (chat.userA != null && chat.userA?.path != adminPath) {
      return chat.userA;
    }
    if (chat.userB != null && chat.userB?.path != adminPath) {
      return chat.userB;
    }
    for (final userRef in chat.users) {
      if (userRef.path != adminPath) {
        return userRef;
      }
    }
    if (chat.userA != null) return chat.userA;
    if (chat.userB != null) return chat.userB;
    if (chat.users.isNotEmpty) return chat.users.first;
    return null;
  }

  bool _isSupportChat(ChatsRecord chat) {
    if (chat.snapshotData['archived'] == true) {
      return false;
    }
    final key = (chat.snapshotData['support_chat_key'] ?? '').toString().trim();
    return key.isNotEmpty;
  }

  String _normalizeChatPreview(dynamic rawValue) {
    if (rawValue is String) {
      final normalized = rawValue.trim();
      if (normalized.isEmpty) {
        return '';
      }
      final lowered = normalized.toLowerCase();
      if (lowered == '[object object]' || lowered == 'object') {
        return 'Сообщение';
      }
      return normalized;
    }
    if (rawValue is Map) {
      final text =
          (rawValue['text'] ?? rawValue['message'] ?? '').toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
      final image =
          (rawValue['image'] ?? rawValue['imageUrl'] ?? '').toString().trim();
      if (image.isNotEmpty) {
        return 'Фото';
      }
      return 'Сообщение';
    }
    if (rawValue is Iterable) {
      return 'Сообщение';
    }
    final fallback = rawValue?.toString().trim() ?? '';
    if (fallback.isEmpty) {
      return '';
    }
    if (fallback.toLowerCase() == '[object object]' ||
        fallback.toLowerCase() == 'object') {
      return 'Сообщение';
    }
    return fallback;
  }

  String _chatPreview(ChatsRecord chat) {
    final normalizedLastMessage = _normalizeChatPreview(chat.lastMessage);
    if (normalizedLastMessage.isNotEmpty) {
      return normalizedLastMessage;
    }
    return _normalizeChatPreview(chat.snapshotData['last_message']);
  }

  String _backendChatUserTitle(ChatsRecord chat) {
    final name = normalizeAdminText(chat.snapshotData['backend_user_name']);
    if (name.isNotEmpty) return name;
    final phone = normalizeAdminText(chat.snapshotData['backend_user_phone']);
    if (phone.isNotEmpty) return phone;
    return 'Пользователь';
  }

  String _backendChatUserSubtitle(ChatsRecord chat) {
    return [
      normalizeAdminText(chat.snapshotData['backend_user_phone']),
      normalizeAdminText(chat.snapshotData['backend_user_city']),
      normalizeAdminText(chat.snapshotData['backend_user_role']),
    ].where((value) => value.isNotEmpty).join(' • ');
  }

  Future<void> _openSupportChat(ChatsRecord chat) async {
    final userRef = _getUserRef(chat);
    final supportChatKey =
        (chat.snapshotData['support_chat_key'] ?? '').toString().trim();
    context.goNamed(
      AdminSupportChatWidget.routeName,
      queryParameters: {
        'chatDocPath': chat.reference.path,
        if (userRef != null) 'userDocPath': userRef.path,
        if (supportChatKey.isNotEmpty) 'supportChatKey': supportChatKey,
      },
      extra: {
        'chatRef': chat.reference,
        if (userRef != null) 'userRef': userRef,
        if (supportChatKey.isNotEmpty) 'supportChatKey': supportChatKey,
      },
    );
  }

  Future<DocumentReference?> _findOrCreateSupportChat(
    UsersRecord user,
  ) async {
    final response = await makeCloudCall(
      'ensureSupportChat',
      {'targetUserDocPath': user.reference.path},
    );
    if (response['success'] != true) {
      return null;
    }
    final chatPath = (response['chatPath'] ?? '').toString().trim();
    if (chatPath.isEmpty) {
      return null;
    }
    return BackendRefs.instance.doc(chatPath);
  }

  Future<UsersRecord?> _pickUserForNewChat() async {
    final usersFuture = loadAdminUsersFromBackend(limit: 400);
    final searchController = TextEditingController();
    String searchQuery = '';

    final selectedUser = await showModalBottomSheet<UsersRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _mtaxiSurface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.82,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Новый чат поддержки',
                        style: FlutterFlowTheme.of(context).headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchController,
                        onChanged: (value) {
                          setModalState(() {
                            searchQuery = value.trim().toLowerCase();
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Имя, телефон, город',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: FutureBuilder<List<UsersRecord>>(
                          future: usersFuture,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    FlutterFlowTheme.of(context).primary,
                                  ),
                                ),
                              );
                            }

                            final users = snapshot.data!
                                .where((user) => !isAdminUser(user))
                                .toList(growable: false);
                            final filtered = searchQuery.isEmpty
                                ? users
                                : users.where((user) {
                                    final firstName = normalizeAdminText(
                                      user.snapshotData['firstName'],
                                    );
                                    final lastName = normalizeAdminText(
                                      user.snapshotData['lastName'],
                                    );
                                    final haystack = [
                                      firstName,
                                      lastName,
                                      buildAdminUserName(
                                        user.snapshotData,
                                        fallback: user.displayName,
                                      ),
                                      normalizeAdminText(user.phoneNumber),
                                      normalizeAdminText(user.city),
                                      normalizeAdminText(user.role),
                                    ].join(' ').toLowerCase();
                                    return haystack.contains(searchQuery);
                                  }).toList(growable: false);

                            if (filtered.isEmpty) {
                              return Center(
                                child: Text(
                                  'Пользователи не найдены',
                                  style:
                                      FlutterFlowTheme.of(context).bodyMedium,
                                ),
                              );
                            }

                            return ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final user = filtered[index];
                                final title = _userTitle(user);
                                final subtitle = [
                                  if (normalizeAdminText(user.phoneNumber)
                                      .isNotEmpty)
                                    normalizeAdminText(user.phoneNumber),
                                  if (normalizeAdminText(user.city).isNotEmpty)
                                    normalizeAdminText(user.city),
                                  if (normalizeAdminText(user.role).isNotEmpty)
                                    normalizeAdminText(user.role),
                                ].join(' • ');
                                return ListTile(
                                  tileColor: _mtaxiSurface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                    ),
                                  ),
                                  title: Text(title),
                                  subtitle:
                                      subtitle.isEmpty ? null : Text(subtitle),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () =>
                                      Navigator.of(sheetContext).pop(user),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
    return selectedUser;
  }

  Future<void> _startNewChat() async {
    final user = await _pickUserForNewChat();
    if (user == null || !mounted) {
      return;
    }

    final chatRef = await _findOrCreateSupportChat(user);
    if (chatRef == null || !mounted) {
      return;
    }

    context.goNamed(
      AdminSupportChatWidget.routeName,
      queryParameters: {
        'chatDocPath': chatRef.path,
        'userDocPath': user.reference.path,
      },
      extra: {'chatRef': chatRef, 'userRef': user.reference},
    );
  }

  Future<bool> _confirmDangerAction({
    required String title,
    required String message,
    required String actionLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _clearAllSupportChats() async {
    final confirmed = await _confirmDangerAction(
      title: 'Очистить все чаты?',
      message: 'Будут удалены все чаты поддержки и сообщения.',
      actionLabel: 'Очистить',
    );
    if (!confirmed || !mounted) return;
    final response = await makeCloudCall('adminClearSupportChats', {});
    if (!mounted) return;
    final success = response['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Чаты очищены'
            : (response['error'] ?? 'Не удалось очистить чаты').toString()),
      ),
    );
    if (success) {
      setState(() {});
    }
  }

  Future<void> _deleteSupportChat(ChatsRecord chat) async {
    final confirmed = await _confirmDangerAction(
      title: 'Удалить чат?',
      message: 'Будет удален этот чат поддержки и все его сообщения.',
      actionLabel: 'Удалить',
    );
    if (!confirmed || !mounted) return;
    final response = await makeCloudCall('adminDeleteSupportChat', {
      'chatDocPath': chat.reference.path,
      'supportChatKey':
          (chat.snapshotData['support_chat_key'] ?? '').toString(),
    });
    if (!mounted) return;
    final success = response['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Чат удален'
            : (response['error'] ?? 'Не удалось удалить чат').toString()),
      ),
    );
    if (success) {
      setState(() {});
    }
  }

  bool _isUnreadForCurrentAdmin(ChatsRecord chat) {
    final raw = chat.snapshotData['unread_for_admin'];
    final unread = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
    return unread > 0;
  }

  String _formatChatTime(DateTime? value) {
    if (value == null) {
      return '';
    }
    return dateTimeFormat(
      'd.MM HH:mm',
      value,
      locale: FFLocalizations.of(context).languageCode,
    );
  }

  DateTime _chatSortTime(ChatsRecord chat) {
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
              (((nanoseconds as num?) ?? 0).round() ~/ 1000000);
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

    final raw = chat.snapshotData['last_message_time'];
    final parsedRaw = parseDynamicDate(raw);
    if (parsedRaw != null) {
      return parsedRaw;
    }
    final updatedAt = chat.snapshotData['updated_at'];
    final parsedUpdatedAt = parseDynamicDate(updatedAt);
    if (parsedUpdatedAt != null) {
      return parsedUpdatedAt;
    }
    final createdAt = chat.snapshotData['created_at'];
    final parsedCreatedAt = parseDynamicDate(createdAt);
    if (parsedCreatedAt != null) {
      return parsedCreatedAt;
    }
    return chat.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = isAdminUser(currentUserDocument);

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: _mtaxiPageBg,
      appBar: AppBar(
        backgroundColor: _mtaxiPageBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'На главную',
          color: Colors.white,
          onPressed: () {
            context.goNamed(AdminHomeWidget.routeName);
          },
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Очистить чаты',
              color: Colors.white,
              onPressed: _clearAllSupportChats,
            ),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'На главную',
            color: Colors.white,
            onPressed: () {
              context.goNamed(AdminHomeWidget.routeName);
            },
          ),
        ],
        title: Text(
          'Чат поддержки',
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                font: GoogleFonts.readexPro(
                  fontWeight: FontWeight.w600,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
                letterSpacing: 0.0,
                fontWeight: FontWeight.w600,
                fontStyle:
                    FlutterFlowTheme.of(context).headlineMedium.fontStyle,
              ),
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _startNewChat,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Новый чат'),
            )
          : null,
      body: AuthUserStreamWidget(
        builder: (context) => SafeArea(
          child: !isAdmin
              ? Center(
                  child: Text(
                    'Доступ только для администратора',
                    style: FlutterFlowTheme.of(context).bodyLarge,
                  ),
                )
              : StreamBuilder<List<ChatsRecord>>(
                  stream: supportChatsStreamFromBackend(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Ошибка загрузки чатов',
                          style: FlutterFlowTheme.of(context).bodyMedium,
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            FlutterFlowTheme.of(context).primary,
                          ),
                        ),
                      );
                    }
                    final chats = (snapshot.data ?? [])
                        .where(_isSupportChat)
                        .toList(growable: false);
                    final latestChatsByUser = <String, ChatsRecord>{};
                    for (final chat in chats) {
                      final userRef = _getUserRef(chat);
                      final key = userRef?.path ?? chat.reference.path;
                      latestChatsByUser.putIfAbsent(key, () => chat);
                    }
                    final visibleChats = latestChatsByUser.values
                        .toList(growable: true)
                      ..sort((a, b) =>
                          _chatSortTime(b).compareTo(_chatSortTime(a)));
                    if (visibleChats.isEmpty) {
                      return Center(
                        child: Text(
                          'Нет обращений',
                          style: FlutterFlowTheme.of(context).bodyMedium,
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: visibleChats.length,
                      itemBuilder: (context, index) {
                        final chat = visibleChats[index];
                        final isUnread = _isUnreadForCurrentAdmin(chat);
                        final timeLabel = _formatChatTime(chat.lastMessageTime);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _openSupportChat(chat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isUnread
                                    ? FlutterFlowTheme.of(context)
                                        .primary
                                        .withValues(alpha: 0.08)
                                    : FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isUnread
                                      ? FlutterFlowTheme.of(context).primary
                                      : FlutterFlowTheme.of(context).alternate,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.forum,
                                    color: isUnread
                                        ? FlutterFlowTheme.of(context).primary
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _backendChatUserTitle(chat),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyLarge
                                              .override(
                                                fontWeight: isUnread
                                                    ? FontWeight.w700
                                                    : FlutterFlowTheme.of(
                                                            context)
                                                        .bodyLarge
                                                        .fontWeight,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            _chatPreview(chat),
                                            _backendChatUserSubtitle(chat),
                                          ]
                                              .where((value) =>
                                                  value.trim().isNotEmpty)
                                              .join(' • '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (timeLabel.isNotEmpty)
                                        Text(
                                          timeLabel,
                                          style: FlutterFlowTheme.of(context)
                                              .labelSmall
                                              .override(
                                                color: isUnread
                                                    ? FlutterFlowTheme.of(
                                                            context)
                                                        .primary
                                                    : FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryText,
                                                fontWeight: isUnread
                                                    ? FontWeight.w700
                                                    : FlutterFlowTheme.of(
                                                            context)
                                                        .labelSmall
                                                        .fontWeight,
                                              ),
                                        ),
                                      if (isUnread)
                                        Container(
                                          margin: const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'NEW',
                                            style: FlutterFlowTheme.of(context)
                                                .labelSmall
                                                .override(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        )
                                      else
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Icon(
                                            Icons.chevron_right,
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: IconButton(
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          tooltip: 'Удалить чат',
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          onPressed: () =>
                                              _deleteSupportChat(chat),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}
