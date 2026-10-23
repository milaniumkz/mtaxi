import '/auth/backend_auth/auth_util.dart';
import '/backend/app_content/app_content.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';

import 'tarif_model.dart';
export 'tarif_model.dart';

const _mtaxiMint = Color(0xFF126E68);
const _mtaxiText = Color(0xFF1B242B);
const _mtaxiMuted = Color(0xFF5C6862);

class TarifWidget extends StatefulWidget {
  const TarifWidget({super.key});

  static String routeName = 'tarif';
  static String routePath = '/tarif';

  @override
  State<TarifWidget> createState() => _TarifWidgetState();
}

class _TarifWidgetState extends State<TarifWidget> {
  late TarifModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TarifModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showDriverTariffs = UserModeResolver.canOpenDriverScreens(
      currentUserDocument,
    );
    final showPassengerTariffs = true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFFCFCFA);
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : _mtaxiText;

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
            'Тарифы',
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
          child: FutureBuilder<Map<String, dynamic>>(
            future: getBackendContentDocument('tariffsContent'),
            builder: (context, snapshot) {
              final data = snapshot.data ?? const <String, dynamic>{};
              return _buildTariffsBody(
                context,
                data: data,
                loading: snapshot.connectionState == ConnectionState.waiting,
                isDark: isDark,
                showPassengerTariffs: showPassengerTariffs,
                showDriverTariffs: showDriverTariffs,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTariffsBody(
    BuildContext context, {
    required Map<String, dynamic> data,
    required bool loading,
    required bool isDark,
    required bool showPassengerTariffs,
    required bool showDriverTariffs,
  }) {
    final driverTariffs = (data['driverTariffs'] as String?)?.trim() ?? '';
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 42, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showPassengerTariffs)
              _buildTariffBlock(
                context,
                isDark: isDark,
                title: 'Такси',
                text: 'Минимальная цена: 1 000 ₸\nКомиссия: 10%',
              ),
            if (showPassengerTariffs) const SizedBox(height: 26),
            if (showPassengerTariffs)
              _buildTariffBlock(
                context,
                isDark: isDark,
                title: 'Доставка',
                text: 'Цена по городу: 1 500 ₸\nКомиссия: 10%',
              ),
            if (showPassengerTariffs) const SizedBox(height: 26),
            if (showPassengerTariffs)
              _buildTariffBlock(
                context,
                isDark: isDark,
                title: 'Межгород',
                text: 'Маршруты по населённым пунктам\nЦена задаётся админкой',
              ),
            if (showPassengerTariffs && showDriverTariffs)
              const SizedBox(height: 26),
            if (showDriverTariffs)
              _buildTariffBlock(
                context,
                isDark: isDark,
                title: 'Тарифы для водителей',
                text: driverTariffs,
              ),
            if (loading)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _mtaxiMint,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTariffBlock(
    BuildContext context, {
    required bool isDark,
    required String title,
    required String text,
  }) {
    final hasText = text.trim().isNotEmpty;
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : _mtaxiText;
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8EBE5);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: FlutterFlowTheme.of(context).titleMedium.override(
                  font: TextStyle(
                    fontFamily: 'Noto Sans',
                    fontWeight: FontWeight.w800,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleMedium.fontStyle,
                  ),
                  color: textColor,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w800,
                  fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            hasText ? text : 'Пока не заполнено',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: TextStyle(
                    fontFamily: 'Noto Sans',
                    fontWeight:
                        FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  color: hasText ? textColor : mutedColor,
                  fontWeight:
                      FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
          ),
        ],
      ),
    );
  }
}
