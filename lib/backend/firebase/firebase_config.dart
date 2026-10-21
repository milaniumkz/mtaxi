import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

const firebaseProjectId = String.fromEnvironment(
  'FIREBASE_PROJECT_ID',
  defaultValue: 'mtaxi-52990',
);
const firebaseWebVapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');
const firebaseWebPushEnabled =
    bool.fromEnvironment('FIREBASE_WEB_PUSH_ENABLED') &&
        firebaseWebVapidKey != '' &&
        String.fromEnvironment('FIREBASE_WEB_API_KEY') != '' &&
        String.fromEnvironment('FIREBASE_WEB_APP_ID') != '' &&
        String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID') != '';

Future<void> initFirebase() async {
  if (Firebase.apps.isNotEmpty) {
    if (Firebase.app().options.projectId != firebaseProjectId) {
      throw StateError(
          'Firebase configuration must belong to $firebaseProjectId.');
    }
    return;
  }
  if (kIsWeb) {
    const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    if (apiKey.isEmpty || appId.isEmpty || senderId.isEmpty) {
      // Web push is not enabled in this client. Keep local web development
      // usable without silently connecting it to a different Firebase project.
      debugPrint('Firebase web configuration missing for $firebaseProjectId.');
      return;
    }
    await Firebase.initializeApp(
        options: const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: firebaseProjectId,
    ));
  } else {
    final app = await Firebase.initializeApp();
    if (app.options.projectId != firebaseProjectId) {
      await app.delete();
      throw StateError(
          'Firebase configuration must belong to $firebaseProjectId.');
    }
  }
}
