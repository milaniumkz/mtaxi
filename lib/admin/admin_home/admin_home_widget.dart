import 'package:flutter/material.dart';
import '/auth/backend_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/backend_support_chat.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import '/admin/admin_utils.dart';
import 'kaspi_requests_banner.dart';
import '/backend/push_notifications/web_push_button.dart';

const _mtaxiPageBg = Color(0xFF12051B);
const _mtaxiMint = Color(0xFF28D8C6);
const _mtaxiAdminBg = Color(0xFFF4F7F8);
const _mtaxiAdminText = Color(0xFF17111D);
const _mtaxiAdminMuted = Color(0xFF7C7484);
const _mtaxiAdminBorder = Color(0xFFE8EDF1);

class AdminHomeWidget extends StatefulWidget {
  const AdminHomeWidget({super.key});

  static String routeName = 'adminHome';
  static String routePath = '/admin';

  @override
  State<AdminHomeWidget> createState() => _AdminHomeWidgetState();
}

class _AdminHomeWidgetState extends State<AdminHomeWidget> {
  static const Duration _recentRegistrationWindow = Duration(days: 3);
  static const int _cancelledOrderStatus = 6;
  Future<_AdminServerStatus>? _serverStatusFuture;
  VoidCallback? _refreshDriverReviewDialog;
  final List<String> _collections = const [
    'users',
    'politika',
    'City',
    'payments',
    'withdrawals',
    'auditLogs',
    'supportContacts',
    'tariffsContent',
    'routerCityToCity',
    'appSettings',
    'order',
  ];

  static const Map<String, String> _collectionLabels = {
    'users': 'Пользователи',
    'politika': 'Политика и условия',
    'City': 'Поселки и тарифы',
    'payments': 'Платежи',
    'withdrawals': 'Заявки на вывод',
    'auditLogs': 'Журнал действий',
    'supportContacts': 'Контакты службы поддержки',
    'tariffsContent': 'Тарифы (тексты)',
    'routerCityToCity': 'Маршруты межгород',
    'appSettings': 'Настройки (runtime/комиссия/доставка)',
    'order': 'Заказы',
  };
  final Set<String> _driverReviewLoadingPaths = <String>{};

  _AdminUserDoc _adminUserDocFromBackend(Map<String, dynamic> user) {
    final id = (user['id'] ?? user['uid']).toString().trim();
    final path = (user['userDocPath'] ?? 'users/$id').toString();
    final data = Map<String, dynamic>.from(user);
    data['phone_number'] ??= user['phone'];
    data['display_name'] ??= user['displayName'] ?? user['name'];
    data['created_time'] ??= user['createdAt'];
    data['password'] = user['hasPassword'] == true ? 'задан' : '';
    return _AdminUserDoc(
      id: id,
      path: path,
      data: data,
      reference: BackendRefs.instance.doc(path),
    );
  }

  bool _isUnreadForCurrentAdmin(ChatsRecord chat) {
    final backendUnreadRaw = chat.snapshotData['unread_for_admin'];
    final backendUnread = backendUnreadRaw is num
        ? backendUnreadRaw.toInt()
        : int.tryParse(backendUnreadRaw?.toString() ?? '');
    if (backendUnread != null) {
      return backendUnread > 0;
    }
    return false;
  }

  String _formatChatTime(BuildContext context, DateTime? value) {
    if (value == null) {
      return '';
    }
    return dateTimeFormat(
      'd.MM HH:mm',
      value,
      locale: FFLocalizations.of(context).languageCode,
    );
  }

