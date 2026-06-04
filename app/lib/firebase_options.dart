// Firebase configuration, hand-derived from android/app/google-services.json
// (project vtxos-7afb3). Passed explicitly to Firebase.initializeApp so init
// does not depend on the google-services Gradle plugin merging google_app_id
// into Android resources — that merge is broken by the custom buildDir override
// in android/build.gradle, which left FirebaseOptions.fromResource() returning
// null and disabled push entirely.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions are not configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for '
          '$defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDr3wlKcGDo90lzqCctChmbrMwuwFemNh0',
    appId: '1:575541915148:android:5fbaa581de7d4686378829',
    messagingSenderId: '575541915148',
    projectId: 'vtxos-7afb3',
    storageBucket: 'vtxos-7afb3.firebasestorage.app',
  );
}
