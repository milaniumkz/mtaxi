import '/backend/app_content/app_content.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';

import 'about_model.dart';
export 'about_model.dart';

const _mtaxiOrange = Color(0xFFE6BD63);
const _mtaxiText = Color(0xFF1B242B);

class AboutWidget extends StatefulWidget {
  const AboutWidget({super.key});

  static String routeName = 'about';
  static String routePath = '/about';

  @override
  State<AboutWidget> createState() => _AboutWidgetState();
}

class _AboutWidgetState extends State<AboutWidget> {
  late AboutModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AboutModel());

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
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFFCFCFA);
    final appBarBg = isDark ? const Color(0xFF13191D) : const Color(0xFFE6BD63);
    final textColor = isDark ? Colors.white : Colors.white;
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
          iconTheme: IconThemeData(color: textColor),
          automaticallyImplyLeading: true,
          title: Text(
            'О приложении',
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
            future: getBackendContentDocument('about'),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return _loadingIndicator(context);
              }
              final text = (snapshot.data?['title'] ?? '').toString().trim();
              return _aboutBody(
                context,
                text.isEmpty ? 'Информация пока не добавлена' : text,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _loadingIndicator(BuildContext context) {
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

  Widget _aboutBody(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFCBD3D8) : _mtaxiText;
    return SingleChildScrollView(
      primary: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 24),
        child: Text(
          text,
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                font: TextStyle(
                  fontFamily: 'Noto Sans',
                ),
                color: textColor,
                lineHeight: 1.45,
                letterSpacing: 0.0,
              ),
        ),
      ),
    );
  }
}
