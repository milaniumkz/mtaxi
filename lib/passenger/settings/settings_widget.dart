import '/auth/backend_auth/auth_util.dart';
import '/backend/app_city_tariffs/app_city_tariffs.dart';
import '/backend/backend_user_adapter.dart';
import '/backend/backend_calls/backend_calls.dart';
import '/backend/push_notifications/push_notifications_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'settings_model.dart';
export 'settings_model.dart';

const _mtaxiText = Color(0xFF1B242B);
const _mtaxiMuted = Color(0xFF5C6862);
const _mtaxiMint = Color(0xFF126E68);
const _mtaxiOrange = Color(0xFFE6BD63);

class SettingsWidget extends StatefulWidget {
  const SettingsWidget({super.key});

  static String routeName = 'settings';
  static String routePath = '/settings';

  @override
  State<SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  late SettingsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isPersistingCitySelection = false;

  Future<List<String>> _loadCityTitles() async {
    return loadAppCityTitles();
  }

  Future<bool> _persistCitySelection({
    required String nextCity,
  }) async {
    final city = nextCity.trim();
    if (city.isEmpty || currentUserUid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить поселок'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return false;
    }

    try {
      final response = await makeCloudCall(
        'updateUserPreferences',
        {'city': city},
      );
      if (response['success'] != true) {
        throw Exception(
          (response['error'] ?? 'Не удалось сохранить поселок').toString(),
        );
      }
      currentUserDocument =
          await applyBackendUserResponse(response) ?? currentUserDocument;
      FFAppState().CityCountry = city;
      FFAppState().update(() {});
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', '').trim().isNotEmpty
                  ? e.toString().replaceFirst('Exception: ', '').trim()
                  : 'Не удалось сохранить поселок',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _selectCity(String city, BuildContext sheetContext) async {
    if (_isPersistingCitySelection) {
      return;
    }
    safeSetState(() {
      _isPersistingCitySelection = true;
    });
    final saved = await _persistCitySelection(nextCity: city);
    if (mounted) {
      safeSetState(() {
        _isPersistingCitySelection = false;
      });
    } else {
      _isPersistingCitySelection = false;
    }
    if (!saved || !sheetContext.mounted) {
      return;
    }
    Navigator.pop(sheetContext);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          FFLocalizations.of(context).getVariableText(
            ruText: 'Поселок сохранен: $city',
            kkText: 'Елді мекен сақталды: $city',
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Удалить аккаунт?',
                kkText: 'Есептік жазбаны жою керек пе?',
              ),
            ),
            content: Text(
              FFLocalizations.of(context).getVariableText(
                ruText:
                    'Аккаунт будет удален. Если вход был давно, приложение попросит войти заново перед удалением.',
                kkText:
                    'Есептік жазба жойылады. Егер кіру бұрын жасалса, жою алдында қайта кіру қажет болады.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Отмена',
                    kkText: 'Бас тарту',
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Удалить',
                    kkText: 'Жою',
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    try {
      GoRouter.of(context).prepareAuthEvent(true);
      await authManager.deleteUser(context);
      GoRouter.of(context).clearRedirectLocation();
      if (!mounted) return;
      context.go(LoginWidget.routePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', '').trim().isNotEmpty
                ? e.toString().replaceFirst('Exception: ', '').trim()
                : FFLocalizations.of(context).getVariableText(
                    ruText:
                        'Не удалось удалить аккаунт. Выйдите и войдите заново, затем повторите удаление.',
                    kkText:
                        'Есептік жазбаны жою мүмкін болмады. Шығып, қайта кіріп, қайталап көріңіз.',
                  ),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SettingsModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final effectiveCity = FFAppState().CityCountry.trim().isNotEmpty
        ? FFAppState().CityCountry.trim()
        : valueOrDefault(currentUserDocument?.city, '').trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFFCFCFA);
    final darkSurface =
        isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : _mtaxiText;
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: darkSurface,
          iconTheme: IconThemeData(color: textColor),
          automaticallyImplyLeading: true,
          title: Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'Настройки',
              kkText: 'Параметрлер',
            ),
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
                  fontWeight:
                      FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: true,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: SingleChildScrollView(
            primary: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 22, 22, 24),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.zero,
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          0.0, 0.0, 0.0, 8.0),
                      child: InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          await showModalBottomSheet(
                            context: context,
                            backgroundColor: darkSurface,
                            builder: (context) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(
                                      Icons.wb_sunny,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                    ),
                                    title: Text(
                                      FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText: 'Светлая тема',
                                        kkText: 'Жеңіл тақырып',
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: TextStyle(
                                              fontFamily: 'Noto Sans',
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                    onTap: () {
                                      setDarkModeSetting(
                                          context, ThemeMode.light);
                                      Navigator.pop(context);
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(
                                      Icons.nights_stay,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                    ),
                                    title: Text(
                                      FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText: 'Тёмная тема',
                                        kkText: 'Қараңғы тақырып',
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: TextStyle(
                                              fontFamily: 'Noto Sans',
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                    onTap: () {
                                      setDarkModeSetting(
                                          context, ThemeMode.dark);
                                      Navigator.pop(context);
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(
                                      Icons.settings,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                    ),
                                    title: Text(
                                      FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText: 'Системная',
                                        kkText: 'Жүйелік',
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: TextStyle(
                                              fontFamily: 'Noto Sans',
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                    onTap: () {
                                      setDarkModeSetting(
                                          context, ThemeMode.system);
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  0, 17, 34, 17),
                              child: Icon(
                                Icons.palette_outlined,
                                color: mutedColor,
                                size: 24.0,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                FFLocalizations.of(context).getVariableText(
                                  ruText: 'Выбор темы',
                                  kkText: 'Тақырыпты таңдау',
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(color: textColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          0.0, 0.0, 0.0, 8.0),
                      child: InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          await showModalBottomSheet(
                            context: context,
                            backgroundColor: darkSurface,
                            builder: (context) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(
                                      Icons.language,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                    ),
                                    title: Text(
                                      FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText: 'Русский',
                                        kkText: 'Орыс тілі',
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: TextStyle(
                                              fontFamily: 'Noto Sans',
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                    onTap: () {
                                      setAppLanguage(context, 'ru');
                                      Navigator.pop(context);
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(
                                      Icons.language,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                    ),
                                    title: Text(
                                      FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText: 'Казахский',
                                        kkText: 'Қазақ тілі',
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: TextStyle(
                                              fontFamily: 'Noto Sans',
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                    onTap: () {
                                      setAppLanguage(context, 'kk');
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  0, 17, 34, 17),
                              child: Icon(
                                Icons.language,
                                color: mutedColor,
                                size: 24.0,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                FFLocalizations.of(context).getVariableText(
                                  ruText: 'Выбор языка',
                                  kkText: 'Тілді таңдау',
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(color: textColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          0.0, 0.0, 0.0, 8.0),
                      child: InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          final cities = await _loadCityTitles();
                          if (!mounted) return;
                          await showModalBottomSheet(
                            context: context,
                            backgroundColor: darkSurface,
                            builder: (context) => SafeArea(
                              child: cities.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        FFLocalizations.of(context)
                                            .getVariableText(
                                          ruText: 'Список поселков пуст',
                                          kkText: 'Елді мекендер тізімі бос',
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium,
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: cities.length,
                                      itemBuilder: (context, index) {
                                        final city = cities[index];
                                        if (city.isEmpty) {
                                          return const SizedBox.shrink();
                                        }
                                        final selected = effectiveCity == city;
                                        return ListTile(
                                          leading: Icon(
                                            selected
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_off,
                                            color: selected
                                                ? FlutterFlowTheme.of(context)
                                                    .primary
                                                : FlutterFlowTheme.of(context)
                                                    .secondaryText,
                                          ),
                                          title: Text(
                                            city,
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: TextStyle(
                                                    fontFamily: 'Noto Sans',
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
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
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
                                          onTap: _isPersistingCitySelection
                                              ? null
                                              : () =>
                                                  _selectCity(city, context),
                                        );
                                      },
                                    ),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  0, 17, 34, 17),
                              child: Icon(
                                Icons.location_on_outlined,
                                color: mutedColor,
                                size: 24.0,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    FFLocalizations.of(context).getVariableText(
                                      ruText: 'Поселок',
                                      kkText: 'Елді мекен',
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(color: textColor),
                                  ),
                                  Text(
                                    effectiveCity.isNotEmpty
                                        ? effectiveCity
                                        : FFLocalizations.of(context)
                                            .getVariableText(
                                            ruText: 'Не выбран',
                                            kkText: 'Таңдалмаған',
                                          ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .override(
                                          color: mutedColor,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: mutedColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          0.0, 0.0, 0.0, 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                0, 17, 34, 17),
                            child: Icon(
                              Icons.volume_up_outlined,
                              color: mutedColor,
                              size: 24.0,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              FFLocalizations.of(context).getVariableText(
                                ruText: 'Звук',
                                kkText: 'Дыбыс',
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(color: textColor),
                            ),
                          ),
                          Switch(
                            value: FFAppState().soundEnabled,
                            activeThumbColor: _mtaxiOrange,
                            activeTrackColor: _mtaxiMint,
                            inactiveThumbColor: mutedColor,
                            onChanged: (value) async {
                              setState(() {
                                FFAppState().soundEnabled = value;
                              });
                              FFAppState().update(() {});
                              await syncCurrentFcmTokenState(
                                orderAlertsEnabled: value,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          0.0, 0.0, 0.0, 8.0),
                      child: InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: _deleteAccount,
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  0, 17, 34, 17),
                              child: Icon(
                                Icons.delete_outline,
                                color: mutedColor,
                                size: 24.0,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                FFLocalizations.of(context).getVariableText(
                                  ruText: 'Удалить аккаунт',
                                  kkText: 'Есептік жазбаны жою',
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(color: textColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
