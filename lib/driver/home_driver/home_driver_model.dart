import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/instant_timer.dart';
import '/index.dart';
import 'home_driver_widget.dart' show HomeDriverWidget;
import 'package:flutter/material.dart';

class HomeDriverModel extends FlutterFlowModel<HomeDriverWidget> {
  ///  State fields for stateful widgets in this page.

  InstantTimer? instantTimer;
  InstantTimer? orderListRefreshTimer;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    instantTimer?.cancel();
    orderListRefreshTimer?.cancel();
  }
}
