import 'dart:async';

import '/auth/backend_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/backend_session.dart';
import '/backend/backend_support_chat.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/backend/uploads/storage.dart';
import '/component/select_balance/select_balance_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/upload_data.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_model.dart';
export 'profile_model.dart';

const _mtaxiText = Color(0xFF1E1525);
const _mtaxiMuted = Color(0xFF73677C);
const _mtaxiOrange = Color(0xFFFF6B00);

class ProfileWidget extends StatefulWidget {
  const ProfileWidget({super.key});

  static String routeName = 'profile';
  static String routePath = '/profile';

  @override
  State<ProfileWidget> createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget> {
  late ProfileModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSwitchingRoleState = false;
  final Set<String> _optimisticallyReadSupportChatPaths = {};
  final Set<String> _optimisticallyReadSupportChatKeys = {};

  String get _currentUserPath => currentUserDocument?.reference.path ?? '';

  Future<void> _refreshCurrentUserRecord() async {
    final response = await makeCloudCall('getSessionBootstrap', {});
    await saveBackendUserFromResponse(response);
  }

  bool get _hasDriverAccount => userHasDriverAccount(currentUserDocument);

  String _effectiveProfileImageUrlForMode(String roleState) {
    if (roleState == 'DRIVER' && _hasDriverAccount) {
      final vehiclePhoto = (currentUserDocument?.avtoImage ?? '').trim();
      if (vehiclePhoto.isNotEmpty) {
        return vehiclePhoto;
      }
    }
    return (currentUserDocument?.photoUrl ?? currentUser?.photoUrl ?? '')
        .trim();
  }

  bool _canChangeProfilePhoto(String roleState) => roleState == 'PASSENGER';

  bool _matchesAuthoritativeTargetRoleState(
    String targetRoleState, [
    UsersRecord? user,
  ]) {
    final current = user ?? currentUserDocument;
    if (current == null) {
      return false;
    }
    final authoritativeRoleState = (current.snapshotData['roleState'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    return authoritativeRoleState == targetRoleState;
  }

  Future<bool> _waitForRoleStateApplied(
    String targetRoleState, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (_matchesAuthoritativeTargetRoleState(targetRoleState)) {
      return true;
    }

    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) {
        return false;
      }
      if (_matchesAuthoritativeTargetRoleState(targetRoleState)) {
        return true;
      }
    }
    return _matchesAuthoritativeTargetRoleState(targetRoleState);
  }

  Future<void> _switchRoleState({
    required String targetRoleState,
    required String routePath,
  }) async {
    if (_isSwitchingRoleState) {
      return;
    }

    safeSetState(() {
      _isSwitchingRoleState = true;
    });

    if (targetRoleState == 'PASSENGER') {
      FFAppState().forcePassengerMode();
    } else {
      FFAppState().clearForcedPassengerMode();
    }
    UserModeResolver.setTransientRoleState(targetRoleState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.go(routePath);
    });
    try {
      unawaited(
        makeCloudCall(
          'updateUserPreferences',
          {
            'userDocPath': currentUserDocument?.reference.path,
            'targetRoleState': targetRoleState,
          },
        ).then((response) async {
          final success = response['success'] == true;
          final code = (response['code'] ?? '').toString().trim().toLowerCase();
          if (success ||
              code == 'unavailable' ||
              code == 'deadline-exceeded' ||
              response['timeout'] == true) {
            if (success) {
              await saveBackendUserFromResponse(response);
            }
            await _waitForRoleStateApplied(targetRoleState);
            return;
          }
          debugPrint(
            'updateUserPreferences background error: ${(response['error'] ?? '').toString().trim()}',
          );
        }).catchError((Object error, StackTrace stackTrace) {
          debugPrint('updateUserPreferences background exception: $error');
        }),
      );
    } finally {
      if (!_matchesAuthoritativeTargetRoleState(targetRoleState)) {
        // Keep transient mode while the authoritative user doc catches up.
      }
      if (mounted) {
        safeSetState(() {
          _isSwitchingRoleState = false;
        });
      } else {
        _isSwitchingRoleState = false;
      }
    }
  }

