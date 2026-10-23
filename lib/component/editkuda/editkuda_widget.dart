import '/auth/backend_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_autocomplete_options_list.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';

import 'editkuda_model.dart';
export 'editkuda_model.dart';

const _mtaxiMint = Color(0xFF126E68);
const _mtaxiText = Color(0xFF1B242B);
const _mtaxiMuted = Color(0xFF5C6862);

class EditkudaWidget extends StatefulWidget {
  const EditkudaWidget({super.key});

  @override
  State<EditkudaWidget> createState() => _EditkudaWidgetState();
}

class _EditkudaWidgetState extends State<EditkudaWidget> {
  late EditkudaModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditkudaModel());

    _model.shortBioTextController ??= TextEditingController();

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
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final surface2 = isDark ? const Color(0xFF243437) : const Color(0xFFF6F2F8);
    final textColor = isDark ? Colors.white : _mtaxiText;
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;
    final buttonText =
        isDark ? const Color(0xFF13191D) : const Color(0xFF12051B);
    return Material(
      color: Colors.transparent,
      elevation: 5.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(0.0),
          bottomRight: Radius.circular(0.0),
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
      ),
      child: Container(
        width: double.infinity,
        height: 370.0,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(0.0),
            bottomRight: Radius.circular(0.0),
            topLeft: Radius.circular(16.0),
            topRight: Radius.circular(16.0),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
                    child: Container(
                      width: 50.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: mutedColor.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16.0, 12.0, 0.0, 0.0),
                child: Text(
                  FFLocalizations.of(context).getText(
                    '5pzzplbn' /* Введите адрес конечной точки? */,
                  ),
                  style: FlutterFlowTheme.of(context).headlineMedium.override(
                        font: TextStyle(
                          fontFamily: 'Noto Sans',
                          fontWeight: FlutterFlowTheme.of(context)
                              .headlineMedium
                              .fontWeight,
                          fontStyle: FlutterFlowTheme.of(context)
                              .headlineMedium
                              .fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontWeight,
                        fontStyle: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontStyle,
                        color: textColor,
                      ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 0.0),
                child: Autocomplete<String>(
                  initialValue: TextEditingValue(),
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text == '') {
                      return const Iterable<String>.empty();
                    }
                    return (_model.adresss ?? const <String>[])
                        .take(5)
                        .toList()
                        .where((option) {
                      final lowercaseOption = option.toLowerCase();
                      return lowercaseOption
                          .contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return AutocompleteOptionsList(
                      textFieldKey: _model.shortBioKey,
                      textController: _model.shortBioTextController!,
                      options: options.toList(),
                      onSelected: onSelected,
                      textStyle:
                          FlutterFlowTheme.of(context).bodyMedium.override(
                                font: TextStyle(
                                  fontFamily: 'Noto Sans',
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
                              ),
                      textHighlightStyle: TextStyle(),
                      elevation: 4.0,
                      optionBackgroundColor: surface2,
                      optionHighlightColor: surface,
                      maxHeight: 200.0,
                    );
                  },
                  onSelected: (String selection) {
                    safeSetState(
                        () => _model.shortBioSelectedOption = selection);
                    FocusScope.of(context).unfocus();
                    Future(() async {
                      _model.coords = await actions.getCoordinatesFromAddress(
                        selection,
                      );
                      FFAppState().kudaCoords = _model.coords;
                      FFAppState().update(() {});
                    });
                  },
                  fieldViewBuilder: (
                    context,
                    textEditingController,
                    focusNode,
                    onEditingComplete,
                  ) {
                    _model.shortBioFocusNode = focusNode;

                    _model.shortBioTextController = textEditingController;
                    return TextFormField(
                      key: _model.shortBioKey,
                      controller: textEditingController,
                      focusNode: focusNode,
                      onEditingComplete: onEditingComplete,
                      onChanged: (_) => EasyDebounce.debounce(
                        '_model.shortBioTextController',
                        Duration(milliseconds: 300),
                        () async {
                          _model.adresss = await actions.getAddressSuggestions(
                            _model.shortBioTextController.text,
                            valueOrDefault(currentUserDocument?.city, ''),
                          );
                          final firstAddress = _model.adresss?.firstOrNull;
                          if (firstAddress != null &&
                              firstAddress.trim().isNotEmpty) {
                            _model.coords =
                                await actions.getCoordinatesFromAddress(
                              firstAddress,
                            );
                            FFAppState().kudaCoords = _model.coords;
                            FFAppState().update(() {});
                          }

                          safeSetState(() {});
                        },
                      ),
                      obscureText: false,
                      decoration: InputDecoration(
                        hintText: FFLocalizations.of(context).getText(
                          '309yrxpg' /* Введите адрес */,
                        ),
                        hintStyle:
                            FlutterFlowTheme.of(context).labelMedium.override(
                                  font: TextStyle(
                                    fontFamily: 'Noto Sans',
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontStyle,
                                  ),
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontStyle,
                                  color: mutedColor,
                                ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: mutedColor.withValues(alpha: 0.22),
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _mtaxiMint,
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: FlutterFlowTheme.of(context).error,
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: FlutterFlowTheme.of(context).error,
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        contentPadding: EdgeInsetsDirectional.fromSTEB(
                            20.0, 32.0, 20.0, 12.0),
                        filled: true,
                        fillColor: surface2,
                      ),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: TextStyle(
                              fontFamily: 'Noto Sans',
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
                      textAlign: TextAlign.start,
                      keyboardType: TextInputType.multiline,
                      validator: _model.shortBioTextControllerValidator
                          .asValidator(context),
                    );
                  },
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 24.0, 0.0, 44.0),
                    child: FFButtonWidget(
                      onPressed: () async {
                        final selected = (_model.shortBioSelectedOption ??
                                _model.shortBioTextController.text)
                            .trim();
                        if (selected.isEmpty) {
                          return;
                        }
                        FFAppState().kudaString = selected;
                        safeSetState(() {});
                        Navigator.pop(context);
                      },
                      text: FFLocalizations.of(context).getText(
                        '18pcaf1u' /* Сохранить */,
                      ),
                      options: FFButtonOptions(
                        width: 270.0,
                        height: 50.0,
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        iconPadding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        color: _mtaxiMint,
                        textStyle:
                            FlutterFlowTheme.of(context).titleMedium.override(
                                  font: TextStyle(
                                    fontFamily: 'Noto Sans',
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                                  color: buttonText,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontStyle,
                                ),
                        elevation: 0.0,
                        borderSide: BorderSide(
                          color: Colors.transparent,
                          width: 1.0,
                        ),
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
  }
}
