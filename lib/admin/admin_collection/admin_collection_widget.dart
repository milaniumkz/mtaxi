import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/admin/admin_utils.dart';
import '/auth/backend_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/app_settings/app_settings.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/index.dart';

const _mtaxiPageBg = Color(0xFF12051B);
const _mtaxiSurface = Color(0xFFFFFFFF);
const _mtaxiSurface2 = Color(0xFFF6F2F8);
const _mtaxiMint = Color(0xFF28D8C6);
const _mtaxiAdminBg = Color(0xFFF4F7F8);
const _mtaxiAdminText = Color(0xFF17111D);
const _mtaxiAdminBorder = Color(0xFFE8EDF1);

class AdminCollectionWidget extends StatefulWidget {
  const AdminCollectionWidget({
    super.key,
    required this.collectionName,
  });

  final String collectionName;

  static String routeName = 'adminCollection';
  static String routePath = '/admin/collection';

  @override
  State<AdminCollectionWidget> createState() => _AdminCollectionWidgetState();
}

class _AdminSelectOption {
  const _AdminSelectOption({
    required this.path,
    required this.label,
    required this.name,
    required this.phone,
  });

  final String path;
  final String label;
  final String name;
  final String phone;
}

enum _FieldType {
  string,
  intType,
  doubleType,
  boolType,
  dateTime,
  reference,
  geo,
  json,
}

class _FieldSpec {
  const _FieldSpec({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.readOnly = false,
    this.helper,
  });

  final String key;
  final String label;
  final _FieldType type;
  final bool required;
  final bool readOnly;
  final String? helper;
}

const List<_FieldSpec> _quickDriverCreateSchema = [
  _FieldSpec(
    key: 'display_name',
    label: 'Имя водителя',
    type: _FieldType.string,
    required: true,
  ),
  _FieldSpec(
    key: 'phone_number',
    label: 'Телефон',
    type: _FieldType.string,
    required: true,
    helper: 'Например: +77001234567',
  ),
  _FieldSpec(
    key: 'city',
    label: 'Поселок',
    type: _FieldType.string,
    required: true,
  ),
  _FieldSpec(
    key: 'Marka',
    label: 'Марка авто',
    type: _FieldType.string,
    required: true,
  ),
  _FieldSpec(
    key: 'model',
    label: 'Модель авто',
    type: _FieldType.string,
    required: true,
  ),
  _FieldSpec(
    key: 'gosNomer',
    label: 'Госномер',
    type: _FieldType.string,
    required: true,
  ),
  _FieldSpec(
    key: 'color',
    label: 'Цвет авто',
    type: _FieldType.string,
    required: true,
  ),
  _FieldSpec(
    key: 'balance',
    label: 'Стартовый баланс',
    type: _FieldType.doubleType,
    helper: 'Можно оставить 0',
  ),
  _FieldSpec(
    key: 'statusDriver',
    label: 'Статус водителя',
    type: _FieldType.string,
    helper: 'Для быстрой регистрации по умолчанию: Подтвержден',
  ),
];

class _UserOrderHistoryEntry {
  const _UserOrderHistoryEntry({
    required this.doc,
    required this.asPassenger,
    required this.asDriver,
  });

  final dynamic doc;
  final bool asPassenger;
  final bool asDriver;
}

class _BackendOrderHistoryDoc {
  const _BackendOrderHistoryDoc({
    required this.id,
    required this.reference,
    required Map<String, dynamic> data,
  }) : _data = data;

  final String id;
  final DocumentReference reference;
  final Map<String, dynamic> _data;

  Map<String, dynamic> data() => _data;
}

class _UserOrderHistoryStats {
  const _UserOrderHistoryStats({
    required this.total,
    required this.completed,
    required this.cancelled,
    required this.asPassenger,
    required this.asDriver,
    required this.passengerCancelled,
    required this.beforeArrivalCancelled,
    required this.latestCancelledAt,
  });

  final int total;
  final int completed;
  final int cancelled;
  final int asPassenger;
  final int asDriver;
  final int passengerCancelled;
  final int beforeArrivalCancelled;
  final DateTime? latestCancelledAt;
}

class _AdminImageWithFallback extends StatefulWidget {
  const _AdminImageWithFallback({
    required this.urls,
    required this.fit,
    required this.errorChild,
  });

  final List<String> urls;
  final BoxFit fit;
  final Widget errorChild;

  @override
  State<_AdminImageWithFallback> createState() =>
      _AdminImageWithFallbackState();
}

class _AdminImageWithFallbackState extends State<_AdminImageWithFallback> {
  int _currentIndex = 0;
  bool _switchScheduled = false;

  @override
  void didUpdateWidget(covariant _AdminImageWithFallback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urls.join('||') != widget.urls.join('||')) {
      _currentIndex = 0;
      _switchScheduled = false;
    }
  }

  void _tryNextUrl() {
    if (_switchScheduled || _currentIndex >= widget.urls.length - 1) {
      return;
    }
    _switchScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentIndex += 1;
        _switchScheduled = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) {
      return widget.errorChild;
    }
    return Image.network(
      widget.urls[_currentIndex],
      fit: widget.fit,
      errorBuilder: (_, __, ___) {
        if (_currentIndex < widget.urls.length - 1) {
          _tryNextUrl();
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return widget.errorChild;
      },
    );
  }
}

class _AdminCollectionWidgetState extends State<AdminCollectionWidget> {
  static const Duration _recentRegistrationWindow = Duration(days: 3);
  static const int _completedOrderStatus = 5;
  static const int _cancelledOrderStatus = 6;
  static const Set<String> _backendManagedUserFields = {
    'activeOrderRef',
    'activeOrderStatus',
    'activePassengerOrderRef',
    'activePassengerOrderStatus',
    'activePassengerOrderUpdatedAt',
    'activePassengerOrderClosedAt',
    'roleResolvedAt',
    'driverAvailabilityUpdatedAt',
    'balanceUpdatedAt',
    'balanceUpdatedBy',
    'orderDelayUpdatedAt',
    'orderDelayUpdatedBy',
    'vehiclePhotoUpdatedAt',
    'driverRegistrationDraftUpdatedAt',
    'driverRegistrationCompletedAt',
    'supportChatRef',
    'supportAdminRef',
    'supportChatRefs',
    'lastPassengerOrderRef',
    'lastPassengerOrderFinalStatus',
    'last_message',
    'last_message_time',
    'last_message_seen_by',
    'lastMessageSeenBy',
    'created_time',
    'dateCreate',
  };
  static const Set<String> _adminEditableUserFields = {
    'firstName',
    'lastName',
    'display_name',
    'phone_number',
    'photo_url',
    'photoUrl',
    'avtoImage',
    'autoImage',
    'techImage',
    'techPassportImage',
    'Marka',
    'model',
    'yersSet',
    'proverka',
    'bonus',
    'balance',
    'ref',
    'colsRef',
    'isDriver',
    'city',
    'coords',
    'gosNomer',
    'color',
    'statusDriver',
    'blocked',
    'vip',
    'orderDelaySeconds',
    'passengerAcceptedCancelDayKey',
    'passengerAcceptedCancelCount',
    'passengerAcceptedCancelLastAt',
  };
  static const Set<String> _adminReadOnlyUserFields = {
    'uid',
    'role',
    'created_time',
    'vehiclePhotoDeleteRequestStatus',
    'driverRegistrationStatus',
    'registrationDraft',
    'profileCompleted',
  };
  static const Set<String> _driverOnlyUserFields = {
    'iin',
    'dataRoj',
    'password',
    'avtoImage',
    'autoImage',
    'vehiclePhotoDeleteRequestStatus',
    'techImage',
    'techPassportImage',
    'Marka',
    'model',
    'yersSet',
    'proverka',
    'gosNomer',
    'color',
    'statusDriver',
    'driverRegistrationStatus',
    'orderDelaySeconds',
  };
  static const Set<String> _clearableUserFields = {
    'firstName',
    'lastName',
    'display_name',
    'phone_number',
    'photo_url',
    'photoUrl',
    'avtoImage',
    'autoImage',
    'techImage',
    'techPassportImage',
    'Marka',
    'model',
    'yersSet',
    'proverka',
    'bonus',
    'ref',
    'colsRef',
    'city',
    'coords',
    'gosNomer',
    'color',
    'passengerAcceptedCancelDayKey',
    'passengerAcceptedCancelCount',
    'passengerAcceptedCancelLastAt',
  };
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _idSearchController = TextEditingController();
  final TextEditingController _filterFieldController = TextEditingController();
  final TextEditingController _filterValueController = TextEditingController();
  final TextEditingController _intercityPointFilterController =
      TextEditingController();
  final TextEditingController _sortFieldController = TextEditingController();
  String _userRoleFilter = 'all';
  bool _sortDescending = false;
  int _limit = 200;
  final List<DocumentSnapshot<Map<String, dynamic>>> _pageStarts = [];
  int _pageIndex = 0;
  DocumentSnapshot<Map<String, dynamic>>? _nextPageStartAfterDoc;
  bool _hasNext = false;
  bool _useLegacyRouterCity = false;
  bool _forceCamelRouterCity = false;
  final Map<String, Future<UsersRecord?>> _userLookupCache = {};
  final Set<String> _orderActionsInProgress = <String>{};
  final Set<String> _quickUserSavesInProgress = <String>{};

  bool get _hasLocalFilters =>
      _searchController.text.trim().isNotEmpty ||
      _filterFieldController.text.trim().isNotEmpty ||
      _filterValueController.text.trim().isNotEmpty ||
      (_isIntercityRouteCollection &&
          _intercityPointFilterController.text.trim().isNotEmpty) ||
      _sortFieldController.text.trim().isNotEmpty ||
      (_isUsersCollection && _userRoleFilter != 'all');

  bool get _isIntercityRouteCollection => const {
        'RouterCityToCity',
        'routerCityToCity',
        'routercitytocity',
      }.contains(widget.collectionName);

  bool get _isOrderCollection => widget.collectionName == 'order';
  bool get _isPaymentsCollection => widget.collectionName == 'payments';
  bool get _isWithdrawalsCollection => widget.collectionName == 'withdrawals';
  bool get _isAuditLogsCollection => widget.collectionName == 'auditLogs';
  bool get _isCityCollection => widget.collectionName == 'City';
  bool get _useBackendOnlyCollections => true;
  bool get _isBackendGenericCollection => const {
        'cityToCity',
        'CityToCityDriver',
        'gruz',
        'GruzDriver',
        'bid',
      }.contains(widget.collectionName);

  void _onLocalFilterChanged() {
    _resetPagination();
  }

  bool _isLongTextField(_FieldSpec spec) {
    if (widget.collectionName == 'politika' && spec.key == 'text') {
      return true;
    }
    if (widget.collectionName == 'tariffsContent' &&
        (spec.key == 'driverTariffs' || spec.key == 'passengerTariffs')) {
      return true;
    }
    return false;
  }

  bool _isUserImageField(_FieldSpec spec) {
    return widget.collectionName == 'users' &&
        const {
          'photo_url',
          'photoUrl',
          'avtoImage',
          'autoImage',
          'techImage',
          'techPassportImage',
        }.contains(spec.key);
  }

  List<_FieldSpec>? _schemaForEditor(
    String collectionName, {
    Map<String, dynamic>? data,
  }) {
    final schema = _schemas[collectionName];
    if (schema == null) {
      return null;
    }
    if (collectionName != 'users') {
      return schema;
    }

    final effectiveUserData = data ?? const <String, dynamic>{};
    final showDriverFields = _looksLikeDriverPayload(effectiveUserData) ||
        _isPendingDriver(effectiveUserData);

    return schema
        .where((spec) =>
            (_adminEditableUserFields.contains(spec.key) ||
                _adminReadOnlyUserFields.contains(spec.key)) &&
            (showDriverFields || !_driverOnlyUserFields.contains(spec.key)))
        .map(
          (spec) => _FieldSpec(
            key: spec.key,
            label: spec.label,
            type: spec.type,
            required: spec.required,
            readOnly:
                spec.readOnly || _adminReadOnlyUserFields.contains(spec.key),
            helper: spec.helper,
          ),
        )
        .toList(growable: false);
  }

  List<MapEntry<String, String>> _documentImageEntries(
    Map<String, dynamic> data,
  ) {
    const variants = {
      'Основное': ['photo_url', 'photoUrl'],
      'Авто': ['avtoImage', 'autoImage'],
      'Техпаспорт': ['techImage', 'techPassportImage'],
    };
    final entries = <MapEntry<String, String>>[];
    for (final entry in variants.entries) {
      for (final key in entry.value) {
        final value = (data[key] ?? '').toString().trim();
        if (value.isNotEmpty) {
          entries.add(MapEntry(entry.key, value));
          break;
        }
      }
    }
    return entries;
  }

  // ignore: unused_element
  List<MapEntry<String, String>> _safeDocumentImageEntries(
    Map<String, dynamic> data,
  ) {
    try {
      return _documentImageEntries(data);
    } catch (e, st) {
      debugPrint('Admin image entry parse error: $e\n$st');
      return const <MapEntry<String, String>>[];
    }
  }

  bool _isHttpUrl(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://');
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
      if (normalized.isNotEmpty) {
        urls.add(normalized);
      }
    }

