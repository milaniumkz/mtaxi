import '/flutter_flow/flutter_flow_util.dart';
import 'editkuda_widget.dart' show EditkudaWidget;
import 'package:flutter/material.dart';

class EditkudaModel extends FlutterFlowModel<EditkudaWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for shortBio widget.
  final shortBioKey = GlobalKey();
  FocusNode? shortBioFocusNode;
  TextEditingController? shortBioTextController;
  String? shortBioSelectedOption;
  String? Function(BuildContext, String?)? shortBioTextControllerValidator;
  // Stores action output result for [Custom Action - getAddressSuggestions] action in shortBio widget.
  List<String>? adresss;
  // Stores action output result for [Custom Action - getCoordinatesFromAddress] action in shortBio widget.
  LatLng? coords;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    shortBioFocusNode?.dispose();
  }
}
