import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'set_profile_driver_widget.dart' show SetProfileDriverWidget;
import 'package:flutter/material.dart';

class SetProfileDriverModel extends FlutterFlowModel<SetProfileDriverWidget> {
  ///  State fields for stateful widgets in this page.

  bool isDataUploading_uploadData2xm = false;
  FFUploadedFile uploadedLocalFile_uploadData2xm =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_uploadData2xm = '';
  bool isDataUploading_carPhoto = false;
  FFUploadedFile uploadedLocalFile_carPhoto =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_carPhoto = '';
  bool isDataUploading_techPhoto = false;
  FFUploadedFile uploadedLocalFile_techPhoto =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_techPhoto = '';

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode1;
  TextEditingController? textController1;
  String? Function(BuildContext, String?)? textController1Validator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode2;
  TextEditingController? textController2;
  String? Function(BuildContext, String?)? textController2Validator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode3;
  TextEditingController? textController3;
  late bool passwordVisibility1;
  String? Function(BuildContext, String?)? textController3Validator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode4;
  TextEditingController? textController4;
  late bool passwordVisibility2;
  String? Function(BuildContext, String?)? textController4Validator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode5;
  TextEditingController? textController5;
  String? Function(BuildContext, String?)? textController5Validator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode6;
  TextEditingController? textController6;
  String? Function(BuildContext, String?)? textController6Validator;
  // State field(s) for TextField widget.
  final textFieldKey7 = GlobalKey();
  FocusNode? textFieldFocusNode7;
  TextEditingController? textController7;
  String? textFieldSelectedOption7;
  String? Function(BuildContext, String?)? textController7Validator;
  DateTime? datePicked;

  @override
  void initState(BuildContext context) {
    passwordVisibility1 = false;
    passwordVisibility2 = false;
  }

  @override
  void dispose() {
    textFieldFocusNode1?.dispose();
    textController1?.dispose();

    textFieldFocusNode2?.dispose();
    textController2?.dispose();

    textFieldFocusNode3?.dispose();
    textController3?.dispose();

    textFieldFocusNode4?.dispose();
    textController4?.dispose();

    textFieldFocusNode5?.dispose();
    textController5?.dispose();

    textFieldFocusNode6?.dispose();
    textController6?.dispose();

    textFieldFocusNode7?.dispose();
  }
}