  DateTime? _createdAtFromUser(Map<String, dynamic> data) {
    final raw = data['created_time'] ?? data['createdAt'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw?.toString() ?? '');
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _isRecentUserRegistration(Map<String, dynamic> data) {
    final createdAt = _createdAtFromUser(data);
    if (createdAt == null) {
      return false;
    }
    return DateTime.now().difference(createdAt) <= _recentRegistrationWindow;
  }

  int _orderStatusFromData(Map<String, dynamic> data) {
    final raw = data['status'];
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  bool _isCancelledOrder(Map<String, dynamic> data) {
    return _orderStatusFromData(data) == _cancelledOrderStatus;
  }

  bool _isDriverPendingReview(Map<String, dynamic> data) {
    final registrationDraft = data['registrationDraft'] == true;
    final profileCompleted = data['profileCompleted'] == true;
    final isDriver = (data['isDriver'] as bool?) == true ||
        (data['role'] ?? '').toString().trim().toLowerCase() == 'driver' ||
        (data['driverRegistrationStatus'] ?? '')
            .toString()
            .trim()
            .toLowerCase()
            .isNotEmpty;
    final status = (data['statusDriver'] ?? '').toString().trim().toLowerCase();
    final registrationStatus = (data['driverRegistrationStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return isDriver &&
        !registrationDraft &&
        profileCompleted &&
        (status == 'pending' || registrationStatus == 'pending_review');
  }

  String _driverReviewName(Map<String, dynamic> data) {
    final name = buildAdminUserName(data);
    if (name.isNotEmpty) {
      return name;
    }
    final phone = normalizeAdminText(data['phone_number'] ?? data['phone']);
    return phone.isNotEmpty ? phone : 'Без имени';
  }

  String _driverReviewFirstName(Map<String, dynamic> data) {
    final firstName = normalizeAdminText(data['firstName']);
    if (firstName.isNotEmpty) {
      return firstName;
    }
    final displayName = buildAdminUserName(data);
    if (displayName.isNotEmpty) {
      return displayName.split(RegExp(r'\s+')).first.trim();
    }
    return '—';
  }

  String _driverReviewLastName(Map<String, dynamic> data) {
    final lastName = normalizeAdminText(data['lastName']);
    if (lastName.isNotEmpty) {
      return lastName;
    }
    final displayName = buildAdminUserName(data);
    if (displayName.isNotEmpty) {
      final parts = displayName.split(RegExp(r'\s+'));
      if (parts.length > 1) {
        return parts.sublist(1).join(' ').trim();
      }
    }
    return '—';
  }

  String _driverReviewMeta(Map<String, dynamic> data) {
    final phone = normalizeAdminText(data['phone_number'] ?? data['phone']);
    final city = normalizeAdminText(data['city']);
    final plate = normalizeAdminText(data['gosNomer']);
    return [phone, city, plate].where((value) => value.isNotEmpty).join(' • ');
  }

  String _driverReviewStatusLabel(Map<String, dynamic> data) {
    final registrationStatus = (data['driverRegistrationStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (registrationStatus == 'pending_review') {
      return 'На проверке';
    }
    if (registrationStatus == 'incomplete') {
      return 'Черновик';
    }
    final status = (data['statusDriver'] ?? '').toString().trim().toLowerCase();
    if (status == 'pending') {
      return 'Ожидает';
    }
    return 'На проверке';
  }

  String _driverReviewValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '—';
  }

  String _driverReviewImageValue(Map<String, dynamic> data, List<String> keys) {
    String fallback = '';
    for (final key in keys) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isEmpty) {
        continue;
      }
      fallback = fallback.isEmpty ? value : fallback;
      if (_isPreviewableImageUrl(value)) {
        return value;
      }
    }
    return fallback.isEmpty ? '—' : fallback;
  }

  List<String> _driverReviewImageCandidates(
    Map<String, dynamic> data,
    List<String> keys, {
    String? ownerId,
  }) {
    final urls = <String>{};
    for (final key in keys) {
      final raw = (data[key] ?? '').toString().trim();
      for (final candidate in _imageUrlCandidates(raw, ownerId: ownerId)) {
        if (candidate.trim().isNotEmpty) {
          urls.add(candidate.trim());
        }
      }
    }
    return urls.toList(growable: false);
  }

  String _driverReviewBirthDateValue(Map<String, dynamic> data) {
    final raw = data['dataRoj'] ?? data['birthDate'];
    DateTime? parsed;
    if (raw is Timestamp) {
      parsed = raw.toDate();
    } else if (raw is DateTime) {
      parsed = raw;
    } else {
      final normalized = raw?.toString().trim() ?? '';
      if (normalized.isEmpty) {
        return '—';
      }
      parsed = DateTime.tryParse(normalized);
      if (parsed == null) {
        return normalized;
      }
    }
    return dateTimeFormat(
      'd.MM.yyyy',
      parsed,
      locale: FFLocalizations.of(context).languageCode,
    );
  }

  bool _isPreviewableImageUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) {
      return false;
    }
    final scheme = uri.scheme.toLowerCase();
    return (scheme == 'http' || scheme == 'https') &&
        uri.host.trim().isNotEmpty;
  }

  List<String> _imageUrlCandidates(
    String rawUrl, {
    String? ownerId,
  }) {
    final value = rawUrl.trim();
    if (value.isEmpty) {
      return const <String>[];
    }

    final urls = <String>{};
    void add(String? candidate) {
      final normalized = candidate?.trim() ?? '';
      if (normalized.isNotEmpty && _isPreviewableImageUrl(normalized)) {
        urls.add(normalized);
      }
    }

    add(value);
    return urls.toList(growable: false);
  }

