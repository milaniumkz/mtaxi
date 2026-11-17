import '/backend/uploads/mtaxi_network_image.dart';
import '/auth/backend_auth/auth_util.dart';
import '/backend/app_city_tariffs/app_city_tariffs.dart';
import '/backend/backend.dart';
import '/backend/backend_user_adapter.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/backend/uploads/storage.dart';
import '/backend/order_state_compat.dart';
import '/flutter_flow/flutter_flow_autocomplete_options_list.dart';
import '/flutter_flow/permissions_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/upload_data.dart';
import 'dart:async';
import '/index.dart';
import 'package:flutter/material.dart';

import 'package:webviewx_plus/webviewx_plus.dart';
import 'set_profile_model.dart';
export 'set_profile_model.dart';
import '/flutter_flow/custom_functions.dart' as functions;

const _mtaxiMint = Color(0xFF126E68);
const _mtaxiMuted = Color(0xFF5C6862);

class SetProfileWidget extends StatefulWidget {
  const SetProfileWidget({super.key});

  static String routeName = 'setProfile';
  static String routePath = '/setProfile';

  @override
  State<SetProfileWidget> createState() => _SetProfileWidgetState();
}

class _SetProfileWidgetState extends State<SetProfileWidget>
    with WidgetsBindingObserver {
  late SetProfileModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  Future<List<String>> _loadCityTitles() async {
    return loadAppCityTitles();
  }

  final _fullNameFieldKey = GlobalKey();
  final _passwordFieldKey = GlobalKey();
  final _passwordRepeatFieldKey = GlobalKey();
  bool _isSubmittingRegistration = false;
  bool get _needsPassword =>
      currentUserDocument?.snapshotData['hasPassword'] != true;

  String _tr({
    required String ru,
    required String kk,
  }) {
    return FFLocalizations.of(context).getVariableText(
      ruText: ru,
      kkText: kk,
    );
  }

  bool _hasValidFullName(String value) {
    return value
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .length >=
        2;
  }

  String? _passwordRepeatFieldError() {
    if (!_needsPassword) return null;
    final password = _model.passwordController?.text ?? '';
    final repeat = _model.passwordRepeatController?.text ?? '';
    if (repeat.trim().isEmpty) {
      return _tr(
        ru: 'Повторите пароль',
        kk: 'Құпиясөзді қайталаңыз',
      );
    }
    if (password != repeat) {
      return _tr(
        ru: 'Пароли не совпадают',
        kk: 'Құпиясөздер сәйкес емес',
      );
    }
    return null;
  }

  String _resolvedPhoneNumber() {
    final appStatePhone = FFAppState().phone.trim();
    if (appStatePhone.isNotEmpty) {
      return appStatePhone;
    }
    final snapshot = currentUserDocument?.snapshotData;
    final snapshotPhone = (snapshot?['phone_number'] ?? '').toString().trim();
    if (snapshotPhone.isNotEmpty) {
      return snapshotPhone;
    }
    final snapshotPhoneNumber =
        (snapshot?['phoneNumber'] ?? '').toString().trim();
    if (snapshotPhoneNumber.isNotEmpty) {
      return snapshotPhoneNumber;
    }
    return currentPhoneNumber.trim();
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
    final selected = (_model.textFieldSelectedOption2 ?? '').trim();
    final typed = (_model.textController2?.text ?? '').trim();
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

  void _hydrateFromUserRecord(UsersRecord? user) {
    if (user == null) {
      return;
    }
    final displayName = _registrationDisplayName(user);
    if ((_model.textController1?.text ?? '').trim().isEmpty &&
        displayName.isNotEmpty) {
      _model.textController1?.text = displayName;
    }
    final city = (user.city).trim();
    if ((_model.textController2?.text ?? '').trim().isEmpty &&
        city.isNotEmpty) {
      _model.textController2?.text = city;
      _model.textFieldSelectedOption2 = city;
    }
    _model.uploadedFileUrl_uploadData9bb =
        _model.uploadedFileUrl_uploadData9bb.isNotEmpty
            ? _model.uploadedFileUrl_uploadData9bb
            : (user.photoUrl).trim();
  }

  Future<void> _leaveRegistrationIfAlreadyReady() async {
    DocumentReference? activeOrderRef;
    try {
      activeOrderRef = await recoverActivePassengerOrderRefFromServer();
    } catch (_) {
      activeOrderRef = getEffectivePassengerOrderRef(currentUserDocument);
    }
    if (!mounted) {
      return;
    }
    if (activeOrderRef != null &&
        !FFAppState().shouldIgnorePassengerOrderRef(activeOrderRef)) {
      FFAppState().pendingRegistrationRole = '';
      FFAppState().clearIgnoredPassengerOrderRef(activeOrderRef.path);
      FFAppState().allowPassengerWaitingScreen(activeOrderRef);
      FFAppState().syncLegacyOrderRefs(
        passengerOrderRef: activeOrderRef,
        driverOrderRef: getEffectiveDriverLegacyOrderRef(),
      );
      FFAppState().clearPassengerOrderCreationState();
      FFAppState().update(() {});
      context.goNamed(
        SeachDriverWidget.routeName,
        queryParameters: {
          'orderDocPath': activeOrderRef.path,
        },
      );
      return;
    }
    if (hasCompletedPassengerProfile(currentUserDocument)) {
      FFAppState().pendingRegistrationRole = '';
      FFAppState().update(() {});
      context.goNamed(HomePageWidget.routeName);
    }
  }

  Future<void> _refreshExistingRegistrationDraft() async {
    safeSetState(() {
      _hydrateFromUserRecord(currentUserDocument);
    });
  }

  Future<void> _showSaveErrorDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (alertDialogContext) {
        return WebViewAware(
          child: AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(alertDialogContext),
                child: Text(_tr(ru: 'Ок', kk: 'Жарайды')),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitPassengerRegistration() async {
    if (_isSubmittingRegistration) {
      return;
    }
    safeSetState(() {});

    final fullName = _model.textController1.text.trim();
    final selectedCity = _selectedCity();
    final password = _model.passwordController.text.trim();
    if (!_hasValidFullName(fullName)) {
      _scrollFieldIntoView(_fullNameFieldKey);
      await _showSaveErrorDialog(
        _tr(
          ru: 'Введите имя и фамилию',
          kk: 'Аты-жөніңізді енгізіңіз',
        ),
      );
      return;
    }
    if (selectedCity.isEmpty) {
      await _showSaveErrorDialog(
        _tr(
          ru: 'Выберите свой город или поселок из списка',
          kk: 'Тізімнен қалаңызды немесе ауылыңызды таңдаңыз',
        ),
      );
      return;
    }
    if (_needsPassword && password.length < 8) {
      _scrollFieldIntoView(_passwordFieldKey);
      await _showSaveErrorDialog(
        _tr(
          ru: 'Пароль должен быть минимум 8 символов',
          kk: 'Құпиясөз ойлап табыңыз',
        ),
      );
      return;
    }
    final passwordRepeatError = _passwordRepeatFieldError();
    if (passwordRepeatError != null) {
      _scrollFieldIntoView(_passwordRepeatFieldKey);
      await _showSaveErrorDialog(passwordRepeatError);
      return;
    }
    final passengerPhotoUrl = _model.uploadedFileUrl_uploadData9bb.trim();
    final existingUserId =
        valueOrDefault(currentUserDocument?.snapshotData['userId'], '');
    final userId = existingUserId.toString().isNotEmpty
        ? existingUserId.toString()
        : functions.generateUserId();

    safeSetState(() {
      _isSubmittingRegistration = true;
    });
    try {
      final response = await makeCloudCall(
        'submitPassengerRegistration',
        {
          'displayName': fullName,
          'city': selectedCity,
          'photoUrl': passengerPhotoUrl,
          'phoneNumber': _resolvedPhoneNumber(),
          'userId': userId,
          'password': password,
        },
        timeout: const Duration(seconds: 15),
      );
      if (response['success'] != true) {
        final error = (response['error'] ?? '').toString().trim();
        throw Exception(
          error.isNotEmpty
              ? error
              : _tr(
                  ru: 'Не удалось сохранить профиль',
                  kk: 'Профильді сақтау мүмкін болмады',
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
      context.goNamedAuth(
        HomePageWidget.routeName,
        context.mounted,
        extra: <String, dynamic>{
          kTransitionInfoKey: TransitionInfo(
            hasTransition: true,
            transitionType: PageTransitionType.scale,
            alignment: Alignment.bottomCenter,
          ),
        },
      );
    } catch (e) {
      if (!mounted) return;
      await _showSaveErrorDialog(
        e.toString().replaceFirst('Exception: ', '').trim().isNotEmpty
            ? e.toString().replaceFirst('Exception: ', '').trim()
            : _tr(
                ru: 'Не удалось сохранить профиль. Проверьте интернет и попробуйте еще раз.',
                kk: 'Профильді сақтау мүмкін болмады. Интернетті тексеріп, қайталап көріңіз.',
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

  Future<bool> _savePassengerRegistrationDraft({
    String? photoUrl,
  }) async {
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      final response = await makeCloudCall(
        'updateUserPreferences',
        {'photoUrl': photoUrl.trim()},
      );
      if (response['success'] == true) {
        currentUserDocument =
            await applyBackendUserResponse(response) ?? currentUserDocument;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _model = createModel(context, () => SetProfileModel());

    _model.textController1 ??= TextEditingController();
    _model.textFieldFocusNode1 ??= FocusNode();

    _model.textController2 ??= TextEditingController();
    _model.passwordController ??= TextEditingController();
    _model.passwordFocusNode ??= FocusNode();

    _model.passwordRepeatController ??= TextEditingController();
    _model.passwordRepeatFocusNode ??= FocusNode();
    _hydrateFromUserRecord(currentUserDocument);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      safeSetState(() {});
      await _leaveRegistrationIfAlreadyReady();
      if (!mounted) {
        return;
      }
      await _refreshExistingRegistrationDraft();
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
        safeSetState(() {});
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFFCFCFA);
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : const Color(0xFF1B242B);
    final appBarBg = isDark ? _mtaxiMint : surface;
    final appBarText = isDark ? Colors.white : textColor;
    const ctaTextColor = Color(0xFF1B242B);
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;
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
              ru: 'Регистрация пассажира',
              kk: 'Жолаушыны тіркеу',
            ),
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  font: TextStyle(
                      fontFamily: 'Noto Sans', fontWeight: FontWeight.w800),
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
                Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAliasWithSaveLayer,
                      color: Colors.transparent,
                      elevation: 0.0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide.none,
                        borderRadius: BorderRadius.circular(0.0),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.start,
                            runSpacing: 8.0,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12.0,
                                      right: 12.0,
                                      top: 8.0,
                                      bottom: 4.0,
                                    ),
                                    child: Text(
                                      _tr(
                                        ru: 'Фото профиля',
                                        kk: 'Профиль суреті (міндетті емес)',
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .override(
                                            font: TextStyle(
                                              fontFamily: 'Noto Sans',
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontStyle,
                                            ),
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodySmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodySmall
                                                    .fontStyle,
                                            color: mutedColor,
                                          ),
                                    ),
                                  ),
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      if (currentUserUid.trim().isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Сначала войдите в аккаунт заново и повторите попытку',
                                            ),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                        return;
                                      }
                                      final selectedMedia =
                                          await selectMediaWithSourceBottomSheet(
                                        context: context,
                                        allowPhoto: true,
                                        maxWidth: 1400.0,
                                        maxHeight: 1400.0,
                                        imageQuality: 78,
                                      );
                                      if (selectedMedia != null &&
                                          selectedMedia.every((m) =>
                                              validateFileFormat(
                                                  m.storagePath, context))) {
                                        showUploadMessage(
                                          context,
                                          _tr(
                                            ru: 'Загружаем фото...',
                                            kk: 'Фото жүктелуде...',
                                          ),
                                          showLoading: true,
                                        );
                                        safeSetState(() => _model
                                                .isDataUploading_uploadData9bb =
                                            true);
                                        var selectedUploadedFiles =
                                            <FFUploadedFile>[];

                                        var downloadUrls = <String>[];
                                        String? uploadError;
                                        try {
                                          selectedUploadedFiles = selectedMedia
                                              .map((m) => FFUploadedFile(
                                                    name: m.storagePath
                                                        .split('/')
                                                        .last,
                                                    bytes: m.bytes,
                                                    height:
                                                        m.dimensions?.height,
                                                    width: m.dimensions?.width,
                                                    blurHash: m.blurHash,
                                                    originalFilename:
                                                        m.originalFilename,
                                                  ))
                                              .toList();

                                          downloadUrls = (await Future.wait(
                                            selectedMedia.map(
                                              (m) async => await uploadData(
                                                  m.storagePath, m.bytes),
                                            ),
                                          ))
                                              .where((u) => u != null)
                                              .map((u) => u!)
                                              .toList();
                                        } catch (e) {
                                          uploadError = e
                                              .toString()
                                              .replaceFirst('Exception: ', '')
                                              .trim();
                                        } finally {
                                          _model.isDataUploading_uploadData9bb =
                                              false;
                                          ScaffoldMessenger.of(context)
                                              .hideCurrentSnackBar();
                                        }
                                        if (uploadError == null &&
                                            selectedUploadedFiles.length ==
                                                selectedMedia.length &&
                                            downloadUrls.length ==
                                                selectedMedia.length) {
                                          safeSetState(() {
                                            _model.uploadedLocalFile_uploadData9bb =
                                                selectedUploadedFiles.first;
                                            _model.uploadedFileUrl_uploadData9bb =
                                                downloadUrls.first;
                                          });
                                          final draftSaved =
                                              await _savePassengerRegistrationDraft(
                                            photoUrl: downloadUrls.first,
                                          );
                                          await _refreshExistingRegistrationDraft();
                                          if (!draftSaved) {
                                            return;
                                          }
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                _tr(
                                                  ru: 'Фото загружено',
                                                  kk: 'Фото жүктелді',
                                                ),
                                              ),
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        } else {
                                          safeSetState(() {});
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                uploadError?.isNotEmpty == true
                                                    ? uploadError!
                                                    : 'Не удалось загрузить фото профиля',
                                              ),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                          return;
                                        }
                                      }
                                    },
                                    child: Container(
                                      width: 42.0,
                                      height: 42.0,
                                      child: Stack(
                                        children: [
                                          if (_model
                                                  .uploadedFileUrl_uploadData9bb !=
                                              '')
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              child:
                                                  ((_model.uploadedLocalFile_uploadData9bb
                                                                  .bytes ??
                                                              Uint8List(0))
                                                          .isNotEmpty)
                                                      ? Image.memory(
                                                          _model.uploadedLocalFile_uploadData9bb
                                                                  .bytes ??
                                                              Uint8List(0),
                                                          width: 42.0,
                                                          height: 42.0,
                                                          fit: BoxFit.cover,
                                                        )
                                                      : MTaxiNetworkImage(
                                                          _model
                                                              .uploadedFileUrl_uploadData9bb,
                                                          width: 42.0,
                                                          height: 42.0,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (
                                                            _,
                                                            __,
                                                            ___,
                                                          ) =>
                                                              Icon(
                                                            Icons
                                                                .broken_image_outlined,
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .secondaryText,
                                                            size: 36.0,
                                                          ),
                                                        ),
                                            ),
                                          if (_model
                                                  .uploadedFileUrl_uploadData9bb ==
                                              '')
                                            Padding(
                                              padding: EdgeInsets.all(5.0),
                                              child: Container(
                                                width: 42.0,
                                                height: 42.0,
                                                decoration: BoxDecoration(
                                                  color: Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0),
                                                ),
                                                child: Icon(
                                                  Icons.add,
                                                  color: _mtaxiMint,
                                                  size: 28.0,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Container(
                                    width: (MediaQuery.sizeOf(context).width -
                                            32.0)
                                        .clamp(220.0, 360.0)
                                        .toDouble(),
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 10.0, 0.0, 0.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    8.0, 0.0, 8.0, 0.0),
                                            child: TextFormField(
                                              key: _fullNameFieldKey,
                                              controller:
                                                  _model.textController1,
                                              focusNode:
                                                  _model.textFieldFocusNode1,
                                              onTap: () => _scrollFieldIntoView(
                                                  _fullNameFieldKey),
                                              autofocus: false,
                                              obscureText: false,
                                              decoration: InputDecoration(
                                                labelText:
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                  'ub7rn9v5' /* Имя и Фамилия */,
                                                ),
                                                floatingLabelBehavior:
                                                    FloatingLabelBehavior
                                                        .always,
                                                labelStyle: FlutterFlowTheme.of(
                                                        context)
                                                    .labelMedium
                                                    .override(
                                                      font: TextStyle(
                                                        fontFamily: 'Noto Sans',
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
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      letterSpacing: 0.0,
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
                                                hintStyle: FlutterFlowTheme.of(
                                                        context)
                                                    .labelMedium
                                                    .override(
                                                      font: TextStyle(
                                                        fontFamily: 'Noto Sans',
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
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      letterSpacing: 0.0,
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
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .alternate,
                                                    width: 2.0,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primary,
                                                    width: 2.0,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0),
                                                ),
                                                errorBorder: OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .error,
                                                    width: 2.0,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0),
                                                ),
                                                focusedErrorBorder:
                                                    OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .error,
                                                    width: 2.0,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0),
                                                ),
                                                contentPadding:
                                                    EdgeInsetsDirectional
                                                        .fromSTEB(14.0, 18.0,
                                                            14.0, 14.0),
                                              ),
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: TextStyle(
                                                          fontFamily:
                                                              'Noto Sans',
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
                                              validator: _model
                                                  .textController1Validator
                                                  .asValidator(context),
                                            ),
                                          ),
                                          Padding(
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
                                                      child:
                                                          CircularProgressIndicator(
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                Color>(
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }
                                                final cityTitles =
                                                    snapshot.data ??
                                                        const <String>[];

                                                return Autocomplete<String>(
                                                  initialValue:
                                                      TextEditingValue(),
                                                  optionsBuilder:
                                                      (textEditingValue) {
                                                    if (textEditingValue.text ==
                                                        '') {
                                                      return const Iterable<
                                                          String>.empty();
                                                    }
                                                    return cityTitles
                                                        .where((option) {
                                                      final lowercaseOption =
                                                          option.toLowerCase();
                                                      return lowercaseOption
                                                          .contains(
                                                              textEditingValue
                                                                  .text
                                                                  .toLowerCase());
                                                    });
                                                  },
                                                  optionsViewBuilder: (context,
                                                      onSelected, options) {
                                                    return AutocompleteOptionsList(
                                                      textFieldKey:
                                                          _model.textFieldKey2,
                                                      textController: _model
                                                          .textController2!,
                                                      options: options.toList(),
                                                      onSelected: onSelected,
                                                      textStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                font: TextStyle(
                                                                  fontFamily:
                                                                      'Noto Sans',
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                              ),
                                                      textHighlightStyle:
                                                          TextStyle(),
                                                      elevation: 4.0,
                                                      optionBackgroundColor:
                                                          surface,
                                                      optionHighlightColor:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryBackground,
                                                      maxHeight: (MediaQuery
                                                                      .sizeOf(
                                                                          context)
                                                                  .height -
                                                              MediaQuery.viewInsetsOf(
                                                                      context)
                                                                  .bottom -
                                                              220.0)
                                                          .clamp(160.0, 300.0)
                                                          .toDouble(),
                                                    );
                                                  },
                                                  onSelected:
                                                      (String selection) {
                                                    safeSetState(() => _model
                                                            .textFieldSelectedOption2 =
                                                        selection);
                                                    FocusScope.of(context)
                                                        .unfocus();
                                                  },
                                                  fieldViewBuilder: (
                                                    context,
                                                    textEditingController,
                                                    focusNode,
                                                    onEditingComplete,
                                                  ) {
                                                    _model.textFieldFocusNode2 =
                                                        focusNode;

                                                    _model.textController2 =
                                                        textEditingController;
                                                    return TextFormField(
                                                      key: _model.textFieldKey2,
                                                      controller:
                                                          textEditingController,
                                                      focusNode: focusNode,
                                                      onTap: () =>
                                                          _scrollFieldIntoView(
                                                              _model
                                                                  .textFieldKey2),
                                                      onEditingComplete:
                                                          onEditingComplete,
                                                      autofocus: false,
                                                      obscureText: false,
                                                      decoration:
                                                          InputDecoration(
                                                        labelText:
                                                            FFLocalizations.of(
                                                                    context)
                                                                .getText(
                                                          '095kee8w' /* Населенный пункт */,
                                                        ),
                                                        floatingLabelBehavior:
                                                            FloatingLabelBehavior
                                                                .always,
                                                        labelStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .override(
                                                                  font:
                                                                      TextStyle(
                                                                    fontFamily:
                                                                        'Noto Sans',
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontStyle,
                                                                ),
                                                        hintStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .override(
                                                                  font:
                                                                      TextStyle(
                                                                    fontFamily:
                                                                        'Noto Sans',
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontStyle,
                                                                ),
                                                        enabledBorder:
                                                            OutlineInputBorder(
                                                          borderSide:
                                                              BorderSide(
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .alternate,
                                                            width: 2.0,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        focusedBorder:
                                                            OutlineInputBorder(
                                                          borderSide:
                                                              BorderSide(
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .primary,
                                                            width: 2.0,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        errorBorder:
                                                            OutlineInputBorder(
                                                          borderSide:
                                                              BorderSide(
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .error,
                                                            width: 2.0,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        focusedErrorBorder:
                                                            OutlineInputBorder(
                                                          borderSide:
                                                              BorderSide(
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .error,
                                                            width: 2.0,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        contentPadding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    14.0,
                                                                    18.0,
                                                                    14.0,
                                                                    14.0),
                                                      ),
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                font: TextStyle(
                                                                  fontFamily:
                                                                      'Noto Sans',
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                              ),
                                                      validator: _model
                                                          .textController2Validator
                                                          .asValidator(context),
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                          if (_needsPassword)
                                            Padding(
                                              padding:
                                                  const EdgeInsetsDirectional
                                                      .fromSTEB(
                                                      8.0, 0.0, 8.0, 8.0),
                                              child: TextFormField(
                                                key: _passwordFieldKey,
                                                controller:
                                                    _model.passwordController,
                                                focusNode:
                                                    _model.passwordFocusNode,
                                                onTap: () =>
                                                    _scrollFieldIntoView(
                                                        _passwordFieldKey),
                                                autofocus: false,
                                                obscureText:
                                                    !_model.passwordVisibility,
                                                decoration: InputDecoration(
                                                  labelText: _tr(
                                                    ru: 'Пароль должен быть минимум 8 символов',
                                                    kk: 'Құпиясөз ойлап табыңыз',
                                                  ),
                                                  floatingLabelBehavior:
                                                      FloatingLabelBehavior
                                                          .always,
                                                  labelStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: TextStyle(
                                                          fontFamily:
                                                              'Noto Sans',
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        letterSpacing: 0.0,
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .alternate,
                                                      width: 2.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 2.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 2.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 2.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsetsDirectional
                                                          .fromSTEB(14.0, 18.0,
                                                          14.0, 14.0),
                                                  suffixIcon: InkWell(
                                                    onTap: () => safeSetState(
                                                      () => _model
                                                              .passwordVisibility =
                                                          !_model
                                                              .passwordVisibility,
                                                    ),
                                                    focusNode: FocusNode(
                                                        skipTraversal: true),
                                                    child: Icon(
                                                      _model.passwordVisibility
                                                          ? Icons
                                                              .visibility_outlined
                                                          : Icons
                                                              .visibility_off_outlined,
                                                      size: 22.0,
                                                    ),
                                                  ),
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          font: TextStyle(
                                                            fontFamily:
                                                                'Noto Sans',
                                                          ),
                                                          letterSpacing: 0.0,
                                                        ),
                                                keyboardType: TextInputType
                                                    .visiblePassword,
                                                validator: _model
                                                    .passwordControllerValidator
                                                    .asValidator(context),
                                              ),
                                            ),
                                          if (_needsPassword)
                                            Padding(
                                              padding:
                                                  const EdgeInsetsDirectional
                                                      .fromSTEB(
                                                      8.0, 0.0, 8.0, 0.0),
                                              child: TextFormField(
                                                key: _passwordRepeatFieldKey,
                                                controller: _model
                                                    .passwordRepeatController,
                                                focusNode: _model
                                                    .passwordRepeatFocusNode,
                                                onTap: () =>
                                                    _scrollFieldIntoView(
                                                        _passwordRepeatFieldKey),
                                                autofocus: false,
                                                obscureText: !_model
                                                    .passwordRepeatVisibility,
                                                decoration: InputDecoration(
                                                  labelText: _tr(
                                                    ru: 'Повторите пароль',
                                                    kk: 'Құпиясөзді қайталаңыз',
                                                  ),
                                                  floatingLabelBehavior:
                                                      FloatingLabelBehavior
                                                          .always,
                                                  labelStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: TextStyle(
                                                          fontFamily:
                                                              'Noto Sans',
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        letterSpacing: 0.0,
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .alternate,
                                                      width: 2.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 2.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 2.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 2.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsetsDirectional
                                                          .fromSTEB(14.0, 18.0,
                                                          14.0, 14.0),
                                                  suffixIcon: InkWell(
                                                    onTap: () => safeSetState(
                                                      () => _model
                                                              .passwordRepeatVisibility =
                                                          !_model
                                                              .passwordRepeatVisibility,
                                                    ),
                                                    focusNode: FocusNode(
                                                        skipTraversal: true),
                                                    child: Icon(
                                                      _model.passwordRepeatVisibility
                                                          ? Icons
                                                              .visibility_outlined
                                                          : Icons
                                                              .visibility_off_outlined,
                                                      size: 22.0,
                                                    ),
                                                  ),
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          font: TextStyle(
                                                            fontFamily:
                                                                'Noto Sans',
                                                          ),
                                                          letterSpacing: 0.0,
                                                        ),
                                                keyboardType: TextInputType
                                                    .visiblePassword,
                                                validator: _model
                                                    .passwordRepeatControllerValidator
                                                    .asValidator(context),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(80, 220, 80, 30),
                            child: FFButtonWidget(
                              onPressed: _isSubmittingRegistration
                                  ? null
                                  : _submitPassengerRegistration,
                              text: _isSubmittingRegistration
                                  ? _tr(
                                      ru: 'Сохраняем профиль...',
                                      kk: 'Профиль сақталып жатыр...',
                                    )
                                  : FFLocalizations.of(context).getText(
                                      'seq0y5x9' /* Далее */,
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
                                      font: TextStyle(
                                        fontFamily: 'Noto Sans',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
