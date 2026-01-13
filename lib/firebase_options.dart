import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    // For this example, we'll return the web configuration for all platforms 
    // as it contains the necessary API keys and project ID. 
    // In a production app, you would have separate configurations for Android and iOS.
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCk2q_WCSk1TfuAwNpvP7X5X5-yXrRYf70',
    appId: '1:714316660548:web:7fdd6894a3fa960ccc6111',
    messagingSenderId: '714316660548',
    projectId: 'dishrv1-6dc29',
    authDomain: 'dishrv1-6dc29.firebaseapp.com',
    databaseURL: 'https://dishrv1-6dc29-default-rtdb.firebaseio.com',
    storageBucket: 'dishrv1-6dc29.firebasestorage.app',
  );
}