  Future<void> _openDriverReviewDetails(
    _AdminUserDoc doc,
  ) async {
    final data = doc.data;
    final loading = _driverReviewLoadingPaths.contains(doc.path);
    final vehicleImageCandidates = _driverReviewImageCandidates(
      data,
      ['avtoImage', 'photo_url'],
      ownerId: doc.id,
    );
    final techImageCandidates = _driverReviewImageCandidates(
      data,
      ['techImage'],
      ownerId: doc.id,
    );
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Анкета водителя',
                          style: FlutterFlowTheme.of(context)
                              .headlineSmall
                              .override(
                                font: TextStyle(
                                  fontFamily: 'Noto Sans',
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .headlineSmall
                                      .fontStyle,
                                ),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDriverReviewInfoRow(
                            'Статус',
                            _driverReviewStatusLabel(data),
                          ),
                          _buildDriverReviewInfoRow(
                            'Имя',
                            _driverReviewFirstName(data),
                          ),
                          _buildDriverReviewInfoRow(
                            'Фамилия',
                            _driverReviewLastName(data),
                          ),
                          _buildDriverReviewInfoRow(
                            'Телефон',
                            _driverReviewValue(data, ['phone_number']),
                          ),
                          _buildDriverReviewInfoRow(
                            'Город',
                            _driverReviewValue(data, ['city']),
                          ),
                          _buildDriverReviewInfoRow(
                            'Госномер',
                            _driverReviewValue(data, ['gosNomer']),
                          ),
                          _buildDriverReviewInfoRow(
                            'Цвет авто',
                            _driverReviewValue(data, ['color']),
                          ),
                          _buildDriverReviewInfoRow(
                            'Дата рождения',
                            _driverReviewBirthDateValue(data),
                          ),
                          _buildDriverReviewInfoRow(
                            'Пароль',
                            _driverReviewValue(data, ['password']),
                          ),
                          _buildDriverReviewImageRow(
                            'Фото профиля/авто',
                            _driverReviewImageValue(
                                data, ['avtoImage', 'photo_url']),
                            candidates: vehicleImageCandidates,
                          ),
                          _buildDriverReviewImageRow(
                            'Фото техпаспорта',
                            _driverReviewImageValue(data, ['techImage']),
                            candidates: techImageCandidates,
                          ),
                          if ((data['driverRegistrationRejectedReason'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            _buildDriverReviewInfoRow(
                              'Причина прошлого отклонения',
                              (data['driverRegistrationRejectedReason'] ?? '')
                                  .toString()
                                  .trim(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: loading
                              ? null
                              : () async {
                                  Navigator.of(dialogContext).pop();
                                  await _approveDriverReview(doc.reference);
                                },
                          text: loading ? '...' : 'Подтвердить',
                          options: FFButtonOptions(
                            height: 42,
                            color: const Color(0xFF2E7D32),
                            textStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: loading
                              ? null
                              : () async {
                                  Navigator.of(dialogContext).pop();
                                  await _rejectDriverReview(doc.reference);
                                },
                          text: loading ? '...' : 'Отклонить',
                          options: FFButtonOptions(
                            height: 42,
                            color: FlutterFlowTheme.of(context).error,
                            textStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                            borderRadius: BorderRadius.circular(10),
                          ),
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
  }

  Widget _buildDriverReviewInfoRow(
    String label,
    String value, {
    bool selectable = false,
  }) {
    final normalizedValue = value.trim().isEmpty ? '—' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: FlutterFlowTheme.of(context).labelMedium.override(
                  font: TextStyle(
                    fontFamily: 'Noto Sans',
                    fontWeight: FontWeight.w700,
                    fontStyle:
                        FlutterFlowTheme.of(context).labelMedium.fontStyle,
                  ),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          selectable
              ? SelectableText(
                  normalizedValue,
                  style: FlutterFlowTheme.of(context).bodyMedium,
                )
              : Text(
                  normalizedValue,
                  style: FlutterFlowTheme.of(context).bodyMedium,
                ),
        ],
      ),
    );
  }

  Widget _buildDriverReviewImageRow(
    String label,
    String value, {
    List<String> candidates = const <String>[],
  }) {
    final normalizedValue = value.trim();
    final hasImage = normalizedValue.isNotEmpty &&
        normalizedValue != '—' &&
        _isPreviewableImageUrl(normalizedValue);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: FlutterFlowTheme.of(context).labelMedium.override(
                  font: TextStyle(
                    fontFamily: 'Noto Sans',
                    fontWeight: FontWeight.w700,
                    fontStyle:
                        FlutterFlowTheme.of(context).labelMedium.fontStyle,
                  ),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          if (!hasImage)
            Text(
              '—',
              style: FlutterFlowTheme.of(context).bodyMedium,
            )
          else
            _DriverReviewImagePreview(
              candidates:
                  candidates.isEmpty ? <String>[normalizedValue] : candidates,
              fallbackText: normalizedValue,
            ),
        ],
      ),
    );
  }

  Future<void> _approveDriverReview(
    DocumentReference<Map<String, dynamic>> userRef,
  ) async {
    await _submitDriverReviewDecision(
      userRef: userRef,
      statusDriver: 'approved',
    );
  }

  Future<void> _rejectDriverReview(
    DocumentReference<Map<String, dynamic>> userRef,
  ) async {
    final controller = TextEditingController();
    String? errorText;
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Причина отклонения'),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Например: фото нечитаемое, не видно госномер',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      setDialogState(() {
                        errorText = 'Укажите причину отклонения';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(text);
                  },
                  child: const Text('Отклонить'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (reason == null || reason.trim().isEmpty) {
      return;
    }
    await _submitDriverReviewDecision(
      userRef: userRef,
      statusDriver: 'rejected',
      rejectedReason: reason.trim(),
    );
  }

  Future<void> _submitDriverReviewDecision({
    required DocumentReference<Map<String, dynamic>> userRef,
    required String statusDriver,
    String? rejectedReason,
  }) async {
    if (_driverReviewLoadingPaths.contains(userRef.path)) {
      return;
    }
    setState(() {
      _driverReviewLoadingPaths.add(userRef.path);
    });
    try {
      final response = await makeCloudCall(
        'approveDriver',
        {
          'userDocPath': userRef.path,
          'statusDriver': statusDriver,
          if (rejectedReason != null && rejectedReason.isNotEmpty)
            'rejectedReason': rejectedReason,
        },
      );
      if (!mounted) return;
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              statusDriver == 'approved'
                  ? 'Водитель подтвержден'
                  : 'Водитель отклонен',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (response['error'] ?? 'Не удалось обработать анкету').toString(),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', '').trim().isNotEmpty
                ? e.toString().replaceFirst('Exception: ', '').trim()
                : 'Не удалось обработать анкету',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _driverReviewLoadingPaths.remove(userRef.path);
        });
        _refreshDriverReviewDialog?.call();
      }
    }
  }

  Future<_AdminDashboardStats> _loadBackendDashboardStats() async {
    final results = await Future.wait([
      makeCloudCall('adminListOrders', {'limit': 500}),
      makeCloudCall('adminListUsers', {'limit': 500}),
      makeCloudCall('getMoneyStats', const {}),
    ]);
    final ordersResponse = results[0];
    final usersResponse = results[1];
    final moneyResponse = results[2];
    if (ordersResponse['success'] != true ||
        usersResponse['success'] != true ||
        moneyResponse['success'] != true) {
      throw Exception('Не удалось загрузить статистику');
    }

    final orders = ordersResponse['orders'] is List
        ? (ordersResponse['orders'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final users = usersResponse['users'] is List
        ? (usersResponse['users'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final totals = moneyResponse['totals'] is Map
        ? Map<String, dynamic>.from(moneyResponse['totals'])
        : <String, dynamic>{};

    final activeOrders =
        orders.where((order) => !_isCancelledOrder(order)).toList();
    final revenue = activeOrders.fold<double>(
      0,
      (sum, order) => sum + _asDouble(order['price']),
    );
    final driverCount = users.where((user) => user['isDriver'] == true).length;
    final recentCount =
        users.where((user) => _isRecentUserRegistration(user)).length;
    final pendingDrivers =
        users.where((user) => _isDriverPendingReview(user)).length;

    return _AdminDashboardStats(
      orderCount: activeOrders.length,
      cancelledOrderCount: orders.length - activeOrders.length,
      orderRevenue: revenue,
      driverCount: driverCount,
      recentRegistrationCount: recentCount,
      pendingDriverCount: pendingDrivers,
      paymentCount:
          int.tryParse(totals['paymentsCount']?.toString() ?? '') ?? 0,
      paymentTotal: _asDouble(totals['topUps']),
      pendingWithdrawalTotal: _asDouble(totals['pendingWithdrawals']),
      withdrawalTotal: _asDouble(totals['withdrawals']),
    );
  }

  Future<_AdminServerStatus> _loadServerStatus() async {
    final stopwatch = Stopwatch()..start();
    try {
      final results = await Future.wait([
        makeCloudCall('getStoreHealth', const {}),
        makeCloudCall('getBackendArchitectureStatus', const {}),
      ]);
      stopwatch.stop();
      final health = results[0];
      final architecture = results[1];
      final store = health['store'] is Map
          ? Map<String, dynamic>.from(health['store'])
          : <String, dynamic>{};
      return _AdminServerStatus(
        ok: health['success'] == true && store['ok'] == true,
        storeType: (store['type'] ?? '—').toString(),
        architecture: (architecture['architecture'] ?? '—').toString(),
        firebaseMode:
            (architecture['firebaseAllowedOnlyFor'] ?? '—').toString(),
        responseMs: stopwatch.elapsedMilliseconds,
        checkedAt: DateTime.now(),
        error: '',
      );
    } catch (e) {
      stopwatch.stop();
      return _AdminServerStatus(
        ok: false,
        storeType: '—',
        architecture: '—',
        firebaseMode: '—',
        responseMs: stopwatch.elapsedMilliseconds,
        checkedAt: DateTime.now(),
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void _refreshServerStatus() {
    setState(() {
      _serverStatusFuture = _loadServerStatus();
    });
  }

  @override
  void initState() {
    super.initState();
    _serverStatusFuture = _loadServerStatus();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = isAdminUser(currentUserDocument);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: isAdmin ? _mtaxiAdminBg : _mtaxiPageBg,
      body: SafeArea(
        child: isAdmin
            ? isWide
                ? Row(
                    children: [
                      _buildAdminSidebar(context),
                      Expanded(child: _buildAdminWorkspace(context)),
                    ],
                  )
                : _buildAdminWorkspace(context)
            : _buildAccessDenied(context),
      ),
    );
  }

  Widget _buildAdminSidebar(BuildContext context) {
    return Container(
      width: 244,
      color: _mtaxiPageBg,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/app_launcher_icon.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'MTaxi',
                style: TextStyle(
                  fontFamily: 'Noto Sans',
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _adminNavItem(context, Icons.dashboard_outlined, 'Дашборд', true),
          _adminNavItem(context, Icons.verified_user_outlined,
              'Модерация водителей', false),
          _adminNavItem(
              context, Icons.people_alt_outlined, 'Пользователи', false),
          _adminNavItem(context, Icons.receipt_long_outlined, 'Заказы', false),
          _adminNavItem(context, Icons.payments_outlined, 'Платежи', false),
          _adminNavItem(
              context, Icons.support_agent_outlined, 'Поддержка', false),
          _adminNavItem(context, Icons.settings_outlined, 'Настройки', false),
          const Spacer(),
          FFButtonWidget(
            onPressed: _signOutAdmin,
            text: 'Выйти',
            options: FFButtonOptions(
              width: double.infinity,
              height: 42,
              color: Colors.white.withValues(alpha: 0.08),
              textStyle: TextStyle(
                fontFamily: 'Noto Sans',
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              elevation: 0,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminNavItem(
      BuildContext context, IconData icon, String label, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? _mtaxiMint : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openAdminSection(label),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(children: [
              Icon(icon,
                  size: 19, color: selected ? _mtaxiPageBg : Colors.white70),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                        fontFamily: 'Noto Sans',
                        color: selected ? _mtaxiPageBg : Colors.white70,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13,
                      ))),
            ]),
          ),
        ),
      ),
    );
  }

  void _openAdminSection(String label) {
    if (label == 'Дашборд') {
      _refreshServerStatus();
      return;
    }
    if (label == 'Модерация водителей') {
      showDialog<void>(
          context: context,
          builder: (dialogContext) =>
              StatefulBuilder(builder: (dialogContext, refresh) {
                _refreshDriverReviewDialog = () {
                  if (dialogContext.mounted) refresh(() {});
                };
                return Dialog(
                    child: SizedBox(
                        width: 760,
                        height: MediaQuery.sizeOf(dialogContext).height * .85,
                        child: Column(children: [
                          Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                  tooltip: 'Закрыть',
                                  onPressed: () => Navigator.pop(dialogContext),
                                  icon: const Icon(Icons.close))),
                          Expanded(
                              child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: _buildDriverReviewSection(
                                      dialogContext))),
                        ])));
              })).whenComplete(() => _refreshDriverReviewDialog = null);
      return;
    }
    if (label == 'Поддержка') {
      context.pushNamed(AdminSupportChatsWidget.routeName);
      return;
    }
    final collection = switch (label) {
      'Пользователи' => 'users',
      'Заказы' => 'order',
      'Платежи' => 'payments',
      'Настройки' => 'appSettings',
      _ => null,
    };
    if (collection != null) {
      context.pushNamed(AdminCollectionWidget.routeName,
          queryParameters: {'collection': collection});
    }
  }

  Widget _buildAdminWorkspace(BuildContext context) {
    return Container(
      color: _mtaxiAdminBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        children: [
          _buildAdminTopBar(context),
          const SizedBox(height: 18),
          _buildDashboard(context),
          const KaspiRequestsBanner(),
          const WebPushButton(),
          const SizedBox(height: 16),
          _buildDriverReviewSection(context),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 760;
              final tiles = [
                _adminActionTile(
                  context,
                  icon: Icons.analytics_outlined,
                  title: 'Статистика водителя',
                  subtitle: 'Активность, поездки и показатели',
                  onTap: () => context.pushNamedAuth(
                    AdminDriverStatsWidget.routeName,
                    context.mounted,
                  ),
                ),
                _adminActionTile(
                  context,
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Статистика денег',
                  subtitle: 'Комиссии, пополнения и возвраты',
                  onTap: () => context.pushNamedAuth(
                    AdminMoneyStatsWidget.routeName,
                    context.mounted,
                  ),
                ),
                _adminActionTile(
                  context,
                  icon: Icons.campaign_outlined,
                  title: 'Рассылка уведомлений',
                  subtitle: 'Пассажирам, водителям или всем',
                  onTap: () => context.pushNamedAuth(
                    AdminNotificationsWidget.routeName,
                    context.mounted,
                  ),
                ),
                _adminActionTile(
                  context,
                  icon: Icons.support_agent_outlined,
                  title: 'Чаты поддержки',
                  subtitle: 'Очередь обращений и ответы',
                  onTap: () => context.pushNamedAuth(
                    AdminSupportChatsWidget.routeName,
                    context.mounted,
                  ),
                ),
              ];
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: tiles
                    .map((tile) => SizedBox(
                          width: twoColumns
                              ? (constraints.maxWidth - 14) / 2
                              : constraints.maxWidth,
                          child: tile,
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildServerStatusPanel(context),
          const SizedBox(height: 16),
          _buildSupportChatsShortcut(context),
          const SizedBox(height: 16),
          _buildAdminSectionsPanel(context),
        ],
      ),
    );
  }

  Widget _buildAdminTopBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Дашборд',
                style: TextStyle(
                  fontFamily: 'Noto Sans',
                  color: _mtaxiAdminText,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ключевые показатели, заказы и проблемы на одном экране',
                style: TextStyle(
                  fontFamily: 'Noto Sans',
                  color: _mtaxiAdminMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _refreshServerStatus,
          tooltip: 'Обновить',
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 8),
        FFButtonWidget(
          onPressed: _signOutAdmin,
          text: 'Выйти',
          options: FFButtonOptions(
            height: 40,
            color: _mtaxiPageBg,
            textStyle: TextStyle(
              fontFamily: 'Noto Sans',
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            elevation: 0,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _adminActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _mtaxiAdminBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _mtaxiMint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF139E92)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Noto Sans',
                      color: _mtaxiAdminText,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Noto Sans',
                      color: _mtaxiAdminMuted,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFB9B3C1)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminSectionsPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _mtaxiAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Разделы управления',
            style: TextStyle(
              fontFamily: 'Noto Sans',
              color: _mtaxiAdminText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ..._collections.map(
            (collection) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storage, color: _mtaxiMint),
              title: Text(
                _collectionLabels[collection] ?? collection,
                style: TextStyle(
                  fontFamily: 'Noto Sans',
                  color: _mtaxiAdminText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing:
                  const Icon(Icons.chevron_right, color: Color(0xFFB9B3C1)),
              onTap: () {
                context.pushNamedAuth(
                  AdminCollectionWidget.routeName,
                  context.mounted,
                  queryParameters: {'collection': collection},
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOutAdmin() async {
    final router = GoRouter.of(context);
    router.prepareAuthEvent(true);
    try {
      await authManager.signOut();
    } catch (_) {}
    router.clearRedirectLocation();
    if (!context.mounted) return;
    context.go(LoginWidget.routePath);
  }

  Widget _buildAccessDenied(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 48),
            const SizedBox(height: 12),
            Text(
              'Доступ только для администратора',
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodyLarge.override(
                    font: TextStyle(
                      fontFamily: 'Noto Sans',
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                    fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                  ),
            ),
            const SizedBox(height: 16),
            FFButtonWidget(
              onPressed: () {
                context.goNamedAuth(HomePageWidget.routeName, context.mounted);
              },
              text: 'На главную',
              options: FFButtonOptions(
                width: 180,
                height: 44,
                color: _mtaxiMint,
                textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                      font: TextStyle(
                        fontFamily: 'Noto Sans',
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).titleSmall.fontStyle,
                      ),
                      color: Colors.white,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleSmall.fontStyle,
                    ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    return _dashboardPanel(
      context,
      child: FutureBuilder<_AdminDashboardStats>(
        future: _loadBackendDashboardStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snapshot.data!;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ordersStatCard(context, stats),
              _driversStatCard(context, stats),
              _registrationsStatCard(context, stats),
              _paymentsStatCard(context, stats),
              _withdrawalsStatCard(context, stats),
            ],
          );
        },
      ),
    );
  }

  Widget _buildServerStatusPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _mtaxiAdminBorder),
      ),
      child: FutureBuilder<_AdminServerStatus>(
        future: _serverStatusFuture,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final status = snapshot.data;
          final ok = status?.ok == true;
          final color = loading
              ? Colors.orange
              : ok
                  ? const Color(0xFF2E7D32)
                  : FlutterFlowTheme.of(context).error;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loading
                          ? 'Проверяем сервер...'
                          : ok
                              ? 'Сервер работает'
                              : 'Проблема с сервером',
                      style: FlutterFlowTheme.of(context).bodyLarge.override(
                            font: TextStyle(
                              fontFamily: 'Noto Sans',
                              fontWeight: FontWeight.w700,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyLarge
                                  .fontStyle,
                            ),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: _refreshServerStatus,
                    tooltip: 'Обновить',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _serverStatusChip(
                    context,
                    'API',
                    loading
                        ? 'проверка'
                        : ok
                            ? 'живой'
                            : 'ошибка',
                    color,
                  ),
                  _serverStatusChip(
                    context,
                    'База',
                    status?.storeType ?? '—',
                    _mtaxiMint,
                  ),
                  _serverStatusChip(
                    context,
                    'Ответ',
                    status == null ? '—' : '${status.responseMs} мс',
                    _mtaxiMint,
                  ),
                  _serverStatusChip(
                    context,
                    'Backend',
                    status?.architecture ?? '—',
                    _mtaxiMint,
                  ),
                  _serverStatusChip(
                    context,
                    'Firebase',
                    status?.firebaseMode ?? '—',
                    _mtaxiMint,
                  ),
                ],
              ),
              if (status != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Проверено: ${dateTimeFormat(
                    'HH:mm:ss',
                    status.checkedAt,
                    locale: FFLocalizations.of(context).languageCode,
                  )}',
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                ),
              ],
              if ((status?.error ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  status!.error,
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        color: FlutterFlowTheme.of(context).error,
                      ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _serverStatusChip(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: FlutterFlowTheme.of(context).labelMedium.override(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            value,
            style: FlutterFlowTheme.of(context).labelMedium,
          ),
        ],
      ),
    );
  }

  Widget _dashboardPanel(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _mtaxiAdminBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Статистика',
            style: FlutterFlowTheme.of(context).bodyLarge.override(
                  font: TextStyle(
                    fontFamily: 'Noto Sans',
                    fontWeight: FontWeight.w700,
                    fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w700,
                  fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _ordersStatCard(BuildContext context, _AdminDashboardStats stats) {
    return _statCard(
      context,
      title: 'Заказы',
      value: '${stats.orderCount}',
      subtitle:
          'Сумма: ${stats.orderRevenue.toStringAsFixed(0)} • Отменено: ${stats.cancelledOrderCount}',
      icon: Icons.assignment,
    );
  }

  Widget _driversStatCard(BuildContext context, _AdminDashboardStats stats) {
    return _statCard(
      context,
      title: 'Водители',
      value: '${stats.driverCount}',
      subtitle: 'Активные',
      icon: Icons.local_taxi,
    );
  }

  Widget _registrationsStatCard(
      BuildContext context, _AdminDashboardStats stats) {
    return _statCard(
      context,
      title: 'Новые',
      value: '${stats.recentRegistrationCount}',
      subtitle: 'На проверке: ${stats.pendingDriverCount}',
      icon: Icons.person_add_alt_1,
    );
  }

  Widget _paymentsStatCard(BuildContext context, _AdminDashboardStats stats) {
    return _statCard(
      context,
      title: 'Платежи',
      value: '${stats.paymentCount}',
      subtitle: 'Сумма: ${formatAppCurrency(stats.paymentTotal)}',
      icon: Icons.payments,
    );
  }

  Widget _withdrawalsStatCard(
      BuildContext context, _AdminDashboardStats stats) {
    return _statCard(
      context,
      title: 'Выводы',
      value: formatAppCurrency(stats.pendingWithdrawalTotal),
      subtitle:
          'Ожидают. Выплачено: ${formatAppCurrency(stats.withdrawalTotal)}',
      icon: Icons.account_balance,
    );
  }

  Widget _buildDriverReviewSection(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: makeCloudCall('adminListUsers', {'limit': 500}),
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || snapshot.data?['success'] != true) {
          return ListTile(
            title: const Text('Не удалось загрузить анкеты'),
            subtitle: const Text('Проверьте подключение и повторите.'),
            trailing: IconButton(
                tooltip: 'Обновить анкеты',
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  if (mounted) setState(() {});
                  _refreshDriverReviewDialog?.call();
                }),
          );
        }
        final rawUsers = snapshot.data?['users'];
        final docs = rawUsers is List
            ? rawUsers
                .whereType<Map>()
                .map((item) =>
                    _adminUserDocFromBackend(Map<String, dynamic>.from(item)))
                .where((doc) => _isDriverPendingReview(doc.data))
                .toList(growable: false)
            : <_AdminUserDoc>[];
        return _buildDriverReviewPanel(context, docs);
      },
    );
  }

  Widget _buildDriverReviewPanel(
    BuildContext context,
    List<_AdminUserDoc> docs,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _mtaxiAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Проверка водителей',
            style: FlutterFlowTheme.of(context).bodyLarge.override(
                  font: TextStyle(
                    fontFamily: 'Noto Sans',
                    fontWeight: FontWeight.w700,
                    fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w700,
                  fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            docs.isEmpty
                ? 'Сейчас нет анкет на проверке'
                : 'На проверке: ${docs.length}',
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
          ),
          if (docs.isNotEmpty) const SizedBox(height: 12),
          if (docs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _mtaxiAdminBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _mtaxiAdminBorder),
              ),
              child: Text(
                'Новые анкеты водителей появятся здесь.',
                style: FlutterFlowTheme.of(context).bodyMedium,
              ),
            ),
          ...docs.map((doc) {
            final data = doc.data;
            final loading = _driverReviewLoadingPaths.contains(doc.path);
            final meta = _driverReviewMeta(data);
            final rejectedReason =
                (data['driverRegistrationRejectedReason'] ?? '')
                    .toString()
                    .trim();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _mtaxiAdminBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _mtaxiAdminBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _driverReviewName(data),
                            style:
                                FlutterFlowTheme.of(context).bodyLarge.override(
                                      font: TextStyle(
                                        fontFamily: 'Noto Sans',
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyLarge
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyLarge
                                          .fontStyle,
                                    ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _driverReviewStatusLabel(data),
                            style: FlutterFlowTheme.of(context)
                                .labelSmall
                                .override(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        meta,
                        style: FlutterFlowTheme.of(context).bodySmall,
                      ),
                    ],
                    if (rejectedReason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Последняя причина отклонения: $rejectedReason',
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              color: FlutterFlowTheme.of(context).error,
                            ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FFButtonWidget(
                        onPressed: () => _openDriverReviewDetails(doc),
                        text: 'Открыть информацию',
                        options: FFButtonOptions(
                          height: 40,
                          color: Colors.white,
                          textStyle:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: TextStyle(
                                      fontFamily: 'Noto Sans',
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: _mtaxiAdminBorder,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FFButtonWidget(
                            onPressed: loading
                                ? null
                                : () => _approveDriverReview(doc.reference),
                            text: loading ? '...' : 'Подтвердить',
                            options: FFButtonOptions(
                              height: 42,
                              color: const Color(0xFF2E7D32),
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FFButtonWidget(
                            onPressed: loading
                                ? null
                                : () => _rejectDriverReview(doc.reference),
                            text: loading ? '...' : 'Отклонить',
                            options: FFButtonOptions(
                              height: 42,
                              color: FlutterFlowTheme.of(context).error,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      width: 178,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _mtaxiAdminBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _mtaxiMint.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF139E92)),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  font: TextStyle(
                    fontFamily: 'Noto Sans',
                    fontWeight: FontWeight.w600,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: FlutterFlowTheme.of(context).headlineSmall.override(
                  font: TextStyle(
                    fontFamily: 'Noto Sans',
                    fontWeight: FontWeight.w700,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineSmall.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w700,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineSmall.fontStyle,
                  color: _mtaxiAdminText,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: FlutterFlowTheme.of(context).labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildSupportChatsShortcut(BuildContext context) {
    return FutureBuilder<List<ChatsRecord>>(
      future: loadSupportChatsFromBackend(),
      builder: (context, snapshot) {
        final chats = snapshot.data ?? const <ChatsRecord>[];
        final unreadChats =
            chats.where(_isUnreadForCurrentAdmin).toList(growable: false);
        final unreadCount = unreadChats.length;
        final highlight = unreadCount > 0;
        final latestUnreadTime =
            unreadChats.isNotEmpty ? unreadChats.first.lastMessageTime : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              context.pushNamedAuth(
                AdminSupportChatsWidget.routeName,
                context.mounted,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: highlight
                    ? Colors.orange.withValues(alpha: 0.10)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: highlight
                      ? Colors.orange.withValues(alpha: 0.45)
                      : _mtaxiAdminBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.forum,
                    color: highlight ? Colors.orange.shade700 : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Чат поддержки',
                          style:
                              FlutterFlowTheme.of(context).bodyLarge.override(
                                    font: TextStyle(
                                      fontFamily: 'Noto Sans',
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyLarge
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyLarge
                                        .fontStyle,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          highlight
                              ? 'Есть новые сообщения: $unreadCount'
                              : 'Открытых диалогов: ${chats.length}',
                          style:
                              FlutterFlowTheme.of(context).bodySmall.override(
                                    color: highlight
                                        ? Colors.orange.shade800
                                        : FlutterFlowTheme.of(context)
                                            .secondaryText,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (latestUnreadTime != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        _formatChatTime(context, latestUnreadTime),
                        style: FlutterFlowTheme.of(context).labelSmall.override(
                              color: highlight
                                  ? Colors.orange.shade800
                                  : FlutterFlowTheme.of(context).secondaryText,
                            ),
                      ),
                    ),
                  if (highlight)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: FlutterFlowTheme.of(context).labelSmall.override(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  Icon(
                    Icons.chevron_right,
                    color: highlight ? Colors.orange.shade700 : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AdminDashboardStats {
  const _AdminDashboardStats({
    required this.orderCount,
    required this.cancelledOrderCount,
    required this.orderRevenue,
    required this.driverCount,
    required this.recentRegistrationCount,
    required this.pendingDriverCount,
    required this.paymentCount,
    required this.paymentTotal,
    required this.pendingWithdrawalTotal,
    required this.withdrawalTotal,
  });

  final int orderCount;
  final int cancelledOrderCount;
  final double orderRevenue;
  final int driverCount;
  final int recentRegistrationCount;
  final int pendingDriverCount;
  final int paymentCount;
  final double paymentTotal;
  final double pendingWithdrawalTotal;
  final double withdrawalTotal;
}

class _AdminServerStatus {
  const _AdminServerStatus({
    required this.ok,
    required this.storeType,
    required this.architecture,
    required this.firebaseMode,
    required this.responseMs,
    required this.checkedAt,
    required this.error,
  });

  final bool ok;
  final String storeType;
  final String architecture;
  final String firebaseMode;
  final int responseMs;
  final DateTime checkedAt;
  final String error;
}

class _AdminUserDoc {
  const _AdminUserDoc({
    required this.id,
    required this.path,
    required this.data,
    required this.reference,
  });

  final String id;
  final String path;
  final Map<String, dynamic> data;
  final DocumentReference<Map<String, dynamic>> reference;
}

class _DriverReviewImagePreview extends StatefulWidget {
  const _DriverReviewImagePreview({
    required this.candidates,
    required this.fallbackText,
  });

  final List<String> candidates;
  final String fallbackText;

  @override
  State<_DriverReviewImagePreview> createState() =>
      _DriverReviewImagePreviewState();
}

class _DriverReviewImagePreviewState extends State<_DriverReviewImagePreview> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final candidates = widget.candidates
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return _fallback(context);
    }

    final imageUrl = candidates[_currentIndex.clamp(0, candidates.length - 1)];
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 240,
        color: const Color(0xFFF2F4F7),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            if (_currentIndex < candidates.length - 1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _currentIndex += 1;
                });
              });
              return const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              );
            }
            return _fallback(context);
          },
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 240,
        color: const Color(0xFFF2F4F7),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image_outlined, size: 28),
            const SizedBox(height: 8),
            SelectableText(
              widget.fallbackText,
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
