import '/auth/backend_auth/auth_util.dart';
import '/backend/app_city_tariffs/app_city_tariffs.dart';
import '/backend/backend.dart';
import '/backend/backend_user_adapter.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/backend/uploads/storage.dart';
import '/flutter_flow/flutter_flow_autocomplete_options_list.dart';
import '/flutter_flow/permissions_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/upload_data.dart';
import '/index.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
import 'set_profile_driver_model.dart';
export 'set_profile_driver_model.dart';
import '/flutter_flow/custom_functions.dart' as functions;

const _mtaxiMint = Color(0xFF28D8C6);
const _mtaxiText = Color(0xFF1E1525);

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
  final _lastNameFieldKey = GlobalKey();
  bool get _needsPassword =>
      currentUserDocument?.snapshotData['hasPassword'] != true;
  final _passwordFieldKey = GlobalKey();
  final _passwordRepeatFieldKey = GlobalKey();
  final _plateFieldKey = GlobalKey();
  final _carColorFieldKey = GlobalKey();
  final _vehiclePhotoBlockKey = GlobalKey();
  final _techPhotoBlockKey = GlobalKey();
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
        ru: 'Добавьте фото профиля водителя',
        kk: 'Жүргізуші профилінің фотосын жүктеңіз',
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
      FFAppState().pendingRegistrationRole = '';
      FFAppState().update(() {});
      currentUserDocument =
          await applyBackendUserResponse(response) ?? currentUserDocument;
      if (!mounted) return;
      await _refreshExistingRegistrationDraft();
      if (!mounted) return;
      await _showMessageDialog(
        context,
        _tr(
          context,
          ru: 'Анкета водителя отправлена на проверку. После подтверждения администратором откроется режим водителя.',
          kk: 'Жүргізуші сауалнамасы тексеруге жіберілді. Әкімші растағаннан кейін жүргізуші режимі ашылады.',
        ),
      );
      if (!mounted) return;
      context.goNamedAuth(
        HomePageWidget.routeName,
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
    safeSetState(() {
      _hydrateFromUserRecord(currentUserDocument);
    });
  }

  Future<bool> _saveDriverRegistrationDraft({
    String? avtoImage,
    String? techImage,
  }) async {
    return true;
  }

  Future<void> _clearDriverRegistrationDraftFields(
    List<String> fieldKeys,
  ) async {}

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
    safeSetState(() => setUploading(true));
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
      safeSetState(() {});
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
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8E2EC);
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
                    font: GoogleFonts.readexPro(
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
              _buildInlineUploadError(context, errorText),
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
    return Image.network(
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

  Widget _buildInlineUploadError(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: FlutterFlowTheme.of(context).error,
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: FlutterFlowTheme.of(context).error,
            size: 18.0,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              message,
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.readexPro(
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).error,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
            ),
          ),
        ],
      ),
    );
  }

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
                  font: GoogleFonts.readexPro(
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
    _model = createModel(context, () => SetProfileDriverModel());

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFEFF2F6);
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final surface2 = isDark ? const Color(0xFF243437) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : _mtaxiText;
    final appBarBg = isDark ? _mtaxiMint : surface;
    final appBarText = isDark ? Colors.white : textColor;
    final ctaTextColor = isDark ? const Color(0xFF071718) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8E2EC);
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        resizeToAvoidBottomInset: true,
        backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: appBarBg,
          iconTheme: IconThemeData(color: appBarText),
          automaticallyImplyLeading: true,
          centerTitle: true,
          elevation: 0,
          title: Text(
            _tr(
              context,
              ru: 'Регистрация водителя',
              kk: 'Жүргізушіні тіркеу',
            ),
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  font: GoogleFonts.outfit(fontWeight: FontWeight.w800),
                  color: appBarText,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        body: SafeArea(
          top: true,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom + 80.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                const SizedBox(height: 28),
                if (_canReturnToPassengerMode() &&
                    MediaQuery.sizeOf(context).width < 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: _isSubmittingRegistration
                            ? null
                            : _returnToPassengerMode,
                        icon: Icon(
                          Icons.arrow_back,
                          color: _mtaxiMint,
                          size: 20.0,
                        ),
                        label: Text(
                          _tr(
                            context,
                            ru: 'Назад в режим пассажира',
                            kk: 'Жолаушы режиміне қайту',
                          ),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.readexPro(
                                      fontWeight: FontWeight.w700,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: _mtaxiMint,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                        ),
                      ),
                    ),
                  ),
                Card(
                  key: _vehiclePhotoBlockKey,
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  color: surface,
                  elevation: 0.0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: _vehiclePhotoError(context) != null
                          ? FlutterFlowTheme.of(context).error
                          : borderColor,
                      width: _vehiclePhotoError(context) != null ? 2.0 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(0.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Text(
                          _tr(
                            context,
                            ru: 'Фото авто',
                            kk: 'Көлік фотосы',
                          ),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.readexPro(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                    color: textColor,
                                  ),
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional(0.0, 0.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                await _pickAndUploadImage(
                                  storageFolderPath:
                                      'users/$currentUserUid/driver_registration/vehicle',
                                  setUploading: (value) => _model
                                      .isDataUploading_uploadData2xm = value,
                                  setLocalFile: (value) => _model
                                      .uploadedLocalFile_uploadData2xm = value,
                                  setUrl: (value) => _model
                                      .uploadedFileUrl_uploadData2xm = value,
                                  userField: 'avtoImage',
                                );
                              },
                              child: Stack(
                                children: [
                                  if (_model.uploadedFileUrl_uploadData2xm ==
                                      '')
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 5.0, 0.0, 0.0),
                                      child: Container(
                                        width: 42.0,
                                        height: 42.0,
                                        decoration: BoxDecoration(
                                          color: surface2,
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                          border: Border.all(
                                            color: _vehiclePhotoError(
                                                        context) !=
                                                    null
                                                ? FlutterFlowTheme.of(context)
                                                    .error
                                                : Colors.transparent,
                                            width:
                                                _vehiclePhotoError(context) !=
                                                        null
                                                    ? 2.0
                                                    : 0.0,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          color: _mtaxiMint,
                                          size: 26.0,
                                        ),
                                      ),
                                    ),
                                  if (_model.uploadedFileUrl_uploadData2xm !=
                                      '')
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: SizedBox(
                                        width: 42.0,
                                        height: 42.0,
                                        child: _buildPreviewImage(
                                          context,
                                          imageUrl: _model
                                              .uploadedFileUrl_uploadData2xm,
                                          localFile: _model
                                              .uploadedLocalFile_uploadData2xm,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (_model.uploadedFileUrl_uploadData2xm != '') ...[
                              const SizedBox(height: 10),
                              _buildUploadSuccessStatus(context),
                              _buildUploadActions(
                                context: context,
                                onReplace: () => _pickAndUploadImage(
                                  storageFolderPath:
                                      'users/$currentUserUid/driver_registration/vehicle',
                                  setUploading: (value) => _model
                                      .isDataUploading_uploadData2xm = value,
                                  setLocalFile: (value) => _model
                                      .uploadedLocalFile_uploadData2xm = value,
                                  setUrl: (value) => _model
                                      .uploadedFileUrl_uploadData2xm = value,
                                  userField: 'avtoImage',
                                ),
                                onDelete: () =>
                                    unawaited(_deleteVehiclePhotoFromDraft()),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_vehiclePhotoError(context) != null)
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
                          child: _buildInlineUploadError(
                            context,
                            _vehiclePhotoError(context)!,
                          ),
                        ),
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 4.0),
                        child: _buildUploadCard(
                          key: _techPhotoBlockKey,
                          context: context,
                          title: _tr(
                            context,
                            ru: 'Техпаспорт',
                            kk: 'Техпаспорт суреті',
                          ),
                          imageUrl: _model.uploadedFileUrl_techPhoto,
                          localFile: _model.uploadedLocalFile_techPhoto,
                          errorText: _techPhotoError(context),
                          onTap: () => _pickAndUploadImage(
                            storageFolderPath:
                                'users/$currentUserUid/driver_registration/tech_passport',
                            setUploading: (value) =>
                                _model.isDataUploading_techPhoto = value,
                            setLocalFile: (value) =>
                                _model.uploadedLocalFile_techPhoto = value,
                            setUrl: (value) =>
                                _model.uploadedFileUrl_techPhoto = value,
                            userField: 'techImage',
                          ),
                          onDelete: () =>
                              unawaited(_deleteTechPhotoFromDraft()),
                        ),
                      ),
                      if (MediaQuery.sizeOf(context).width < 0)
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    15.0, 5.0, 15.0, 0.0),
                                child: Container(
                                  width: MediaQuery.sizeOf(context).width * 0.8,
                                  child: TextFormField(
                                    key: _firstNameFieldKey,
                                    controller: _model.textController1,
                                    focusNode: _model.textFieldFocusNode1,
                                    onChanged: (_) {
                                      if (_didAttemptSubmit)
                                        safeSetState(() {});
                                    },
                                    onTap: () => _scrollFieldIntoView(
                                        _firstNameFieldKey),
                                    autofocus: false,
                                    obscureText: false,
                                    decoration: InputDecoration(
                                      labelText: _tr(
                                        context,
                                        ru: 'Имя и Фамилия',
                                        kk: 'Аты және тегі',
                                      ),
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.always,
                                      errorText: _requiredFieldError(
                                        _model.textController1?.text ?? '',
                                        _tr(
                                          context,
                                          ru: 'Введите имя и фамилию',
                                          kk: 'Атыңыз бен тегіңізді енгізіңіз',
                                        ),
                                      ),
                                      labelStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .override(
                                            font: GoogleFonts.readexPro(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                      hintStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .override(
                                            font: GoogleFonts.readexPro(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .alternate,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      contentPadding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              14.0, 18.0, 14.0, 14.0),
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.readexPro(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                    validator: _model.textController1Validator
                                        .asValidator(context),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (MediaQuery.sizeOf(context).width < 0)
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    15.0, 5.0, 15.0, 0.0),
                                child: Container(
                                  width: MediaQuery.sizeOf(context).width * 0.8,
                                  child: TextFormField(
                                    key: _lastNameFieldKey,
                                    controller: _model.textController2,
                                    focusNode: _model.textFieldFocusNode2,
                                    onChanged: (_) {
                                      if (_didAttemptSubmit)
                                        safeSetState(() {});
                                    },
                                    onTap: () =>
                                        _scrollFieldIntoView(_lastNameFieldKey),
                                    autofocus: false,
                                    obscureText: false,
                                    decoration: InputDecoration(
                                      labelText:
                                          FFLocalizations.of(context).getText(
                                        'e61j3fsj' /* Фамилия */,
                                      ),
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.always,
                                      errorText: _requiredFieldError(
                                        _model.textController2?.text ?? '',
                                        _tr(
                                          context,
                                          ru: 'Введите фамилию',
                                          kk: 'Тегіңізді енгізіңіз',
                                        ),
                                      ),
                                      labelStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .override(
                                            font: GoogleFonts.readexPro(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                      hintStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .override(
                                            font: GoogleFonts.readexPro(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .alternate,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      contentPadding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              14.0, 18.0, 14.0, 14.0),
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.readexPro(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                    validator: _model.textController2Validator
                                        .asValidator(context),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (_needsPassword)
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    15.0, 5.0, 15.0, 0.0),
                                child: Container(
                                  width: MediaQuery.sizeOf(context).width * 0.8,
                                  child: TextFormField(
                                    key: _passwordFieldKey,
                                    controller: _model.textController3,
                                    focusNode: _model.textFieldFocusNode3,
                                    onChanged: (_) {
                                      if (_didAttemptSubmit)
                                        safeSetState(() {});
                                    },
                                    onTap: () =>
                                        _scrollFieldIntoView(_passwordFieldKey),
                                    autofocus: false,
                                    obscureText: !_model.passwordVisibility1,
                                    decoration: InputDecoration(
                                      labelText:
                                          FFLocalizations.of(context).getText(
                                        'z8p3pkmb' /* Придумайте пароль */,
                                      ),
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.always,
                                      errorText: _requiredFieldError(
                                        _model.textController3?.text ?? '',
                                        _tr(
                                          context,
                                          ru: 'Придумайте пароль',
                                          kk: 'Құпиясөз ойлап табыңыз',
                                        ),
                                      ),
                                      labelStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .override(
                                            font: GoogleFonts.readexPro(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                      hintStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .override(
                                            font: GoogleFonts.readexPro(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .alternate,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      contentPadding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              14.0, 18.0, 14.0, 14.0),
                                      suffixIcon: InkWell(
                                        onTap: () async {
                                          safeSetState(() =>
                                              _model.passwordVisibility1 =
                                                  !_model.passwordVisibility1);
                                        },
                                        focusNode:
                                            FocusNode(skipTraversal: true),
                                        child: Icon(
                                          _model.passwordVisibility1
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.readexPro(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                    keyboardType: TextInputType.visiblePassword,
                                    validator: _model.textController3Validator
                                        .asValidator(context),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (_needsPassword)
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    15.0, 5.0, 15.0, 0.0),
                                child: Container(
                                  width: MediaQuery.sizeOf(context).width * 0.8,
                                  child: TextFormField(
                                    key: _passwordRepeatFieldKey,
                                    controller: _model.textController4,
                                    focusNode: _model.textFieldFocusNode4,
                                    onChanged: (_) {
                                      if (_didAttemptSubmit)
                                        safeSetState(() {});
                                    },
                                    onTap: () => _scrollFieldIntoView(
                                        _passwordRepeatFieldKey),
                                    autofocus: false,
                                    obscureText: !_model.passwordVisibility2,
                                    decoration: InputDecoration(
                                      labelText:
                                          FFLocalizations.of(context).getText(
                                        '3u2799x2' /* Повторите пароль */,
                                      ),
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.always,
                                      errorText:
                                          _passwordRepeatFieldError(context),
                                      labelStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .override(
                                            font: GoogleFonts.readexPro(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                      hintStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .override(
                                            font: GoogleFonts.readexPro(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .alternate,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      contentPadding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              14.0, 18.0, 14.0, 14.0),
                                      suffixIcon: InkWell(
                                        onTap: () async {
                                          safeSetState(() =>
                                              _model.passwordVisibility2 =
                                                  !_model.passwordVisibility2);
                                        },
                                        focusNode:
                                            FocusNode(skipTraversal: true),
                                        child: Icon(
                                          _model.passwordVisibility2
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.readexPro(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                    keyboardType: TextInputType.visiblePassword,
                                    validator: _model.textController4Validator
                                        .asValidator(context),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  15.0, 5.0, 15.0, 0.0),
                              child: Container(
                                width: MediaQuery.sizeOf(context).width * 0.8,
                                child: TextFormField(
                                  key: _plateFieldKey,
                                  controller: _model.textController5,
                                  focusNode: _model.textFieldFocusNode5,
                                  onChanged: (_) {
                                    if (_didAttemptSubmit) safeSetState(() {});
                                  },
                                  onTap: () =>
                                      _scrollFieldIntoView(_plateFieldKey),
                                  autofocus: false,
                                  obscureText: false,
                                  decoration: InputDecoration(
                                    labelText:
                                        FFLocalizations.of(context).getText(
                                      'otwuet73' /* Гос. Номер */,
                                    ),
                                    hintText: '123 ABC 01',
                                    floatingLabelBehavior:
                                        FloatingLabelBehavior.always,
                                    errorText: _plateFieldError(context),
                                    labelStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .override(
                                          font: GoogleFonts.readexPro(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontStyle,
                                        ),
                                    hintStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .override(
                                          font: GoogleFonts.readexPro(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontStyle,
                                        ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                        width: 2.0,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context)
                                            .primary,
                                        width: 2.0,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color:
                                            FlutterFlowTheme.of(context).error,
                                        width: 2.0,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color:
                                            FlutterFlowTheme.of(context).error,
                                        width: 2.0,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    contentPadding:
                                        EdgeInsetsDirectional.fromSTEB(
                                            14.0, 18.0, 14.0, 14.0),
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.readexPro(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  inputFormatters: [
                                    _KazakhstanPlateInputFormatter(),
                                  ],
                                  validator: _model.textController5Validator
                                      .asValidator(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  15.0, 5.0, 15.0, 0.0),
                              child: Container(
                                width: MediaQuery.sizeOf(context).width * 0.8,
                                child: TextFormField(
                                  key: _carColorFieldKey,
                                  controller: _model.textController6,
                                  focusNode: _model.textFieldFocusNode6,
                                  onChanged: (_) {
                                    if (_didAttemptSubmit) safeSetState(() {});
                                  },
                                  onTap: () =>
                                      _scrollFieldIntoView(_carColorFieldKey),
                                  autofocus: false,
                                  obscureText: false,
                                  decoration: InputDecoration(
                                    labelText:
                                        FFLocalizations.of(context).getText(
                                      '77se37qq' /* Цвет авто */,
                                    ),
                                    floatingLabelBehavior:
                                        FloatingLabelBehavior.always,
                                    errorText: _requiredFieldError(
                                      _model.textController6?.text ?? '',
                                      _tr(
                                        context,
                                        ru: 'Введите цвет авто',
                                        kk: 'Көлік түсін енгізіңіз',
                                      ),
                                    ),
                                    labelStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .override(
                                          font: GoogleFonts.readexPro(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontStyle,
                                        ),
                                    hintStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .override(
                                          font: GoogleFonts.readexPro(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontStyle,
                                        ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                        width: 2.0,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context)
                                            .primary,
                                        width: 2.0,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color:
                                            FlutterFlowTheme.of(context).error,
                                        width: 2.0,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color:
                                            FlutterFlowTheme.of(context).error,
                                        width: 2.0,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    contentPadding:
                                        EdgeInsetsDirectional.fromSTEB(
                                            14.0, 18.0, 14.0, 14.0),
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.readexPro(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                  validator: _model.textController6Validator
                                      .asValidator(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: FutureBuilder<List<String>>(
                                future: _loadCityTitles(),
                                builder: (context, snapshot) {
                                  // Customize what your widget looks like when it's loading.
                                  if (!snapshot.hasData) {
                                    return Center(
                                      child: SizedBox(
                                        width: 50.0,
                                        height: 50.0,
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            FlutterFlowTheme.of(context)
                                                .primary,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final cityTitles =
                                      snapshot.data ?? const <String>[];

                                  return Autocomplete<String>(
                                    initialValue: TextEditingValue(
                                      text: _model.textController7?.text ?? '',
                                    ),
                                    optionsBuilder: (textEditingValue) {
                                      if (textEditingValue.text == '') {
                                        return const Iterable<String>.empty();
                                      }
                                      return cityTitles.where((option) {
                                        final lowercaseOption =
                                            option.toLowerCase();
                                        return lowercaseOption.contains(
                                            textEditingValue.text
                                                .toLowerCase());
                                      });
                                    },
                                    optionsViewBuilder:
                                        (context, onSelected, options) {
                                      return AutocompleteOptionsList(
                                        textFieldKey: _model.textFieldKey7,
                                        textController: _model.textController7!,
                                        options: options.toList(),
                                        onSelected: onSelected,
                                        textStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.readexPro(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                        textHighlightStyle: TextStyle(),
                                        elevation: 4.0,
                                        optionBackgroundColor: surface,
                                        optionHighlightColor:
                                            FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                        maxHeight: (MediaQuery.sizeOf(context)
                                                    .height -
                                                MediaQuery.viewInsetsOf(context)
                                                    .bottom -
                                                220.0)
                                            .clamp(160.0, 360.0)
                                            .toDouble(),
                                      );
                                    },
                                    onSelected: (String selection) {
                                      safeSetState(() =>
                                          _model.textFieldSelectedOption7 =
                                              selection);
                                      FocusScope.of(context).unfocus();
                                    },
                                    fieldViewBuilder: (
                                      context,
                                      textEditingController,
                                      focusNode,
                                      onEditingComplete,
                                    ) {
                                      _model.textFieldFocusNode7 = focusNode;

                                      _model.textController7 =
                                          textEditingController;
                                      return TextFormField(
                                        key: _model.textFieldKey7,
                                        controller: textEditingController,
                                        focusNode: focusNode,
                                        onTap: () => _scrollFieldIntoView(
                                            _model.textFieldKey7),
                                        onEditingComplete: onEditingComplete,
                                        autofocus: false,
                                        obscureText: false,
                                        decoration: InputDecoration(
                                          labelText: _tr(
                                            context,
                                            ru: 'Населенный пункт',
                                            kk: 'Елді мекен',
                                          ),
                                          floatingLabelBehavior:
                                              FloatingLabelBehavior.always,
                                          errorText: _didAttemptSubmit &&
                                                  _selectedCity().isEmpty
                                              ? _tr(
                                                  context,
                                                  ru: 'Выберите город из списка',
                                                  kk: 'Тізімнен қалаңызды таңдаңыз',
                                                )
                                              : null,
                                          labelStyle: FlutterFlowTheme.of(
                                                  context)
                                              .labelMedium
                                              .override(
                                                font: GoogleFonts.readexPro(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                          hintStyle: FlutterFlowTheme.of(
                                                  context)
                                              .labelMedium
                                              .override(
                                                font: GoogleFonts.readexPro(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelMedium
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .alternate,
                                              width: 2.0,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                              width: 2.0,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .error,
                                              width: 2.0,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                          ),
                                          focusedErrorBorder:
                                              OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .error,
                                              width: 2.0,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                          ),
                                          contentPadding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  14.0, 18.0, 14.0, 14.0),
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.readexPro(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                        validator: _model
                                            .textController7Validator
                                            .asValidator(context),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (MediaQuery.sizeOf(context).width < 0)
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    15.0, 10.0, 15.0, 0.0),
                                child: InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: _pickBirthDate,
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText:
                                          FFLocalizations.of(context).getText(
                                        'jae81zbb' /* Дата рождения */,
                                      ),
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.always,
                                      errorText: _didAttemptSubmit &&
                                              _model.datePicked == null
                                          ? _tr(
                                              context,
                                              ru: 'Введите дату рождения',
                                              kk: 'Туған күніңізді енгізіңіз',
                                            )
                                          : null,
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .alternate,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .alternate,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      contentPadding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              14.0, 14.0, 14.0, 14.0),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _model.datePicked == null
                                                ? 'Выберите дату'
                                                : dateTimeFormat(
                                                    "d/M/y",
                                                    _model.datePicked,
                                                    locale: FFLocalizations.of(
                                                            context)
                                                        .languageCode,
                                                  ),
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: GoogleFonts.readexPro(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                  ),
                                                  color:
                                                      _model.datePicked == null
                                                          ? FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText
                                                          : FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.calendar_month_outlined,
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          size: 24.0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(80, 205, 80, 30),
                        child: FFButtonWidget(
                          onPressed: _isSubmittingRegistration
                              ? null
                              : _submitDriverRegistration,
                          text: _isSubmittingRegistration
                              ? _tr(
                                  context,
                                  ru: 'Отправляем анкету...',
                                  kk: 'Сауалнаманы жіберіп жатырмыз...',
                                )
                              : _tr(
                                  context,
                                  ru: 'Далее',
                                  kk: 'Әрі қарай',
                                ),
                          options: FFButtonOptions(
                            height: 54.0,
                            padding: EdgeInsetsDirectional.fromSTEB(
                                24.0, 0.0, 24.0, 0.0),
                            iconPadding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            color: _mtaxiMint,
                            textStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  font: GoogleFonts.readexPro(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                                  color: ctaTextColor,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w800,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                            elevation: 0.0,
                            borderSide: BorderSide(
                              color: Colors.transparent,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
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
