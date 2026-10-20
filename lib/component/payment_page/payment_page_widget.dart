import '/backend/backend_calls/backend_calls.dart';
import '/backend/payment_session_guard.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_web_view.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/instant_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'payment_page_model.dart';
export 'payment_page_model.dart';

const _mtaxiMuted = Color(0xFF73677C);

class PaymentPageWidget extends StatefulWidget {
  const PaymentPageWidget({
    super.key,
    required this.url,
    required this.paymentId,
  });

  final String? url;
  final String? paymentId;

  @override
  State<PaymentPageWidget> createState() => _PaymentPageWidgetState();
}

class _PaymentPageWidgetState extends State<PaymentPageWidget> {
  late PaymentPageModel _model;
  bool _canClose = false;
  bool _statusRequestInFlight = false;
  bool _isCompleted = false;
  String _statusText = 'Ожидаем подтверждение оплаты...';
  String _errorText = '';

  bool _isAppReturnUrl(String url) {
    final normalized = url.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(normalized);
    final host = uri?.host ?? '';
    return normalized.contains('kassa24paymentcallback') ||
        host.contains('mtaxi') ||
        host.endsWith('web.app') ||
        host.endsWith('firebaseapp.com');
  }

  Future<bool> _handlePaymentNavigation(String url) async {
    if (!_isAppReturnUrl(url)) {
      return true;
    }
    if (mounted) {
      setState(() {
        _errorText = '';
        _statusText = 'Проверяем оплату...';
      });
    }
    await _refreshPaymentStatus();
    return false;
  }

  Future<void> _closeAfterSuccess() async {
    if (!mounted || _isCompleted) {
      return;
    }
    _isCompleted = true;
    _model.instantTimer?.cancel();
    Navigator.of(context).pop(true);
  }

  Future<void> _closeWithoutPayment() async {
    if (!mounted || _isCompleted) {
      return;
    }
    _isCompleted = true;
    _model.instantTimer?.cancel();
    Navigator.of(context).pop(false);
  }

  Future<void> _refreshPaymentStatus() async {
    if (_statusRequestInFlight || (widget.paymentId ?? '').trim().isEmpty) {
      return;
    }

    _statusRequestInFlight = true;
    try {
      final response = await makeCloudCall(
        'getDriverTopUpPaymentStatus',
        {
          'paymentId': widget.paymentId!.trim(),
        },
      );
      if (!mounted) {
        return;
      }

      final success = response['success'] == true;
      final paymentStatus =
          (response['paymentStatus'] ?? '').toString().trim().toLowerCase();

      if (!success) {
        setState(() {
          _errorText =
              (response['error'] ?? 'Не удалось проверить оплату').toString();
        });
        return;
      }

      if (paymentStatus == 'success') {
        setState(() {
          _canClose = true;
          _errorText = '';
          _statusText = 'Оплата подтверждена. Баланс зачислен.';
        });
        _model.instantTimer?.cancel();
        return;
      }

      if (paymentStatus == 'failed') {
        setState(() {
          _errorText = '';
          _statusText =
              'Оплата не подтверждена. Завершите оплату в окне Kassa24.';
        });
        return;
      }

      setState(() {
        _errorText = '';
        _statusText = 'Ожидаем подтверждение оплаты...';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = 'Не удалось проверить статус оплаты';
      });
    } finally {
      _statusRequestInFlight = false;
    }
  }

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    PaymentSessionGuard.isPaymentActive = true;
    _model = createModel(context, () => PaymentPageModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.instantTimer = InstantTimer.periodic(
        duration: const Duration(seconds: 3),
        callback: (timer) async {
          await _refreshPaymentStatus();
        },
        startImmediately: true,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    PaymentSessionGuard.isPaymentActive = false;
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1B2528) : const Color(0xFFEFF2F6);
    final surface = isDark ? const Color(0xFF13191D) : const Color(0xFFFFFFFF);
    final textColor = isDark ? Colors.white : const Color(0xFF1E1525);
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : _mtaxiMuted;
    final borderColor =
        isDark ? const Color(0xFF2C3A3F) : const Color(0xFFE8E2EC);
    final ctaColor = isDark ? const Color(0xFF28D8C6) : const Color(0xFFFF6500);
    return PopScope(
      canPop: true,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.92,
        child: DecoratedBox(
          decoration: BoxDecoration(color: pageBg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 58.0,
                color: surface,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 0.0,
                      child: IconButton(
                        onPressed: _closeWithoutPayment,
                        icon: Icon(
                          Icons.arrow_back,
                          color: textColor,
                          size: 22.0,
                        ),
                        tooltip: 'Назад',
                      ),
                    ),
                    Text(
                      'Пополнение',
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).titleMedium.override(
                            font: GoogleFonts.readexPro(
                              fontWeight: FontWeight.w800,
                            ),
                            color: textColor,
                            fontSize: 22.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 30.0, 24.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Касса 24',
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).titleLarge.override(
                            font: GoogleFonts.readexPro(
                              fontWeight: FontWeight.w800,
                            ),
                            color: textColor,
                            fontSize: 22.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      _statusText,
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            font: GoogleFonts.readexPro(),
                            color: mutedColor,
                            letterSpacing: 0.0,
                          ),
                    ),
                    if (_errorText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _errorText,
                          textAlign: TextAlign.center,
                          style:
                              FlutterFlowTheme.of(context).bodySmall.override(
                                    font: GoogleFonts.readexPro(),
                                    color: FlutterFlowTheme.of(context).error,
                                    letterSpacing: 0.0,
                                  ),
                        ),
                      ),
                    if (_canClose)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: FFButtonWidget(
                          onPressed: _closeAfterSuccess,
                          text: 'Закрыть',
                          options: FFButtonOptions(
                            height: 44.0,
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                24.0, 0.0, 24.0, 0.0),
                            iconPadding: const EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            color: ctaColor,
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
                                  color: Colors.white,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                            elevation: 0.0,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: borderColor,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FlutterFlowWebView(
                    content: widget.url!,
                    bypass: false,
                    onNavigationRequest: _handlePaymentNavigation,
                    width: MediaQuery.sizeOf(context).width * 1.0,
                    height: MediaQuery.sizeOf(context).height * 1.0,
                    verticalScroll: true,
                    horizontalScroll: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
