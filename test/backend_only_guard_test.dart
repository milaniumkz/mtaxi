import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtaxi/backend/backend_session.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('backend URL guard detects local development addresses', () {
    expect(isLocalMTaxiBackendUrl(''), isTrue);
    expect(isLocalMTaxiBackendUrl('http://localhost:8080'), isTrue);
    expect(isLocalMTaxiBackendUrl('http://127.0.0.1:8080'), isTrue);
    expect(isLocalMTaxiBackendUrl('http://0.0.0.0:8080'), isTrue);
    expect(isLocalMTaxiBackendUrl('http://10.0.2.2:8080'), isTrue);
    expect(isLocalMTaxiBackendUrl('https://100.64.0.1'), isTrue);
    expect(isLocalMTaxiBackendUrl('https://100.127.255.255'), isTrue);
    expect(isLocalMTaxiBackendUrl('https://100.128.0.1'), isFalse);
    expect(isLocalMTaxiBackendUrl('https://169.254.1.10'), isTrue);
    expect(isLocalMTaxiBackendUrl('http://192.168.1.10:8080'), isTrue);
    expect(isLocalMTaxiBackendUrl('http://172.16.0.10:8080'), isTrue);
    expect(isLocalMTaxiBackendUrl('http://172.31.255.10:8080'), isTrue);
    expect(isLocalMTaxiBackendUrl('http://172.32.0.10:8080'), isFalse);
    expect(isLocalMTaxiBackendUrl('https://[::1]:8080'), isTrue);
    expect(isLocalMTaxiBackendUrl('https://[fd12::1]'), isTrue);
    expect(isLocalMTaxiBackendUrl('https://[fe80::1]'), isTrue);
    expect(isLocalMTaxiBackendUrl('https://api.mtaxi.example.kz'), isFalse);

    final backendSession =
        File('lib/backend/backend_session.dart').readAsStringSync();
    final guardStart =
        backendSession.indexOf('void ensureMTaxiBackendUrlAllowed()');
    final callStart = backendSession
        .indexOf('Future<Map<String, dynamic>> mtaxiBackendCall(');
    final guardCall =
        backendSession.indexOf('ensureMTaxiBackendUrlAllowed();', callStart);
    final httpPost = backendSession.indexOf('.post(', callStart);
    expect(guardStart, isNot(-1), reason: 'Missing release backend URL guard.');
    expect(guardCall, isNot(-1),
        reason: 'Backend calls must invoke release URL guard.');
    expect(httpPost, isNot(-1), reason: 'Missing backend HTTP call.');
    expect(
      guardCall < httpPost,
      isTrue,
      reason: 'Release backend URL guard must run before any HTTP request.',
    );
    expect(
      backendSession,
      contains("uri?.scheme.toLowerCase() != 'https'"),
      reason:
          'Release guard must require HTTPS when MTAXI_REQUIRE_REMOTE_BACKEND=true.',
    );
    expect(
      backendSession,
      contains('isLocalMTaxiBackendUrl(mtaxiBackendBaseUrl)'),
      reason:
          'Release guard must reject localhost, emulator and private LAN backend URLs.',
    );
  });

  test('client keeps Firebase only for FCM/Core dependencies', () {
    final pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final dependencies = (pubspec['dependencies'] as YamlMap)
        .keys
        .map((key) => key.toString())
        .toSet();

    const allowedFirebaseDependencies = {
      'firebase_core',
      'firebase_core_platform_interface',
      'firebase_core_web',
      'firebase_messaging',
      'firebase_messaging_platform_interface',
      'firebase_messaging_web',
    };
    const forbiddenFirebaseDependencies = {
      'cloud_firestore',
      'cloud_functions',
      'firebase_auth',
      'firebase_crashlytics',
      'firebase_database',
      'firebase_performance',
      'firebase_storage',
    };
    const forbiddenClientAuthDependencies = {
      'google_sign_in',
      'google_sign_in_android',
      'google_sign_in_ios',
      'google_sign_in_platform_interface',
      'google_sign_in_web',
      'sign_in_with_apple',
      'sign_in_with_apple_platform_interface',
      'sign_in_with_apple_web',
    };

    expect(
      dependencies.intersection(forbiddenFirebaseDependencies),
      isEmpty,
      reason:
          'Backend-only mode must not bring back Firebase Auth/DB/Functions/Storage.',
    );
    expect(
      dependencies.intersection(forbiddenClientAuthDependencies),
      isEmpty,
      reason:
          'Client login must stay on MTaxi backend SMS/password, not platform auth SDKs.',
    );
    expect(
      dependencies.where((name) => name.startsWith('firebase_')).toSet(),
      allowedFirebaseDependencies,
    );

    const forbiddenClientPlacesDependencies = {
      'flutter_google_places',
      'google_api_headers',
      'google_maps_webservice',
    };
    expect(
      dependencies.intersection(forbiddenClientPlacesDependencies),
      isEmpty,
      reason:
          'Address search and place details must go through MTaxi backend, not client Google Places SDKs.',
    );
  });

  test('lib does not import direct Firebase data/auth SDK packages', () {
    const forbiddenImports = [
      "package:cloud_firestore/",
      "package:cloud_functions/",
      "package:firebase_auth/",
      "package:firebase_crashlytics/",
      "package:firebase_database/",
      "package:firebase_performance/",
      "package:firebase_storage/",
      "/backend/cloud_functions/",
      "/backend/firebase_storage/",
    ];
    const forbiddenFirebaseStorageRuntimeMarkers = [
      'FirebaseStorage',
      'firebasestorage.googleapis.com',
      '.firebasestorage.app',
      '.appspot.com',
    ];
    const forbiddenLegacyCompatNames = [
      'FirebaseFirestore',
      'FirestoreRecord',
      'FFFirestorePage',
      'FFFirebaseStruct',
      'FirestoreUtilData',
      'mapFromFirestore',
      'mapToFirestore',
      'firestore_util.dart',
      'firestoreUtilData',
    ];

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final import in forbiddenImports) {
        if (source.contains(import)) {
          offenders.add('${entity.path}: $import');
        }
      }
      for (final marker in forbiddenFirebaseStorageRuntimeMarkers) {
        if (source.contains(marker)) {
          offenders.add('${entity.path}: $marker');
        }
      }
      for (final marker in forbiddenLegacyCompatNames) {
        if (source.contains(marker)) {
          offenders.add('${entity.path}: $marker');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Client data/auth/storage/functions must go through MTaxi backend APIs.',
    );

    final backendExports = File('lib/backend/backend.dart').readAsStringSync();
    expect(
      backendExports,
      isNot(contains("package:firebase_core/firebase_core.dart")),
      reason:
          'Firebase Core must stay scoped to FCM initialization, not exported from the generic backend layer.',
    );
  });

  test('Firebase Core and Messaging imports stay scoped to push only', () {
    final messagingImportOffenders = <String>[];
    final coreImportOffenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final normalizedPath = entity.path.replaceAll('\\', '/');
      final source = entity.readAsStringSync();
      if (source.contains("package:firebase_messaging/firebase_messaging.dart")) {
        final allowed = normalizedPath == 'lib/main.dart' ||
            normalizedPath.startsWith('lib/backend/push_notifications/');
        if (!allowed) {
          messagingImportOffenders.add(entity.path);
        }
      }
      if (source.contains("package:firebase_core/firebase_core.dart") &&
          normalizedPath != 'lib/backend/firebase/firebase_config.dart') {
        coreImportOffenders.add(entity.path);
      }
    }

    expect(
      messagingImportOffenders,
      isEmpty,
      reason: 'Firebase Messaging must be used only for FCM push handling.',
    );
    expect(
      coreImportOffenders,
      isEmpty,
      reason: 'Firebase Core must be used only for Firebase/FCM init.',
    );
  });

  test('auth manager remains a backend-only compatibility wrapper', () {
    final authManager = File('lib/auth/backend_auth/backend_auth_manager.dart')
        .readAsStringSync();
    final authUtil =
        File('lib/auth/backend_auth/auth_util.dart').readAsStringSync();

    for (final source in [authManager, authUtil]) {
      expect(source, isNot(contains("package:firebase_auth/")));
      expect(source, isNot(contains('FirebaseAuth.instance')));
      expect(source, isNot(contains('verifyPhoneNumber')));
      expect(source, isNot(contains('PhoneAuthProvider')));
      expect(source, isNot(contains('signInWithCredential')));
    }

    expect(authManager,
        contains("mtaxiBackendCall(\n      'getSessionBootstrap'"));
    expect(authManager, contains("mtaxiBackendCall(\n      'setPassword'"));
    expect(authManager,
        contains("mtaxiBackendCall(\n      'deleteCurrentAccountDeep'"));
    expect(authManager, contains('saveBackendAccessToken(token)'));
    expect(authManager, contains('clearBackendSession()'));
    expect(
      authManager,
      contains('phoneAuthManager.triggerOnCodeSent = true'),
      reason:
          'Phone auth screen transition is local UI state; SMS itself is sent by backend requestSmsCode.',
    );
  });

  test('backend-only runtime switches cannot enable Firebase data paths', () {
    final backendSession =
        File('lib/backend/backend_session.dart').readAsStringSync();
    expect(
      backendSession,
      contains('bool get isMTaxiBackendEnabled => true;'),
      reason: 'Client runtime must always use MTaxi backend APIs.',
    );

    final adminCollection =
        File('lib/admin/admin_collection/admin_collection_widget.dart')
            .readAsStringSync();
    expect(
      adminCollection,
      contains('bool get _useBackendOnlyCollections => true;'),
      reason:
          'Admin collections must not fall back to direct Firebase data access.',
    );
  });

  test('legacy FlutterFlow query helpers contain no Firebase reads', () {
    final backendSource = File('lib/backend/backend.dart').readAsStringSync();

    String functionBody(String signature, String nextSignature) {
      final functionStart = backendSource.indexOf(signature);
      expect(functionStart, isNot(-1), reason: 'Missing $signature');
      final nextStart = backendSource.indexOf(nextSignature, functionStart + 1);
      expect(nextStart, isNot(-1),
          reason: 'Missing next marker $nextSignature');
      return backendSource.substring(functionStart, nextStart);
    }

    final helpers = {
      'queryCollectionCount': functionBody(
        'Future<int> queryCollectionCount',
        'Stream<List<T>> queryCollection<T>',
      ),
      'queryCollection': functionBody(
        'Stream<List<T>> queryCollection<T>',
        'Future<List<T>> queryCollectionOnce<T>',
      ),
      'queryCollectionOnce': functionBody(
        'Future<List<T>> queryCollectionOnce<T>',
        'Filter filterIn',
      ),
      'queryCollectionPage': functionBody(
        'Future<FFBackendPage<T>> queryCollectionPage<T>',
        '\n}',
      ),
    };

    for (final entry in helpers.entries) {
      expect(
        entry.value,
        isNot(contains('.snapshots()')),
        reason: '${entry.key} must not keep old Firestore stream fallback.',
      );
      expect(
        entry.value,
        isNot(contains('.get()')),
        reason: '${entry.key} must not keep old Firestore read fallback.',
      );
      expect(
        entry.value,
        isNot(contains('.count()')),
        reason: '${entry.key} must not keep old Firestore count fallback.',
      );
    }
  });

  test('generated record models contain no Firebase document reads', () {
    final offenders = <String>[];

    for (final entity
        in Directory('lib/backend/schema').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('_record.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final read in ['ref.snapshots()', 'ref.get()']) {
        if (source.contains(read)) {
          offenders.add('${entity.path}: $read');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Generated record models must not keep old Firestore document read fallback.',
    );
  });

  test('generated mobile dependency files keep Firebase only for push', () {
    const allowedFirebasePlugins = {
      'firebase_core',
      'firebase_core_platform_interface',
      'firebase_core_web',
      'firebase_messaging',
      'firebase_messaging_platform_interface',
      'firebase_messaging_web',
    };
    const forbiddenNames = {
      'cloud_firestore',
      'cloud_functions',
      'firebase_auth',
      'firebase_crashlytics',
      'firebase_database',
      'firebase_performance',
      'firebase_storage',
      'FirebaseAuth',
      'FirebaseFirestore',
      'FirebaseFunctions',
      'FirebaseStorage',
      'FirebaseCrashlytics',
      'FirebasePerformance',
      'google_sign_in',
      'google_sign_in_ios',
      'GoogleSignIn',
      'GTMAppAuth',
      'GTMSessionFetcher',
      'sign_in_with_apple',
    };

    final lock = loadYaml(File('pubspec.lock').readAsStringSync()) as YamlMap;
    final lockedPackages = (lock['packages'] as YamlMap)
        .keys
        .map((key) => key.toString())
        .where(
            (name) => name.startsWith('firebase_') || name.startsWith('cloud_'))
        .toSet();
    expect(lockedPackages.difference(allowedFirebasePlugins), isEmpty);

    final plugins = jsonDecode(
      File('.flutter-plugins-dependencies').readAsStringSync(),
    ) as Map<String, dynamic>;
    final generatedPluginNames = <String>{};
    for (final platform
        in (plugins['plugins'] as Map<String, dynamic>).values) {
      for (final plugin in platform as List<dynamic>) {
        generatedPluginNames
            .add((plugin as Map<String, dynamic>)['name'].toString());
      }
    }
    expect(
      generatedPluginNames
          .where((name) =>
              name.startsWith('firebase_') || name.startsWith('cloud_'))
          .toSet()
          .difference(allowedFirebasePlugins),
      isEmpty,
    );

    final generatedFiles = [
      'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java',
      'ios/Runner/GeneratedPluginRegistrant.m',
      'ios/Runner/GeneratedPluginRegistrant.h',
      'ios/Podfile.lock',
      'ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift',
    ];
    final offenders = <String>[];
    for (final path in generatedFiles) {
      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }
      final source = file.readAsStringSync();
      for (final name in forbiddenNames) {
        if (source.contains(name)) {
          offenders.add('$path: $name');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Native/generated files must keep Firebase only for FCM push.',
    );

    final nativeFirebasePlugins = <String>{};
    for (final path in generatedFiles.take(3)) {
      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }
      final source = file.readAsStringSync();
      nativeFirebasePlugins.addAll(
        RegExp(r'firebase_[a-z_]+').allMatches(source).map((match) {
          return match.group(0)!;
        }),
      );
    }
    expect(
      nativeFirebasePlugins.difference({
        'firebase_core',
        'firebase_messaging',
      }),
      isEmpty,
      reason:
          'Android/iOS registrants must include only Firebase Core and Messaging for FCM.',
    );

    final podfileLock = File('ios/Podfile.lock');
    if (podfileLock.existsSync()) {
      final podFirebasePlugins =
          RegExp(r'^\s*- (firebase_[a-z_]+)\b', multiLine: true)
              .allMatches(podfileLock.readAsStringSync())
              .map((match) => match.group(1)!)
              .toSet();
      expect(
        podFirebasePlugins.difference({
          'firebase_core',
          'firebase_messaging',
        }),
        isEmpty,
        reason:
            'iOS Podfile.lock must include only Firebase Core and Messaging Flutter plugins.',
      );
    }
  });

  test('repository does not keep legacy Firebase backend artifacts', () {
    const forbiddenPaths = [
      'firebase',
      'public',
      'public_user',
      'ios/build',
      'ios/Pods/FirebaseAuth',
      'ios/Pods/FirebaseFirestore',
      'ios/Pods/FirebaseFunctions',
      'ios/Pods/FirebaseStorage',
      'ios/Pods/Local Podspecs/cloud_firestore.podspec.json',
      'ios/Pods/Local Podspecs/firebase_auth.podspec.json',
      'ios/Pods/Local Podspecs/firebase_storage.podspec.json',
      'ios/Pods/Local Podspecs/cloud_functions.podspec.json',
    ];

    final offenders = forbiddenPaths
        .where((path) =>
            FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound)
        .toList();
    expect(
      offenders,
      isEmpty,
      reason:
          'Firebase must remain only for FCM push; old Hosting/Functions/Auth/Firestore/Storage artifacts must not be committed.',
    );

    final firebaseConfig =
        File('lib/backend/firebase/firebase_config.dart').readAsStringSync();
    expect(firebaseConfig, isNot(contains('authDomain')));
    expect(firebaseConfig, isNot(contains('storageBucket')));

    final firebaseNativeConfigFiles = [
      'android/app/google-services.json',
      'ios/Runner/GoogleService-Info.plist',
    ];
    final configOffenders = <String>[];
    for (final path in firebaseNativeConfigFiles) {
      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }
      final source = file.readAsStringSync();
      for (final marker in [
        'STORAGE_BUCKET',
        'storage_bucket',
        'authDomain',
        'DATABASE_URL',
        '<key>IS_SIGNIN_ENABLED</key>\n\t<true>',
        '<key>IS_APPINVITE_ENABLED</key>\n\t<true>',
      ]) {
        if (source.contains(marker)) {
          configOffenders.add('$path: $marker');
        }
      }
    }
    expect(
      configOffenders,
      isEmpty,
      reason:
          'Firebase native config must stay minimal for Core/Messaging only, without Auth/Firestore/Storage endpoints.',
    );
  });

  test('legacy generated API wrappers cannot call old external services', () {
    final apiCalls =
        File('lib/backend/api_requests/api_calls.dart').readAsStringSync();

    expect(
      apiCalls,
      contains("'SMS отправляется только через backend.'"),
      reason: 'Legacy SmsCall must remain a local compatibility stub.',
    );
    expect(
      apiCalls,
      contains("'Токен авторизации выдает только backend.'"),
      reason: 'Legacy TokenCall must remain a local compatibility stub.',
    );
    expect(apiCalls, contains("mtaxiBackendCall('createDriverTopUpPayment'"));
    expect(apiCalls, contains("mtaxiBackendCall('createDriverWithdrawal'"));

    const forbiddenClientEndpoints = [
      'functions.net',
      'run.app',
      'wappi',
      'api/v1/message',
      'getcustomtoken',
      'createcustomauthtoken',
      'token?',
      'sms?',
    ];
    final lowerApiCalls = apiCalls.toLowerCase();
    final offenders = forbiddenClientEndpoints
        .where((endpoint) => lowerApiCalls.contains(endpoint))
        .toList();
    expect(
      offenders,
      isEmpty,
      reason:
          'Generated API calls must not bypass MTaxi backend. Firebase is allowed only for FCM push.',
    );
  });

  test('client has no direct Google Places SDK or API key usage', () {
    const forbiddenClientPlaces = [
      "package:flutter_google_places/",
      "package:google_api_headers/",
      "package:google_maps_webservice/",
      'FlutterFlowPlacePicker',
      'GoogleMapsPlaces(',
      'PlacesAutocomplete.show',
      'androidApiKey',
      'iosApiKey',
      'webApiKey',
    ];

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final marker in forbiddenClientPlaces) {
        if (source.contains(marker)) {
          offenders.add('${entity.path}: $marker');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Places autocomplete/details must use MTaxi backend endpoints; provider keys stay server-side.',
    );
  });

  test('client code has no direct legacy backend, sms, or payment endpoints',
      () {
    const forbiddenClientEndpoints = [
      'functions.net',
      'run.app',
      'wappi',
      'pult24',
      'placeholder.com',
      'api/v1/message',
      'getcustomtoken',
      'createcustomauthtoken',
    ];

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync().toLowerCase();
      for (final endpoint in forbiddenClientEndpoints) {
        if (source.contains(endpoint)) {
          offenders.add('${entity.path}: $endpoint');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Client must call only MTaxi backend. Firebase is allowed only for FCM push.',
    );
  });

  test('admin generic Firebase write fallback stays unreachable', () {
    final adminCollection =
        File('lib/admin/admin_collection/admin_collection_widget.dart')
            .readAsStringSync();

    final editorStart = adminCollection.indexOf('Future<void> _openEditor(');
    expect(editorStart, isNot(-1), reason: 'Missing admin editor');
    final editorGuard = adminCollection.indexOf(
      'if (_useBackendOnlyCollections)',
      editorStart,
    );
    final editorReturn = adminCollection.indexOf('return;', editorGuard);
    final editorInitialData =
        adminCollection.indexOf('final initialData = data', editorStart);
    expect(
      editorGuard,
      isNot(-1),
      reason: 'Admin editor must block direct Firebase writes in backend mode.',
    );
    expect(editorReturn, isNot(-1));
    expect(editorInitialData, isNot(-1));
    expect(
      editorReturn < editorInitialData,
      isTrue,
      reason:
          'The legacy editor must exit completely before preparing old Firebase editor state.',
    );

    for (final forbiddenWrite in [
      'reference.set(',
      '.add(converted)',
      'reference.delete()',
    ]) {
      expect(
        adminCollection,
        isNot(contains(forbiddenWrite)),
        reason:
            'Admin backend-only client must not keep direct Firebase write fallback $forbiddenWrite.',
      );
    }

    final deleteStart = adminCollection.indexOf('Future<void> _confirmDelete(');
    expect(deleteStart, isNot(-1), reason: 'Missing admin delete handler');
    final deleteGuard = adminCollection.indexOf(
      'if (_useBackendOnlyCollections)',
      deleteStart,
    );
    expect(deleteGuard, isNot(-1));

    expect(
      adminCollection,
      isNot(contains('.snapshots()')),
      reason: 'Admin collection screen must not keep old Firestore streams.',
    );

    final queryStart =
        adminCollection.indexOf('Query<Map<String, dynamic>> _buildQuery()');
    final queryDisabled = adminCollection.indexOf(
      "throw StateError('Backend-only query fallback is disabled')",
      queryStart,
    );
    expect(queryStart, isNot(-1),
        reason: 'Missing admin backend-only query guard');
    expect(queryDisabled, isNot(-1));
    expect(
      adminCollection,
      isNot(contains('BackendRefs.instance.collection(collectionName)')),
      reason: '_buildQuery must not create an old direct collection query.',
    );
  });
}
