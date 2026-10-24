import '/backend/uploads/mtaxi_network_image.dart';
import '/design/driver_approval.dart';
import '/design/mtaxi_theme.dart';
import '/auth/backend_auth/auth_util.dart';
import '/backend/app_city_tariffs/app_city_tariffs.dart';
import '/backend/backend.dart';
import '/backend/backend_user_adapter.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/backend/uploads/storage.dart';

import '/flutter_flow/permissions_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

import '/flutter_flow/upload_data.dart';
import '/index.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
import 'set_profile_driver_model.dart';
export 'set_profile_driver_model.dart';
import '/flutter_flow/custom_functions.dart' as functions;

const _mtaxiMint = Color(0xFF126E68);
const _mtaxiText = Color(0xFF1B242B);

class _KazakhstanPlateInputFormatter extends TextInputFormatter {
  static final _digitPattern = RegExp(r'\d');
  static final _letterPattern = RegExp(r'[A-ZА-Я]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw =
        newValue.text.toUpperCase().replaceAll(RegExp(r'[^0-9A-ZА-Я]'), '');
    final buffer = StringBuffer();

    for (final codeUnit in raw.codeUnits) {
      if (buffer.length >= 8) {
        break;
      }
      final char = String.fromCharCode(codeUnit);
      final nextIndex = buffer.length;
      final expectsDigit = nextIndex < 3 || nextIndex >= 6;
      final isAllowed = expectsDigit
          ? _digitPattern.hasMatch(char)
          : _letterPattern.hasMatch(char);
      if (isAllowed) {
        buffer.write(char);
      }
    }

    final normalized = buffer.toString();
    final formatted = _formatKazakhstanPlate(normalized);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _normalizeKazakhstanPlate(String value) {
  return value.toUpperCase().replaceAll(RegExp(r'[^0-9A-ZА-Я]'), '');
}

String _formatKazakhstanPlate(String value) {
  final normalized = _normalizeKazakhstanPlate(value);
  final parts = <String>[];
  if (normalized.isNotEmpty) {
    parts.add(
        normalized.substring(0, normalized.length > 3 ? 3 : normalized.length));
  }
  if (normalized.length > 3) {
    parts.add(
        normalized.substring(3, normalized.length > 6 ? 6 : normalized.length));
  }
  if (normalized.length > 6) {
    parts.add(
        normalized.substring(6, normalized.length > 8 ? 8 : normalized.length));
  }
  return parts.join(' ');
}

bool _isValidKazakhstanPlate(String value) {
  return RegExp(r'^\d{3}[A-ZА-Я]{3}\d{2}$')
      .hasMatch(_normalizeKazakhstanPlate(value));
}

class SetProfileDriverWidget extends StatefulWidget {
  const SetProfileDriverWidget({super.key});

  static String routeName = 'setProfileDriver';
  static String routePath = '/setProfileDriver';

  @override
  State<SetProfileDriverWidget> createState() => _SetProfileDriverWidgetState();
}

class _SetProfileDriverWidgetState extends State<SetProfileDriverWidget>
    with WidgetsBindingObserver {
  late SetProfileDriverModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _firstNameFieldKey = GlobalKey();
  bool get _needsPassword =>
      currentUserDocument?.snapshotData['hasPassword'] != true;
  final _passwordFieldKey = GlobalKey();
  final _passwordRepeatFieldKey = GlobalKey();
  final _plateFieldKey = GlobalKey();
  final _carColorFieldKey = GlobalKey();
  final _vehiclePhotoBlockKey = GlobalKey();
  final _techPhotoBlockKey = GlobalKey();
  final Map<String, String> _uploadErrors = {};
  int _designStep = 0;
  late final String _draftUid;
  bool _draftRestored = false;
  Future<void> _draftWrites = Future<void>.value();
  String get _draftKey => 'mtaxi_driver_registration_draft_$_draftUid';
  late Future<List<String>> _cities;
  bool _didAttemptSubmit = false;
  bool _isSubmittingRegistration = false;
  bool _isCheckingLocationPermission = false;

  Future<List<String>> _loadCityTitles() async {
    return loadAppCityTitles();
  }

  String _tr(
    BuildContext context, {
    required String ru,
    required String kk,
  }) {
    return FFLocalizations.of(context).getVariableText(
      ruText: ru,
      kkText: kk,
    );
  }

  String? _requiredFieldError(String value, String message) {
    if (!_didAttemptSubmit || value.trim().isNotEmpty) {
      return null;
    }
    return message;
  }

  String? _plateFieldError(BuildContext context) {
    if (!_didAttemptSubmit) {
      return null;
    }
    final value = _model.textController5?.text ?? '';
    if (value.trim().isEmpty) {
      return _tr(
        context,
        ru: 'Введите госномер',
        kk: 'Мемлекеттік нөмірді енгізіңіз',
      );
    }
    if (!_isValidKazakhstanPlate(value)) {
      return _tr(
        context,
        ru: 'Формат: 123 ABC 01',
        kk: 'Формат: 123 ABC 01',
      );
    }
    return null;
  }

  String? _passwordRepeatFieldError(BuildContext context) {
    if (!_needsPassword) return null;
    if (!_didAttemptSubmit) {
      return null;
    }
    final password = _model.textController3?.text ?? '';
    final repeat = _model.textController4?.text ?? '';
    if (repeat.trim().isEmpty) {
      return _tr(
        context,
        ru: 'Повторите пароль',
        kk: 'Құпиясөзді қайталаңыз',
      );
    }
    if (password != repeat) {
      return _tr(
        context,
        ru: 'Пароли не совпадают',
        kk: 'Құпиясөздер сәйкес емес',
      );
    }
    return null;
  }

  String? _vehiclePhotoError(BuildContext context) {
    if (!_didAttemptSubmit) {
      return null;
    }
    if (_model.uploadedFileUrl_uploadData2xm.isEmpty) {
      return _tr(
        context,
        ru: 'Добавьте фото автомобиля',
        kk: 'Көліктің фотосын жүктеңіз',
      );
    }
    return null;
  }

  String? _techPhotoError(BuildContext context) {
    if (!_didAttemptSubmit || _model.uploadedFileUrl_techPhoto.isNotEmpty) {
      return null;
    }
    return _tr(
      context,
      ru: 'Добавьте фото техпаспорта',
      kk: 'Техпаспорт суретін жүктеңіз',
    );
  }

  GlobalKey? _firstInvalidRegistrationKey(BuildContext context) {
    if (_vehiclePhotoError(context) != null) return _vehiclePhotoBlockKey;
    if (_techPhotoError(context) != null) return _techPhotoBlockKey;
    if ((_model.textController1?.text ?? '').trim().isEmpty) {
      return _firstNameFieldKey;
    }
    if (_plateFieldError(context) != null) return _plateFieldKey;
    if (_needsPassword && (_model.textController3?.text ?? '').trim().isEmpty) {
      return _passwordFieldKey;
    }
    if (_passwordRepeatFieldError(context) != null) {
      return _passwordRepeatFieldKey;
    }
    return null;
  }

  List<String> _collectRegistrationErrors(BuildContext context) {
    final errors = <String>[];
    void addIf(String? error) {
      if (error != null && error.trim().isNotEmpty) {
        errors.add(error);
      }
    }

    addIf(_vehiclePhotoError(context));
    addIf(_model.uploadedFileUrl_techPhoto.isEmpty
        ? _tr(
            context,
            ru: 'Добавьте фото техпаспорта',
            kk: 'Техпаспорт суретін жүктеңіз',
          )
        : null);
    addIf(_requiredFieldError(
      _model.textController1?.text ?? '',
      _tr(context,
          ru: 'Введите имя и фамилию', kk: 'Атыңыз бен тегіңізді енгізіңіз'),
    ));
    addIf(_plateFieldError(context));
    addIf(_selectedCity().isEmpty
        ? _tr(
            context,
            ru: 'Выберите свой город или поселок из списка',
            kk: 'Тізімнен қалаңызды немесе ауылыңызды таңдаңыз',
          )
        : null);
    if (_needsPassword)
      addIf(_requiredFieldError(
        _model.textController3?.text ?? '',
        _tr(context, ru: 'Придумайте пароль', kk: 'Құпиясөз ойлап табыңыз'),
      ));
    addIf(_passwordRepeatFieldError(context));
    return errors.toSet().toList();
  }

  Future<void> _showMessageDialog(BuildContext context, String text) async {
    await showDialog(
      context: context,
      builder: (alertDialogContext) {
        return WebViewAware(
          child: AlertDialog(
            content: Text(text),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(alertDialogContext),
                child: Text(
                  _tr(
                    context,
                    ru: 'Ок',
                    kk: 'Жарайды',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitDriverRegistration() async {
    if (_isSubmittingRegistration) {
      return;
    }
    _didAttemptSubmit = true;
    safeSetState(() {});
    final validationErrors = _collectRegistrationErrors(context);
    if (validationErrors.isNotEmpty) {
      final invalidKey = _firstInvalidRegistrationKey(context);
      if (invalidKey != null) {
        _scrollFieldIntoView(invalidKey);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              ru: 'Заполните выделенные поля',
              kk: 'Белгіленген өрістерді толтырыңыз',
            ),
          ),
        ),
      );
      return;
    }

    if (!await _ensureLocationPermissionGranted()) {
      return;
    }

    final fullNameParts = _model.textController1.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    final firstName = fullNameParts.isEmpty ? '' : fullNameParts.first;
    final lastName = fullNameParts.length > 1
        ? fullNameParts.skip(1).join(' ')
        : _model.textController2.text.trim();
    final displayName = [firstName, lastName]
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .trim();
    final gosNomer = _formatKazakhstanPlate(_model.textController5.text);
    final color = _model.textController6.text.trim();
    final selectedCity = _selectedCity();
    final existingUserId =
        valueOrDefault(currentUserDocument?.snapshotData['userId'], '');
    final userId = existingUserId.toString().isNotEmpty
        ? existingUserId.toString()
        : functions.generateUserId();

    safeSetState(() {
      _isSubmittingRegistration = true;
    });
    try {
      final payload = <String, dynamic>{
        'firstName': firstName,
        'lastName': lastName,
        'displayName': displayName,
        'phoneNumber': FFAppState().phone,
        'avtoImage': _model.uploadedFileUrl_uploadData2xm,
        'techImage': _model.uploadedFileUrl_techPhoto,
        'birthDate': _model.datePicked?.toIso8601String(),
        'password': _model.textController3.text,
        'color': color,
        'gosNomer': gosNomer,
        'city': selectedCity,
        'userId': userId,
      };
      final response = await makeCloudCall(
        'submitDriverRegistration',
        payload,
        timeout: const Duration(seconds: 20),
      );
      if (response['success'] != true) {
        final error = (response['error'] ?? '').toString().trim();
        throw Exception(
          error.isNotEmpty
              ? error
              : _tr(
                  context,
                  ru: 'Не удалось сохранить регистрацию водителя',
                  kk: 'Жүргізуші тіркеуін сақтау мүмкін болмады',
                ),
        );
      }
      try {
        await _draftWrites;
        final draftPrefs = await SharedPreferences.getInstance();
        await draftPrefs.remove(_draftKey);
      } catch (_) {
        // Registration is already confirmed by the server; draft cleanup is local.
      }
      FFAppState().pendingRegistrationRole = '';
      FFAppState().update(() {});
      currentUserDocument =
          await applyBackendUserResponse(response) ?? currentUserDocument;
      if (!mounted) return;
      await _refreshExistingRegistrationDraft();
      if (!mounted) return;
      await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (approvalContext) => DriverApproval(
                onProfile: () => Navigator.pop(approvalContext),
                onSupport: () =>
                    approvalContext.pushNamed(SupportChatWidget.routeName),
              )));
      if (!mounted) return;
      context.goNamedAuth(
        ProfileWidget.routeName,
        context.mounted,
      );
    } catch (e) {
      if (!mounted) return;
      await _showMessageDialog(
        context,
        e.toString().replaceFirst('Exception: ', '').trim().isNotEmpty
            ? e.toString().replaceFirst('Exception: ', '').trim()
            : _tr(
                context,
                ru: 'Не удалось сохранить регистрацию. Проверьте интернет и попробуйте еще раз.',
                kk: 'Тіркеуді сақтау мүмкін болмады. Интернетті тексеріп, қайталап көріңіз.',
              ),
      );
    } finally {
      if (mounted) {
        safeSetState(() {
          _isSubmittingRegistration = false;
        });
      }
    }
  }

  Future<void> _pickBirthDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _model.datePicked ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: getCurrentTimestamp,
    );
    if (pickedDate == null) {
      return;
    }
    safeSetState(() {
      _model.datePicked = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
    });
  }

  void _scrollFieldIntoView(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      final fieldContext = key.currentContext;
      if (fieldContext == null) return;
      await Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: 0.22,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  String _selectedCity() {
    final selected = (_model.textFieldSelectedOption7 ?? '').trim();
    final typed = (_model.textController7?.text ?? '').trim();
    if (typed.isEmpty) {
      return '';
    }
    if (selected.isEmpty) {
      return typed;
    }
    return selected == typed ? selected : typed;
  }

  String _registrationDisplayName(UsersRecord? user) {
    final data = user?.snapshotData ?? const <String, dynamic>{};
    final firstName = normalizeDisplayText(data['firstName']);
    final lastName = normalizeDisplayText(data['lastName']);
    final compositeName =
        [firstName, lastName].where((part) => part.isNotEmpty).join(' ').trim();
    if (compositeName.isNotEmpty) {
      return compositeName;
    }

    final displayName = normalizeDisplayText(
      data['display_name'] ?? data['displayName'],
    );
    if (displayName.isNotEmpty) {
      return displayName;
    }

    return normalizeDisplayText(user?.displayName ?? '');
  }

  bool _canReturnToPassengerMode() {
    final user = currentUserDocument;
    if (user == null) {
      return false;
    }
    final displayName = _registrationDisplayName(user);
    final city = user.city.trim();
    final roleState =
        (user.snapshotData['roleState'] ?? '').toString().trim().toUpperCase();
    final preferredMode = (user.snapshotData['preferredClientMode'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return displayName.isNotEmpty &&
        (city.isNotEmpty ||
            roleState == 'PASSENGER' ||
            preferredMode == 'passenger');
  }

  Future<void> _returnToPassengerMode() async {
    FFAppState().pendingRegistrationRole = '';
    FFAppState().clearPassengerOrderCreationState();
    UserModeResolver.setTransientRoleState('PASSENGER');
    FFAppState().update(() {});
    try {
      final response = await makeCloudCall(
        'updateUserPreferences',
        {'targetRoleState': 'PASSENGER'},
      );
      if (response['success'] == true) {
        currentUserDocument =
            await applyBackendUserResponse(response) ?? currentUserDocument;
      }
    } catch (_) {}
    if (!mounted) {
      return;
    }
    context.goNamedAuth(
      HomePageWidget.routeName,
      context.mounted,
      ignoreRedirect: true,
      extra: <String, dynamic>{
        kTransitionInfoKey: TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.scale,
          alignment: Alignment.bottomCenter,
        ),
      },
    );
  }

  void _hydrateFromUserRecord(UsersRecord? user) {
    final data = user?.snapshotData ?? const <String, dynamic>{};
    if ((_model.textController1?.text ?? '').trim().isEmpty) {
      final firstName = normalizeDisplayText(data['firstName']);
      final lastName = normalizeDisplayText(data['lastName']);
      final fallbackNameParts = _registrationDisplayName(user)
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList();
      if (firstName.isNotEmpty) {
        _model.textController1?.text = firstName;
      } else if (fallbackNameParts.isNotEmpty) {
        _model.textController1?.text = fallbackNameParts.first;
      }
      if ((_model.textController2?.text ?? '').trim().isEmpty) {
        if (lastName.isNotEmpty) {
          _model.textController2?.text = lastName;
        } else if (fallbackNameParts.length > 1) {
          _model.textController2?.text = fallbackNameParts.skip(1).join(' ');
        }
      }
    }
    _model.textController5?.text =
        (_model.textController5?.text ?? '').trim().isNotEmpty
            ? _model.textController5!.text
            : _formatKazakhstanPlate((user?.gosNomer ?? '').trim());
    _model.textController6?.text =
        (_model.textController6?.text ?? '').trim().isNotEmpty
            ? _model.textController6!.text
            : (user?.color ?? '').trim();
    final city = (user?.city ?? '').trim();
    if (city.isNotEmpty &&
        (_model.textController7?.text ?? '').trim().isEmpty) {
      _model.textController7?.text = city;
      _model.textFieldSelectedOption7 = city;
    }
    final dataRoj = data['dataRoj'];
    if (_model.datePicked == null) {
      if (dataRoj is Timestamp) {
        _model.datePicked = dataRoj.toDate();
      } else if (dataRoj is DateTime) {
        _model.datePicked = dataRoj;
      }
    }
    _model.uploadedFileUrl_uploadData2xm =
        _model.uploadedFileUrl_uploadData2xm.isNotEmpty
            ? _model.uploadedFileUrl_uploadData2xm
            : (user?.avtoImage ?? user?.photoUrl ?? '').trim();
    _model.uploadedFileUrl_techPhoto =
        _model.uploadedFileUrl_techPhoto.isNotEmpty
            ? _model.uploadedFileUrl_techPhoto
            : (user?.techImage ?? '').trim();
  }

  Future<void> _refreshExistingRegistrationDraft() async {
    if (_draftRestored || _draftUid.isEmpty) return;
    _draftRestored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || !mounted || currentUserUid != _draftUid) return;
      final draft = jsonDecode(raw);
      if (draft is! Map) return;
      safeSetState(() {
        final fields = <String, TextEditingController?>{
          'name': _model.textController1,
          'surname': _model.textController2,
          'plate': _model.textController5,
          'color': _model.textController6,
          'city': _model.textController7,
        };
        for (final entry in fields.entries) {
          if (draft[entry.key] is String) entry.value?.text = draft[entry.key];
        }
        _model.textFieldSelectedOption7 = _model.textController7?.text;
        _model.datePicked =
            DateTime.tryParse(draft['birthDate']?.toString() ?? '');
        if (draft['avtoImage'] is String)
          _model.uploadedFileUrl_uploadData2xm = draft['avtoImage'];
        if (draft['techImage'] is String)
          _model.uploadedFileUrl_techPhoto = draft['techImage'];
        _designStep = draft['step'] == 1 ? 1 : 0;
      });
    } catch (_) {
      // A malformed local draft must not prevent registration.
    }
  }

  Future<bool> _saveDriverRegistrationDraft(
      {String? avtoImage, String? techImage}) async {
    if (_draftUid.isEmpty || currentUserUid != _draftUid) return false;
    // Never persist either password controller in a registration draft.
    final data = jsonEncode({
      'name': _model.textController1?.text ?? '',
      'surname': _model.textController2?.text ?? '',
      'plate': _model.textController5?.text ?? '',
      'color': _model.textController6?.text ?? '',
      'city': _selectedCity(),
      'birthDate': _model.datePicked?.toIso8601String(),
      'avtoImage': avtoImage ?? _model.uploadedFileUrl_uploadData2xm,
      'techImage': techImage ?? _model.uploadedFileUrl_techPhoto,
      'step': _designStep,
    });
    final write = _draftWrites.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_draftKey, data))
        throw StateError('Draft not saved');
    });
    _draftWrites = write.catchError((_) {});
    try {
      await write;
      return true;
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_tr(context,
                ru: 'Не удалось сохранить черновик на устройстве. Не закрывайте анкету до отправки.',
                kk: 'Құрылғыда жоба сақталмады. Жібергенше сауалнаманы жаппаңыз.'))));
      return false;
    }
  }

  Future<void> _clearDriverRegistrationDraftFields(
      List<String> fieldKeys) async {
    await _saveDriverRegistrationDraft();
  }

  Future<void> _deleteVehiclePhotoFromDraft() async {
    safeSetState(() {
      _model.uploadedFileUrl_uploadData2xm = '';
      _model.uploadedLocalFile_uploadData2xm = FFUploadedFile(
        bytes: Uint8List.fromList([]),
        originalFilename: '',
      );
    });
    await _clearDriverRegistrationDraftFields(
      const [
        'avtoImage',
        'photo_url',
      ],
    );
    await _refreshExistingRegistrationDraft();
  }

  Future<void> _deleteTechPhotoFromDraft() async {
    safeSetState(() {
      _model.uploadedFileUrl_techPhoto = '';
      _model.uploadedLocalFile_techPhoto = FFUploadedFile(
        bytes: Uint8List.fromList([]),
        originalFilename: '',
      );
    });
    await _clearDriverRegistrationDraftFields(
      const ['techImage'],
    );
    await _refreshExistingRegistrationDraft();
  }

  Future<void> _showLocationPermissionDialog({
    required bool openSettings,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (alertDialogContext) {
        return WebViewAware(
          child: AlertDialog(
            content: Text(
              openSettings
                  ? _tr(
                      context,
                      ru: 'Для регистрации нужен постоянный доступ к геолокации. Включите его в настройках приложения.',
                      kk: 'Тіркелу үшін геолокацияға тұрақты рұқсат керек. Оны қолданба баптауларынан қосыңыз.',
                    )
                  : _tr(
                      context,
                      ru: 'Для регистрации нужно разрешить доступ к геолокации.',
                      kk: 'Тіркелу үшін геолокацияға рұқсат беру керек.',
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(alertDialogContext),
                child: Text(
                  openSettings
                      ? _tr(
                          context,
                          ru: 'Открыть настройки',
                          kk: 'Баптауларды ашу',
                        )
                      : _tr(
                          context,
                          ru: 'Повторить',
                          kk: 'Қайта сұрау',
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (openSettings) {
      await openAppSettings();
    }
  }

  Future<bool> _ensureLocationPermissionGranted() async {
    if (kIsWeb) {
      return true;
    }
    if (_isCheckingLocationPermission || !mounted) {
      return false;
    }

    _isCheckingLocationPermission = true;
    try {
      while (mounted) {
        final status = await locationPermission.status;
        if (status == PermissionStatus.granted ||
            status == PermissionStatus.limited) {
          return true;
        }

        if (status == PermissionStatus.permanentlyDenied ||
            status == PermissionStatus.restricted) {
          await _showLocationPermissionDialog(openSettings: true);
          return false;
        }

        await requestPermission(locationPermission);
        final updatedStatus = await locationPermission.status;
        if (updatedStatus == PermissionStatus.granted ||
            updatedStatus == PermissionStatus.limited) {
          return true;
        }

        await _showLocationPermissionDialog(
          openSettings: updatedStatus == PermissionStatus.permanentlyDenied ||
              updatedStatus == PermissionStatus.restricted,
        );
        if (updatedStatus == PermissionStatus.permanentlyDenied ||
            updatedStatus == PermissionStatus.restricted) {
          return false;
        }
      }
    } finally {
      _isCheckingLocationPermission = false;
    }

    return false;
  }

  Future<void> _pickAndUploadImage({
    required String storageFolderPath,
    required ValueSetter<bool> setUploading,
    required ValueSetter<FFUploadedFile> setLocalFile,
    required ValueSetter<String> setUrl,
    required String userField,
  }) async {
    if (_isSubmittingRegistration ||
        _model.isDataUploading_uploadData2xm ||
        _model.isDataUploading_techPhoto) return;
    if (currentUserUid.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      await _showMessageDialog(
        context,
        _tr(
          context,
          ru: 'Сначала войдите в аккаунт заново, затем повторите загрузку фото.',
          kk: 'Алдымен аккаунтқа қайта кіріп, содан кейін фотоны қайта жүктеп көріңіз.',
        ),
      );
      return;
    }

    final selectedMedia = await selectMediaWithSourceBottomSheet(
      context: context,
      allowPhoto: true,
      storageFolderPath: storageFolderPath,
      maxWidth: 1600.0,
      maxHeight: 1600.0,
      imageQuality: 78,
    );
    if (selectedMedia == null ||
        !selectedMedia
            .every((m) => validateFileFormat(m.storagePath, context))) {
      return;
    }

    showUploadMessage(
      context,
      _tr(
        context,
        ru: 'Загружаем фото...',
        kk: 'Фото жүктелуде...',
      ),
      showLoading: true,
    );
    safeSetState(() {
      setUploading(true);
      _uploadErrors.remove(userField);
    });
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
        selectedMedia.map(
          (m) async => uploadData(m.storagePath, m.bytes),
        ),
      ))
          .where((u) => u != null)
          .map((u) => u!)
          .toList();
    } catch (e) {
      uploadError = e.toString().replaceFirst('Exception: ', '').trim();
    } finally {
      safeSetState(() => setUploading(false));
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    if (uploadError != null ||
        selectedUploadedFiles.length != selectedMedia.length ||
        downloadUrls.length != selectedMedia.length) {
      safeSetState(() => _uploadErrors[userField] = uploadError?.isNotEmpty ==
              true
          ? uploadError!
          : _tr(context,
              ru: 'Фото не загрузилось. Проверьте интернет и попробуйте ещё раз.',
              kk: 'Фото жүктелмеді. Интернетті тексеріп, қайталап көріңіз.'));
      if (!mounted) return;
      await _showMessageDialog(
        context,
        uploadError?.isNotEmpty == true
            ? uploadError!
            : _tr(
                context,
                ru: 'Фото не загрузилось. Проверьте интернет и попробуйте еще раз.',
                kk: 'Фото жүктелмеді. Интернетті тексеріп, қайталап көріңіз.',
              ),
      );
      return;
    }

    safeSetState(() {
      setLocalFile(selectedUploadedFiles.first);
      setUrl(downloadUrls.first);
    });
    final draftSaved = userField == 'avtoImage'
        ? await _saveDriverRegistrationDraft(
            avtoImage: downloadUrls.first,
          )
        : await _saveDriverRegistrationDraft(techImage: downloadUrls.first);
    await _refreshExistingRegistrationDraft();
    if (!draftSaved) {
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            context,
            ru: 'Фото загружено',
            kk: 'Фото жүктелді',
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildUploadCard({
    Key? key,
    required BuildContext context,
    required String title,
    required String imageUrl,
    required FFUploadedFile localFile,
    String? errorText,
    required Future<void> Function() onTap,
    required VoidCallback onDelete,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final surface2 = isDark ? const Color(0xFF243437) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : _mtaxiText;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8EBE5);
    final hasImage = imageUrl.isNotEmpty;
    final hasError = errorText != null && errorText.trim().isNotEmpty;
    return Card(
      key: key,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      color: surface2,
      elevation: 0.0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: hasError ? FlutterFlowTheme.of(context).error : borderColor,
          width: hasError ? 2.0 : 1.0,
        ),
        borderRadius: BorderRadius.circular(14.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              title,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: TextStyle(
                      fontFamily: 'Noto Sans',
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    color: textColor,
                  ),
            ),
            const SizedBox(height: 10),
            InkWell(
              splashColor: Colors.transparent,
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Container(
                  width: 42.0,
                  height: 42.0,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: hasError
                          ? FlutterFlowTheme.of(context).error
                          : Colors.transparent,
                      width: hasError ? 2.0 : 0.0,
                    ),
                  ),
                  child: hasImage
                      ? _buildPreviewImage(
                          context,
                          imageUrl: imageUrl,
                          localFile: localFile,
                        )
                      : Icon(
                          Icons.add_a_photo_outlined,
                          color: _mtaxiMint,
                          size: 26.0,
                        ),
                ),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(height: 10),
              _buildUploadSuccessStatus(context),
              const SizedBox(height: 8),
              _buildUploadActions(
                context: context,
                onReplace: onTap,
                onDelete: onDelete,
              ),
            ],
            if (hasError) ...[
              const SizedBox(height: 10),
              _buildInlineUploadError(context, errorText,
                  onRetry: () => onTap()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewImage(
    BuildContext context, {
    required String imageUrl,
    required FFUploadedFile localFile,
  }) {
    final localBytes = localFile.bytes;
    if (localBytes != null && localBytes.isNotEmpty) {
      return Image.memory(
        localBytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return MTaxiNetworkImage(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Icon(
        Icons.broken_image_outlined,
        color: FlutterFlowTheme.of(context).secondaryText,
        size: 36.0,
      ),
    );
  }

  Widget _buildInlineUploadError(BuildContext context, String message,
          {required VoidCallback onRetry}) =>
      MTaxiUploadError(message: message, onRetry: onRetry);

  Widget _buildUploadSuccessStatus(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F7ED),
        borderRadius: BorderRadius.circular(999.0),
        border: Border.all(
          color: const Color(0xFF24A148),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF24A148),
            size: 18.0,
          ),
          const SizedBox(width: 6.0),
          Text(
            _tr(
              context,
              ru: 'Загружено',
              kk: 'Жүктелді',
            ),
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  font: TextStyle(
                    fontFamily: 'Noto Sans',
                    fontWeight: FontWeight.w600,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
                  color: const Color(0xFF176B2C),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadActions({
    required BuildContext context,
    required Future<void> Function() onReplace,
    required VoidCallback onDelete,
  }) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8.0,
      runSpacing: 4.0,
      children: [
        TextButton.icon(
          onPressed: onReplace,
          icon: Icon(
            Icons.swap_horiz,
            color: FlutterFlowTheme.of(context).primary,
            size: 18.0,
          ),
          label: Text(
            _tr(context, ru: 'Заменить', kk: 'Ауыстыру'),
          ),
        ),
        TextButton.icon(
          onPressed: onDelete,
          icon: Icon(
            Icons.delete_outline,
            color: FlutterFlowTheme.of(context).error,
            size: 18.0,
          ),
          label: Text(
            _tr(context, ru: 'Удалить', kk: 'Өшіру'),
            style: TextStyle(color: FlutterFlowTheme.of(context).error),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draftUid = currentUserUid;
    _model = createModel(context, () => SetProfileDriverModel());
    _cities = _loadCityTitles();

    _model.textController1 ??= TextEditingController();
    _model.textFieldFocusNode1 ??= FocusNode();

    _model.textController2 ??= TextEditingController();
    _model.textFieldFocusNode2 ??= FocusNode();

    _model.textController3 ??= TextEditingController();
    _model.textFieldFocusNode3 ??= FocusNode();

    _model.textController4 ??= TextEditingController();
    _model.textFieldFocusNode4 ??= FocusNode();

    _model.textController5 ??= TextEditingController();
    _model.textFieldFocusNode5 ??= FocusNode();

    _model.textController6 ??= TextEditingController();
    _model.textFieldFocusNode6 ??= FocusNode();

    _model.textController7 ??= TextEditingController();

    _hydrateFromUserRecord(currentUserDocument);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      safeSetState(() {});
      await _refreshExistingRegistrationDraft();
      await _ensureLocationPermissionGranted();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _model.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }
    unawaited(() async {
      final hasPermission = await getPermissionStatus(locationPermission);
      if (!hasPermission && mounted) {
        await _ensureLocationPermissionGranted();
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    String tr(String ru, String kk) => _tr(context, ru: ru, kk: kk);
    final uploading = _model.isDataUploading_uploadData2xm ||
        _model.isDataUploading_techPhoto;
    Future<void> profilePhoto() => _pickAndUploadImage(
          storageFolderPath:
              'users/$currentUserUid/driver_registration/vehicle',
          setUploading: (value) => _model.isDataUploading_uploadData2xm = value,
          setLocalFile: (value) =>
              _model.uploadedLocalFile_uploadData2xm = value,
          setUrl: (value) => _model.uploadedFileUrl_uploadData2xm = value,
          userField: 'avtoImage',
        );
    Future<void> techPhoto() => _pickAndUploadImage(
          storageFolderPath:
              'users/$currentUserUid/driver_registration/tech_passport',
          setUploading: (value) => _model.isDataUploading_techPhoto = value,
          setLocalFile: (value) => _model.uploadedLocalFile_techPhoto = value,
          setUrl: (value) => _model.uploadedFileUrl_techPhoto = value,
          userField: 'techImage',
        );
    return PopScope(
        canPop: _designStep == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_isSubmittingRegistration)
            setState(() => _designStep = 0);
        },
        child: Scaffold(
          appBar: AppBar(
              title: Text(tr('Стать водителем', 'Жүргізуші болу')),
              leading: _designStep == 1
                  ? IconButton(
                      tooltip: tr('Назад', 'Артқа'),
                      onPressed: _isSubmittingRegistration
                          ? null
                          : () => setState(() => _designStep = 0),
                      icon: const Icon(Icons.arrow_back))
                  : null),
          body: SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            tr('Шаг ${_designStep + 1} из 2',
                                '2 қадамның ${_designStep + 1}-қадамы'),
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                            value: (_designStep + 1) / 2,
                            color: MTaxiDesign.gold,
                            backgroundColor: MTaxiDesign.surface),
                        const SizedBox(height: 24),
                        Text(
                            _designStep == 0
                                ? tr(
                                    'Вы и ваш автомобиль', 'Сіз және көлігіңіз')
                                : tr('Проверим документы',
                                    'Құжаттарды тексерейік'),
                            style: const TextStyle(
                                fontSize: 31, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Text(tr(
                            'Анкета попадёт администратору. Заказы откроются после подтверждения.',
                            'Сауалнама әкімшіге жіберіледі. Тапсырыстар растаудан кейін ашылады.')),
                        const SizedBox(height: 24),
                        if (_designStep == 0) ...[
                          TextField(
                              key: _firstNameFieldKey,
                              controller: _model.textController1,
                              enabled: !_isSubmittingRegistration,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                  labelText: tr('Имя и фамилия', 'Аты-жөні'),
                                  errorText: _requiredFieldError(
                                      _model.textController1.text,
                                      tr('Введите имя',
                                          'Атыңызды енгізіңіз')))),
                          const SizedBox(height: 14),
                          TextField(
                              key: _plateFieldKey,
                              controller: _model.textController5,
                              enabled: !_isSubmittingRegistration,
                              inputFormatters: [
                                _KazakhstanPlateInputFormatter()
                              ],
                              decoration: InputDecoration(
                                  labelText:
                                      tr('Госномер', 'Мемлекеттік нөмір'),
                                  hintText: '123 ABC 01',
                                  errorText: _plateFieldError(context))),
                          const SizedBox(height: 14),
                          TextField(
                              key: _carColorFieldKey,
                              controller: _model.textController6,
                              enabled: !_isSubmittingRegistration,
                              decoration: InputDecoration(
                                  labelText:
                                      tr('Цвет автомобиля', 'Көлік түсі'))),
                          const SizedBox(height: 14),
                          FutureBuilder<List<String>>(
                              future: _cities,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState !=
                                    ConnectionState.done)
                                  return const LinearProgressIndicator();
                                final items = snapshot.data ?? [];
                                if (snapshot.hasError || items.isEmpty)
                                  return TextButton.icon(
                                      onPressed: () => setState(
                                          () => _cities = _loadCityTitles()),
                                      icon: const Icon(Icons.refresh),
                                      label: Text(tr(
                                          'Не удалось загрузить посёлки. Повторить',
                                          'Ауылдар жүктелмеді. Қайталау')));
                                final selected = _selectedCity();
                                return DropdownButtonFormField<String>(
                                    initialValue: items.contains(selected)
                                        ? selected
                                        : null,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                        labelText: tr('Город или посёлок',
                                            'Қала немесе ауыл')),
                                    items: [
                                      for (final city in items)
                                        DropdownMenuItem(
                                            value: city, child: Text(city))
                                    ],
                                    onChanged: _isSubmittingRegistration
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _model.textController7.text =
                                                  value ?? '';
                                              _model.textFieldSelectedOption7 =
                                                  value;
                                            });
                                          });
                              }),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                              onPressed: _pickBirthDate,
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: Text(_model.datePicked == null
                                  ? tr('Дата рождения', 'Туған күні')
                                  : dateTimeFormat(
                                      'd/M/y', _model.datePicked))),
                          if (_needsPassword) ...[
                            const SizedBox(height: 14),
                            TextField(
                                key: _passwordFieldKey,
                                controller: _model.textController3,
                                obscureText: true,
                                maxLength: 128,
                                decoration: InputDecoration(
                                    labelText: tr('Пароль', 'Құпиясөз'),
                                    helperText: tr('От 8 до 128 символов',
                                        '8–128 таңба'))),
                            const SizedBox(height: 14),
                            TextField(
                                key: _passwordRepeatFieldKey,
                                controller: _model.textController4,
                                obscureText: true,
                                decoration: InputDecoration(
                                    labelText: tr('Повторите пароль',
                                        'Құпиясөзді қайталаңыз'),
                                    errorText:
                                        _passwordRepeatFieldError(context))),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                              onPressed: () {
                                setState(() => _didAttemptSubmit = true);
                                if (_model.textController1.text
                                        .trim()
                                        .isEmpty ||
                                    _plateFieldError(context) != null ||
                                    _selectedCity().isEmpty ||
                                    (_needsPassword &&
                                        (_model.textController3.text
                                                    .trim()
                                                    .length <
                                                8 ||
                                            _passwordRepeatFieldError(
                                                    context) !=
                                                null))) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text(tr(
                                          'Проверьте имя, номер, посёлок и пароль',
                                          'Аты-жөнін, нөмірін, ауылын және құпиясөзді тексеріңіз'))));
                                  return;
                                }
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  _designStep = 1;
                                  _didAttemptSubmit = false;
                                });
                                unawaited(_saveDriverRegistrationDraft());
                              },
                              child: Text(tr('Продолжить', 'Жалғастыру'))),
                        ] else ...[
                          _buildUploadCard(
                              key: _vehiclePhotoBlockKey,
                              context: context,
                              title: tr('Фото автомобиля',
                                  'Көліктің фотосы'),
                              imageUrl: _model.uploadedFileUrl_uploadData2xm,
                              localFile: _model.uploadedLocalFile_uploadData2xm,
                              errorText: _uploadErrors['avtoImage'] ??
                                  _vehiclePhotoError(context),
                              onTap: profilePhoto,
                              onDelete: () =>
                                  unawaited(_deleteVehiclePhotoFromDraft())),
                          const SizedBox(height: 16),
                          _buildUploadCard(
                              key: _techPhotoBlockKey,
                              context: context,
                              title: tr('Техпаспорт', 'Техпаспорт'),
                              imageUrl: _model.uploadedFileUrl_techPhoto,
                              localFile: _model.uploadedLocalFile_techPhoto,
                              errorText: _uploadErrors['techImage'] ??
                                  _techPhotoError(context),
                              onTap: techPhoto,
                              onDelete: () =>
                                  unawaited(_deleteTechPhotoFromDraft())),
                          const SizedBox(height: 20),
                          MTaxiCard(
                              child: Text(tr(
                                  'Снимки должны быть чёткими, а данные — читаемыми. 1 000 бонусных ₸ начислятся один раз после первого подтверждения анкеты.',
                                  'Суреттер анық, деректер оқылатын болуы керек. 1 000 бонус ₸ сауалнама алғаш расталғаннан кейін бір рет есептеледі.'))),
                          if (uploading)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: LinearProgressIndicator()),
                          const SizedBox(height: 24),
                          FilledButton(
                              onPressed: _isSubmittingRegistration ||
                                      uploading ||
                                      _model.uploadedFileUrl_uploadData2xm
                                          .isEmpty ||
                                      _model.uploadedFileUrl_techPhoto.isEmpty
                                  ? null
                                  : _submitDriverRegistration,
                              child: Text(_isSubmittingRegistration
                                  ? tr('Отправляем…', 'Жіберілуде…')
                                  : tr('Отправить на проверку',
                                      'Тексеруге жіберу'))),
                        ],
                        if (_canReturnToPassengerMode())
                          TextButton(
                              onPressed: _isSubmittingRegistration
                                  ? null
                                  : _returnToPassengerMode,
                              child: Text(tr(
                                  'Вернуться в профиль', 'Профильге оралу'))),
                      ]))),
        ));
  }
}
