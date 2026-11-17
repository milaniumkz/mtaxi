import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Compare the live router, not a route snapshot captured before an API await.
bool openDriverOrderOnce(BuildContext context, String orderDocPath) {
  if (!context.mounted) return false;
  final router = GoRouter.of(context);
  final current = router.routeInformationProvider.value.uri;
  if (current.path == '/homeDriverOrder' &&
      current.queryParameters['orderDocPath'] == orderDocPath) return false;
  router.goNamed('homeDriverOrder',
      queryParameters: {'orderDocPath': orderDocPath});
  return true;
}
