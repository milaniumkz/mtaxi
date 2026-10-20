import '/backend/api_requests/api_calls.dart';
import '/component/logo/logo_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'sms_virefication_widget.dart' show SmsVireficationWidget;
import 'package:flutter/material.dart';

class SmsVireficationModel extends FlutterFlowModel<SmsVireficationWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for logo component.
  late LogoModel logoModel;
  // State field(s) for PinCode widget.
  TextEditingController? pinCodeController;
  FocusNode? pinCodeFocusNode;
  String? Function(BuildContext, String?)? pinCodeControllerValidator;
  // State field(s) for Admin password.
  TextEditingController? adminPasswordController;
  FocusNode? adminPasswordFocusNode;
  String? Function(BuildContext, String?)? adminPasswordControllerValidator;
  // Stores action output result for [Backend Call - API (token)] action in Button widget.
  ApiCallResponse? apiResultwhd;

  @override
  void initState(BuildContext context) {
    logoModel = createModel(context, () => LogoModel());
    pinCodeController = TextEditingController();
    adminPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    logoModel.dispose();
    pinCodeFocusNode?.dispose();
    pinCodeController?.dispose();
    adminPasswordFocusNode?.dispose();
    adminPasswordController?.dispose();
  }
}
