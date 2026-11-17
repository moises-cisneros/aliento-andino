# Aliento Andino — Mobile

Aplicación móvil desarrollada con Flutter. Arquitectura BLoC, navegación con Go Router.

## Requisitos previos

- Flutter SDK >= 3.10.0
- Dart SDK >= 3.10.0
- Android SDK (para compilar APK)
- Backend corriendo (local o producción)

## Instalación

```bash
cd mobile
flutter pub get
```

## Ejecutar en desarrollo

El backend local debe estar corriendo en `localhost:8000`.

```bash
# En emulador Android
flutter run

# En dispositivo físico (conectado por USB)
flutter run -d <device_id>

# Ver dispositivos disponibles
flutter devices
```

> En Android, la app apunta automáticamente a `http://10.0.2.2:8000/api` (emulador) cuando no se configura `API_BASE_URL`.

## Compilar APK

### APK de desarrollo (apunta a localhost)

```bash
flutter build apk --release
```

### APK de producción (apunta al servidor)

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://alientoandino.com/api
```

El APK se genera en:

```
build/app/outputs/flutter-apk/app-release.apk
```

## Ejecutar tests

```bash
flutter test
```

Con cobertura (mínimo 75% sobre `lib/`, sin archivos generados `*.g.dart`; es la barrera que aplica CI):

```bash
flutter test --coverage
node ../../scripts/mobile-coverage.mjs coverage/lcov.info --min 75
```

## Estructura del proyecto

```
lib/
├── main.dart                  # Entry point
├── app.dart                   # MaterialApp, Router, Providers
├── core/
│   ├── config/                # AppConfig (URLs, keys)
│   ├── network/               # ApiClient, AuthInterceptor (Dio)
│   ├── router/                # GoRouter
│   └── theme/                 # AppTheme (claro/oscuro)
└── features/
    ├── auth/                  # Login, registro, Google OAuth
    ├── lessons/               # Categorías, lecciones, práctica
    ├── profile/               # Perfil, stats, configuración
    ├── rankings/              # Rankings, logros, XP
    └── social/                # Feed, posts, comentarios
```

## Variables de configuración (--dart-define)

| Variable               | Descripción               | Default (desarrollo)                          |
| ---------------------- | ------------------------- | --------------------------------------------- |
| `API_BASE_URL`         | URL base del API          | `http://10.0.2.2:8000/api` (Android emulator) |
| `GOOGLE_WEB_CLIENT_ID` | Client ID de Google OAuth | Incluido en el código                         |
