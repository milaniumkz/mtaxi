import '/backend/app_content/app_content.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';

import 'politik_model.dart';
export 'politik_model.dart';

const _mtaxiText = Color(0xFF1B242B);
const _mtaxiMuted = Color(0xFF5C6862);
const _mtaxiMint = Color(0xFF126E68);

class PolitikWidget extends StatefulWidget {
  const PolitikWidget({super.key});

  @override
  State<PolitikWidget> createState() => _PolitikWidgetState();
}

class _PolitikWidgetState extends State<PolitikWidget> {
  late PolitikModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PolitikModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFF12051B);
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : _mtaxiText;
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8EBE5);
    final buttonText =
        isDark ? const Color(0xFF13191D) : const Color(0xFF12051B);
    return Container(
      color: pageBg,
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/app_launcher_icon.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Политика и соглашение',
                      style: FlutterFlowTheme.of(context).titleMedium.override(
                            font: TextStyle(
                              fontFamily: 'Noto Sans',
                              fontWeight: FontWeight.w800,
                            ),
                            color: textColor,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  FlutterFlowIconButton(
                    borderRadius: 12.0,
                    buttonSize: 40.0,
                    fillColor: _mtaxiMint,
                    icon: Icon(
                      Icons.close_rounded,
                      color: buttonText,
                      size: 22.0,
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: borderColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FutureBuilder<Map<String, dynamic>>(
                  future: getBackendContentDocument('politika'),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: SizedBox(
                          width: 50.0,
                          height: 50.0,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _mtaxiMint,
                            ),
                          ),
                        ),
                      );
                    }
                    final text =
                        (snapshot.data?['text'] ?? '').toString().trim();
                    if (text.isEmpty) {
                      return Center(
                        child: Text(
                          'Документ пока не заполнен',
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    color: mutedColor,
                                  ),
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: SelectableText(
                        text,
                        textAlign: TextAlign.left,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: TextStyle(
                                fontFamily: 'Noto Sans',
                              ),
                              color: textColor,
                              lineHeight: 1.45,
                              letterSpacing: 0.0,
                            ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
