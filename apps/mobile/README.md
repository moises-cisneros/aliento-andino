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

El backend local debe estar corriendo (por defecto en `http://localhost:8050` o `http://10.0.2.2:8050/api` según corresponda).

### Comandos de ejecución

Desde la raíz del monorepo:

```bash
pnpm dev:mobile:host
```

O desde el directorio `apps/mobile`:

```bash
flutter run
```

### 1. Detección y selección de dispositivos

```bash
# Listar dispositivos conectados y plataformas disponibles (desktop, web, emuladores activos, móviles)
flutter devices

# Listar emuladores configurados en el sistema
flutter emulators

# Iniciar un emulador específico
flutter emulators --launch <emulator_id>
# Ejemplo:
flutter emulators --launch Pixel_8_Api_35

# Ejecutar en un dispositivo o emulador específico
flutter run -d <device_id>
```

> **Nota:** Si ejecutás `flutter run` y hay más de un dispositivo disponible, Flutter te presentará un menú interactivo numérico en la terminal para que elijas cuál usar.

### 2. Dispositivo físico por USB

1. En el teléfono Android: activá **Opciones de desarrollador** y encendé **Depuración por USB**.
2. Conectá el dispositivo a la PC mediante cable USB y aceptá el diálogo de autorización de huella digital RSA en la pantalla del celular.
3. Verificá que el dispositivo esté detectado:

   ```bash
   adb devices
   flutter devices
   ```

4. Ejecutá con `flutter run -d <device_id>` o seleccionándolo en el menú.

### 3. Dispositivo físico por Wi-Fi (misma red local)

Asegurate de que el celular y la PC estén conectados a la **misma red Wi-Fi**.

#### Método A: Vía USB inicial (`adb tcpip`)

1. Conectá el celular por USB a la PC.
2. Abrí el puerto TCP en el dispositivo:

   ```bash
   adb tcpip 5555
   ```

3. Desconectá el cable USB.
4. Obtené la IP local del teléfono (_Ajustes > Wi-Fi > Detalles de la red_) y conectate:

   ```bash
   adb connect <IP_DEL_CELULAR>:5555
   ```

5. Comprobá la conexión con `adb devices` y ejecutá:

   ```bash
   flutter run -d <IP_DEL_CELULAR>:5555
   ```

#### Método B: Depuración inalámbrica nativa (Android 11+)

1. En el teléfono: _Opciones de desarrollador > Depuración inalámbrica_ (habilitar).
2. Tocá en _Vincular dispositivo con código de vinculación_. Se mostrará la IP, un puerto de vinculación y un código de 6 dígitos.
3. En la PC vinculá el dispositivo:

   ```bash
   adb pair <IP>:<PUERTO_DE_VINCULACION>
   # Ingresá el código de 6 dígitos cuando te lo pida
   ```

4. Conectate utilizando la IP y el puerto principal que se muestra en la pantalla de depuración inalámbrica:

   ```bash
   adb connect <IP>:<PUERTO_PRINCIPAL>
   ```

5. Ya podés ejecutar la aplicación con `flutter run` o `pnpm dev:mobile:host`.

### 4. Dispositivo físico mediante Tunnel Proxy (sin cables ni Wi-Fi compartida)

Si tu dispositivo móvil está en otra red o utilizando datos móviles (4G/5G), podés exponer tu backend local mediante el túnel integrado en el monorepo:

```bash
# En la raíz del monorepo
pnpm tunnel
```

El proxy detectará si el backend en `localhost:8050` está listo, generará una URL pública segura (`https://<subdominio>.loca.lt`) e imprimirá el comando listo para ejecutar:

```bash
flutter run --dart-define=API_BASE_URL=https://aliento-andino-dev.loca.lt/api
```

> En Android, la app apunta automáticamente a `http://10.0.2.2:8050/api` (emulador) cuando no se configura `API_BASE_URL`.

## Cuentas de prueba para desarrollo

Una vez ejecutados los seeders del backend (`docker compose exec backend python seed_all.py`), disponés de las siguientes credenciales para iniciar sesión en la app móvil:

### Administrador

Configurado en las variables de entorno de `.env` / `.env.example`:

- **Email:** `admin@alientoandino.org`
- **Contraseña:** `Admin1234!`

### Alumnos de prueba (50 estudiantes)

Generados automáticamente por `seed_all.py` con progreso, XP y sesiones históricas:

- **Contraseña universal para alumnos:** `Andino123!`
- **Ejemplos de cuentas activas:**
  - `alejandrogar@example.com`
  - `diegogom@example.com`
  - `monicasil@example.com`
  - `nicolascru@example.com`
  - `camilalop@example.com`

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
| `API_BASE_URL`         | URL base del API          | `http://10.0.2.2:8050/api` (Android emulator) |
| `GOOGLE_WEB_CLIENT_ID` | Client ID de Google OAuth | Incluido en el código                         |
