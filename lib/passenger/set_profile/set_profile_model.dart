import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'set_profile_widget.dart' show SetProfileWidget;
import 'package:flutter/material.dart';

class SetProfileModel extends FlutterFlowModel<SetProfileWidget> {
  ///  State fields for stateful widgets in this page.

  bool isDataUploading_uploadData9bb = false;
  FFUploadedFile uploadedLocalFile_uploadData9bb =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_uploadData9bb = '';

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode1;
  TextEditingController? textController1;
  String? Function(BuildContext, String?)? textController1Validator;
  // State field(s) for TextField widget.
  final textFieldKey2 = GlobalKey();
  FocusNode? textFieldFocusNode2;
  TextEditingController? textController2;
  String? textFieldSelectedOption2;
  String? Function(BuildContext, String?)? textController2Validator;
  // State field(s) for password widgets.
  FocusNode? passwordFocusNode;
  TextEditingController? passwordController;
  String? Function(BuildContext, String?)? passwordControllerValidator;
  bool passwordVisibility = false;

  FocusNode? passwordRepeatFocusNode;
  TextEditingController? passwordRepeatController;
  String? Function(BuildContext, String?)? passwordRepeatControllerValidator;
  bool passwordRepeatVisibility = false;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode1?.dispose();
    textController1?.dispose();

    textFieldFocusNode2?.dispose();
    passwordFocusNode?.dispose();
    passwordController?.dispose();

    passwordRepeatFocusNode?.dispose();
    passwordRepeatController?.dispose();
  }
}
