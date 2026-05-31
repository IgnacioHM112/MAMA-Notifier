# Mama-Notifier Flutter App

Esta app móvil está diseñada para que el teléfono detecte el Wi-Fi seguro y envíe eventos automáticos al backend de Mama-Notifier.

## Archivos principales

- `lib/main.dart`: UI, login y registro de la tarea de segundo plano.
- `lib/api_service.dart`: autenticación con JWT y envío de eventos al servidor.
- `lib/wifi_monitor.dart`: detección de Wi-Fi seguro y envío de eventos de llegada/salida.
- `lib/event_model.dart`: modelo de payload para el evento.
- `pubspec.yaml`: dependencias necesarias.

## Dependencias necesarias

Agregá estas dependencias en `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^0.14.0
  connectivity_plus: ^4.0.0
  network_info_plus: ^4.0.0
  flutter_secure_storage: ^8.0.0
  workmanager: ^0.5.0
  uuid: ^3.0.0
```

## Cómo instalar

1. Abrí una terminal en la carpeta `flutter`.
2. Ejecutá:

```bash
flutter pub get
```

3. Ejecutá la app en un emulador o dispositivo Android.

## Configuración obligatoria

En `lib/api_service.dart`, ya está configurada esta URL para tu teléfono real vía ngrok:

```dart
final String baseUrl = "https://straining-fiscally-regulator.ngrok-free.dev/api/v1";
```

Si más adelante querés probar en un emulador Android local, cambiá a:

```dart
final String baseUrl = "http://10.0.2.2:5000/api/v1";
```

Para un teléfono real conectado a la misma red local podés usar la IP de tu PC:

```dart
final String baseUrl = "http://192.168.1.100:5000/api/v1";
```

## Firma y release

Para crear un APK release con firma propia, generá un keystore y configurá `android/key.properties`.

Crea el keystore con este comando:

```powershell
keytool -genkey -v -keystore "%USERPROFILE%\.android\mama_notifier_keystore.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias mama_notifier_key
```

Luego completá `android/key.properties` con tus contraseñas y la ruta correcta.

## Permisos Android

Para que la app pueda leer el SSID de la red Wi-Fi, agregá estas líneas en `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

También puede ser necesario permitir tráfico HTTP en Android 9+ si usás `http://`:

```xml
<application
    android:usesCleartextTraffic="true"
    ...>
```

## Segundo plano

La app usa `workmanager` para ejecutar una tarea periódica cada 15 minutos que:

- verifica si el dispositivo está conectado al SSID seguro
- envía `llegada` si recién se conectó a esa red
- envía `salida` si se desconectó o cambió a otra red

## Qué hace el usuario

1. Inicia sesión con email y contraseña.
2. Configura el SSID del Wi-Fi seguro.
3. Activa el monitoreo de segundo plano.

Después de eso, la app debería enviar los avisos automáticamente sin que el usuario toque nada todos los días.

## Comando de build rápido

Si ya configuraste el SDK y el keystore, podés construir la APK con este script:

```powershell
cd flutter\scripts
.\build_apk.ps1
```

El APK resultante quedará en:

```text
flutter\build\app\outputs\flutter-apk\app-release.apk
```
