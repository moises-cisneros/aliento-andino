// Configuración de Firebase generada para Aliento Andino.
// Solo Android está configurado por ahora — iOS se agrega cuando se publique.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'FirebaseOptions no configurado para Web. '
        'Generar con `flutterfire configure` si se necesita.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'FirebaseOptions no configurado para iOS. '
          'Generar con `flutterfire configure` si se necesita.',
        );
      default:
        throw UnsupportedError(
          'FirebaseOptions no soportado en esta plataforma.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCbj6KDKYsDF31eb7iCg-WlzLttCTouYqY',
    appId: '1:85165749876:android:8a6195381cc3383240c321',
    messagingSenderId: '85165749876',
    projectId: 'aliento-andino',
    storageBucket: 'aliento-andino.firebasestorage.app',
  );
}
