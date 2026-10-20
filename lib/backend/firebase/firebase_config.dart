import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
            projectId: "mtaxi-vzqw6a",
            messagingSenderId: "84335333032",
            appId: "1:84335333032:web:bd1a9b73f88d63c4117c9d"));
  } else {
    await Firebase.initializeApp();
  }
}
