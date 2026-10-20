import '/flutter_flow/flutter_flow_util.dart';
import 'edit_ot_widget.dart' show EditOtWidget;
import 'package:flutter/material.dart';

class EditOtModel extends FlutterFlowModel<EditOtWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for shortBio widget.
  final shortBioKey = GlobalKey();
  FocusNode? shortBioFocusNode;
  TextEditingController? shortBioTextController;
  String? shortBioSelectedOption;
  String? Function(BuildContext, String?)? shortBioTextControllerValidator;
  // Stores action output result for [Custom Action - getAddressSuggestions] action in shortBio widget.
  List<String>? adresToString;
  // Stores action output result for [Custom Action - getCoordinatesFromAddress] action in shortBio widget.
  LatLng? coordsAdres;
  // Stores action output result for [Custom Action - getFullAddressFromCoords] action in Button widget.
  String? finalAdres;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    shortBioFocusNode?.dispose();
  }
}
