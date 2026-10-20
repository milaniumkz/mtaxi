import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'seach_driver_widget.dart' show SeachDriverWidget;
import 'package:flutter/material.dart';

class SeachDriverModel extends FlutterFlowModel<SeachDriverWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend query compatibility] action in Button widget.
  List<BidRecord>? listBid;
  // Stores action output result for [Backend Call - Read Document] action in Button widget.
  UsersRecord? idDriver;
  // Stores action output result for [Backend Call - Read Document] action in Button widget.
  UsersRecord? idDriverPhone;
  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