  Future<void> _changeProfilePhoto() async {
    if (currentUserUid.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала войдите в аккаунт заново и повторите попытку'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    FFAppState().clearPassengerOrderCreationState();
    FFAppState().update(() {});
    final selectedMedia = await selectMediaWithSourceBottomSheet(
      context: context,
      allowPhoto: true,
    );
    if (selectedMedia == null ||
        !selectedMedia
            .every((m) => validateFileFormat(m.storagePath, context))) {
      return;
    }
    if (!mounted) {
      return;
    }

    showUploadMessage(
      context,
      'Загружаем фото...',
      showLoading: true,
    );
    safeSetState(() => _model.isDataUploading_uploadData4to = true);
    var selectedUploadedFiles = <FFUploadedFile>[];
    var downloadUrls = <String>[];
    String? uploadError;
    try {
      selectedUploadedFiles = selectedMedia
          .map((m) => FFUploadedFile(
                name: m.storagePath.split('/').last,
                bytes: m.bytes,
                height: m.dimensions?.height,
                width: m.dimensions?.width,
                blurHash: m.blurHash,
                originalFilename: m.originalFilename,
              ))
          .toList();

      downloadUrls = (await Future.wait(
        selectedMedia.map((m) async {
          final filename = m.storagePath.split('/').last.trim();
          final safeFilename = filename.isEmpty
              ? 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg'
              : filename;
          return uploadData(
            'users/$currentUserUid/profile/$safeFilename',
            m.bytes,
          );
        }),
      ))
          .where((u) => u != null)
          .map((u) => u!)
          .toList();
    } catch (e) {
      uploadError = e.toString().replaceFirst('Exception: ', '').trim();
    } finally {
      _model.isDataUploading_uploadData4to = false;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    if (uploadError != null ||
        selectedUploadedFiles.length != selectedMedia.length ||
        downloadUrls.length != selectedMedia.length) {
      safeSetState(() {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uploadError?.isNotEmpty == true
                ? uploadError!
                : 'Не удалось загрузить фото профиля',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final uploadedUrl = downloadUrls.first.trim();
    if (uploadedUrl.isEmpty) {
      return;
    }

    safeSetState(() {
      _model.uploadedLocalFile_uploadData4to = selectedUploadedFiles.first;
      _model.uploadedFileUrl_uploadData4to = uploadedUrl;
    });
    try {
      final response = await makeCloudCall(
        'updateUserPreferences',
        {
          'photoUrl': uploadedUrl,
        },
      );
      if (response['success'] != true) {
        throw Exception(
          (response['error'] ?? 'Не удалось сохранить фото профиля').toString(),
        );
      }
      await saveBackendUserFromResponse(response);
      await _refreshCurrentUserRecord();
      if (mounted) {
        safeSetState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Фото профиля обновлено'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openDriverTopUpSheet() async {
    if (!userHasApprovedDriverAccess(currentUserDocument)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Пополнение доступно после подтверждения водителя администратором',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: const SelectBalanceWidget(),
        );
      },
    );
  }

  String _formatMoneyValue(double value) {
    return formatAppCurrency(value.abs());
  }

  bool _chatBelongsToCurrentUser(ChatsRecord chat, String userPath) {
    if (userPath.isEmpty) {
      return false;
    }
    final inUsers = chat.users.any((ref) => ref.path == userPath);
    return chat.userA?.path == userPath ||
        chat.userB?.path == userPath ||
        inUsers;
  }

  bool _isSupportChatForCurrentUser(ChatsRecord chat) {
    final userPath = _currentUserPath;
    final userData = currentUserDocument?.snapshotData ?? const {};
    final knownSupportKeys = <String>{};
    final refsByPath = <String>{};

    final storedSupportKey =
        (userData['supportChatKey'] ?? '').toString().trim();
    if (storedSupportKey.isNotEmpty) {
      knownSupportKeys.add(storedSupportKey);
    }
    final supportAdminRef = userData['supportAdminRef'];
    if (userPath.isNotEmpty && supportAdminRef is DocumentReference) {
      knownSupportKeys.add('$userPath|${supportAdminRef.path}');
    }

    final supportKey =
        (chat.snapshotData['support_chat_key'] ?? '').toString().trim();
    if (supportKey.isNotEmpty && knownSupportKeys.isNotEmpty) {
      return knownSupportKeys.contains(supportKey);
    }

    final supportChatRef = userData['supportChatRef'];
    if (supportChatRef is DocumentReference) {
      refsByPath.add(supportChatRef.path);
    }
    final supportChatRefs = userData['supportChatRefs'];
    if (supportChatRefs is Iterable) {
      for (final value in supportChatRefs) {
        if (value is DocumentReference) {
          refsByPath.add(value.path);
        }
      }
    }
    if (refsByPath.isNotEmpty) {
      return refsByPath.contains(chat.reference.path);
    }

    if (supportKey.isNotEmpty) {
      return true;
    }
    return refsByPath.contains(chat.reference.path);
  }

  int _supportUnreadChatsCount(List<ChatsRecord> chats) {
    final userPath = _currentUserPath;
    if (userPath.isEmpty) return 0;
    final unreadChatIds = <String>{};
    for (final chat in chats) {
      final backendUnreadRaw = chat.snapshotData['unread_for_user'];
      final backendUnread = backendUnreadRaw is num
          ? backendUnreadRaw.toInt()
          : int.tryParse(backendUnreadRaw?.toString() ?? '');
      if (backendUnread != null) {
        if (backendUnread > 0) {
          unreadChatIds.add('path:${chat.reference.path}');
        }
        continue;
      }
      if (!_chatBelongsToCurrentUser(chat, userPath)) {
        continue;
      }
      if (!_isSupportChatForCurrentUser(chat)) {
        continue;
      }
      final supportKey =
          (chat.snapshotData['support_chat_key'] ?? '').toString().trim();
      final unreadIdentity = supportKey.isNotEmpty
          ? 'key:$supportKey'
          : 'path:${chat.reference.path}';
      if (supportKey.isNotEmpty &&
          _optimisticallyReadSupportChatKeys.contains(supportKey)) {
        continue;
      }
      if (_optimisticallyReadSupportChatPaths.contains(chat.reference.path)) {
        continue;
      }
      if (chat.lastMessageSentBy == null ||
          chat.lastMessageSentBy?.path == userPath) {
        continue;
      }
      final isSeen = chat.lastMessageSeenBy.any((ref) => ref.path == userPath);
      if (!isSeen) {
        unreadChatIds.add(unreadIdentity);
      }
    }
    return unreadChatIds.length;
  }

  Future<void> _markSupportChatsRead({
    List<ChatsRecord>? visibleChats,
  }) async {
    if (_currentUserPath.isEmpty) return;

    final refsByPath = <String, DocumentReference>{};
    final supportKeys = <String>{};
    void addChatRef(DocumentReference? ref) {
      final path = ref?.path ?? '';
      if (path.isEmpty) return;
      refsByPath[path] = ref!;
    }

    void addSupportKey(dynamic value) {
      final key = value?.toString().trim() ?? '';
      if (key.isEmpty) return;
      supportKeys.add(key);
    }

    if (visibleChats != null) {
      for (final chat in visibleChats) {
        if (_chatBelongsToCurrentUser(chat, _currentUserPath)) {
          addChatRef(chat.reference);
          addSupportKey(chat.snapshotData['support_chat_key']);
        }
      }
    }

    final userData = currentUserDocument?.snapshotData ?? const {};
    final supportChatRef = userData['supportChatRef'];
    if (supportChatRef is DocumentReference) {
      addChatRef(supportChatRef);
    }
    final supportChatRefs = userData['supportChatRefs'];
    if (supportChatRefs is Iterable) {
      for (final value in supportChatRefs) {
        if (value is DocumentReference) {
          addChatRef(value);
        }
      }
    }
    addSupportKey(userData['supportChatKey']);

    if (refsByPath.isNotEmpty && mounted) {
      setState(() {
        _optimisticallyReadSupportChatPaths.addAll(refsByPath.keys);
        _optimisticallyReadSupportChatKeys.addAll(supportKeys);
      });
    }

    if (refsByPath.isEmpty) {
      try {
        final response = await makeCloudCall('getMySupportChat', {});
        final path = response['chatPath']?.toString().trim() ?? '';
        final key = response['supportChatKey']?.toString().trim() ?? '';
        if (path.isNotEmpty) {
          refsByPath[path] = BackendRefs.instance.doc(path);
        }
        if (key.isNotEmpty) {
          supportKeys.add(key);
        }
        if (refsByPath.isNotEmpty && mounted) {
          setState(() {
            _optimisticallyReadSupportChatPaths.addAll(refsByPath.keys);
            _optimisticallyReadSupportChatKeys.addAll(supportKeys);
          });
        }
      } catch (e) {
        debugPrint('Failed to load backend support chat before read mark: $e');
      }
    }

    for (final chatRef in refsByPath.values) {
      var marked = false;
      try {
        final response = await makeCloudCall(
          'markSupportChatRead',
          {'chatDocPath': chatRef.path},
        );
        marked = response['success'] == true;
        if (marked) {
          addSupportKey(response['supportChatKey']);
          final returnedPaths = response['supportChatPaths'];
          if (returnedPaths is Iterable) {
            for (final value in returnedPaths) {
              final path = value?.toString().trim() ?? '';
              if (path.isEmpty) {
                continue;
              }
              refsByPath[path] = BackendRefs.instance.doc(path);
            }
          }
          if (mounted) {
            setState(() {
              _optimisticallyReadSupportChatPaths.addAll(refsByPath.keys);
              _optimisticallyReadSupportChatKeys.addAll(supportKeys);
            });
          }
        }
      } catch (e) {
        debugPrint('markSupportChatRead failed for ${chatRef.path}: $e');
      }

      if (marked) {
        continue;
      }
    }
  }

  void _openSupportChat({List<ChatsRecord>? visibleChats}) {
    unawaited(_markSupportChatsRead(visibleChats: visibleChats));
    context.pushNamed(SupportChatWidget.routeName);
  }

  Widget _buildRoleModeToggle({
    required bool isPassengerMode,
    required bool isDriverMode,
    required bool hasDriverAccount,
    required String statusDriver,
    required String roleState,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceAlt =
        isDark ? const Color(0xFF243437) : const Color(0xFFF6F2F8);
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8E2EC);
    Widget segment({
      required IconData icon,
      required String title,
      required bool active,
      required Future<void> Function()? onTap,
    }) {
      final enabled = onTap != null && !_isSwitchingRoleState;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: active ? _mtaxiOrange : Colors.transparent,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.readexPro(
                            fontWeight: FontWeight.w700,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                          color: active
                              ? Colors.white
                              : enabled
                                  ? FlutterFlowTheme.of(context).primaryText
                                  : FlutterFlowTheme.of(context).secondaryText,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w700,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentModeTitle = switch (roleState) {
      'DRIVER_ONLINE' || 'DRIVER_OFFLINE' || 'DRIVER_ON_TRIP' => 'Водитель',
      'DRIVER_PENDING' => 'Ожидание проверки',
      'ADMIN' => 'Администратор',
      'BLOCKED' => 'Заблокирован',
      _ => 'Пассажир',
    };
    final canSwitchRoles = roleState != 'ADMIN' && roleState != 'BLOCKED';
    final canOpenDriverMode =
        hasDriverAccount && UserModeResolver.userHasApprovedDriverAccess();
    final canStartDriverFlow =
        !canOpenDriverMode && !isDriverRegistrationPendingReview();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6.0, 0.0, 6.0, 8.0),
            child: Text(
              'Текущий режим: $currentModeTitle',
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.readexPro(
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: surfaceAlt,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: borderColor,
              ),
            ),
            child: Row(
              children: [
                segment(
                  icon: Icons.person_outline,
                  title: 'Пассажир',
                  active: isPassengerMode,
                  onTap: isPassengerMode || !canSwitchRoles
                      ? null
                      : () async {
                          await _switchRoleState(
                            targetRoleState: 'PASSENGER',
                            routePath: HomePageWidget.routePath,
                          );
                        },
                ),
                const SizedBox(width: 4.0),
                segment(
                  icon: Icons.directions_car_filled_outlined,
                  title: 'Водитель',
                  active: isDriverMode,
                  onTap: !canSwitchRoles
                      ? null
                      : () async {
                          if (canOpenDriverMode) {
                            await _switchRoleState(
                              targetRoleState: 'DRIVER_ONLINE',
                              routePath: HomeDriverWidget.routePath,
                            );
                            return;
                          }
                          if (canStartDriverFlow) {
                            FFAppState().pendingRegistrationRole = 'driver';
                            FFAppState().update(() {});
                            context.goNamedAuth(
                              SetProfileDriverWidget.routeName,
                              context.mounted,
                              extra: <String, dynamic>{
                                kTransitionInfoKey: TransitionInfo(
                                  hasTransition: true,
                                  transitionType: PageTransitionType.scale,
                                  alignment: Alignment.bottomCenter,
                                ),
                              },
                            );
                            return;
                          }
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDriverAccount = userHasDriverAccount(currentUserDocument);
    final roleState = getUserRoleState(currentUserDocument);
    final isPassengerMode = roleState == 'PASSENGER';
    final isDriverMode =
        UserModeResolver.resolveActiveMode(currentUserDocument) == 'driver';
    final driverBalance = valueOrDefault(currentUserDocument?.balance, 0.0);
    final hasDriverDebt = driverBalance < 0;
    final balanceTitle = hasDriverDebt ? 'К оплате:' : 'Баланс:';
    final balanceValue = _formatMoneyValue(driverBalance);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFEFF2F6);
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : _mtaxiText;
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8E2EC);
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: pageBg,
        body: SingleChildScrollView(
          primary: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 58.0, 24.0, 110.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                InkWell(
                  splashColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onTap: _canChangeProfilePhoto(roleState)
                      ? _changeProfilePhoto
                      : null,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.zero,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Stack(
                      children: [
                        Align(
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 12.0, 0.0, 0.0),
                            child: Container(
                              width: 100.0,
                              height: 100.0,
                              decoration: BoxDecoration(
                                color: surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: surface, width: 2),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(2.0),
                                child: AuthUserStreamWidget(
                                  builder: (context) {
                                    final imageUrl =
                                        _effectiveProfileImageUrlForMode(
                                      roleState,
                                    );
                                    if (imageUrl.isEmpty) {
                                      return Icon(
                                        Icons.person,
                                        size: 24.0,
                                        color: mutedColor,
                                      );
                                    }
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(50.0),
                                      child: Image.network(
                                        imageUrl,
                                        width: 100.0,
                                        height: 100.0,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Icon(
                                          Icons.person,
                                          size: 24.0,
                                          color: mutedColor,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 22.0),
                      child: AuthUserStreamWidget(
                        builder: (context) => Text(
                          currentUserDisplayName,
                          textAlign: TextAlign.center,
                          style: FlutterFlowTheme.of(context)
                              .headlineSmall
                              .override(
                                font: GoogleFonts.outfit(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .headlineSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .headlineSmall
                                      .fontStyle,
                                ),
                                color: textColor,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w800,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .headlineSmall
                                    .fontStyle,
                              ),
                        ),
                      ),
                    ),
                    if (isDriverMode)
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(10.0),
                                  child: Text(
                                    balanceTitle,
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.readexPro(
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          color: textColor,
                                          fontSize: 16.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(10.0),
                                  child: AuthUserStreamWidget(
                                    builder: (context) => Text(
                                      balanceValue,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.readexPro(
                                              fontWeight: FontWeight.w800,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: hasDriverDebt
                                                ? Colors.red
                                                : textColor,
                                            fontSize: 23.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w800,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(8, 18, 8, 14),
                                  child: FFButtonWidget(
                                    onPressed: _openDriverTopUpSheet,
                                    text: 'Пополнить',
                                    options: FFButtonOptions(
                                      width: double.infinity,
                                      height: 50.0,
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                              24.0, 0.0, 24.0, 0.0),
                                      iconPadding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                              0.0, 0.0, 0.0, 0.0),
                                      color: _mtaxiOrange,
                                      textStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .override(
                                            font: GoogleFonts.readexPro(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .fontStyle,
                                            ),
                                            color: Colors.white,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontStyle,
                                          ),
                                      elevation: 0.0,
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: borderColor,
                    ),
                  ),
                  child: Column(
                    children: [
                      _ProfileMenuItem(
                        icon: Icons.history,
                        title: FFLocalizations.of(context).getVariableText(
                          ruText: 'История заказов',
                          kkText: 'Тапсырыстар тарихы',
                        ),
                        onTap: () => context.pushNamed(MeOrderWidget.routeName),
                      ),
                      _ProfileMenuItem(
                        icon: Icons.policy_sharp,
                        title: FFLocalizations.of(context).getVariableText(
                          ruText: 'Политика и условия',
                          kkText: 'Саясат және шарттар',
                        ),
                        onTap: () =>
                            context.pushNamed(PolitikaWidget.routeName),
                      ),
                      _ProfileMenuItem(
                        icon: Icons.pallet,
                        title: FFLocalizations.of(context).getVariableText(
                          ruText: 'Тарифы',
                          kkText: 'Тарифтер',
                        ),
                        onTap: () => context.pushNamed(TarifWidget.routeName),
                      ),
                      StreamBuilder<List<ChatsRecord>>(
                        stream: mySupportChatStreamFromBackend(
                          interval: const Duration(seconds: 8),
                        ),
                        builder: (context, snapshot) {
                          final chats = snapshot.data ?? const [];
                          final unreadCount = _supportUnreadChatsCount(chats);
                          return _ProfileMenuItem(
                            icon: Icons.support_agent,
                            title: FFLocalizations.of(context).getVariableText(
                              ruText: 'Служба поддержки',
                              kkText: 'Қолдау қызметі',
                            ),
                            badgeCount: unreadCount,
                            onTap: () => _openSupportChat(
                              visibleChats: chats,
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      AuthUserStreamWidget(
                        builder: (context) {
                          final statusDriver = valueOrDefault(
                              currentUserDocument?.statusDriver, '');
                          return _buildRoleModeToggle(
                            isPassengerMode: isPassengerMode,
                            isDriverMode: isDriverMode,
                            hasDriverAccount: hasDriverAccount,
                            statusDriver: statusDriver,
                            roleState: roleState,
                          );
                        },
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

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : _mtaxiText;
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            if (badgeCount > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                margin: const EdgeInsets.only(right: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  textAlign: TextAlign.center,
                  style: FlutterFlowTheme.of(context).labelSmall.override(
                        color: Colors.white,
                        fontSize: 9.0,
                      ),
                ),
              ),
            Expanded(
              child: Text(
                title,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.readexPro(
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: textColor,
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: mutedColor,
            ),
          ],
        ),
      ),
    );
  }
}
