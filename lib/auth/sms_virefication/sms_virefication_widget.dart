import 'package:flutter/material.dart';
import '/auth/login/login_widget.dart';

/// Compatibility route for bookmarks and notifications from older versions.
class SmsVireficationWidget extends StatelessWidget {
  const SmsVireficationWidget({super.key});
  static String routeName = 'smsVirefication';
  static String routePath = '/smsVirefication';
  @override
  Widget build(BuildContext context) => const LoginWidget();
}
