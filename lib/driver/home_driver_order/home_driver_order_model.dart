import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/instant_timer.dart';
import '/index.dart';
import 'home_driver_order_widget.dart' show HomeDriverOrderWidget;
import 'package:flutter/material.dart';

class HomeDriverOrderModel extends FlutterFlowModel<HomeDriverOrderWidget> {
  ///  State fields for stateful widgets in this page.

  InstantTimer? instantTimer;
  // Stores action output result for [Backend Call - Read Document] action in Button widget.
  UsersRecord? idDriver;
  // Stores action output result for [Backend Call - Read Document] action in Button widget.
  UsersRecord? idUserPhones;
  // Stores action output result for [Backend Call - Read Document] action in Button widget.
  UsersRecord? iduserphone;
  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    instantTimer?.cancel();
  }
}
