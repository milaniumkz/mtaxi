import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/app_content/app_content.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'politika_model.dart';
export 'politika_model.dart';

const _mtaxiOrange = Color(0xFFFF6500);
const _mtaxiMuted = Color(0xFF73677C);

class PolitikaWidget extends StatefulWidget {
  const PolitikaWidget({super.key});

  static String routeName = 'politika';
  static String routePath = '/politika';

  @override
  State<PolitikaWidget> createState() => _PolitikaWidgetState();
}

class _PolitikaWidgetState extends State<PolitikaWidget> {
  late PolitikaModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PolitikaModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFEFF2F6);
    final appBarBg = isDark ? const Color(0xFF13191D) : const Color(0xFFFF6500);
    final appBarText = isDark ? Colors.white : Colors.white;
    final bodyText = isDark ? const Color(0xFFCBD3D8) : _mtaxiMuted;
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: appBarBg,
          iconTheme: IconThemeData(color: appBarText),
          automaticallyImplyLeading: true,
          title: Text(
            FFLocalizations.of(context).getText(
              '4a9cqlwr' /* Политика и условия */,
            ),
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.outfit(
                    fontWeight:
                        FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  color: appBarText,
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FutureBuilder<Map<String, dynamic>>(
                future: getBackendContentDocument('politika'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: SizedBox(
                        width: 50.0,
                        height: 50.0,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _mtaxiOrange,
                          ),
                        ),
                      ),
                    );
                  }
                  final text = (snapshot.data?['text'] ?? '').toString().trim();
                  return Container(
                    padding: const EdgeInsets.all(0),
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: SelectableText(
                      text.isEmpty ? 'Политика не заполнена' : text,
                      textAlign: TextAlign.start,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.readexPro(),
                            color: bodyText,
                            lineHeight: 1.45,
                            letterSpacing: 0.0,
                          ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
