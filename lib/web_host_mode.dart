import 'package:flutter/foundation.dart' show kIsWeb;

bool isWebAdminHost() {
  if (!kIsWeb) {
    return false;
  }
  final host = Uri.base.host.toLowerCase();
  return host == 'mtaxi-controls.web.app' ||
      host == 'mtaxi-controls.firebaseapp.com' ||
      host.startsWith('mtaxi-controls.');
}