    add(value);
    add(Uri.encodeFull(value));
    return urls.toList(growable: false);
  }

  bool get _isUsersCollection => widget.collectionName == 'users';
  bool get _isPolitikaCollection => _resolvedCollectionName() == 'politika';
  bool get _isAppSettingsCollection =>
      _resolvedCollectionName() == 'appSettings';
  bool get _isBackendContentCollection => const {
        'politika',
        'about',
        'supportContacts',
        'tariffsContent',
      }.contains(widget.collectionName);
  Future<void> _savePolitikaDocument(
    Map<String, dynamic> converted,
  ) async {
    final response = await makeCloudCall(
      'adminSavePolitika',
      {
        'text': (converted['text'] ?? '').toString(),
      },
    );
    if (response['success'] != true) {
      final error = (response['error'] ?? '').toString().trim();
      throw Exception(
        error.isNotEmpty ? error : 'Не удалось сохранить политику',
      );
    }
  }

  dynamic _encodeCallableValue(dynamic value) {
    if (_isAdminDeleteSentinel(value)) {
      return const {'__delete': true};
    }
    if (value is GeoPoint) {
      return {
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is DocumentReference) {
      return value.path;
    }
    if (value is List) {
      return value.map(_encodeCallableValue).toList(growable: false);
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _encodeCallableValue(item)),
      );
    }
    return value;
  }

  static const Map<String, bool> _adminDeleteSentinel = {'__delete': true};

  bool _isAdminDeleteSentinel(dynamic value) {
    return value is Map && value.length == 1 && value['__delete'] == true;
  }

  Future<bool> _confirmDeleteUserImageField(
    BuildContext context, {
    required String label,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Удалить фото?'),
            content: Text(
              'Фото "$label" будет удалено из анкеты водителя. Это действие требует явного подтверждения администратора.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _saveUserDocument(
    DocumentReference reference,
    Map<String, dynamic> converted,
    Map<String, dynamic> initialData,
  ) async {
    final remaining = Map<String, dynamic>.from(converted);
    final isDriverLike = _looksLikeDriverPayload({
      ...initialData,
      ...converted,
    });
    final currentFirstName = normalizeAdminText(initialData['firstName']);
    final currentLastName = normalizeAdminText(initialData['lastName']);
    String resolveTargetNamePart(String key, String currentValue) {
      if (!remaining.containsKey(key)) {
        return currentValue;
      }
      final raw = remaining[key];
      if (_isAdminDeleteSentinel(raw)) {
        return '';
      }
      return normalizeAdminText(raw);
    }

    final targetFirstName =
        resolveTargetNamePart('firstName', currentFirstName);
    final targetLastName = resolveTargetNamePart('lastName', currentLastName);
    final didChangeNameParts = targetFirstName != currentFirstName ||
        targetLastName != currentLastName;
    if (didChangeNameParts) {
      final compositeName = [targetFirstName, targetLastName]
          .where((part) => part.isNotEmpty)
          .join(' ')
          .trim();
      if (compositeName.isNotEmpty) {
        remaining['display_name'] = compositeName;
      } else if (_clearableUserFields.contains('display_name')) {
        remaining['display_name'] = _adminDeleteSentinel;
      }
    }

    Future<void> callAdminMutation(
      String functionName,
      Map<String, dynamic> payload,
    ) async {
      final response = await makeCloudCall(
        functionName,
        {
          'userDocPath': reference.path,
          ...payload,
        },
      );
      if (response['success'] != true) {
        final error = (response['error'] ?? '').toString().trim();
        throw Exception(error.isNotEmpty
            ? error
            : 'Не удалось выполнить операцию администратора');
      }
    }

    final currentBalance = (initialData['balance'] as num?)?.toDouble() ??
        double.tryParse((initialData['balance'] ?? '').toString());
    final targetBalance = (converted['balance'] as num?)?.toDouble() ??
        double.tryParse((converted['balance'] ?? '').toString());
    if (isDriverLike &&
        targetBalance != null &&
        (currentBalance == null || currentBalance != targetBalance)) {
      await callAdminMutation(
        'adminTopUpDriverBalance',
        {'targetBalance': targetBalance},
      );
      remaining.remove('balance');
    }

    final currentCity = (initialData['city'] ?? '').toString().trim();
    final targetCity = (converted['city'] ?? '').toString().trim();
    if (isDriverLike && targetCity.isNotEmpty && targetCity != currentCity) {
      await callAdminMutation(
        'adminUpdateDriverCity',
        {'city': targetCity},
      );
      remaining.remove('city');
    }

    final currentOrderDelay =
        (initialData['orderDelaySeconds'] as num?)?.toInt() ??
            int.tryParse((initialData['orderDelaySeconds'] ?? '').toString());
    final targetOrderDelay =
        (converted['orderDelaySeconds'] as num?)?.toInt() ??
            int.tryParse((converted['orderDelaySeconds'] ?? '').toString());
    if (isDriverLike &&
        targetOrderDelay != null &&
        (currentOrderDelay == null || currentOrderDelay != targetOrderDelay)) {
      await callAdminMutation(
        'adminUpdateDriverOrderDelay',
        {'orderDelaySeconds': targetOrderDelay},
      );
      remaining.remove('orderDelaySeconds');
    }

    final currentStatusDriver =
        (initialData['statusDriver'] ?? '').toString().trim();
    final targetStatusDriver =
        (converted['statusDriver'] ?? '').toString().trim();
    if (isDriverLike &&
        targetStatusDriver.isNotEmpty &&
        targetStatusDriver != currentStatusDriver) {
      await callAdminMutation(
        'approveDriver',
        {'statusDriver': targetStatusDriver},
      );
      remaining.remove('statusDriver');
    }

    final currentBlocked = initialData['blocked'] == true;
    final targetBlocked = converted['blocked'] == true;
    if (converted.containsKey('blocked') && targetBlocked != currentBlocked) {
      await callAdminMutation(
        targetBlocked ? 'blockDriver' : 'unblockDriver',
        const {},
      );
      remaining.remove('blocked');
    }

    remaining.removeWhere((key, value) {
      if (_backendManagedUserFields.contains(key)) {
        return true;
      }
      return _sameAdminFieldValue(initialData[key], value);
    });

    if (remaining.isEmpty) {
      return;
    }

    final response = await makeCloudCall(
      'adminUpdateUserDocument',
      {
        'userDocPath': reference.path,
        'fields': remaining.map(
          (key, value) => MapEntry(key, _encodeCallableValue(value)),
        ),
      },
    );
    if (response['success'] != true) {
      final error = (response['error'] ?? '').toString().trim();
      throw Exception(
        error.isNotEmpty ? error : 'Не удалось сохранить пользователя',
      );
    }
  }

  bool _sameAdminFieldValue(dynamic current, dynamic next) {
    if (current == null && next == null) {
      return true;
    }
    if (current is DocumentReference && next is DocumentReference) {
      return current.path == next.path;
    }
    if (current is GeoPoint && next is GeoPoint) {
      return current.latitude == next.latitude &&
          current.longitude == next.longitude;
    }
    if (current is Timestamp) {
      current = current.toDate();
    }
    if (next is Timestamp) {
      next = next.toDate();
    }
    if (current is DateTime && next is DateTime) {
      return current.isAtSameMomentAs(next);
    }
    if (current is num && next is num) {
      return current.toDouble() == next.toDouble();
    }
    if (current is List || current is Map || next is List || next is Map) {
      try {
        return jsonEncode(current) == jsonEncode(next);
      } catch (_) {
        return false;
      }
    }
    return current == next;
  }

  Future<void> _saveQuickUserField(
    BuildContext context,
    DocumentReference reference,
    Map<String, dynamic> initialData,
    String key,
    Object? value, {
    Map<String, dynamic> extraFields = const {},
  }) async {
    final saveKey = '${reference.path}::$key';
    if (_quickUserSavesInProgress.contains(saveKey)) {
      return;
    }
    setState(() {
      _quickUserSavesInProgress.add(saveKey);
    });
    try {
      await _saveUserDocument(
        reference,
        {key: value, ...extraFields},
        initialData,
      );
      if (!mounted || !context.mounted) return;
      _clearPaginationCursor();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сохранено'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка сохранения: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _quickUserSavesInProgress.remove(saveKey);
        });
      } else {
        _quickUserSavesInProgress.remove(saveKey);
      }
    }
  }

  bool _looksLikeDriverPayload(Map<String, dynamic> converted) {
    final statusDriver = (converted['statusDriver'] ?? '').toString().trim();
    final role = (converted['role'] ?? '').toString().trim().toLowerCase();
    final driverRegistrationStatus =
        (converted['driverRegistrationStatus'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    return converted['isDriver'] == true ||
        statusDriver.isNotEmpty ||
        role == 'driver' ||
        const {
          'incomplete',
          'pending_review',
          'approved',
          'rejected',
        }.contains(driverRegistrationStatus);
  }

  bool _matchesUserRoleFilter(Map<String, dynamic> data) {
    if (!_isUsersCollection || _userRoleFilter == 'all') {
      return true;
    }
    final isDriver = _looksLikeDriverPayload(data);
    if (_userRoleFilter == 'drivers') {
      return isDriver;
    }
    if (_userRoleFilter == 'passengers') {
      return !isDriver;
    }
    return true;
  }

  Future<void> _createUserDocument(
    Map<String, dynamic> converted,
  ) async {
    if (_looksLikeDriverPayload(converted)) {
      final firstName = normalizeAdminText(converted['firstName']);
      final lastName = normalizeAdminText(converted['lastName']);
      final currentDisplayName = normalizeAdminText(converted['display_name']);
      if (currentDisplayName.isEmpty) {
        final compositeName = [firstName, lastName]
            .where((part) => part.isNotEmpty)
            .join(' ')
            .trim();
        if (compositeName.isNotEmpty) {
          converted['display_name'] = compositeName;
        }
      }
      final response = await makeCloudCall(
        'adminCreateDriver',
        {
          'fields': converted.map(
            (key, value) => MapEntry(key, _encodeCallableValue(value)),
          ),
        },
      );
      if (response['success'] == true) {
        return;
      }
      final error = (response['error'] ?? '').toString().trim();
      throw Exception(
        error.isNotEmpty ? error : 'Не удалось создать водителя',
      );
    }

    final response = await makeCloudCall(
      'adminCreatePassenger',
      {
        'fields': converted.map(
          (key, value) => MapEntry(key, _encodeCallableValue(value)),
        ),
      },
    );
    if (response['success'] == true) {
      return;
    }
    final error = (response['error'] ?? '').toString().trim();
    throw Exception(
      error.isNotEmpty ? error : 'Не удалось создать пассажира',
    );
  }

  Widget _buildSingletonSettingsCard(
    BuildContext context, {
    required String title,
    required Map<String, dynamic> data,
    required VoidCallback onEdit,
    VoidCallback? onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _mtaxiSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _mtaxiAdminBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FlutterFlowTheme.of(context).titleMedium.override(
                        font: GoogleFonts.readexPro(
                          fontWeight: FontWeight.w600,
                          fontStyle: FlutterFlowTheme.of(context)
                              .titleMedium
                              .fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).titleMedium.fontStyle,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _safeDocSummary(data),
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                  style: FlutterFlowTheme.of(context).bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete?.call();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Редактировать'),
              ),
              if (onDelete != null)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Удалить'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackendContentBody(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: makeCloudCall('getContentDocument', {
        'collection': widget.collectionName,
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildInfoCard(
                context,
                title: 'Ошибка загрузки',
                message: 'Не удалось открыть раздел: ${snapshot.error}',
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              SizedBox(height: 24),
              Center(child: CircularProgressIndicator()),
            ],
          );
        }
        final document = snapshot.data?['document'];
        final data = document is Map
            ? Map<String, dynamic>.from(document)
            : <String, dynamic>{};
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSingletonSettingsCard(
              context,
              title: 'main',
              data: data,
              onEdit: () => _openBackendContentEditor(
                context,
                data: data,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openBackendContentEditor(
    BuildContext context, {
    required Map<String, dynamic> data,
  }) async {
    final schema = _schemaForEditor(widget.collectionName, data: data) ?? [];
    final controllers = <String, TextEditingController>{
      for (final spec in schema)
        spec.key: TextEditingController(text: (data[spec.key] ?? '').toString())
    };
    String? errorText;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(_collectionLabels[widget.collectionName] ??
                  widget.collectionName),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final spec in schema) ...[
                        TextField(
                          controller: controllers[spec.key],
                          minLines: _isLongTextField(spec) ? 6 : 1,
                          maxLines: _isLongTextField(spec) ? 12 : 1,
                          decoration: InputDecoration(
                            labelText: spec.label,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (errorText != null)
                        Text(
                          errorText!,
                          style: TextStyle(
                            color: FlutterFlowTheme.of(context).error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() {
                            isSaving = true;
                            errorText = null;
                          });
                          try {
                            final fields = <String, dynamic>{
                              for (final spec in schema)
                                spec.key:
                                    controllers[spec.key]?.text.trim() ?? ''
                            };
                            final response = await makeCloudCall(
                              'adminUpdateContentDocument',
                              {
                                'collection': widget.collectionName,
                                'fields': fields,
                              },
                            );
                            if (response['success'] != true) {
                              throw Exception(response['error']?.toString() ??
                                  'Не удалось сохранить');
                            }
                            if (mounted) {
                              Navigator.pop(context);
                              safeSetState(() {});
                            }
                          } catch (e) {
                            setModalState(() {
                              errorText =
                                  'Ошибка сохранения: ${_humanizeAdminError(e)}';
                              isSaving = false;
                            });
                          }
                        },
                  child: Text(isSaving ? 'Сохраняем...' : 'Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  dynamic _convertBackendGenericField(_FieldSpec spec, String rawText) {
    final text = _isLongTextField(spec)
        ? rawText.replaceAll('\r\n', '\n')
        : rawText.trim();
    if (text.isEmpty) {
      if (spec.required) {
        throw Exception('Заполните поле: ${spec.label}');
      }
      return null;
    }
    switch (spec.type) {
      case _FieldType.string:
        return text;
      case _FieldType.intType:
        final value = int.tryParse(text);
        if (value == null) {
          throw Exception('Поле "${spec.label}" должно быть числом');
        }
        return value;
      case _FieldType.doubleType:
        final value = double.tryParse(text.replaceAll(',', '.'));
        if (value == null) {
          throw Exception('Поле "${spec.label}" должно быть числом');
        }
        return value;
      case _FieldType.boolType:
        final normalized = text.toLowerCase();
        if (const {'true', '1', 'yes', 'да'}.contains(normalized)) {
          return true;
        }
        if (const {'false', '0', 'no', 'нет'}.contains(normalized)) {
          return false;
        }
        throw Exception('Поле "${spec.label}" должно быть true/false');
      case _FieldType.dateTime:
        final value = DateTime.tryParse(text);
        if (value == null) {
          throw Exception('Поле "${spec.label}" должно быть датой');
        }
        return value.toIso8601String();
      case _FieldType.reference:
        return text;
      case _FieldType.geo:
        final parts = text.split(',');
        if (parts.length != 2) {
          throw Exception('Поле "${spec.label}" в формате lat,lng');
        }
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat == null || lng == null) {
          throw Exception('Поле "${spec.label}" в формате lat,lng');
        }
        return {'latitude': lat, 'longitude': lng};
      case _FieldType.json:
        return json.decode(text);
    }
  }

  String _genericFieldText(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is Map || value is List) {
      return json.encode(value);
    }
    return value.toString();
  }

  Widget _buildBackendGenericCollectionBody(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: makeCloudCall('adminListGenericCollection', {
        'collection': widget.collectionName,
        'query': _searchController.text.trim(),
        'limit': _limit,
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilters(context),
              const SizedBox(height: 8),
              _buildInfoCard(
                context,
                title: 'Ошибка загрузки',
                message: 'Не удалось открыть раздел: ${snapshot.error}',
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilters(context),
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        }
        final rawDocs = snapshot.data?['documents'];
        final documents = rawDocs is List
            ? rawDocs
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: documents.length + 2,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildFilters(context);
            }
            if (documents.isEmpty && index == 1) {
              return _buildInfoCard(
                context,
                title: 'Нет данных',
                message: 'В backend пока нет документов этого раздела.',
              );
            }
            if (index == documents.length + 1) {
              return const SizedBox(height: 72);
            }
            final data = documents[index - 1];
            final id = (data['id'] ?? data['docPath'] ?? '').toString();
            return _buildSingletonSettingsCard(
              context,
              title: id.isEmpty ? widget.collectionName : id,
              data: data,
              onEdit: () => _openBackendGenericEditor(context, data: data),
              onDelete: () => _confirmDeleteBackendGeneric(context, data),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteBackendGeneric(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final id = (data['id'] ?? '').toString().trim();
    if (id.isEmpty) {
      return;
    }
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (alertDialogContext) {
            return AlertDialog(
              title: const Text('Удалить документ?'),
              content: const Text('Это действие необратимо.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(alertDialogContext, false),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(alertDialogContext, true),
                  child: const Text('Удалить'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!shouldDelete) {
      return;
    }
    final response = await makeCloudCall('adminDeleteGenericDocument', {
      'collection': widget.collectionName,
      'id': id,
    });
    if (response['success'] != true) {
      final error = (response['error'] ?? '').toString().trim();
      throw Exception(error.isNotEmpty ? error : 'Не удалось удалить документ');
    }
    if (mounted) {
      safeSetState(() {});
    }
  }

  Future<void> _openBackendGenericEditor(
    BuildContext context, {
    Map<String, dynamic>? data,
  }) async {
    final schema = _schemaForEditor(widget.collectionName, data: data ?? {}) ??
        const <_FieldSpec>[];
    final controllers = <String, TextEditingController>{
      for (final spec in schema)
        if (!spec.readOnly)
          spec.key: TextEditingController(
            text: _genericFieldText(data?[spec.key]),
          )
    };
    String? errorText;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(data == null ? 'Добавить документ' : 'Редактировать'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final spec in schema)
                        if (!spec.readOnly) ...[
                          TextField(
                            controller: controllers[spec.key],
                            minLines: spec.type == _FieldType.json ? 4 : 1,
                            maxLines: spec.type == _FieldType.json ? 10 : 1,
                            decoration: InputDecoration(
                              labelText: spec.label,
                              helperText: spec.helper,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            keyboardType: spec.type == _FieldType.string ||
                                    spec.type == _FieldType.reference ||
                                    spec.type == _FieldType.json
                                ? TextInputType.text
                                : TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                        ],
                      if (errorText != null)
                        Text(
                          errorText!,
                          style: TextStyle(
                            color: FlutterFlowTheme.of(context).error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() {
                            isSaving = true;
                            errorText = null;
                          });
                          try {
                            final fields = <String, dynamic>{};
                            for (final spec in schema) {
                              if (spec.readOnly) {
                                continue;
                              }
                              final value = _convertBackendGenericField(
                                spec,
                                controllers[spec.key]?.text ?? '',
                              );
                              if (value != null) {
                                fields[spec.key] = value;
                              }
                            }
                            final response = await makeCloudCall(
                              'adminUpsertGenericDocument',
                              {
                                'collection': widget.collectionName,
                                'id': data?['id'],
                                'fields': fields,
                              },
                            );
                            if (response['success'] != true) {
                              throw Exception(response['error']?.toString() ??
                                  'Не удалось сохранить');
                            }
                            if (mounted) {
                              Navigator.pop(context);
                              safeSetState(() {});
                            }
                          } catch (e) {
                            setModalState(() {
                              errorText =
                                  'Ошибка сохранения: ${_humanizeAdminError(e)}';
                              isSaving = false;
                            });
                          }
                        },
                  child: Text(isSaving ? 'Сохраняем...' : 'Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  Widget _buildAppSettingsBody(BuildContext context) {
    return FutureBuilder<AppRuntimeSettings>(
      future: getAppRuntimeSettings(forceRefresh: true),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildInfoCard(
                context,
                title: 'Ошибка загрузки',
                message: 'Не удалось открыть настройки: ${snapshot.error}',
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              SizedBox(height: 24),
              Center(child: CircularProgressIndicator()),
            ],
          );
        }
        final data = currentAppRuntimeSettingsRaw;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSingletonSettingsCard(
              context,
              title: 'main',
              data: data,
              onEdit: () => _openBackendAppSettingsEditor(
                context,
                data: data,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openBackendAppSettingsEditor(
    BuildContext context, {
    required Map<String, dynamic> data,
  }) async {
    final schema = _schemaForEditor('appSettings', data: data) ?? [];
    final controllers = <String, TextEditingController>{
      for (final spec in schema)
        spec.key: TextEditingController(text: (data[spec.key] ?? '').toString())
    };
    String? errorText;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Настройки'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final spec in schema) ...[
                      TextField(
                        controller: controllers[spec.key],
                        decoration: InputDecoration(
                          labelText: spec.label,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (errorText != null)
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: FlutterFlowTheme.of(context).error,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() {
                            isSaving = true;
                            errorText = null;
                          });
                          try {
                            final converted = <String, dynamic>{};
                            for (final spec in schema) {
                              final text =
                                  controllers[spec.key]?.text.trim() ?? '';
                              if (text.isEmpty) {
                                throw Exception(
                                    'Заполните поле: ${spec.label}');
                              }
                              final value = double.tryParse(text);
                              if (value == null) {
                                throw Exception(
                                    'Поле "${spec.label}" должно быть числом');
                              }
                              converted[spec.key] = value;
                            }
                            await updateAppRuntimeSettingsFromBackend(
                                converted);
                            if (mounted) {
                              Navigator.pop(context);
                              safeSetState(() {});
                            }
                          } catch (e) {
                            setModalState(() {
                              errorText =
                                  'Ошибка сохранения: ${_humanizeAdminError(e)}';
                              isSaving = false;
                            });
                          }
                        },
                  child: Text(isSaving ? 'Сохраняем...' : 'Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  Widget _buildBackendCityTariffsBody(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: makeCloudCall('adminListCityTariffs', {
        'query': _searchController.text.trim(),
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildInfoCard(
                context,
                title: 'Ошибка загрузки',
                message: 'Не удалось открыть тарифы: ${snapshot.error}',
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              SizedBox(height: 24),
              Center(child: CircularProgressIndicator()),
            ],
          );
        }
        final rawTariffs = snapshot.data?['tariffs'];
        final tariffs = rawTariffs is List
            ? rawTariffs
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];
        if (tariffs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildInfoCard(
                context,
                title: 'Нет данных',
                message: 'Тарифы поселков пока не созданы.',
              ),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tariffs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final tariff = tariffs[index];
            final title = (tariff['title'] ?? '').toString();
            return _buildSingletonSettingsCard(
              context,
              title: title.isEmpty ? 'Поселок' : title,
              data: tariff,
              onEdit: () => _openBackendCityTariffEditor(
                context,
                data: tariff,
              ),
            );
          },
        );
      },
    );
  }

  String _backendPathId(Map<String, dynamic> data, String pathKey) {
    final path = (data[pathKey] ?? '').toString().trim();
    if (path.isNotEmpty) {
      final parts = path.split('/').where((part) => part.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        return parts.last;
      }
    }
    return (data['id'] ?? '').toString().trim();
  }

  DocumentReference _backendDocumentReference(
    String collection,
    Map<String, dynamic> data,
    String pathKey,
  ) {
    final path = (data[pathKey] ?? '').toString().trim();
    if (path.contains('/')) {
      return BackendRefs.instance.doc(path);
    }
    return BackendRefs.instance.collection(collection).doc(
          _backendPathId(data, pathKey),
        );
  }

  Map<String, dynamic> _normalizeBackendUserData(Map<String, dynamic> user) {
    final data = Map<String, dynamic>.from(user);
    data['display_name'] ??= data['displayName'];
    data['phone_number'] ??= data['phone'];
    data['created_time'] ??= data['createdAt'] ?? data['created_at'];
    return data;
  }

  Map<String, dynamic> _normalizeBackendOrderData(Map<String, dynamic> order) {
    final data = Map<String, dynamic>.from(order);
    data['date'] ??= data['createdAt'];
    data['dateCreate'] ??= data['createdAt'];
    data['idUser'] ??= (data['passengerId'] ?? '').toString().trim().isNotEmpty
        ? BackendRefs.instance.doc('users/${data['passengerId']}')
        : null;
    data['idDriver'] ??= (data['driverId'] ?? '').toString().trim().isNotEmpty
        ? BackendRefs.instance.doc('users/${data['driverId']}')
        : null;
    return data;
  }

  String _backendUserRoleFilter() {
    switch (_userRoleFilter) {
      case 'drivers':
        return 'driver';
      case 'passengers':
        return 'passenger';
      default:
        return '';
    }
  }

  Widget _buildBackendUsersBody(BuildContext context) {
    final idSearch = _idSearchController.text.trim();
    final query =
        idSearch.isNotEmpty ? idSearch : _searchController.text.trim();
    return FutureBuilder<Map<String, dynamic>>(
      future: makeCloudCall('adminListUsers', {
        'query': query,
        'role': _backendUserRoleFilter(),
        'limit': _limit,
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilters(context),
              const SizedBox(height: 8),
              _buildInfoCard(
                context,
                title: 'Ошибка загрузки пользователей',
                message: 'Не удалось открыть пользователей: ${snapshot.error}',
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilters(context),
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        }
        final rawUsers = snapshot.data?['users'];
        final users = rawUsers is List
            ? rawUsers
                .whereType<Map>()
                .map((item) => _normalizeBackendUserData(
                      Map<String, dynamic>.from(item),
                    ))
                .where(_matchesUserRoleFilter)
                .toList()
            : <Map<String, dynamic>>[];
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilters(context),
                  const SizedBox(height: 8),
                  _buildInfoCard(
                    context,
                    title: 'Пользователи',
                    message:
                        'Показано: ${users.length}. Источник: backend users.',
                  ),
                ],
              );
            }
            if (users.isEmpty) {
              return _buildInfoCard(
                context,
                title: 'Нет данных',
                message: 'По текущим фильтрам ничего не найдено.',
              );
            }
            return _buildBackendUserCard(
              context,
              data: users[index - 1],
            );
          },
        );
      },
    );
  }

  Widget _buildBackendUserCard(
    BuildContext context, {
    required Map<String, dynamic> data,
  }) {
    final reference = _backendDocumentReference('users', data, 'userDocPath');
    final createdAt = _asDateTime(data['created_time']);
    final isRecentUser = _isRecentRegistration(data);
    final isPendingDriver = _isPendingDriver(data);
    final highlightColor =
        isPendingDriver ? Colors.orange : FlutterFlowTheme.of(context).primary;
    final shouldHighlightCard = isRecentUser || isPendingDriver;
    final blockedBusy =
        _quickUserSavesInProgress.contains('${reference.path}::blocked');
    final vipBusy =
        _quickUserSavesInProgress.contains('${reference.path}::vip');
    final delayBusy = _quickUserSavesInProgress
        .contains('${reference.path}::orderDelaySeconds');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: shouldHighlightCard
            ? highlightColor.withValues(alpha: 0.07)
            : _mtaxiSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: shouldHighlightCard
              ? highlightColor.withValues(alpha: 0.34)
              : _mtaxiAdminBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_outline, color: _mtaxiMint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _backendPathId(data, 'userDocPath'),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.readexPro(
                                fontWeight: FontWeight.w600,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w600,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (isRecentUser)
                          _buildStatusChip(
                            context,
                            label: 'Новый',
                            color: _mtaxiMint,
                            icon: Icons.fiber_new,
                          ),
                        if (isPendingDriver)
                          _buildStatusChip(
                            context,
                            label: 'На проверке',
                            color: Colors.orange,
                            icon: Icons.pending_actions,
                          ),
                      ],
                    ),
                  ],
                ),
                if (createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Создан: ${_formatDateTime(context, createdAt)}',
                      style: FlutterFlowTheme.of(context).labelSmall,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  _safeDocSummary(data),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: FlutterFlowTheme.of(context).labelMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Блок'),
                        const SizedBox(width: 8),
                        Switch(
                          value: data['blocked'] == true,
                          onChanged: blockedBusy
                              ? null
                              : (value) => _saveQuickUserField(
                                    context,
                                    reference,
                                    data,
                                    'blocked',
                                    value,
                                  ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('VIP'),
                        const SizedBox(width: 8),
                        Switch(
                          value: data['vip'] == true,
                          onChanged: vipBusy
                              ? null
                              : (value) => _saveQuickUserField(
                                    context,
                                    reference,
                                    data,
                                    'vip',
                                    value,
                                    extraFields: value
                                        ? const {'orderDelaySeconds': 0}
                                        : const {},
                                  ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Задержка'),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: () {
                            final raw = data['orderDelaySeconds'];
                            final parsed = raw is num
                                ? raw.toInt()
                                : int.tryParse(raw?.toString() ?? '');
                            return (parsed ?? 10).clamp(0, 10).toInt();
                          }(),
                          onChanged: delayBusy
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  _saveQuickUserField(
                                    context,
                                    reference,
                                    data,
                                    'orderDelaySeconds',
                                    value,
                                  );
                                },
                          items: List.generate(
                            11,
                            (i) => DropdownMenuItem<int>(
                              value: i,
                              child: Text('$i сек'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Редактировать пользователя',
            child: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _openBackendUserEditor(
                context,
                reference: reference,
                data: data,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBackendUserEditor(
    BuildContext context, {
    required DocumentReference reference,
    required Map<String, dynamic> data,
  }) async {
    final schema =
        _schemaForEditor('users', data: data) ?? const <_FieldSpec>[];
    final editable = schema.where((spec) => !spec.readOnly).toList();
    final controllers = <String, TextEditingController>{};
    final bools = <String, bool>{};
    for (final spec in editable) {
      final raw = data[spec.key];
      if (spec.type == _FieldType.boolType) {
        bools[spec.key] = raw == true;
      } else {
        controllers[spec.key] = TextEditingController(
          text: _genericFieldText(raw),
        );
      }
    }
    String? errorText;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Редактировать пользователя'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final spec in editable) ...[
                        if (spec.type == _FieldType.boolType)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(spec.label),
                            value: bools[spec.key] ?? false,
                            onChanged: (value) {
                              setModalState(() {
                                bools[spec.key] = value;
                                if (spec.key == 'vip' && value) {
                                  controllers['orderDelaySeconds']?.text = '0';
                                }
                              });
                            },
                          )
                        else
                          TextField(
                            controller: controllers[spec.key],
                            minLines: spec.type == _FieldType.json ? 4 : 1,
                            maxLines: spec.type == _FieldType.json ? 10 : 1,
                            decoration: InputDecoration(
                              labelText: spec.label,
                              helperText: spec.helper,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            keyboardType: spec.type == _FieldType.string ||
                                    spec.type == _FieldType.reference ||
                                    spec.type == _FieldType.json ||
                                    spec.type == _FieldType.dateTime
                                ? TextInputType.text
                                : TextInputType.number,
                          ),
                        const SizedBox(height: 12),
                      ],
                      if (errorText != null)
                        Text(
                          errorText!,
                          style: TextStyle(
                            color: FlutterFlowTheme.of(context).error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() {
                            isSaving = true;
                            errorText = null;
                          });
                          try {
                            final fields = <String, dynamic>{};
                            for (final spec in editable) {
                              if (spec.type == _FieldType.boolType) {
                                fields[spec.key] = bools[spec.key] ?? false;
                              } else {
                                final raw = controllers[spec.key]?.text ?? '';
                                if (raw.trim().isEmpty) {
                                  continue;
                                }
                                fields[spec.key] =
                                    _convertBackendGenericField(spec, raw);
                              }
                            }
                            await _saveUserDocument(reference, fields, data);
                            if (mounted) {
                              Navigator.pop(context);
                              _clearPaginationCursor();
                              safeSetState(() {});
                            }
                          } catch (e) {
                            setModalState(() {
                              errorText =
                                  'Ошибка сохранения: ${_humanizeAdminError(e)}';
                              isSaving = false;
                            });
                          }
                        },
                  child: Text(isSaving ? 'Сохраняем...' : 'Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  int? _backendOrderStatusFilter() {
    final field = _filterFieldController.text.trim().toLowerCase();
    if (field != 'status' && field != 'статус') {
      return null;
    }
    return int.tryParse(_filterValueController.text.trim());
  }

  Widget _buildBackendOrdersBody(BuildContext context) {
    final idSearch = _idSearchController.text.trim();
    final query =
        idSearch.isNotEmpty ? idSearch : _searchController.text.trim();
    return FutureBuilder<Map<String, dynamic>>(
      future: makeCloudCall('adminListOrders', {
        'query': query,
        if (_backendOrderStatusFilter() != null)
          'status': _backendOrderStatusFilter(),
        'limit': _limit,
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilters(context),
              const SizedBox(height: 8),
              _buildInfoCard(
                context,
                title: 'Ошибка загрузки заказов',
                message: 'Не удалось открыть заказы: ${snapshot.error}',
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilters(context),
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        }
        final rawOrders = snapshot.data?['orders'];
        final orders = rawOrders is List
            ? rawOrders
                .whereType<Map>()
                .map((item) => _normalizeBackendOrderData(
                      Map<String, dynamic>.from(item),
                    ))
                .toList()
            : <Map<String, dynamic>>[];
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilters(context),
                  const SizedBox(height: 8),
                  _buildInfoCard(
                    context,
                    title: 'Заказы',
                    message:
                        'Показано: ${orders.length}. Источник: backend orders.',
                  ),
                ],
              );
            }
            if (orders.isEmpty) {
              return _buildInfoCard(
                context,
                title: 'Нет данных',
                message: 'По текущим фильтрам ничего не найдено.',
              );
            }
            return _buildBackendOrderCard(
              context,
              data: orders[index - 1],
            );
          },
        );
      },
    );
  }

  Widget _buildBackendOrderCard(
    BuildContext context, {
    required Map<String, dynamic> data,
  }) {
    final reference = _backendDocumentReference('order', data, 'orderDocPath');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _mtaxiSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _mtaxiAdminBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_taxi_outlined, color: _mtaxiMint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _backendPathId(data, 'orderDocPath'),
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.readexPro(
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                ),
                const SizedBox(height: 6),
                _buildOrderSummary(context, reference, data),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendPaymentsBody(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: makeCloudCall('adminListPayments', {
        'query': _searchController.text.trim(),
        'limit': _limit,
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilters(context),
              const SizedBox(height: 8),
              _buildInfoCard(
                context,
                title: 'Ошибка загрузки платежей',
                message: 'Не удалось открыть платежи: ${snapshot.error}',
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilters(context),
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        }
        final rawPayments = snapshot.data?['payments'];
        final payments = rawPayments is List
            ? rawPayments
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length + 2,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilters(context),
                  const SizedBox(height: 8),
                  _buildInfoCard(
                    context,
                    title: 'Платежи',
                    message:
                        'Показано: ${payments.length}. Источник: backend payments, свежие сверху.',
                  ),
                ],
              );
            }
            if (payments.isEmpty && index == 1) {
              return _buildInfoCard(
                context,
                title: 'Нет данных',
                message: 'Платежей пока нет.',
              );
            }
            if (index == payments.length + 1) {
              return _buildLoadMore(context);
            }
            return _buildBackendPaymentCard(
              context,
              payment: payments[index - 1],
            );
          },
        );
      },
    );
  }

  Widget _buildBackendPaymentCard(
    BuildContext context, {
    required Map<String, dynamic> payment,
  }) {
    final status = (payment['status'] ?? '').toString();
    final amount = payment['amount'];
    final paymentId =
        (payment['paymentId'] ?? payment['payment_id'] ?? payment['id'] ?? '')
            .toString();
    final userPhone = (payment['userPhone'] ?? '').toString();
    final createdAt =
        _asDateTime(payment['createdAt'] ?? payment['created_at']);
    final paidAt = _asDateTime(payment['paidAt'] ?? payment['paid_at']);
    final statusColor = status == 'success'
        ? Colors.green
        : status == 'failed'
            ? Colors.red
            : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _mtaxiSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _mtaxiAdminBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.payments_outlined, color: _mtaxiMint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        paymentId.isEmpty ? 'Платеж' : paymentId,
                        style:
                            FlutterFlowTheme.of(context).titleMedium.override(
                                  font: GoogleFonts.readexPro(
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontStyle,
                                ),
                      ),
                    ),
                    _buildStatusChip(
                      context,
                      label: status.isEmpty ? 'status' : status,
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatusChip(
                      context,
                      label: 'Сумма: ${_formatSummaryValue(amount)} ₸',
                      color: Colors.green,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    if (userPhone.isNotEmpty)
                      _buildStatusChip(
                        context,
                        label: userPhone,
                        color: _mtaxiMint,
                        icon: Icons.person_outline,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    if (createdAt != null)
                      'Создан: ${_formatDateTime(context, createdAt)}',
                    if (paidAt != null)
                      'Оплачен: ${_formatDateTime(context, paidAt)}',
                  ].join('  '),
                  style: FlutterFlowTheme.of(context).labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendWithdrawalsBody(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: makeCloudCall('adminListWithdrawals', {
        'query': _searchController.text.trim(),
        'limit': _limit,
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilters(context),
              const SizedBox(height: 8),
              _buildInfoCard(
                context,
                title: 'Ошибка загрузки выводов',
                message: 'Не удалось открыть заявки: ${snapshot.error}',
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilters(context),
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        }
        final rawWithdrawals = snapshot.data?['withdrawals'];
        final withdrawals = rawWithdrawals is List
            ? rawWithdrawals
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: withdrawals.length + 2,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilters(context),
                  const SizedBox(height: 8),
                  _buildInfoCard(
                    context,
                    title: 'Заявки на вывод',
                    message:
                        'Показано: ${withdrawals.length}. Источник: backend withdrawals, свежие сверху.',
                  ),
                ],
              );
            }
            if (withdrawals.isEmpty && index == 1) {
              return _buildInfoCard(
                context,
                title: 'Нет данных',
                message: 'Заявок на вывод пока нет.',
              );
            }
            if (index == withdrawals.length + 1) {
              return _buildLoadMore(context);
            }
            return _buildBackendWithdrawalCard(
              context,
              withdrawal: withdrawals[index - 1],
            );
          },
        );
      },
    );
  }

  Future<void> _resolveBackendWithdrawal(
    BuildContext context, {
    required Map<String, dynamic> withdrawal,
    required String action,
  }) async {
    final withdrawalId = (withdrawal['withdrawalId'] ??
            withdrawal['withdraw_id'] ??
            withdrawal['id'] ??
            '')
        .toString()
        .trim();
    if (withdrawalId.isEmpty) {
      return;
    }
    final response = await makeCloudCall('adminResolveWithdrawal', {
      'withdrawalId': withdrawalId,
      'action': action,
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response['success'] == true
              ? (action == 'approve' ? 'Вывод подтвержден' : 'Вывод отклонен')
              : (response['error'] ?? 'Не удалось выполнить действие')
                  .toString(),
        ),
      ),
    );
    if (response['success'] == true && mounted) {
      setState(() {});
    }
  }

  Widget _buildBackendWithdrawalCard(
    BuildContext context, {
    required Map<String, dynamic> withdrawal,
  }) {
    final status = (withdrawal['status'] ?? '').toString();
    final amount = withdrawal['amount'];
    final withdrawalId = (withdrawal['withdrawalId'] ??
            withdrawal['withdraw_id'] ??
            withdrawal['id'] ??
            '')
        .toString();
    final userPhone = (withdrawal['userPhone'] ?? '').toString();
    final cardNumber =
        (withdrawal['cardNumber'] ?? withdrawal['card_number'] ?? '')
            .toString();
    final createdAt =
        _asDateTime(withdrawal['createdAt'] ?? withdrawal['created_at']);
    final resolvedAt =
        _asDateTime(withdrawal['resolvedAt'] ?? withdrawal['resolved_at']);
    final normalizedStatus = status.toLowerCase();
    final pending = normalizedStatus == 'pending';
    final statusColor = normalizedStatus == 'success'
        ? Colors.green
        : normalizedStatus == 'rejected' || normalizedStatus == 'failed'
            ? Colors.red
            : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _mtaxiSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _mtaxiAdminBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_balance, color: _mtaxiMint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        withdrawalId.isEmpty ? 'Заявка на вывод' : withdrawalId,
                        style:
                            FlutterFlowTheme.of(context).titleMedium.override(
                                  font: GoogleFonts.readexPro(
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontStyle,
                                ),
                      ),
                    ),
                    _buildStatusChip(
                      context,
                      label: status.isEmpty ? 'status' : status,
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatusChip(
                      context,
                      label: 'Сумма: ${_formatSummaryValue(amount)} ₸',
                      color: Colors.indigo,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    if (userPhone.isNotEmpty)
                      _buildStatusChip(
                        context,
                        label: userPhone,
                        color: _mtaxiMint,
                        icon: Icons.person_outline,
                      ),
                    if (cardNumber.isNotEmpty)
                      _buildStatusChip(
                        context,
                        label: cardNumber,
                        color: Colors.blueGrey,
                        icon: Icons.credit_card,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    if (createdAt != null)
                      'Создан: ${_formatDateTime(context, createdAt)}',
                    if (resolvedAt != null)
                      'Обработан: ${_formatDateTime(context, resolvedAt)}',
                  ].join('  '),
                  style: FlutterFlowTheme.of(context).labelMedium,
                ),
                if (pending) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FFButtonWidget(
                        onPressed: () => _resolveBackendWithdrawal(
                          context,
                          withdrawal: withdrawal,
                          action: 'approve',
                        ),
                        text: 'Подтвердить',
                        options: FFButtonOptions(
                          height: 36,
                          color: Colors.green,
                          textStyle:
                              FlutterFlowTheme.of(context).labelLarge.override(
                                    font: GoogleFonts.readexPro(),
                                    color: Colors.white,
                                    letterSpacing: 0.0,
                                  ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      FFButtonWidget(
                        onPressed: () => _resolveBackendWithdrawal(
                          context,
                          withdrawal: withdrawal,
                          action: 'reject',
                        ),
                        text: 'Отклонить',
                        options: FFButtonOptions(
                          height: 36,
                          color: Colors.red,
                          textStyle:
                              FlutterFlowTheme.of(context).labelLarge.override(
                                    font: GoogleFonts.readexPro(),
                                    color: Colors.white,
                                    letterSpacing: 0.0,
                                  ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _backendAuditActionFilter() {
    final field = _filterFieldController.text.trim().toLowerCase();
    if (field == 'action' || field == 'действие') {
      return _filterValueController.text.trim();
    }
    return '';
  }

  String _backendAuditTargetFilter() {
    final field = _filterFieldController.text.trim().toLowerCase();
    if (field == 'target' || field == 'цель' || field == 'документ') {
      return _filterValueController.text.trim();
    }
    return '';
  }

  Widget _buildBackendAuditLogsBody(BuildContext context) {
    final idSearch = _idSearchController.text.trim();
    final query =
        idSearch.isNotEmpty ? idSearch : _searchController.text.trim();
    return FutureBuilder<Map<String, dynamic>>(
      future: makeCloudCall('adminListAuditLogs', {
        'query': query,
        if (_backendAuditActionFilter().isNotEmpty)
          'action': _backendAuditActionFilter(),
        if (_backendAuditTargetFilter().isNotEmpty)
          'target': _backendAuditTargetFilter(),
        'limit': _limit,
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilters(context),
              const SizedBox(height: 8),
              _buildInfoCard(
                context,
                title: 'Ошибка загрузки журнала',
                message: 'Не удалось открыть журнал: ${snapshot.error}',
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilters(context),
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        }
        final rawLogs = snapshot.data?['logs'];
        final logs = rawLogs is List
            ? rawLogs
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilters(context),
                  const SizedBox(height: 8),
                  _buildInfoCard(
                    context,
                    title: 'Журнал действий',
                    message:
                        'Показано: ${logs.length}. Источник: backend auditLogs, свежие сверху.',
                  ),
                ],
              );
            }
            if (logs.isEmpty) {
              return _buildInfoCard(
                context,
                title: 'Нет данных',
                message: 'По текущим фильтрам записей нет.',
              );
            }
            return _buildBackendAuditLogCard(context, log: logs[index - 1]);
          },
        );
      },
    );
  }

  Widget _buildBackendAuditLogCard(
    BuildContext context, {
    required Map<String, dynamic> log,
  }) {
    final action = (log['action'] ?? '').toString();
    final target = (log['target'] ?? '').toString();
    final adminPhone = (log['adminPhone'] ?? '').toString();
    final createdAt = _asDateTime(log['createdAt'] ?? log['created_at']);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _mtaxiSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _mtaxiAdminBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.manage_history_outlined, color: _mtaxiMint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.isEmpty ? 'Действие администратора' : action,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.readexPro(
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                ),
                const SizedBox(height: 6),
                if (createdAt != null)
                  Text(
                    _formatDateTime(context, createdAt),
                    style: FlutterFlowTheme.of(context).labelSmall,
                  ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (target.isNotEmpty) 'Цель: $target',
                    if (adminPhone.isNotEmpty) 'Админ: $adminPhone',
                  ].join('\n'),
                  style: FlutterFlowTheme.of(context).labelMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _compactJsonPreview({
                    if (log['extra'] != null) 'extra': log['extra'],
                    if (log['after'] != null) 'after': log['after'],
                  }),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: FlutterFlowTheme.of(context).labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _compactJsonPreview(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return 'Без дополнительных данных';
    }
    final text = jsonEncode(data);
    return text.length > 320 ? '${text.substring(0, 320)}...' : text;
  }

  Future<void> _openBackendCityTariffEditor(
    BuildContext context, {
    Map<String, dynamic>? data,
  }) async {
    final schema = _schemaForEditor('City', data: data ?? {}) ?? [];
    final controllers = <String, TextEditingController>{
      for (final spec in schema)
        spec.key:
            TextEditingController(text: (data?[spec.key] ?? '').toString())
    };
    String? errorText;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title:
                  Text(data == null ? 'Добавить тариф' : 'Редактировать тариф'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final spec in schema) ...[
                        TextField(
                          controller: controllers[spec.key],
                          decoration: InputDecoration(
                            labelText: spec.label,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          keyboardType: spec.type == _FieldType.string
                              ? TextInputType.text
                              : TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (errorText != null)
                        Text(
                          errorText!,
                          style: TextStyle(
                            color: FlutterFlowTheme.of(context).error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() {
                            isSaving = true;
                            errorText = null;
                          });
                          try {
                            final title =
                                controllers['title']?.text.trim() ?? '';
                            if (title.isEmpty) {
                              throw Exception('Укажите поселок');
                            }
                            double parsePrice(String key, String label) {
                              final text = controllers[key]?.text.trim() ?? '';
                              final value = double.tryParse(
                                text.replaceAll(',', '.'),
                              );
                              if (value == null) {
                                throw Exception(
                                    'Поле "$label" должно быть числом');
                              }
                              return value;
                            }

                            final response =
                                await makeCloudCall('adminUpsertCityTariff', {
                              'id': data?['id'],
                              'title': title,
                              'priceDay':
                                  parsePrice('priceDay', 'Дневная цена'),
                              'priceNight':
                                  parsePrice('priceNight', 'Ночная цена'),
                              'deliveryPrice':
                                  parsePrice('deliveryPrice', 'Цена доставки'),
                            });
                            if (response['success'] != true) {
                              throw Exception(response['error']?.toString() ??
                                  'Не удалось сохранить');
                            }
                            if (mounted) {
                              Navigator.pop(context);
                              safeSetState(() {});
                            }
                          } catch (e) {
                            setModalState(() {
                              errorText =
                                  'Ошибка сохранения: ${_humanizeAdminError(e)}';
                              isSaving = false;
                            });
                          }
                        },
                  child: Text(isSaving ? 'Сохраняем...' : 'Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  String _routeStringValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  Widget _buildBackendIntercityRouteCard(
    BuildContext context, {
    required Map<String, dynamic> route,
  }) {
    final from = _routeStringValue(route, ['ot', 'from', 'otkuda', 'fromCity']);
    final to = _routeStringValue(route, ['kuda', 'to', 'kudaCity', 'toCity']);
    final title = [
      from.isEmpty ? 'Откуда не указано' : from,
      to.isEmpty ? 'Куда не указано' : to,
    ].join(' → ');

    return _buildSingletonSettingsCard(
      context,
      title: title,
      data: route,
      onEdit: () => _openBackendIntercityRouteEditor(
        context,
        data: route,
      ),
    );
  }

  Widget _buildBackendIntercityRoutesBody(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: makeCloudCall('adminListIntercityRoutes', {
        'query': _intercityPointFilterController.text.trim().isNotEmpty
            ? _intercityPointFilterController.text.trim()
            : _searchController.text.trim(),
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilters(context),
              const SizedBox(height: 8),
              _buildInfoCard(
                context,
                title: 'Ошибка загрузки маршрутов',
                message: 'Не удалось открыть маршруты: ${snapshot.error}',
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilters(context),
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        }
        final rawRoutes = snapshot.data?['routes'];
        final routes = rawRoutes is List
            ? rawRoutes
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: routes.length + 2,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilters(context),
                  const SizedBox(height: 8),
                  _buildInfoCard(
                    context,
                    title: 'Маршруты межгород',
                    message:
                        'Показано: ${routes.length}. Источник: backend intercityRoutes.',
                  ),
                ],
              );
            }
            if (routes.isEmpty && index == 1) {
              return _buildInfoCard(
                context,
                title: 'Нет маршрутов',
                message: 'В backend пока нет маршрутов межгорода.',
              );
            }
            if (index == routes.length + 1) {
              return const SizedBox(height: 72);
            }
            return _buildBackendIntercityRouteCard(
              context,
              route: routes[index - 1],
            );
          },
        );
      },
    );
  }

  Future<void> _openBackendIntercityRouteEditor(
    BuildContext context, {
    Map<String, dynamic>? data,
  }) async {
    final schema = _schemaForEditor('routerCityToCity', data: data ?? {}) ?? [];
    final controllers = <String, TextEditingController>{
      for (final spec in schema)
        spec.key:
            TextEditingController(text: (data?[spec.key] ?? '').toString())
    };
    String? errorText;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(
                  data == null ? 'Добавить маршрут' : 'Редактировать маршрут'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final spec in schema) ...[
                        TextField(
                          controller: controllers[spec.key],
                          decoration: InputDecoration(
                            labelText: spec.label,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          keyboardType: spec.type == _FieldType.string
                              ? TextInputType.text
                              : TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (errorText != null)
                        Text(
                          errorText!,
                          style: TextStyle(
                            color: FlutterFlowTheme.of(context).error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() {
                            isSaving = true;
                            errorText = null;
                          });
                          try {
                            final from = controllers['ot']?.text.trim() ?? '';
                            final to = controllers['kuda']?.text.trim() ?? '';
                            if (from.isEmpty || to.isEmpty) {
                              throw Exception('Укажите откуда и куда');
                            }
                            double parseNumber(String key, String label) {
                              final text = controllers[key]?.text.trim() ?? '';
                              final value =
                                  double.tryParse(text.replaceAll(',', '.'));
                              if (value == null) {
                                throw Exception(
                                    'Поле "$label" должно быть числом');
                              }
                              return value;
                            }

                            final response = await makeCloudCall(
                                'adminUpsertIntercityRoute', {
                              'id': data?['id'],
                              'ot': from,
                              'kuda': to,
                              'tarif': parseNumber('tarif', 'Цена'),
                              'com': parseNumber('com', 'Комиссия'),
                            });
                            if (response['success'] != true) {
                              throw Exception(response['error']?.toString() ??
                                  'Не удалось сохранить');
                            }
                            if (mounted) {
                              Navigator.pop(context);
                              safeSetState(() {});
                            }
                          } catch (e) {
                            setModalState(() {
                              errorText =
                                  'Ошибка сохранения: ${_humanizeAdminError(e)}';
                              isSaving = false;
                            });
                          }
                        },
                  child: Text(isSaving ? 'Сохраняем...' : 'Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  Widget _buildIntercityRoutesBody(BuildContext context) {
    return _buildBackendIntercityRoutesBody(context);
  }

  Widget _buildBackendUnsupportedCollectionBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFilters(context),
        const SizedBox(height: 8),
        _buildInfoCard(
          context,
          title: 'Раздел не подключен',
          message:
              'Коллекция ${_resolvedCollectionName()} еще не перенесена на backend. '
              'Данные доступны только через backend.',
        ),
      ],
    );
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  bool _isRecentRegistration(Map<String, dynamic> data) {
    final createdAt = _asDateTime(data['created_time']);
    if (createdAt == null) {
      return false;
    }
    return DateTime.now().difference(createdAt) <= _recentRegistrationWindow;
  }

  bool _isPendingDriver(Map<String, dynamic> data) {
    final registrationDraft = data['registrationDraft'] == true;
    final profileCompleted = data['profileCompleted'] == true;
    final isDriver = (data['isDriver'] as bool?) == true ||
        (data['role'] ?? '').toString().trim().toLowerCase() == 'driver';
    final status = (data['statusDriver'] ?? '').toString().trim().toLowerCase();
    final driverRegistrationStatus = (data['driverRegistrationStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return isDriver &&
        !registrationDraft &&
        profileCompleted &&
        (status == 'pending' || driverRegistrationStatus == 'pending_review');
  }

  String _formatDateTime(BuildContext context, DateTime? value) {
    if (value == null) {
      return '';
    }
    return dateTimeFormat(
      'd.MM.yyyy HH:mm',
      value,
      locale: FFLocalizations.of(context).languageCode,
    );
  }

  int _orderStatusFromData(Map<String, dynamic> data) {
    final raw = data['status'];
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _orderStatusLabel(int status) {
    switch (status) {
      case 0:
        return 'Ожидание водителя';
      case 1:
        return 'Заказ принят';
      case 2:
        return 'Водитель в пути';
      case 3:
        return 'Водитель приехал';
      case 4:
        return 'Вы в пути';
      case _completedOrderStatus:
        return 'Выполнен';
      case _cancelledOrderStatus:
        return 'Отменен';
      default:
        return 'Статус $status';
    }
  }

  Color _orderStatusColor(int status) {
    switch (status) {
      case _completedOrderStatus:
        return Colors.green;
      case _cancelledOrderStatus:
        return Colors.red;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.indigo;
      default:
        return FlutterFlowTheme.of(context).primary;
    }
  }

  IconData _orderStatusIcon(int status) {
    switch (status) {
      case _completedOrderStatus:
        return Icons.check_circle_outline;
      case _cancelledOrderStatus:
        return Icons.cancel_outlined;
      case 3:
        return Icons.place_outlined;
      case 4:
        return Icons.route_outlined;
      default:
        return Icons.local_taxi_outlined;
    }
  }

  String _orderTypeLabel(String rawType) {
    switch (rawType.trim().toLowerCase()) {
      case 'delivery':
        return 'Доставка';
      case 'intercity':
        return 'Межгород';
      default:
        return 'Такси';
    }
  }

  String _formatOrderPrice(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return 'Не указана';
    }
    return formatAppCurrency(parsed);
  }

  Future<UsersRecord?> _getUserByRef(DocumentReference? ref) {
    if (ref == null) {
      return Future.value(null);
    }
    return _userLookupCache.putIfAbsent(ref.path, () async {
      final userId = ref.path.split('/').where((part) => part.isNotEmpty).last;
      if (userId.isEmpty) {
        return null;
      }
      try {
        final response = await makeCloudCall('adminListUsers', {
          'query': userId,
          'limit': 10,
        });
        final users = response['users'];
        if (users is! List) {
          return null;
        }
        for (final item in users.whereType<Map>()) {
          final data =
              _normalizeBackendUserData(Map<String, dynamic>.from(item));
          final path =
              (data['userDocPath'] ?? 'users/${data['id']}').toString().trim();
          if (path != ref.path && (data['id'] ?? '').toString() != userId) {
            continue;
          }
          return UsersRecord.getDocumentFromData(data, ref);
        }
      } catch (e) {
        debugPrint('Backend user lookup failed for ${ref.path}: $e');
      }
      return null;
    });
  }

  String _formatUserLabel(
    UsersRecord? user,
    DocumentReference? ref, {
    String? fallbackPhone,
    required String emptyLabel,
  }) {
    final userData = user?.snapshotData ?? const <String, dynamic>{};
    final name =
        buildAdminUserName(userData, fallback: user?.displayName ?? '');
    final phone = normalizeAdminText(user?.phoneNumber ?? fallbackPhone ?? '');
    if (name.isNotEmpty && phone.isNotEmpty) {
      return '$name • $phone';
    }
    if (name.isNotEmpty) {
      return name;
    }
    if (phone.isNotEmpty) {
      return phone;
    }
    if (ref != null) {
      return ref.id;
    }
    return emptyLabel;
  }

  Widget _buildDetailLine(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final labelStyle = FlutterFlowTheme.of(context).bodySmall.override(
          font: GoogleFonts.readexPro(
            fontWeight: FontWeight.w700,
            fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
          ),
          letterSpacing: 0.0,
          fontWeight: FontWeight.w700,
          fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
        );
    final valueStyle = FlutterFlowTheme.of(context).bodySmall.override(
          font: GoogleFonts.readexPro(
            fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
            fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
          ),
          letterSpacing: 0.0,
          fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
          fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
        );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$label: ', style: labelStyle),
            TextSpan(text: value, style: valueStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(
    BuildContext context,
    DocumentReference reference,
    Map<String, dynamic> data,
  ) {
    final status = _orderStatusFromData(data);
    final statusColor = _orderStatusColor(status);
    final typeLabel = _orderTypeLabel((data['type'] ?? '').toString());
    final city = (data['city'] ?? '').toString().trim();
    final from = (data['ot'] ?? '').toString().trim();
    final to = (data['kuda'] ?? '').toString().trim();
    final comment = (data['comment'] ?? '').toString().trim();
    final when = _asDateTime(data['date']);
    final acceptedAt = _asDateTime(data['dateAccept']);
    final cancelledAt = _asDateTime(data['cancelledAt']);
    final cancelledBy = (data['cancelledBy'] ?? '').toString().trim();
    final cancelStage = (data['cancelStage'] ?? '').toString().trim();
    final adminAction = (data['adminAction'] ?? '').toString().trim();
    final adminActionAt = _asDateTime(data['adminActionAt']);
    final refundRaw = data['adminActionRefundAmount'];
    final adminActionRefundAmount = refundRaw is num
        ? refundRaw.toDouble()
        : double.tryParse(refundRaw?.toString() ?? '') ?? 0;
    final isNight = data['isNight'] == true;
    final userRef = data['idUser'] as DocumentReference?;
    final driverRef = data['idDriver'] as DocumentReference?;
    final driverPhone = (data['driverPhone'] ?? '').toString().trim();
    final canReopen = _canAdminReopenOrder(status, driverRef);
    final canCancel = _canAdminCancelOrder(status);
    final canComplete = _canAdminCompleteOrder(status, driverRef);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatusChip(
              context,
              label: _orderStatusLabel(status),
              color: statusColor,
              icon: _orderStatusIcon(status),
            ),
            _buildStatusChip(
              context,
              label: typeLabel,
              color: _mtaxiMint,
              icon: Icons.category_outlined,
            ),
            if (city.isNotEmpty)
              _buildStatusChip(
                context,
                label: city,
                color: Colors.teal,
                icon: Icons.location_city_outlined,
              ),
            _buildStatusChip(
              context,
              label: 'Цена: ${_formatOrderPrice(data['price'])}',
              color: Colors.blueGrey,
              icon: isNight ? Icons.nightlight_round : Icons.payments_outlined,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildDetailLine(
          context,
          label: 'Когда',
          value: when != null ? _formatDateTime(context, when) : 'Не указано',
        ),
        if (acceptedAt != null)
          _buildDetailLine(
            context,
            label: 'Водитель взял',
            value: _formatDateTime(context, acceptedAt),
          ),
        _buildDetailLine(
          context,
          label: 'Откуда',
          value: from.isNotEmpty ? from : 'Не указано',
        ),
        _buildDetailLine(
          context,
          label: 'Куда',
          value: to.isNotEmpty ? to : 'Не указано',
        ),
        FutureBuilder<List<UsersRecord?>>(
          future: Future.wait<UsersRecord?>([
            _getUserByRef(userRef),
            _getUserByRef(driverRef),
          ]),
          builder: (context, snapshot) {
            final passenger = snapshot.hasData && snapshot.data!.isNotEmpty
                ? snapshot.data![0]
                : null;
            final driver = snapshot.hasData && snapshot.data!.length > 1
                ? snapshot.data![1]
                : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailLine(
                  context,
                  label: 'Пассажир',
                  value: _formatUserLabel(
                    passenger,
                    userRef,
                    emptyLabel: 'Не указан',
                  ),
                ),
                _buildDetailLine(
                  context,
                  label: 'Водитель',
                  value: _formatUserLabel(
                    driver,
                    driverRef,
                    fallbackPhone: driverPhone,
                    emptyLabel: 'Не назначен',
                  ),
                ),
              ],
            );
          },
        ),
        if (comment.isNotEmpty)
          _buildDetailLine(
            context,
            label: 'Комментарий',
            value: comment,
          ),
        if (status == _cancelledOrderStatus && cancelledBy.isNotEmpty)
          _buildDetailLine(
            context,
            label: 'Кто отменил',
            value: _cancelledByLabel(cancelledBy),
          ),
        if (status == _cancelledOrderStatus && cancelStage.isNotEmpty)
          _buildDetailLine(
            context,
            label: 'Этап отмены',
            value: _cancelStageLabel(cancelStage),
          ),
        if (status == _cancelledOrderStatus && cancelledAt != null)
          _buildDetailLine(
            context,
            label: 'Отменен',
            value: _formatDateTime(context, cancelledAt),
          ),
        if (adminAction.isNotEmpty)
          _buildDetailLine(
            context,
            label: 'Последнее действие админа',
            value: adminActionAt != null
                ? '${_adminOrderActionLabel(adminAction)} • ${_formatDateTime(context, adminActionAt)}'
                : _adminOrderActionLabel(adminAction),
          ),
        if (adminActionRefundAmount > 0)
          _buildDetailLine(
            context,
            label: 'Возврат комиссии',
            value: _formatOrderPrice(adminActionRefundAmount),
          ),
        if (canReopen || canCancel || canComplete)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canComplete)
                  _buildAdminOrderActionButton(
                    context,
                    orderRef: reference,
                    action: 'complete',
                    label: 'Завершить',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                if (canReopen)
                  _buildAdminOrderActionButton(
                    context,
                    orderRef: reference,
                    action: 'reopen',
                    label: 'В очередь',
                    icon: Icons.refresh,
                    color: Colors.orange,
                  ),
                if (canCancel)
                  _buildAdminOrderActionButton(
                    context,
                    orderRef: reference,
                    action: 'cancel',
                    label: 'Отменить',
                    icon: Icons.cancel_outlined,
                    color: Colors.red,
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _buildAdminOrderStatusControls(
            context,
            orderRef: reference,
            currentStatus: status,
          ),
        ),
      ],
    );
  }

  DateTime? _userOrderHistoryDate(Map<String, dynamic> data) {
    return _asDateTime(data['date']) ??
        _asDateTime(data['dateAccept']) ??
        _asDateTime(data['cancelledAt']) ??
        _asDateTime(data['createdAt']) ??
        _asDateTime(data['updatedAt']) ??
        _asDateTime(data['created_at']) ??
        _asDateTime(data['created_time']);
  }

  String _userOrderRoleLabel(_UserOrderHistoryEntry entry) {
    if (entry.asPassenger && entry.asDriver) {
      return 'Пассажир и водитель';
    }
    if (entry.asDriver) {
      return 'Водитель';
    }
    return 'Пассажир';
  }

  Color _userOrderRoleColor(_UserOrderHistoryEntry entry) {
    if (entry.asPassenger && entry.asDriver) {
      return Colors.deepPurple;
    }
    return entry.asDriver ? Colors.indigo : Colors.teal;
  }

  String _userDocumentLabel(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) {
    final name = buildAdminUserName(data);
    final phone = normalizeAdminText(
      data['phone_number'] ?? data['phoneNumber'],
    );
    if (name.isNotEmpty && phone.isNotEmpty) {
      return '$name • $phone';
    }
    if (name.isNotEmpty) {
      return name;
    }
    if (phone.isNotEmpty) {
      return phone;
    }
    return reference.id;
  }

  String _cancelledByLabel(dynamic value) {
    final normalized = (value ?? '').toString().trim().toLowerCase();
    switch (normalized) {
      case 'passenger':
        return 'Пассажир';
      case 'driver':
        return 'Водитель';
      case 'admin':
        return 'Админ';
      case 'system':
        return 'Система';
      default:
        return normalized.isNotEmpty ? normalized : 'Не указано';
    }
  }

  String _cancelStageLabel(dynamic value) {
    final normalized = (value ?? '').toString().trim().toLowerCase();
    switch (normalized) {
      case 'before_arrival':
        return 'До приезда водителя';
      case 'after_arrival':
        return 'После приезда водителя';
      case 'on_trip':
        return 'Во время поездки';
      default:
        return normalized.isNotEmpty ? normalized : 'Не указано';
    }
  }

  String _adminOrderActionLabel(String action) {
    if (action.startsWith('setStatus:')) {
      final status = int.tryParse(action.split(':').last);
      if (status != null) {
        return 'Статус: ${_orderStatusLabel(status)}';
      }
    }
    switch (action.trim().toLowerCase()) {
      case 'reopen':
        return 'Возврат в очередь';
      case 'cancel':
        return 'Отмена админом';
      case 'complete':
        return 'Завершение админом';
      default:
        return action;
    }
  }

  bool _canAdminReopenOrder(int status, DocumentReference? driverRef) {
    if (status == _completedOrderStatus) {
      return false;
    }
    return status != 0 || driverRef != null;
  }

  bool _canAdminCancelOrder(int status) {
    return status >= 0 &&
        status < _completedOrderStatus &&
        status != _cancelledOrderStatus;
  }

  bool _canAdminCompleteOrder(int status, DocumentReference? driverRef) {
    return driverRef != null && status > 0 && status < _completedOrderStatus;
  }

  Future<bool> _confirmAdminOrderAction(
    BuildContext context, {
    required String action,
  }) async {
    final isReopen = action == 'reopen';
    final isComplete = action == 'complete';
    final targetStatus = action.startsWith('setStatus:')
        ? int.tryParse(action.split(':').last)
        : null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          targetStatus != null
              ? 'Поставить статус "${_orderStatusLabel(targetStatus)}"?'
              : isReopen
                  ? 'Вернуть заказ в очередь?'
                  : isComplete
                      ? 'Завершить заказ?'
                      : 'Отменить заказ?',
        ),
        content: Text(
          targetStatus != null
              ? 'Админ принудительно изменит статус заказа. Система синхронизирует активный заказ у пассажира и водителя.'
              : isReopen
                  ? 'Заказ снова станет доступен водителям. Если комиссия уже списана, система вернет ее текущему водителю один раз.'
                  : isComplete
                      ? 'Заказ будет закрыт как выполненный, активные ссылки у водителя и пассажира очистятся.'
                      : 'Заказ будет отменен от имени админа. Если комиссия уже списана, система вернет ее текущему водителю один раз.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Нет'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              targetStatus != null
                  ? 'Поставить'
                  : isReopen
                      ? 'Вернуть'
                      : isComplete
                          ? 'Завершить'
                          : 'Отменить',
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _runAdminOrderAction(
    BuildContext context, {
    required DocumentReference orderRef,
    required String action,
  }) async {
    final orderPath = orderRef.path;
    if (_orderActionsInProgress.contains(orderPath)) {
      return;
    }

    final confirmed = await _confirmAdminOrderAction(
      context,
      action: action,
    );
    if (!confirmed) {
      return;
    }

    setState(() {
      _orderActionsInProgress.add(orderPath);
    });

    try {
      final targetStatus = action.startsWith('setStatus:')
          ? int.tryParse(action.split(':').last)
          : null;
      final response = await makeCloudCall('adminManageOrder', {
        'orderDocPath': orderPath,
        'action': targetStatus == null ? action : 'setStatus',
        if (targetStatus != null) 'targetStatus': targetStatus,
      });
      final success = response['success'] == true;
      final message = (success
              ? response['message']
              : response['error'] ?? 'Не удалось обработать заказ')
          .toString();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _orderActionsInProgress.remove(orderPath);
        });
      } else {
        _orderActionsInProgress.remove(orderPath);
      }
    }
  }

  Widget _buildAdminOrderActionButton(
    BuildContext context, {
    required DocumentReference orderRef,
    required String action,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isBusy = _orderActionsInProgress.contains(orderRef.path);
    return OutlinedButton.icon(
      onPressed: isBusy
          ? null
          : () => _runAdminOrderAction(
                context,
                orderRef: orderRef,
                action: action,
              ),
      icon: isBusy
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
    );
  }

  Widget _buildAdminOrderStatusControls(
    BuildContext context, {
    required DocumentReference orderRef,
    required int currentStatus,
  }) {
    final statuses = const [0, 1, 2, 3, 4, 5, 6];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Поставить статус',
          style: FlutterFlowTheme.of(context).labelMedium.override(
                font: GoogleFonts.readexPro(
                  fontWeight: FontWeight.w700,
                  fontStyle: FlutterFlowTheme.of(context).labelMedium.fontStyle,
                ),
                letterSpacing: 0.0,
                fontWeight: FontWeight.w700,
                fontStyle: FlutterFlowTheme.of(context).labelMedium.fontStyle,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: statuses
              .map(
                (status) => _buildAdminOrderActionButton(
                  context,
                  orderRef: orderRef,
                  action: 'setStatus:$status',
                  label: status == currentStatus
                      ? '${_orderStatusLabel(status)} • сейчас'
                      : _orderStatusLabel(status),
                  icon: _orderStatusIcon(status),
                  color: status == currentStatus
                      ? Colors.grey
                      : _orderStatusColor(status),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Future<List<_UserOrderHistoryEntry>> _loadUserOrderHistory(
    DocumentReference userRef,
  ) async {
    final results = await Future.wait([
      makeCloudCall('adminListOrders', {
        'userDocPath': userRef.path,
        'limit': 500,
      }),
      makeCloudCall('adminListOrders', {
        'driverDocPath': userRef.path,
        'limit': 500,
      }),
    ]);
    final merged = <String, _UserOrderHistoryEntry>{};

    for (final order in _backendOrders(results[0])) {
      final doc = _backendOrderHistoryDoc(order);
      merged[doc.id] = _UserOrderHistoryEntry(
        doc: doc,
        asPassenger: true,
        asDriver: merged[doc.id]?.asDriver ?? false,
      );
    }

    for (final order in _backendOrders(results[1])) {
      final doc = _backendOrderHistoryDoc(order);
      merged[doc.id] = _UserOrderHistoryEntry(
        doc: doc,
        asPassenger: merged[doc.id]?.asPassenger ?? false,
        asDriver: true,
      );
    }

    final items = merged.values.toList();
    items.sort(_compareUserOrderHistoryEntries);
    return items;
  }

  List<Map<String, dynamic>> _backendOrders(Map<String, dynamic> response) {
    return (response['orders'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  _BackendOrderHistoryDoc _backendOrderHistoryDoc(Map<String, dynamic> order) {
    final orderPath =
        (order['orderDocPath'] ?? 'order/${order['id']}').toString().trim();
    final passengerId = (order['passengerId'] ?? '').toString().trim();
    final driverId = (order['driverId'] ?? '').toString().trim();
    final data = <String, dynamic>{
      ...order,
      'idUser': passengerId.isNotEmpty
          ? BackendRefs.instance.doc('users/$passengerId')
          : null,
      'idDriver': driverId.isNotEmpty
          ? BackendRefs.instance.doc('users/$driverId')
          : null,
    };
    return _BackendOrderHistoryDoc(
      id: orderPath.split('/').last,
      reference: BackendRefs.instance.doc(orderPath),
      data: data,
    );
  }

  int _compareUserOrderHistoryEntries(
    _UserOrderHistoryEntry a,
    _UserOrderHistoryEntry b,
  ) {
    final aDate = _userOrderHistoryDate(a.doc.data());
    final bDate = _userOrderHistoryDate(b.doc.data());
    final aMs = aDate?.millisecondsSinceEpoch ?? 0;
    final bMs = bDate?.millisecondsSinceEpoch ?? 0;
    final cmp = bMs.compareTo(aMs);
    if (cmp != 0) {
      return cmp;
    }
    return b.doc.id.toString().compareTo(a.doc.id.toString());
  }

  List<_AdminSelectOption> _adminUserOptionsFromResponse(
    Map<String, dynamic>? response,
  ) {
    final rawUsers = response?['users'];
    if (rawUsers is! List) {
      return const <_AdminSelectOption>[];
    }
    return rawUsers
        .whereType<Map>()
        .map((item) {
          final data = Map<String, dynamic>.from(item);
          final id = (data['id'] ?? data['uid'] ?? '').toString().trim();
          final path =
              (data['userDocPath'] ?? (id.isNotEmpty ? 'users/$id' : ''))
                  .toString()
                  .trim();
          final name = buildDisplayNameFromData(data);
          final phone =
              normalizeDisplayText(data['phone'] ?? data['phone_number']);
          final label = [
            if (name.isNotEmpty) name else 'Без имени',
            if (phone.isNotEmpty) phone,
          ].join(' • ');
          return _AdminSelectOption(
            path: path,
            label: label,
            name: name,
            phone: phone,
          );
        })
        .where((option) => option.path.isNotEmpty)
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }

  List<String> _cityOptionsFromResponse(Map<String, dynamic>? response) {
    final rawTariffs = response?['tariffs'];
    if (rawTariffs is! List) {
      return const <String>[];
    }
    final cities = rawTariffs
        .whereType<Map>()
        .map((item) => normalizeAdminText(
              item['city'] ?? item['title'] ?? item['name'],
            ))
        .where((city) => city.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return cities;
  }

  Future<void> _saveOrderDocument(
    DocumentReference? reference,
    Map<String, dynamic> converted,
  ) async {
    if (reference != null) {
      if (converted.containsKey('status')) {
        final response = await makeCloudCall('adminManageOrder', {
          'orderDocPath': reference.path,
          'action': 'setStatus:${converted['status']}',
        });
        if (response['success'] == true) {
          return;
        }
        final error = (response['error'] ?? '').toString().trim();
        throw Exception(
            error.isNotEmpty ? error : 'Не удалось изменить статус заказа');
      }
      throw Exception(
        'В backend-режиме редактирование заказа доступно через кнопки статуса',
      );
    }

    final payload = converted.map(
      (key, value) => MapEntry(key, _encodeCallableValue(value)),
    );
    final idUser = converted['idUser'];
    if (idUser is DocumentReference) {
      payload['userDocPath'] = idUser.path;
    }
    final response = await makeCloudCall('adminCreateOrder', payload);
    if (response['success'] == true) {
      return;
    }
    final error = (response['error'] ?? '').toString().trim();
    throw Exception(error.isNotEmpty ? error : 'Не удалось создать заказ');
  }

  _UserOrderHistoryStats _buildUserOrderHistoryStats(
    List<_UserOrderHistoryEntry> items,
  ) {
    var completed = 0;
    var cancelled = 0;
    var asPassenger = 0;
    var asDriver = 0;
    var passengerCancelled = 0;
    var beforeArrivalCancelled = 0;
    DateTime? latestCancelledAt;

    for (final entry in items) {
      final data = entry.doc.data();
      final status = _orderStatusFromData(data);
      if (entry.asPassenger) {
        asPassenger++;
      }
      if (entry.asDriver) {
        asDriver++;
      }
      if (status == _completedOrderStatus) {
        completed++;
      }
      if (status == _cancelledOrderStatus) {
        cancelled++;
        final cancelledAt = _asDateTime(data['cancelledAt']);
        if (cancelledAt != null &&
            (latestCancelledAt == null ||
                cancelledAt.isAfter(latestCancelledAt))) {
          latestCancelledAt = cancelledAt;
        }
        final cancelledBy =
            (data['cancelledBy'] ?? '').toString().trim().toLowerCase();
        if (entry.asPassenger && cancelledBy == 'passenger') {
          passengerCancelled++;
        }
        final cancelStage =
            (data['cancelStage'] ?? '').toString().trim().toLowerCase();
        if (cancelStage == 'before_arrival') {
          beforeArrivalCancelled++;
        }
      }
    }

    return _UserOrderHistoryStats(
      total: items.length,
      completed: completed,
      cancelled: cancelled,
      asPassenger: asPassenger,
      asDriver: asDriver,
      passengerCancelled: passengerCancelled,
      beforeArrivalCancelled: beforeArrivalCancelled,
      latestCancelledAt: latestCancelledAt,
    );
  }

  Widget _buildUserOrderHistoryItem(
    BuildContext context,
    _UserOrderHistoryEntry entry,
  ) {
    final data = entry.doc.data();
    final status = _orderStatusFromData(data);
    final statusColor = _orderStatusColor(status);
    final roleColor = _userOrderRoleColor(entry);
    final typeLabel = _orderTypeLabel((data['type'] ?? '').toString());
    final when = _userOrderHistoryDate(data);
    final city = (data['city'] ?? '').toString().trim();
    final from = (data['ot'] ?? '').toString().trim();
    final to = (data['kuda'] ?? '').toString().trim();
    final comment = (data['comment'] ?? '').toString().trim();
    final cancelledBy = (data['cancelledBy'] ?? '').toString().trim();
    final cancelStage = (data['cancelStage'] ?? '').toString().trim();
    final commissionRefunded = data['commissionRefunded'] == true;
    final driverRef = data['idDriver'] as DocumentReference?;
    final counterpartRef = entry.asDriver && !entry.asPassenger
        ? data['idUser'] as DocumentReference?
        : driverRef;
    final counterpartLabel =
        entry.asDriver && !entry.asPassenger ? 'Пассажир' : 'Водитель';
    final fallbackPhone = entry.asDriver && !entry.asPassenger
        ? (data['customerPhone'] ?? '').toString().trim()
        : (data['driverPhone'] ?? '').toString().trim();
    final canReopen = _canAdminReopenOrder(status, driverRef);
    final canCancel = _canAdminCancelOrder(status);
    final canComplete = _canAdminCompleteOrder(status, driverRef);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _mtaxiAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(
                context,
                label: _userOrderRoleLabel(entry),
                color: roleColor,
                icon: entry.asDriver && !entry.asPassenger
                    ? Icons.drive_eta_outlined
                    : Icons.person_outline,
              ),
              _buildStatusChip(
                context,
                label: _orderStatusLabel(status),
                color: statusColor,
                icon: _orderStatusIcon(status),
              ),
              _buildStatusChip(
                context,
                label: typeLabel,
                color: _mtaxiMint,
                icon: Icons.category_outlined,
              ),
              _buildStatusChip(
                context,
                label: _formatOrderPrice(data['price']),
                color: Colors.blueGrey,
                icon: Icons.payments_outlined,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDetailLine(
            context,
            label: 'Когда',
            value: when != null ? _formatDateTime(context, when) : 'Не указано',
          ),
          _buildDetailLine(
            context,
            label: 'Откуда',
            value: from.isNotEmpty ? from : 'Не указано',
          ),
          _buildDetailLine(
            context,
            label: 'Куда',
            value: to.isNotEmpty ? to : 'Не указано',
          ),
          if (city.isNotEmpty)
            _buildDetailLine(
              context,
              label: 'Поселок',
              value: city,
            ),
          FutureBuilder<UsersRecord?>(
            future: _getUserByRef(counterpartRef),
            builder: (context, snapshot) {
              return _buildDetailLine(
                context,
                label: counterpartLabel,
                value: _formatUserLabel(
                  snapshot.data,
                  counterpartRef,
                  fallbackPhone: fallbackPhone,
                  emptyLabel: entry.asDriver && !entry.asPassenger
                      ? 'Не указан'
                      : 'Не назначен',
                ),
              );
            },
          ),
          if (comment.isNotEmpty)
            _buildDetailLine(
              context,
              label: 'Комментарий',
              value: comment,
            ),
          if (status == _cancelledOrderStatus && cancelledBy.isNotEmpty)
            _buildDetailLine(
              context,
              label: 'Кто отменил',
              value: _cancelledByLabel(cancelledBy),
            ),
          if (status == _cancelledOrderStatus && cancelStage.isNotEmpty)
            _buildDetailLine(
              context,
              label: 'Этап отмены',
              value: _cancelStageLabel(cancelStage),
            ),
          if (status == _cancelledOrderStatus)
            _buildDetailLine(
              context,
              label: 'Комиссия',
              value: commissionRefunded
                  ? 'Водителю возвращена'
                  : 'Возврата не было',
            ),
          if (canReopen || canCancel || canComplete)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canComplete)
                    _buildAdminOrderActionButton(
                      context,
                      orderRef: entry.doc.reference,
                      action: 'complete',
                      label: 'Завершить',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                  if (canReopen)
                    _buildAdminOrderActionButton(
                      context,
                      orderRef: entry.doc.reference,
                      action: 'reopen',
                      label: 'В очередь',
                      icon: Icons.refresh,
                      color: Colors.orange,
                    ),
                  if (canCancel)
                    _buildAdminOrderActionButton(
                      context,
                      orderRef: entry.doc.reference,
                      action: 'cancel',
                      label: 'Отменить',
                      icon: Icons.cancel_outlined,
                      color: Colors.red,
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildAdminOrderStatusControls(
              context,
              orderRef: entry.doc.reference,
              currentStatus: status,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Future<void> _showUserOrderHistory(
    BuildContext context, {
    required DocumentReference reference,
    required Map<String, dynamic> data,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final historyFuture = _loadUserOrderHistory(reference);
        final userLabel = _userDocumentLabel(data, reference);

        return SafeArea(
          child: Container(
            height: MediaQuery.sizeOf(sheetContext).height * 0.92,
            decoration: BoxDecoration(
              color: _mtaxiPageBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Заказы и управление',
                              style: FlutterFlowTheme.of(sheetContext)
                                  .headlineSmall
                                  .override(
                                    font: GoogleFonts.readexPro(
                                      fontWeight: FontWeight.w600,
                                      fontStyle:
                                          FlutterFlowTheme.of(sheetContext)
                                              .headlineSmall
                                              .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(sheetContext)
                                        .headlineSmall
                                        .fontStyle,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userLabel,
                              style:
                                  FlutterFlowTheme.of(sheetContext).bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: FutureBuilder<List<_UserOrderHistoryEntry>>(
                      future: historyFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return _buildInfoCard(
                            context,
                            title: 'Ошибка загрузки',
                            message:
                                'Не удалось загрузить историю заказов: ${snapshot.error}',
                          );
                        }

                        final items = snapshot.data ?? const [];
                        if (items.isEmpty) {
                          return _buildInfoCard(
                            context,
                            title: 'Нет поездок',
                            message:
                                'По этому пользователю пока нет заказов в основной коллекции.',
                          );
                        }

                        final stats = _buildUserOrderHistoryStats(items);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildStatusChip(
                                  context,
                                  label: 'Всего: ${stats.total}',
                                  color: _mtaxiMint,
                                  icon: Icons.list_alt_outlined,
                                ),
                                _buildStatusChip(
                                  context,
                                  label: 'Выполнено: ${stats.completed}',
                                  color: Colors.green,
                                  icon: Icons.check_circle_outline,
                                ),
                                _buildStatusChip(
                                  context,
                                  label: 'Отменено: ${stats.cancelled}',
                                  color: Colors.red,
                                  icon: Icons.cancel_outlined,
                                ),
                                _buildStatusChip(
                                  context,
                                  label:
                                      'Сам отменил: ${stats.passengerCancelled}',
                                  color: Colors.deepOrange,
                                  icon: Icons.warning_amber_outlined,
                                ),
                                _buildStatusChip(
                                  context,
                                  label:
                                      'До приезда: ${stats.beforeArrivalCancelled}',
                                  color: Colors.orange,
                                  icon: Icons.timer_off_outlined,
                                ),
                                _buildStatusChip(
                                  context,
                                  label: 'Как пассажир: ${stats.asPassenger}',
                                  color: Colors.teal,
                                  icon: Icons.person_outline,
                                ),
                                _buildStatusChip(
                                  context,
                                  label: 'Как водитель: ${stats.asDriver}',
                                  color: Colors.indigo,
                                  icon: Icons.drive_eta_outlined,
                                ),
                              ],
                            ),
                            if (stats.latestCancelledAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _buildDetailLine(
                                  context,
                                  label: 'Последняя отмена',
                                  value: _formatDateTime(
                                    context,
                                    stats.latestCancelledAt,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) =>
                                    _buildUserOrderHistoryItem(
                                  context,
                                  items[index],
                                ),
                              ),
                            ),
                          ],
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
  }

  Widget _buildStatusChip(
    BuildContext context, {
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: FlutterFlowTheme.of(context).labelSmall.override(
                  font: GoogleFonts.readexPro(
                    fontWeight: FontWeight.w700,
                    fontStyle:
                        FlutterFlowTheme.of(context).labelSmall.fontStyle,
                  ),
                  color: color,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w700,
                  fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
                ),
          ),
        ],
      ),
    );
  }

  String _normalizeSearchText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  String _searchableValue(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is DocumentReference) {
      return value.path;
    }
    if (value is Iterable) {
      return value.map(_searchableValue).join(' ');
    }
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key} ${_searchableValue(entry.value)}')
          .join(' ');
    }
    return value.toString();
  }

  Future<void> _copyText(BuildContext context, String value) async {
    if (value.trim().isEmpty) return;
    var copied = false;
    try {
      await Clipboard.setData(ClipboardData(text: value));
      copied = true;
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          copied ? 'Ссылка скопирована' : 'Не удалось скопировать ссылку',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showImagePreview(
    BuildContext context, {
    required String title,
    required String url,
    String? ownerId,
  }) async {
    final imageUrls = _imageUrlCandidates(url, ownerId: ownerId);
    final openUrl = imageUrls.isNotEmpty ? imageUrls.first : url.trim();
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _AdminImageWithFallback(
                      urls: imageUrls,
                      fit: BoxFit.cover,
                      errorChild: Container(
                        color: _mtaxiSurface2,
                        alignment: Alignment.center,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Не удалось загрузить изображение'),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  openUrl,
                  style: FlutterFlowTheme.of(context).bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await launchURL(openUrl);
              },
              child: const Text('Открыть ссылку'),
            ),
            TextButton(
              onPressed: () async {
                await _copyText(context, openUrl);
              },
              child: const Text('Копировать ссылку'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageThumb(
    BuildContext context, {
    required String label,
    required String url,
    String? ownerId,
  }) {
    final imageUrls = _imageUrlCandidates(url, ownerId: ownerId);
    return InkWell(
      onTap: () => _showImagePreview(
        context,
        title: label,
        url: url,
        ownerId: ownerId,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 72,
              height: 72,
              color: _mtaxiSurface2,
              child: _AdminImageWithFallback(
                urls: imageUrls,
                fit: BoxFit.cover,
                errorChild: const Icon(
                  Icons.broken_image_outlined,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FlutterFlowTheme.of(context).labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  static const Map<String, String> _collectionLabels = {
    'users': 'Пользователи',
    'politika': 'Политика и условия',
    'CityToCityDriver': 'Водители межгород',
    'City': 'Поселки и тарифы',
    'payments': 'Платежи',
    'withdrawals': 'Заявки на вывод',
    'auditLogs': 'Журнал действий',
    'supportContacts': 'Контакты службы поддержки',
    'about': 'Служба поддержки',
    'tariffsContent': 'Тарифы (тексты)',
    'orderDriverAdmin': 'Заказы водителя (админ)',
    'cityToCity': 'Межгород (заказы)',
    'routerCityToCity': 'Маршруты межгород',
    'routercitytocity': 'Маршруты межгород',
    'RouterCityToCity': 'Маршруты межгород',
    'intercityTariff': 'Тариф межгород (км)',
    'appSettings': 'Настройки (runtime/комиссия/доставка)',
    'order': 'Заказы',
    'gruz': 'Доставка (заказы)',
    'GruzDriver': 'Водители доставки',
    'bid': 'Предложения цены',
    'chats': 'Чаты',
    'chat_messages': 'Сообщения',
  };

  static const Map<String, List<_FieldSpec>> _schemas = {
    'users': [
      _FieldSpec(key: 'email', label: 'Email', type: _FieldType.string),
      _FieldSpec(key: 'firstName', label: 'Имя', type: _FieldType.string),
      _FieldSpec(key: 'lastName', label: 'Фамилия', type: _FieldType.string),
      _FieldSpec(
          key: 'photo_url',
          label: 'Основное фото (URL)',
          type: _FieldType.string),
      _FieldSpec(key: 'uid', label: 'UID', type: _FieldType.string),
      _FieldSpec(
          key: 'created_time', label: 'Создан', type: _FieldType.dateTime),
      _FieldSpec(
          key: 'registrationDraft',
          label: 'Черновик регистрации',
          type: _FieldType.boolType,
          readOnly: true),
      _FieldSpec(
          key: 'profileCompleted',
          label: 'Профиль завершен',
          type: _FieldType.boolType,
          readOnly: true),
      _FieldSpec(
          key: 'phone_number', label: 'Телефон', type: _FieldType.string),
      _FieldSpec(key: 'status', label: 'Статус', type: _FieldType.intType),
      _FieldSpec(key: 'iin', label: 'ИИН', type: _FieldType.intType),
      _FieldSpec(
          key: 'dataRoj', label: 'Дата рождения', type: _FieldType.dateTime),
      _FieldSpec(key: 'password', label: 'Пароль', type: _FieldType.string),
      _FieldSpec(
          key: 'avtoImage', label: 'Фото авто (URL)', type: _FieldType.string),
      _FieldSpec(
          key: 'vehiclePhotoDeleteRequestStatus',
          label: 'Статус запроса удаления фото авто',
          type: _FieldType.string,
          readOnly: true),
      _FieldSpec(
          key: 'techImage',
          label: 'Фото техпаспорта (URL)',
          type: _FieldType.string),
      _FieldSpec(key: 'Marka', label: 'Марка', type: _FieldType.string),
      _FieldSpec(key: 'model', label: 'Модель', type: _FieldType.string),
      _FieldSpec(key: 'yersSet', label: 'Год', type: _FieldType.dateTime),
      _FieldSpec(key: 'proverka', label: 'Проверен', type: _FieldType.boolType),
      _FieldSpec(key: 'bonus', label: 'Бонус', type: _FieldType.doubleType),
      _FieldSpec(key: 'balance', label: 'Баланс', type: _FieldType.doubleType),
      _FieldSpec(key: 'ref', label: 'Рефкод', type: _FieldType.string),
      _FieldSpec(
          key: 'colsRef', label: 'Кол-во реф.', type: _FieldType.intType),
      _FieldSpec(key: 'isDriver', label: 'Водитель', type: _FieldType.boolType),
      _FieldSpec(key: 'city', label: 'Поселок', type: _FieldType.string),
      _FieldSpec(
          key: 'coords',
          label: 'Координаты',
          type: _FieldType.geo,
          helper: 'lat,lng'),
      _FieldSpec(key: 'gosNomer', label: 'Госномер', type: _FieldType.string),
      _FieldSpec(key: 'color', label: 'Цвет', type: _FieldType.string),
      _FieldSpec(
          key: 'role', label: 'Роль', type: _FieldType.string, readOnly: true),
      _FieldSpec(
          key: 'statusDriver',
          label: 'Статус водителя',
          type: _FieldType.string),
      _FieldSpec(
          key: 'driverRegistrationStatus',
          label: 'Статус регистрации водителя',
          type: _FieldType.string,
          readOnly: true),
      _FieldSpec(
          key: 'blocked', label: 'Заблокирован', type: _FieldType.boolType),
      _FieldSpec(
          key: 'vip', label: 'VIP (без комиссии)', type: _FieldType.boolType),
      _FieldSpec(
          key: 'orderDelaySeconds',
          label: 'Задержка заказа (сек)',
          type: _FieldType.intType,
          helper: 'От 0 до 10. Для VIP всегда используется 0.'),
      _FieldSpec(
          key: 'passengerAcceptedCancelDayKey',
          label: 'День счётчика отмен пассажира',
          type: _FieldType.string,
          helper:
              'YYYY-MM-DD. Для сброса можно очистить или поставить сегодня.'),
      _FieldSpec(
          key: 'passengerAcceptedCancelCount',
          label: 'Отмены принятых заказов сегодня',
          type: _FieldType.intType,
          helper:
              'После превышения лимита из appSettings блокируется только оформление нового заказа.'),
      _FieldSpec(
          key: 'passengerAcceptedCancelLastAt',
          label: 'Последняя отмена принятого заказа',
          type: _FieldType.dateTime),
    ],
    'politika': [
      _FieldSpec(key: 'text', label: 'Текст', type: _FieldType.string),
    ],
    'about': [
      _FieldSpec(key: 'title', label: 'Текст', type: _FieldType.string),
    ],
    'supportContacts': [
      _FieldSpec(
          key: 'whatsAppPhone',
          label: 'WhatsApp номер',
          type: _FieldType.string,
          helper: 'Например: +77001234567'),
      _FieldSpec(
          key: 'callPhone',
          label: 'Телефон для звонков',
          type: _FieldType.string,
          helper: 'Например: +77001234567'),
    ],
    'tariffsContent': [
      _FieldSpec(
        key: 'driverTariffs',
        label: 'Тарифы для водителей',
        type: _FieldType.string,
        helper: 'Многострочный текст. Будет показан в разделе Тарифы.',
      ),
      _FieldSpec(
        key: 'passengerTariffs',
        label: 'Тарифы для пассажиров',
        type: _FieldType.string,
        helper: 'Многострочный текст. Будет показан в разделе Тарифы.',
      ),
    ],
    'City': [
      _FieldSpec(key: 'title', label: 'Поселок', type: _FieldType.string),
      _FieldSpec(
          key: 'priceDay', label: 'Дневная цена', type: _FieldType.doubleType),
      _FieldSpec(
          key: 'priceNight', label: 'Ночная цена', type: _FieldType.doubleType),
      _FieldSpec(
          key: 'deliveryPrice',
          label: 'Цена доставки',
          type: _FieldType.doubleType),
    ],
    'order': [
      _FieldSpec(
          key: 'idUser',
          label: 'Пассажир',
          type: _FieldType.reference,
          required: true),
      _FieldSpec(
          key: 'type',
          label: 'Тип заказа',
          type: _FieldType.string,
          required: true),
      _FieldSpec(
          key: 'city',
          label: 'Поселок',
          type: _FieldType.string,
          required: true),
      _FieldSpec(
          key: 'ot', label: 'Откуда', type: _FieldType.string, required: true),
      _FieldSpec(
          key: 'kuda', label: 'Куда', type: _FieldType.string, required: true),
      _FieldSpec(
          key: 'price',
          label: 'Цена',
          type: _FieldType.doubleType,
          required: true),
      _FieldSpec(key: 'comment', label: 'Комментарий', type: _FieldType.string),
      _FieldSpec(key: 'status', label: 'Статус', type: _FieldType.intType),
      _FieldSpec(
          key: 'isNight', label: 'Ночной тариф', type: _FieldType.boolType),
    ],
    'cityToCity': [
      _FieldSpec(key: 'otkuda', label: 'Откуда', type: _FieldType.string),
      _FieldSpec(key: 'kuda', label: 'Куда', type: _FieldType.string),
      _FieldSpec(key: 'price', label: 'Цена', type: _FieldType.doubleType),
      _FieldSpec(key: 'mesta', label: 'Места', type: _FieldType.intType),
      _FieldSpec(key: 'date', label: 'Дата', type: _FieldType.dateTime),
      _FieldSpec(
          key: 'idUser', label: 'Пассажир (ref)', type: _FieldType.reference),
      _FieldSpec(
          key: 'idDriver', label: 'Водитель (ref)', type: _FieldType.reference),
      _FieldSpec(key: 'dateCreate', label: 'Создан', type: _FieldType.dateTime),
      _FieldSpec(key: 'status', label: 'Статус', type: _FieldType.boolType),
    ],
    'CityToCityDriver': [
      _FieldSpec(key: 'otkuda', label: 'Откуда', type: _FieldType.string),
      _FieldSpec(key: 'kuda', label: 'Куда', type: _FieldType.string),
      _FieldSpec(key: 'price', label: 'Цена', type: _FieldType.doubleType),
      _FieldSpec(key: 'mesta', label: 'Места', type: _FieldType.intType),
      _FieldSpec(key: 'date', label: 'Дата', type: _FieldType.dateTime),
      _FieldSpec(
          key: 'idUser', label: 'Пассажир (ref)', type: _FieldType.reference),
      _FieldSpec(
          key: 'idDriver', label: 'Водитель (ref)', type: _FieldType.reference),
      _FieldSpec(key: 'dateCreate', label: 'Создан', type: _FieldType.dateTime),
      _FieldSpec(key: 'status', label: 'Статус', type: _FieldType.boolType),
      _FieldSpec(key: 'post', label: 'Опубликован', type: _FieldType.boolType),
      _FieldSpec(
          key: 'passenger', label: 'Пассажир', type: _FieldType.boolType),
    ],
    'routerCityToCity': [
      _FieldSpec(key: 'ot', label: 'Откуда', type: _FieldType.string),
      _FieldSpec(key: 'kuda', label: 'Куда', type: _FieldType.string),
      _FieldSpec(key: 'tarif', label: 'Цена', type: _FieldType.doubleType),
      _FieldSpec(key: 'com', label: 'Комиссия', type: _FieldType.doubleType),
    ],
    'routercitytocity': [
      _FieldSpec(key: 'ot', label: 'Откуда', type: _FieldType.string),
      _FieldSpec(key: 'kuda', label: 'Куда', type: _FieldType.string),
      _FieldSpec(key: 'tarif', label: 'Цена', type: _FieldType.doubleType),
      _FieldSpec(key: 'com', label: 'Комиссия', type: _FieldType.doubleType),
    ],
    'RouterCityToCity': [
      _FieldSpec(key: 'ot', label: 'Откуда', type: _FieldType.string),
      _FieldSpec(key: 'kuda', label: 'Куда', type: _FieldType.string),
      _FieldSpec(key: 'tarif', label: 'Цена', type: _FieldType.doubleType),
      _FieldSpec(key: 'com', label: 'Комиссия', type: _FieldType.doubleType),
    ],
    'intercityTariff': [
      _FieldSpec(
          key: 'pricePerKm', label: 'Цена за км', type: _FieldType.doubleType),
      _FieldSpec(
          key: 'minPrice',
          label: 'Минимальная цена',
          type: _FieldType.doubleType),
    ],
    'appSettings': [
      _FieldSpec(
          key: 'orderCommissionPercent',
          label: 'Комиссия (%)',
          type: _FieldType.doubleType),
    ],
    'orderDriverAdmin': [
      _FieldSpec(
          key: 'idDriver', label: 'Водитель (ref)', type: _FieldType.reference),
      _FieldSpec(key: 'status', label: 'Статус', type: _FieldType.intType),
      _FieldSpec(key: 'Text', label: 'Текст', type: _FieldType.string),
    ],
    'payments': [
      _FieldSpec(key: 'amount', label: 'Сумма', type: _FieldType.doubleType),
      _FieldSpec(key: 'created_at', label: 'Создан', type: _FieldType.dateTime),
      _FieldSpec(key: 'paid_at', label: 'Оплачен', type: _FieldType.dateTime),
      _FieldSpec(
          key: 'payment_id', label: 'Payment ID', type: _FieldType.string),
      _FieldSpec(key: 'status', label: 'Статус', type: _FieldType.string),
      _FieldSpec(key: 'user_id', label: 'User ID', type: _FieldType.string),
    ],
    'gruz': [
      _FieldSpec(key: 'otkuda', label: 'Откуда', type: _FieldType.string),
      _FieldSpec(key: 'kuda', label: 'Куда', type: _FieldType.string),
      _FieldSpec(key: 'price', label: 'Цена', type: _FieldType.doubleType),
      _FieldSpec(key: 'mesta', label: 'Места', type: _FieldType.intType),
      _FieldSpec(key: 'date', label: 'Дата', type: _FieldType.dateTime),
      _FieldSpec(
          key: 'idUser', label: 'Пассажир (ref)', type: _FieldType.reference),
      _FieldSpec(
          key: 'idDriver', label: 'Водитель (ref)', type: _FieldType.reference),
      _FieldSpec(key: 'dateCreate', label: 'Создан', type: _FieldType.dateTime),
      _FieldSpec(key: 'status', label: 'Статус', type: _FieldType.boolType),
    ],
    'GruzDriver': [
      _FieldSpec(key: 'otkuda', label: 'Откуда', type: _FieldType.string),
      _FieldSpec(key: 'kuda', label: 'Куда', type: _FieldType.string),
      _FieldSpec(key: 'price', label: 'Цена', type: _FieldType.doubleType),
      _FieldSpec(key: 'mesta', label: 'Места', type: _FieldType.intType),
      _FieldSpec(key: 'date', label: 'Дата', type: _FieldType.dateTime),
      _FieldSpec(
          key: 'idUser', label: 'Пассажир (ref)', type: _FieldType.reference),
      _FieldSpec(
          key: 'idDriver', label: 'Водитель (ref)', type: _FieldType.reference),
      _FieldSpec(key: 'dateCreate', label: 'Создан', type: _FieldType.dateTime),
      _FieldSpec(key: 'status', label: 'Статус', type: _FieldType.boolType),
      _FieldSpec(key: 'post', label: 'Опубликован', type: _FieldType.boolType),
      _FieldSpec(
          key: 'passenger', label: 'Пассажир', type: _FieldType.boolType),
    ],
    'bid': [
      _FieldSpec(
          key: 'idUser', label: 'Пассажир (ref)', type: _FieldType.reference),
      _FieldSpec(
          key: 'idDriver', label: 'Водитель (ref)', type: _FieldType.reference),
      _FieldSpec(key: 'price', label: 'Цена', type: _FieldType.doubleType),
      _FieldSpec(key: 'status', label: 'Статус', type: _FieldType.intType),
      _FieldSpec(
          key: 'order', label: 'Order (ref)', type: _FieldType.reference),
      _FieldSpec(key: 'created_at', label: 'Создан', type: _FieldType.dateTime),
    ],
    'chats': [
      _FieldSpec(key: 'users', label: 'Users (JSON)', type: _FieldType.json),
      _FieldSpec(
          key: 'last_message', label: 'Последнее', type: _FieldType.string),
      _FieldSpec(
          key: 'last_message_time', label: 'Время', type: _FieldType.dateTime),
    ],
    'chat_messages': [
      _FieldSpec(key: 'chat', label: 'Чат (ref)', type: _FieldType.reference),
      _FieldSpec(key: 'user', label: 'User (ref)', type: _FieldType.reference),
      _FieldSpec(key: 'text', label: 'Текст', type: _FieldType.string),
      _FieldSpec(key: 'created_at', label: 'Создан', type: _FieldType.dateTime),
    ],
  };

  @override
  void dispose() {
    _searchController.dispose();
    _idSearchController.dispose();
    _filterFieldController.dispose();
    _filterValueController.dispose();
    _intercityPointFilterController.dispose();
    _sortFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = isAdminUser(currentUserDocument);
    final hasCollection = widget.collectionName.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: _mtaxiAdminBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Назад',
          color: _mtaxiAdminText,
          onPressed: () => context.goNamed(AdminHomeWidget.routeName),
        ),
        title: Text(
          _collectionLabels[widget.collectionName] ?? widget.collectionName,
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                font: GoogleFonts.readexPro(
                  fontWeight: FontWeight.w600,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
                letterSpacing: 0.0,
                color: _mtaxiAdminText,
                fontWeight: FontWeight.w600,
                fontStyle:
                    FlutterFlowTheme.of(context).headlineMedium.fontStyle,
              ),
        ),
      ),
      floatingActionButton: isAdmin &&
              (_isBackendContentCollection ||
                  _isCityCollection ||
                  _isIntercityRouteCollection ||
                  _isBackendGenericCollection) &&
              !_isUsersCollection &&
              !_isOrderCollection &&
              !_isPaymentsCollection &&
              !_isWithdrawalsCollection &&
              !_isAuditLogsCollection
          ? FloatingActionButton.extended(
              onPressed: () => _isPolitikaCollection
                  ? _openBackendContentEditor(
                      context,
                      data: const <String, dynamic>{},
                    )
                  : _isCityCollection
                      ? _openBackendCityTariffEditor(context)
                      : _isIntercityRouteCollection
                          ? _openBackendIntercityRouteEditor(context)
                          : _isBackendGenericCollection
                              ? _openBackendGenericEditor(context)
                              : _isBackendContentCollection
                                  ? _openBackendContentEditor(
                                      context,
                                      data: const <String, dynamic>{},
                                    )
                                  : _openEditor(context),
              label: Text(_isPolitikaCollection ? 'Редактировать' : 'Добавить'),
              icon: const Icon(Icons.add),
              backgroundColor: _mtaxiMint,
              foregroundColor: _mtaxiPageBg,
            )
          : null,
      body: SafeArea(
        child: isAdmin && hasCollection
            ? _isBackendContentCollection
                ? _buildBackendContentBody(context)
                : _isAppSettingsCollection
                    ? _buildAppSettingsBody(context)
                    : _isUsersCollection
                        ? _buildBackendUsersBody(context)
                        : _isOrderCollection
                            ? _buildBackendOrdersBody(context)
                            : _isPaymentsCollection
                                ? _buildBackendPaymentsBody(context)
                                : _isWithdrawalsCollection
                                    ? _buildBackendWithdrawalsBody(context)
                                    : _isAuditLogsCollection
                                        ? _buildBackendAuditLogsBody(context)
                                        : _isCityCollection
                                            ? _buildBackendCityTariffsBody(
                                                context)
                                            : _isIntercityRouteCollection
                                                ? _buildIntercityRoutesBody(
                                                    context)
                                                : _isBackendGenericCollection
                                                    ? _buildBackendGenericCollectionBody(
                                                        context)
                                                    : _buildBackendUnsupportedCollectionBody(
                                                        context)
            : _buildAccessDenied(context, hasCollection: hasCollection),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final hasActiveFilters = _searchController.text.isNotEmpty ||
        _idSearchController.text.isNotEmpty ||
        _hasLocalFilters;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _mtaxiSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _mtaxiAdminBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Фильтры',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.readexPro(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  color: _mtaxiAdminText,
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _idSearchController,
            decoration: InputDecoration(
              labelText: 'Быстрый поиск по ID (точное совпадение)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (_) => _resetPagination(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Поиск (ID или текст)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (_) => _onLocalFilterChanged(),
          ),
          if (_isUsersCollection) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _userRoleFilter,
              decoration: InputDecoration(
                labelText: 'Статус пользователя',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Все')),
                DropdownMenuItem(value: 'drivers', child: Text('Водители')),
                DropdownMenuItem(value: 'passengers', child: Text('Пассажиры')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _userRoleFilter = value);
                _resetPagination();
              },
            ),
          ],
          if (_isIntercityRouteCollection) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _intercityPointFilterController,
              decoration: InputDecoration(
                labelText: 'Отбор по населенному пункту',
                helperText: 'Ищет сразу в Откуда и Куда',
                prefixIcon: const Icon(Icons.travel_explore_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (_) => _onLocalFilterChanged(),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _filterFieldController,
                  decoration: InputDecoration(
                    labelText: 'Поле фильтра',
                    helperText: _isIntercityRouteCollection
                        ? 'Для маршрутов можно писать: откуда, куда, поселок, цена'
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (_) => _onLocalFilterChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _filterValueController,
                  decoration: InputDecoration(
                    labelText: 'Значение',
                    helperText: _isIntercityRouteCollection
                        ? 'Для текста ищет по вхождению, не только точно'
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (_) => _onLocalFilterChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sortFieldController,
                  decoration: InputDecoration(
                    labelText: 'Сортировка по полю',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (_) => _onLocalFilterChanged(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<int>(
                  initialValue: _limit,
                  decoration: InputDecoration(
                    labelText: 'Лимит',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [100, 200, 500, 1000]
                      .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _limit = value);
                    _resetPagination();
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Сортировка по убыванию'),
                  value: _sortDescending,
                  onChanged: (v) =>
                      setState(() => _sortDescending = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
          Text(
            _isUsersCollection
                ? 'Поиск понимает имя, телефон, ID и цифры без пробелов.'
                : 'Общий поиск и фильтр по полю применяются по загруженным документам.',
            style: FlutterFlowTheme.of(context).labelSmall,
          ),
          if (hasActiveFilters)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FFButtonWidget(
                onPressed: () {
                  _searchController.clear();
                  _idSearchController.clear();
                  _filterFieldController.clear();
                  _filterValueController.clear();
                  _intercityPointFilterController.clear();
                  _sortFieldController.clear();
                  _userRoleFilter = 'all';
                  _sortDescending = false;
                  _resetPagination();
                  setState(() {});
                },
                text: 'Сбросить фильтры',
                options: FFButtonOptions(
                  height: 36,
                  color: _mtaxiSurface2,
                  textStyle: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.readexPro(
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodySmall.fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                  elevation: 0,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ignore: unused_element
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final searchText = _normalizeSearchText(_searchController.text.trim());
    final searchDigits = _digitsOnly(_searchController.text.trim());
    final filterField =
        _normalizeFilterField(_filterFieldController.text.trim());
    final filterValueRaw = _filterValueController.text.trim();
    final intercityPointFilter =
        _normalizeSearchText(_intercityPointFilterController.text.trim());
    final sortField = _sortFieldController.text.trim();
    final parsedFilterValue =
        filterField.isNotEmpty && filterValueRaw.isNotEmpty
            ? _parseFilterValue(filterValueRaw)
            : null;

    final filtered = docs.where((doc) {
      final data = doc.data();

      if (!_matchesUserRoleFilter(data)) {
        return false;
      }

      if (_isIntercityRouteCollection && intercityPointFilter.isNotEmpty) {
        final pointValues = [
          _routeStringValue(data, ['ot', 'from', 'otkuda', 'fromCity']),
          _routeStringValue(data, ['kuda', 'to', 'kudaCity', 'toCity']),
        ];
        final matchesPoint = pointValues.any(
          (value) => _normalizeSearchText(value).contains(intercityPointFilter),
        );
        if (!matchesPoint) {
          return false;
        }
      }

      if (filterField.isNotEmpty && filterValueRaw.isNotEmpty) {
        if (_isIntercityRouteCollection && filterField == '*route*') {
          final routeFields = [
            'ot',
            'from',
            'otkuda',
            'fromCity',
            'kuda',
            'to',
            'kudaCity',
            'toCity',
          ];
          final expectedStr = filterValueRaw.toLowerCase();
          final matched = routeFields.any((key) =>
              (data[key] ?? '').toString().toLowerCase().contains(expectedStr));
          if (!matched) return false;
        } else {
          final actualFieldKey = _resolveActualFieldKey(data, filterField);
          if (actualFieldKey == null) return false;
          final actual = data[actualFieldKey];
          final actualStr = (actual ?? '').toString().toLowerCase();
          final expectedStr =
              (parsedFilterValue ?? '').toString().toLowerCase();
          final matches = actual is String || parsedFilterValue is String
              ? actualStr.contains(expectedStr)
              : actual == parsedFilterValue || actualStr == expectedStr;
          if (!matches) return false;
        }
      }

      if (searchText.isEmpty) {
        return true;
      }

      final buffer = StringBuffer()..write(doc.id);
      data.forEach((key, value) {
        buffer.write(' $key ${_searchableValue(value)}');
      });
      final rawHaystack = buffer.toString();
      final haystack = _normalizeSearchText(rawHaystack);
      if (haystack.contains(searchText)) {
        return true;
      }
      if (searchDigits.isNotEmpty &&
          _digitsOnly(rawHaystack).contains(searchDigits)) {
        return true;
      }
      return false;
    }).toList();

    int compareDynamic(dynamic a, dynamic b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      if (a is num && b is num) return a.compareTo(b);
      if (a is bool && b is bool) return a == b ? 0 : (a ? 1 : -1);
      if (a is Timestamp && b is Timestamp) return a.compareTo(b);
      if (a is DateTime && b is DateTime) return a.compareTo(b);
      return a.toString().toLowerCase().compareTo(b.toString().toLowerCase());
    }

    if (sortField.isNotEmpty) {
      filtered.sort((a, b) {
        final actualSortFieldA = _resolveActualFieldKey(a.data(), sortField);
        final actualSortFieldB = _resolveActualFieldKey(b.data(), sortField);
        final cmp = compareDynamic(
          actualSortFieldA == null ? null : a.data()[actualSortFieldA],
          actualSortFieldB == null ? null : b.data()[actualSortFieldB],
        );
        if (cmp != 0) return _sortDescending ? -cmp : cmp;
        final idCmp = a.id.compareTo(b.id);
        return _sortDescending ? -idCmp : idCmp;
      });
    } else if (_isOrderCollection) {
      filtered.sort((a, b) {
        final cmp = compareDynamic(
          _asDateTime(b.data()['date']),
          _asDateTime(a.data()['date']),
        );
        if (cmp != 0) {
          return cmp;
        }
        return a.id.compareTo(b.id);
      });
    } else if (_isUsersCollection) {
      filtered.sort((a, b) {
        final aPending = _isPendingDriver(a.data());
        final bPending = _isPendingDriver(b.data());
        if (aPending != bPending) {
          return aPending ? -1 : 1;
        }
        final cmp = compareDynamic(
          _asDateTime(b.data()['created_time']),
          _asDateTime(a.data()['created_time']),
        );
        if (cmp != 0) {
          return cmp;
        }
        return a.id.compareTo(b.id);
      });
    }

    if (_isPolitikaCollection && filtered.isNotEmpty) {
      final canonicalDoc = filtered.where((doc) => doc.id == 'main').toList();
      return canonicalDoc.isNotEmpty
          ? <QueryDocumentSnapshot<Map<String, dynamic>>>[canonicalDoc.first]
          : <QueryDocumentSnapshot<Map<String, dynamic>>>[filtered.first];
    }

    return filtered;
  }

  // ignore: unused_element
  Query<Map<String, dynamic>> _buildQuery() {
    throw StateError('Backend-only query fallback is disabled');
  }

  String _resolvedCollectionName() {
    if (widget.collectionName == 'RouterCityToCity') {
      return 'routerCityToCity';
    }
    if (widget.collectionName == 'routercitytocity') {
      return _forceCamelRouterCity ? 'routerCityToCity' : 'routercitytocity';
    }
    if (widget.collectionName == 'routerCityToCity' && _useLegacyRouterCity) {
      return 'routercitytocity';
    }
    return widget.collectionName;
  }

  dynamic _parseFilterValue(String input) {
    final lower = input.toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
    final numValue = num.tryParse(input.replaceAll(',', '.'));
    if (numValue != null) return numValue;
    return input;
  }

  String _normalizeFilterField(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return raw;
    }
    final normalized = raw.toLowerCase();
    final schema = _schemas[widget.collectionName] ?? const <_FieldSpec>[];
    for (final spec in schema) {
      if (spec.key.toLowerCase() == normalized ||
          spec.label.toLowerCase() == normalized) {
        return spec.key;
      }
    }
    if (_isIntercityRouteCollection) {
      switch (normalized) {
        case 'откуда':
        case 'from':
          return 'ot';
        case 'куда':
        case 'to':
          return 'kuda';
        case 'поселок':
        case 'маршрут':
        case 'route':
          return '*route*';
        case 'цена':
        case 'тариф':
          return 'tarif';
      }
    }
    return raw;
  }

  String? _resolveActualFieldKey(
    Map<String, dynamic> data,
    String filterField,
  ) {
    if (data.containsKey(filterField)) {
      return filterField;
    }
    final normalized = filterField.toLowerCase();
    for (final key in data.keys) {
      if (key.toLowerCase() == normalized) {
        return key;
      }
    }
    return null;
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _mtaxiSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _mtaxiAdminBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.readexPro(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: FlutterFlowTheme.of(context).bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMore(BuildContext context) {
    final idSearch = _idSearchController.text.trim();
    if (idSearch.isNotEmpty || _hasLocalFilters) {
      return const SizedBox.shrink();
    }
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FFButtonWidget(
            onPressed: _pageIndex <= 0 ? null : _loadPrevPage,
            text: 'Назад',
            options: FFButtonOptions(
              width: 120,
              height: 40,
              color: _mtaxiSurface2,
              textStyle: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.readexPro(
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
              elevation: 0,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          FFButtonWidget(
            onPressed: _hasNext ? _loadNextPage : null,
            text: 'Вперед',
            options: FFButtonOptions(
              width: 120,
              height: 40,
              color: _mtaxiSurface2,
              textStyle: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.readexPro(
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
              elevation: 0,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }

  void _resetPagination() {
    setState(() {
      _clearPaginationCursor();
    });
  }

  void _clearPaginationCursor() {
    _pageIndex = 0;
    _pageStarts.clear();
    _nextPageStartAfterDoc = null;
    _hasNext = false;
  }

  void _loadNextPage() {
    if (_nextPageStartAfterDoc == null) {
      return;
    }
    setState(() {
      _pageIndex += 1;
    });
  }

  void _loadPrevPage() {
    if (_pageIndex <= 0) {
      return;
    }
    setState(() {
      _pageIndex -= 1;
      _nextPageStartAfterDoc = null;
    });
  }

  // ignore: unused_element
  void _syncPageStart(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      _hasNext = false;
      return;
    }
    if (_pageStarts.length <= _pageIndex) {
      _pageStarts.add(docs.first);
    } else {
      _pageStarts[_pageIndex] = docs.first;
    }
    _nextPageStartAfterDoc = docs.last;
    _hasNext = docs.length >= _limit;
  }

  // ignore: unused_element
  Future<void> _showBlocked(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (alertDialogContext) {
        return AlertDialog(
          title: const Text('Действие запрещено'),
          content: const Text('Этот документ защищен от изменений.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(alertDialogContext),
              child: const Text('Ok'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccessDenied(BuildContext context,
      {required bool hasCollection}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 48),
            const SizedBox(height: 12),
            Text(
              hasCollection
                  ? 'Доступ только для администратора'
                  : 'Коллекция не указана',
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodyLarge.override(
                    font: GoogleFonts.readexPro(
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
                      font: GoogleFonts.readexPro(
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

  String _docSummary(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return 'Пустой документ';
    }

    final compositeName = buildAdminUserName(data);
    if (compositeName.isNotEmpty) {
      final phone = normalizeAdminText(
        data['phone_number'] ?? data['phoneNumber'],
      );
      if (phone.isNotEmpty) {
        return '$compositeName • $phone';
      }
      return compositeName;
    }

    final preferredKeys = [
      'display_name',
      'displayName',
      'phone_number',
      'phoneNumber',
      'phone',
      'name',
      'surname',
      'title',
      'status',
      'statusDriver',
      'city',
      'role',
    ];

    final buffer = StringBuffer();
    for (final key in preferredKeys) {
      if (data.containsKey(key)) {
        final value = _formatSummaryValue(data[key]);
        if (value.isEmpty) {
          continue;
        }
        buffer.write('$key: $value  ');
      }
      if (buffer.length > 80) break;
    }

    if (buffer.isNotEmpty) {
      return buffer.toString().trim();
    }

    final firstKeys = data.keys
        .where(
          (key) => !_isUserImageField(
            _FieldSpec(key: key, label: key, type: _FieldType.string),
          ),
        )
        .where((key) => !_isNoisySummaryKey(key))
        .where((key) => _formatSummaryValue(data[key]).isNotEmpty)
        .take(2)
        .toList();
    if (firstKeys.isNotEmpty) {
      return firstKeys
          .map((k) => '$k: ${_formatSummaryValue(data[k])}')
          .join('  ');
    }
    return 'Документ без краткого описания';
  }

  String _safeDocSummary(Map<String, dynamic> data) {
    try {
      return _docSummary(data);
    } catch (e, st) {
      debugPrint('Admin summary render error: $e\n$st');
      return 'Не удалось собрать краткое описание документа';
    }
  }

  bool _isNoisySummaryKey(String key) {
    if (_backendManagedUserFields.contains(key)) {
      return true;
    }
    final normalized = key.trim();
    return normalized.endsWith('At') ||
        normalized.endsWith('_at') ||
        normalized.endsWith('Ref') ||
        normalized.endsWith('_ref') ||
        normalized.startsWith('active') ||
        normalized.startsWith('last_') ||
        normalized.startsWith('last');
  }

  String _formatSummaryValue(dynamic raw) {
    if (raw == null) {
      return '';
    }
    if (raw is Timestamp) {
      return dateTimeFormat('dd.MM.yyyy HH:mm', raw.toDate());
    }
    if (raw is DateTime) {
      return dateTimeFormat('dd.MM.yyyy HH:mm', raw);
    }
    if (raw is GeoPoint) {
      return '${raw.latitude.toStringAsFixed(4)}, ${raw.longitude.toStringAsFixed(4)}';
    }
    if (raw is DocumentReference) {
      return raw.path;
    }
    if (raw is bool) {
      return raw ? 'да' : 'нет';
    }
    if (raw is num) {
      return raw.toString();
    }
    final value = raw.toString().trim();
    if (value.isEmpty || _isHttpUrl(value)) {
      return '';
    }
    if (value.startsWith('Timestamp(') || value.startsWith('Instance of ')) {
      return '';
    }
    return value;
  }

  String _humanizeAdminError(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return 'Не удалось сохранить данные';
    }
    if (raw.startsWith('Exception:')) {
      final cleaned = raw.replaceFirst('Exception:', '').trim();
      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }
    return raw;
  }

  // ignore: unused_element
  Future<void> _confirmDelete(
    BuildContext context,
    DocumentReference reference,
  ) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (alertDialogContext) {
            return AlertDialog(
              title: const Text('Удалить документ?'),
              content: const Text('Это действие необратимо.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(alertDialogContext, false),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(alertDialogContext, true),
                  child: const Text('Удалить'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldDelete) {
      if (_useBackendOnlyCollections) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Прямое удаление отключено. Используйте backend-действия.'),
          ),
        );
        return;
      }
      throw UnsupportedError(
          'Direct backend bypass delete fallback is disabled');
    }
  }

  Future<void> _openEditor(
    BuildContext context, {
    DocumentReference? reference,
    Map<String, dynamic>? data,
  }) async {
    if (_useBackendOnlyCollections) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Прямое сохранение отключено. Используйте backend-действия.'),
        ),
      );
      return;
    }

    final initialData = data ?? <String, dynamic>{};
    final encoded = _encodeValue(initialData);
    final jsonController = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(encoded),
    );
    final isQuickDriverCreate =
        reference == null && widget.collectionName == 'users';
    final schema = isQuickDriverCreate
        ? _quickDriverCreateSchema
        : _schemaForEditor(widget.collectionName, data: initialData);
    final fieldControllers = <String, TextEditingController>{};
    final fieldBools = <String, bool>{};
    final deletedUserImageKeys = <String>{};
    if (schema != null) {
      for (final spec in schema) {
        final raw = initialData[spec.key];
        if (spec.type == _FieldType.boolType) {
          fieldBools[spec.key] = raw == true;
          continue;
        }
        String valueText = '';
        if (raw != null) {
          if (spec.type == _FieldType.reference && raw is DocumentReference) {
            valueText = raw.path;
          } else if (spec.type == _FieldType.geo && raw is GeoPoint) {
            valueText = '${raw.latitude},${raw.longitude}';
          } else if (spec.type == _FieldType.dateTime && raw is Timestamp) {
            valueText = raw.toDate().toIso8601String();
          } else if (spec.type == _FieldType.dateTime && raw is DateTime) {
            valueText = raw.toIso8601String();
          } else if (spec.type == _FieldType.json) {
            valueText = const JsonEncoder.withIndent('  ').convert(raw);
          } else if (spec.type == _FieldType.string) {
            valueText = normalizeAdminText(raw);
          } else {
            valueText = raw.toString();
          }
        }
        fieldControllers[spec.key] = TextEditingController(text: valueText);
      }
    }

    if (isQuickDriverCreate) {
      fieldControllers['balance']?.text = '0';
      fieldControllers['statusDriver']?.text = 'approved';
    }

    if (widget.collectionName == 'order') {
      fieldControllers.putIfAbsent(
          'type', () => TextEditingController(text: 'taxi'));
      if ((fieldControllers['type']?.text ?? '').isEmpty) {
        fieldControllers['type']!.text = 'taxi';
      }
      fieldControllers.putIfAbsent(
          'status', () => TextEditingController(text: '0'));
      if ((fieldControllers['status']?.text ?? '').isEmpty) {
        fieldControllers['status']!.text = '0';
      }
      fieldBools.putIfAbsent('isNight', () => false);
    }

    String? errorText;
    bool isSaving = false;
    final bool useJsonEditor = schema == null;
    final orderUsersFuture = widget.collectionName == 'order'
        ? makeCloudCall('adminListUsers', {'limit': 500})
        : null;
    final orderUserSearchController = TextEditingController();
    final orderCustomerPhoneController = TextEditingController(
      text: (initialData['customerPhone'] ??
              initialData['customer_phone'] ??
              initialData['phone'] ??
              '')
          .toString(),
    );
    final orderCustomerNameController = TextEditingController(
      text: (initialData['customerName'] ??
              initialData['customer_name'] ??
              initialData['clientName'] ??
              initialData['userName'] ??
              initialData['name'] ??
              initialData['display_name'] ??
              '')
          .toString(),
    );

    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return Padding(
          padding: MediaQuery.viewInsetsOf(context),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isQuickDriverCreate
                          ? 'Быстрая регистрация водителя'
                          : reference == null
                              ? 'Новый документ'
                              : 'Редактирование',
                      style:
                          FlutterFlowTheme.of(context).headlineSmall.override(
                                font: GoogleFonts.readexPro(
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .headlineSmall
                                      .fontStyle,
                                ),
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .headlineSmall
                                    .fontStyle,
                              ),
                    ),
                    const SizedBox(height: 12),
                    if (isQuickDriverCreate) ...[
                      Text(
                        'Заполните только рабочие поля. UID, роль, статус на линии, даты и служебные поля создаются автоматически.',
                        style: FlutterFlowTheme.of(context).bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Режим "Расширенно" скрыт, оставляем только форму.
                    const SizedBox(height: 12),
                    if (!useJsonEditor)
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: schema.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final spec = schema[index];
                            if (spec.type == _FieldType.boolType) {
                              return SwitchListTile(
                                title: Text(spec.label),
                                value: fieldBools[spec.key] ?? false,
                                onChanged: spec.readOnly
                                    ? null
                                    : (value) {
                                        setModalState(() {
                                          fieldBools[spec.key] = value;
                                        });
                                      },
                              );
                            }
                            final controller = fieldControllers[spec.key] ??
                                TextEditingController();
                            fieldControllers[spec.key] = controller;
                            if (spec.type == _FieldType.dateTime) {
                              return TextField(
                                controller: controller,
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: spec.label,
                                  helperText:
                                      spec.helper ?? 'Выберите дату и время',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  suffixIcon: const Icon(Icons.calendar_today),
                                ),
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (date == null) return;
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (time == null) return;
                                  final combined = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  );
                                  setModalState(() {
                                    controller.text =
                                        combined.toIso8601String();
                                  });
                                },
                              );
                            }

                            if (widget.collectionName == 'order' &&
                                spec.type == _FieldType.reference &&
                                spec.key == 'idUser') {
                              return FutureBuilder<Map<String, dynamic>>(
                                future: orderUsersFuture,
                                builder: (context, snapshot) {
                                  final users = _adminUserOptionsFromResponse(
                                      snapshot.data);
                                  final q = orderUserSearchController.text
                                      .trim()
                                      .toLowerCase();
                                  final filtered = users
                                      .where((u) {
                                        if (q.isEmpty) return true;
                                        final hay = '${u.label} ${u.path}'
                                            .toLowerCase();
                                        return hay.contains(q);
                                      })
                                      .take(100)
                                      .toList();
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      TextField(
                                        controller: orderUserSearchController,
                                        decoration: InputDecoration(
                                          labelText:
                                              'Поиск заказчика (имя/телефон)',
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          suffixIcon: orderUserSearchController
                                                  .text.isEmpty
                                              ? null
                                              : IconButton(
                                                  onPressed: () {
                                                    setModalState(() {
                                                      orderUserSearchController
                                                          .clear();
                                                    });
                                                  },
                                                  icon: const Icon(Icons.clear),
                                                ),
                                        ),
                                        onChanged: (_) => setModalState(() {}),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        initialValue: controller.text.isNotEmpty
                                            ? controller.text
                                            : null,
                                        items: [
                                          const DropdownMenuItem<String>(
                                            value: '',
                                            child: Text(
                                                'Не выбран (ввести номер ниже)'),
                                          ),
                                          ...filtered.map(
                                            (u) => DropdownMenuItem<String>(
                                              value: u.path,
                                              child: Text(
                                                u.label,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: spec.readOnly
                                            ? null
                                            : (value) {
                                                setModalState(() {
                                                  controller.text =
                                                      (value ?? '').trim();
                                                  if (controller
                                                      .text.isNotEmpty) {
                                                    final selected = users
                                                        .where((u) =>
                                                            u.path ==
                                                            controller.text)
                                                        .toList();
                                                    if (selected.isNotEmpty &&
                                                        orderCustomerPhoneController
                                                            .text
                                                            .trim()
                                                            .isEmpty) {
                                                      orderCustomerPhoneController
                                                              .text =
                                                          selected.first.phone;
                                                    }
                                                    if (selected.isNotEmpty &&
                                                        orderCustomerNameController
                                                            .text
                                                            .trim()
                                                            .isEmpty) {
                                                      orderCustomerNameController
                                                              .text =
                                                          selected.first.name;
                                                    }
                                                  }
                                                });
                                              },
                                        decoration: InputDecoration(
                                          labelText: spec.label,
                                          helperText:
                                              'Выберите пользователя или оставьте пустым и укажите номер',
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: orderCustomerNameController,
                                        decoration: InputDecoration(
                                          labelText: 'Имя заказчика',
                                          helperText:
                                              'Сохраняется в заказе и показывается водителю',
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller:
                                            orderCustomerPhoneController,
                                        decoration: InputDecoration(
                                          labelText:
                                              'Номер заказчика (если нет в системе)',
                                          helperText:
                                              'Этот номер увидит водитель',
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ],
                                  );
                                },
                              );
                            }

                            if (spec.type == _FieldType.reference &&
                                (spec.key == 'idUser' ||
                                    spec.key == 'idDriver')) {
                              final usersFuture = makeCloudCall(
                                'adminListUsers',
                                {'limit': 500},
                              );
                              return FutureBuilder<Map<String, dynamic>>(
                                future: usersFuture,
                                builder: (context, snapshot) {
                                  final users = _adminUserOptionsFromResponse(
                                      snapshot.data);
                                  final items = users
                                      .map(
                                        (u) => DropdownMenuItem<String>(
                                          value: u.path,
                                          child: Text(u.label),
                                        ),
                                      )
                                      .toList();
                                  return DropdownButtonFormField<String>(
                                    initialValue: controller.text.isNotEmpty
                                        ? controller.text
                                        : null,
                                    items: items,
                                    onChanged: spec.readOnly
                                        ? null
                                        : (value) {
                                            setModalState(() {
                                              controller.text = value ?? '';
                                            });
                                          },
                                    decoration: InputDecoration(
                                      labelText: spec.label,
                                      helperText: spec.helper ??
                                          'Выберите пользователя',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }

                            if (spec.type == _FieldType.string &&
                                spec.key == 'type') {
                              return DropdownButtonFormField<String>(
                                initialValue: controller.text.isNotEmpty
                                    ? controller.text
                                    : null,
                                items: const [
                                  DropdownMenuItem(
                                      value: 'taxi', child: Text('Такси')),
                                  DropdownMenuItem(
                                      value: 'delivery',
                                      child: Text('Доставка')),
                                  DropdownMenuItem(
                                      value: 'intercity',
                                      child: Text('Межгород')),
                                ],
                                onChanged: spec.readOnly
                                    ? null
                                    : (value) {
                                        setModalState(() {
                                          controller.text = value ?? '';
                                        });
                                      },
                                decoration: InputDecoration(
                                  labelText: spec.label,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }

                            if (spec.type == _FieldType.string &&
                                spec.key == 'city') {
                              final citiesFuture = makeCloudCall(
                                'adminListCityTariffs',
                                {'limit': 500},
                              );
                              return FutureBuilder<Map<String, dynamic>>(
                                future: citiesFuture,
                                builder: (context, snapshot) {
                                  final cities =
                                      _cityOptionsFromResponse(snapshot.data);
                                  final items = cities
                                      .map((title) => DropdownMenuItem<String>(
                                            value: title,
                                            child: Text(title),
                                          ))
                                      .toList();
                                  return DropdownButtonFormField<String>(
                                    initialValue: controller.text.isNotEmpty
                                        ? controller.text
                                        : null,
                                    items: items,
                                    onChanged: spec.readOnly
                                        ? null
                                        : (value) {
                                            setModalState(() {
                                              controller.text = value ?? '';
                                            });
                                          },
                                    decoration: InputDecoration(
                                      labelText: spec.label,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }

                            if (spec.type == _FieldType.string &&
                                spec.key == 'role') {
                              return DropdownButtonFormField<String>(
                                initialValue: controller.text.isNotEmpty
                                    ? controller.text
                                    : null,
                                items: const [
                                  DropdownMenuItem(
                                      value: 'passenger',
                                      child: Text('Пассажир')),
                                  DropdownMenuItem(
                                      value: 'driver', child: Text('Водитель')),
                                  DropdownMenuItem(
                                      value: 'admin', child: Text('Админ')),
                                ],
                                onChanged: spec.readOnly
                                    ? null
                                    : (value) {
                                        setModalState(() {
                                          controller.text = value ?? '';
                                        });
                                      },
                                decoration: InputDecoration(
                                  labelText: spec.label,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }

                            if (spec.type == _FieldType.string &&
                                spec.key == 'statusDriver') {
                              return DropdownButtonFormField<String>(
                                initialValue: controller.text.isNotEmpty
                                    ? controller.text
                                    : null,
                                items: const [
                                  DropdownMenuItem(
                                      value: 'pending',
                                      child: Text('Ожидает подтверждения')),
                                  DropdownMenuItem(
                                      value: 'approved',
                                      child: Text('Подтвержден')),
                                  DropdownMenuItem(
                                      value: 'rejected',
                                      child: Text('Отклонен')),
                                ],
                                onChanged: spec.readOnly
                                    ? null
                                    : (value) {
                                        setModalState(() {
                                          controller.text = value ?? '';
                                        });
                                      },
                                decoration: InputDecoration(
                                  labelText: spec.label,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }

                            if (spec.type == _FieldType.intType &&
                                spec.key == 'status') {
                              return DropdownButtonFormField<int>(
                                initialValue: int.tryParse(controller.text),
                                items: const [
                                  DropdownMenuItem(
                                      value: 0, child: Text('Новый')),
                                  DropdownMenuItem(
                                      value: 1, child: Text('В работе')),
                                  DropdownMenuItem(
                                      value: 2,
                                      child: Text('Назначен водитель')),
                                  DropdownMenuItem(
                                      value: 3, child: Text('На месте')),
                                  DropdownMenuItem(
                                      value: 4, child: Text('Поездка')),
                                  DropdownMenuItem(
                                      value: 5, child: Text('Завершен')),
                                  DropdownMenuItem(
                                      value: 6, child: Text('Отменен')),
                                ],
                                onChanged: spec.readOnly
                                    ? null
                                    : (value) {
                                        setModalState(() {
                                          controller.text =
                                              value?.toString() ?? '';
                                        });
                                      },
                                decoration: InputDecoration(
                                  labelText: spec.label,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }

                            if (_isLongTextField(spec)) {
                              return TextField(
                                controller: controller,
                                readOnly: spec.readOnly,
                                minLines: 8,
                                maxLines: 18,
                                keyboardType: TextInputType.multiline,
                                textAlignVertical: TextAlignVertical.top,
                                decoration: InputDecoration(
                                  labelText: spec.label,
                                  helperText: spec.helper ??
                                      'Вставьте полный текст политики. Переносы строк сохраняются.',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }

                            if (_isUserImageField(spec)) {
                              final imageUrl = controller.text.trim();
                              final isMarkedForDeletion =
                                  deletedUserImageKeys.contains(spec.key);
                              final requiresDriverDeleteRequest =
                                  spec.key == 'avtoImage';
                              final vehicleDeletePending =
                                  requiresDriverDeleteRequest &&
                                      (((data?['vehiclePhotoDeleteRequestStatus']) ??
                                                  '')
                                              .toString()
                                              .trim() ==
                                          'pending_admin_approval');
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: controller,
                                    readOnly: spec.readOnly,
                                    onChanged: (_) => setModalState(() {
                                      if (controller.text.trim().isNotEmpty) {
                                        deletedUserImageKeys.remove(spec.key);
                                      }
                                    }),
                                    decoration: InputDecoration(
                                      labelText: spec.label,
                                      helperText: spec.helper ??
                                          'Ссылка на изображение. Можно скопировать или сразу проверить превью.',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      suffixIcon: IconButton(
                                        onPressed: imageUrl.isEmpty
                                            ? null
                                            : () =>
                                                _copyText(context, imageUrl),
                                        icon: const Icon(Icons.copy_rounded),
                                        tooltip: 'Копировать ссылку',
                                      ),
                                    ),
                                  ),
                                  if (imageUrl.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FFButtonWidget(
                                            onPressed: () => _showImagePreview(
                                              context,
                                              title: spec.label,
                                              url: imageUrl,
                                              ownerId: reference?.id,
                                            ),
                                            text: 'Открыть фото',
                                            options: FFButtonOptions(
                                              height: 38,
                                              color: _mtaxiSurface2,
                                              textStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall,
                                              elevation: 0,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: BorderSide(
                                                color: Colors.white
                                                    .withValues(alpha: 0.1),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        FFButtonWidget(
                                          onPressed: vehicleDeletePending
                                              ? () async {
                                                  final response =
                                                      await makeCloudCall(
                                                    'approveVehiclePhotoDeletion',
                                                    {
                                                      'userDocPath':
                                                          reference?.path,
                                                    },
                                                  );
                                                  if (response['success'] !=
                                                      true) {
                                                    final error =
                                                        (response['error'] ??
                                                                '')
                                                            .toString()
                                                            .trim();
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          error.isNotEmpty
                                                              ? error
                                                              : 'Не удалось подтвердить удаление фото',
                                                        ),
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  Navigator.of(context).pop();
                                                  safeSetState(() {});
                                                }
                                              : requiresDriverDeleteRequest
                                                  ? null
                                                  : spec.readOnly
                                                      ? null
                                                      : () async {
                                                          final confirmed =
                                                              await _confirmDeleteUserImageField(
                                                            context,
                                                            label: spec.label,
                                                          );
                                                          if (!confirmed) {
                                                            return;
                                                          }
                                                          setModalState(() {
                                                            controller.clear();
                                                            deletedUserImageKeys
                                                                .add(spec.key);
                                                          });
                                                        },
                                          text: vehicleDeletePending
                                              ? 'Подтвердить удаление'
                                              : 'Удалить фото',
                                          options: FFButtonOptions(
                                            height: 38,
                                            color: vehicleDeletePending
                                                ? _mtaxiMint
                                                : FlutterFlowTheme.of(context)
                                                    .error,
                                            textStyle: FlutterFlowTheme.of(
                                                    context)
                                                .bodySmall
                                                .override(
                                                  font: GoogleFonts.readexPro(),
                                                  color: Colors.white,
                                                  letterSpacing: 0.0,
                                                ),
                                            elevation: 0,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        if (vehicleDeletePending) ...[
                                          const SizedBox(width: 8),
                                          FFButtonWidget(
                                            onPressed: () async {
                                              final response =
                                                  await makeCloudCall(
                                                'rejectVehiclePhotoDeletion',
                                                {
                                                  'userDocPath':
                                                      reference?.path,
                                                },
                                              );
                                              if (response['success'] != true) {
                                                final error =
                                                    (response['error'] ?? '')
                                                        .toString()
                                                        .trim();
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      error.isNotEmpty
                                                          ? error
                                                          : 'Не удалось отклонить удаление фото',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                              Navigator.of(context).pop();
                                              safeSetState(() {});
                                            },
                                            text: 'Отклонить',
                                            options: FFButtonOptions(
                                              height: 38,
                                              color: _mtaxiSurface2,
                                              textStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall,
                                              elevation: 0,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: BorderSide(
                                                color: Colors.white
                                                    .withValues(alpha: 0.1),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (vehicleDeletePending)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          'Водитель запросил удаление фото авто. Удаление произойдет только после подтверждения администратора.',
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall,
                                        ),
                                      )
                                    else if (requiresDriverDeleteRequest)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          'Фото авто удаляется только по запросу водителя и после подтверждения администратора.',
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: _buildImageThumb(
                                        context,
                                        label: spec.label,
                                        url: imageUrl,
                                        ownerId: reference?.id,
                                      ),
                                    ),
                                  ] else if (isMarkedForDeletion) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Фото будет удалено после сохранения.',
                                      style: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .override(
                                            font: GoogleFonts.readexPro(),
                                            color: FlutterFlowTheme.of(context)
                                                .error,
                                            letterSpacing: 0.0,
                                          ),
                                    ),
                                  ],
                                ],
                              );
                            }

                            return TextField(
                              controller: controller,
                              readOnly: spec.readOnly,
                              decoration: InputDecoration(
                                labelText: spec.label,
                                helperText: spec.helper ??
                                    (spec.required
                                        ? 'Обязательное поле'
                                        : null),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              keyboardType:
                                  spec.type == _FieldType.doubleType ||
                                          spec.type == _FieldType.intType
                                      ? TextInputType.number
                                      : TextInputType.text,
                            );
                          },
                        ),
                      ),
                    if (useJsonEditor && schema == null)
                      Column(
                        children: [
                          Text(
                            'Поддерживаемые типы: строки, числа, bool, массивы, '
                            'объекты, а также специальные форматы: '
                            '{"__timestamp": "2026-02-05T12:00:00Z"}, '
                            '{"__geo": {"lat": 0.0, "lng": 0.0}}, '
                            '{"__ref": "collection/doc"}',
                            style: FlutterFlowTheme.of(context).labelSmall,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: jsonController,
                            maxLines: 16,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              errorText: errorText,
                            ),
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    if (errorText != null && errorText!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context)
                              .error
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context)
                                .error
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          errorText!,
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.readexPro(),
                                    color: FlutterFlowTheme.of(context).error,
                                    letterSpacing: 0.0,
                                  ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FFButtonWidget(
                            onPressed:
                                isSaving ? null : () => Navigator.pop(context),
                            text: 'Отмена',
                            options: FFButtonOptions(
                              height: 44,
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    font: GoogleFonts.readexPro(
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FFButtonWidget(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    setModalState(() {
                                      isSaving = true;
                                      errorText = null;
                                    });
                                    try {
                                      Map<String, dynamic> converted;
                                      if (useJsonEditor) {
                                        final decoded = json
                                            .decode(jsonController.text.trim());
                                        if (decoded is! Map) {
                                          throw Exception(
                                              'Ожидается JSON-объект');
                                        }
                                        converted = Map<String, dynamic>.from(
                                          _decodeValue(decoded) as Map,
                                        );
                                      } else {
                                        final map = <String, dynamic>{};
                                        for (final spec in schema) {
                                          if (spec.readOnly) {
                                            continue;
                                          }
                                          if (spec.type ==
                                              _FieldType.boolType) {
                                            map[spec.key] =
                                                fieldBools[spec.key] ?? false;
                                            continue;
                                          }
                                          if (_isUserImageField(spec) &&
                                              deletedUserImageKeys
                                                  .contains(spec.key)) {
                                            map[spec.key] =
                                                _adminDeleteSentinel;
                                            continue;
                                          }
                                          final rawText =
                                              fieldControllers[spec.key]
                                                      ?.text ??
                                                  '';
                                          final text = _isLongTextField(spec)
                                              ? rawText.replaceAll('\r\n', '\n')
                                              : rawText.trim();
                                          final isEffectivelyEmpty =
                                              _isLongTextField(spec)
                                                  ? text.trim().isEmpty
                                                  : text.isEmpty;
                                          if (isEffectivelyEmpty) {
                                            if (widget.collectionName ==
                                                    'order' &&
                                                spec.key == 'idUser') {
                                              continue;
                                            }
                                            if (spec.required) {
                                              throw Exception(
                                                  'Заполните поле: ${spec.label}');
                                            }
                                            if (_isUsersCollection &&
                                                _clearableUserFields
                                                    .contains(spec.key)) {
                                              map[spec.key] =
                                                  _adminDeleteSentinel;
                                            }
                                            continue;
                                          }
                                          switch (spec.type) {
                                            case _FieldType.string:
                                              map[spec.key] = text;
                                              break;
                                            case _FieldType.intType:
                                              final val = int.tryParse(text);
                                              if (val == null) {
                                                throw Exception(
                                                    'Поле "${spec.label}" должно быть числом');
                                              }
                                              map[spec.key] = val;
                                              break;
                                            case _FieldType.doubleType:
                                              final val = double.tryParse(text);
                                              if (val == null) {
                                                throw Exception(
                                                    'Поле "${spec.label}" должно быть числом');
                                              }
                                              map[spec.key] = val;
                                              break;
                                            case _FieldType.dateTime:
                                              final val =
                                                  DateTime.tryParse(text);
                                              if (val == null) {
                                                throw Exception(
                                                    'Поле "${spec.label}" должно быть датой');
                                              }
                                              map[spec.key] = val;
                                              break;
                                            case _FieldType.reference:
                                              map[spec.key] = BackendRefs
                                                  .instance
                                                  .doc(text);
                                              break;
                                            case _FieldType.geo:
                                              final parts = text.split(',');
                                              if (parts.length == 2) {
                                                final lat = double.tryParse(
                                                    parts[0].trim());
                                                final lng = double.tryParse(
                                                    parts[1].trim());
                                                if (lat != null &&
                                                    lng != null) {
                                                  map[spec.key] =
                                                      GeoPoint(lat, lng);
                                                } else {
                                                  throw Exception(
                                                      'Поле "${spec.label}" в формате lat,lng');
                                                }
                                              } else {
                                                throw Exception(
                                                    'Поле "${spec.label}" в формате lat,lng');
                                              }
                                              break;
                                            case _FieldType.json:
                                              map[spec.key] = json.decode(text);
                                              break;
                                            case _FieldType.boolType:
                                              break;
                                          }
                                        }
                                        converted = map;
                                        if (widget.collectionName == 'order') {
                                          final selectedUserPath =
                                              (fieldControllers['idUser']
                                                          ?.text ??
                                                      '')
                                                  .trim();
                                          final customerPhone =
                                              orderCustomerPhoneController.text
                                                  .trim();
                                          final customerName =
                                              orderCustomerNameController.text
                                                  .trim();
                                          if (selectedUserPath.isEmpty &&
                                              customerPhone.isEmpty) {
                                            throw Exception(
                                                'Укажите заказчика: выберите пользователя или введите номер телефона');
                                          }
                                          if (customerName.isNotEmpty) {
                                            converted['customerName'] =
                                                customerName;
                                          } else if (reference != null &&
                                              [
                                                initialData['customerName'],
                                                initialData['customer_name'],
                                                initialData['clientName'],
                                                initialData['userName'],
                                                initialData['name'],
                                                initialData['display_name'],
                                              ].any((v) => (v ?? '')
                                                  .toString()
                                                  .trim()
                                                  .isNotEmpty)) {
                                            converted['customerName'] =
                                                FieldValue.delete();
                                          }
                                          if (customerPhone.isNotEmpty) {
                                            converted['customerPhone'] =
                                                customerPhone;
                                          } else if (reference != null &&
                                              (initialData['customerPhone'] ??
                                                      '')
                                                  .toString()
                                                  .isNotEmpty) {
                                            converted['customerPhone'] =
                                                FieldValue.delete();
                                          }
                                        }
                                      }

                                      if (_isPolitikaCollection) {
                                        await _savePolitikaDocument(converted);
                                      } else if (widget.collectionName ==
                                          'order') {
                                        await _saveOrderDocument(
                                          reference,
                                          converted,
                                        );
                                      } else if (reference != null) {
                                        if (_isUsersCollection) {
                                          await _saveUserDocument(
                                            reference,
                                            converted,
                                            initialData,
                                          );
                                        } else {
                                          throw UnsupportedError(
                                            'Direct backend bypass save fallback is disabled',
                                          );
                                        }
                                      } else {
                                        if (_isUsersCollection) {
                                          await _createUserDocument(converted);
                                        } else {
                                          throw UnsupportedError(
                                            'Direct backend bypass create fallback is disabled',
                                          );
                                        }
                                      }

                                      if (mounted) {
                                        Navigator.pop(context);
                                      }
                                    } catch (e) {
                                      setModalState(() {
                                        errorText =
                                            'Ошибка сохранения: ${_humanizeAdminError(e)}';
                                        isSaving = false;
                                      });
                                    }
                                  },
                            text: isSaving ? 'Сохраняем...' : 'Сохранить',
                            options: FFButtonOptions(
                              height: 44,
                              color: _mtaxiMint,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    font: GoogleFonts.readexPro(
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                    color: Colors.white,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    orderUserSearchController.dispose();
    orderCustomerPhoneController.dispose();
  }

  dynamic _encodeValue(dynamic value) {
    if (value is Timestamp) {
      return {'__timestamp': value.toDate().toIso8601String()};
    }
    if (value is GeoPoint) {
      return {
        '__geo': {
          'lat': value.latitude,
          'lng': value.longitude,
        }
      };
    }
    if (value is DocumentReference) {
      return {'__ref': value.path};
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key, _encodeValue(val)));
    }
    if (value is List) {
      return value.map(_encodeValue).toList();
    }
    return value;
  }

  dynamic _decodeValue(dynamic value) {
    if (value is List) {
      return value.map(_decodeValue).toList();
    }
    if (value is Map) {
      if (value.containsKey('__timestamp')) {
        final raw = value['__timestamp']?.toString();
        if (raw != null && raw.isNotEmpty) {
          return Timestamp.fromDate(DateTime.parse(raw));
        }
      }
      if (value.containsKey('__geo')) {
        final geo = value['__geo'] as Map?;
        if (geo != null) {
          final lat = geo['lat'];
          final lng = geo['lng'];
          if (lat is num && lng is num) {
            return GeoPoint(lat.toDouble(), lng.toDouble());
          }
        }
      }
      if (value.containsKey('__ref')) {
        final path = value['__ref']?.toString();
        if (path != null && path.isNotEmpty) {
          return BackendRefs.instance.doc(path);
        }
      }
      return value.map((key, val) => MapEntry(key, _decodeValue(val)));
    }
    return value;
  }
}
