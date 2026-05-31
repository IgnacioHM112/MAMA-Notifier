# Publicar MamaNotifier en Google Play

## 1. Nombre de la app instalada
La app ya está configurada para instalarse como:

- **MamaNotifier**

Esto se define en:

- `flutter/android/app/src/main/AndroidManifest.xml`

## 2. Package name / Application ID
La app está configurada con:

- `com.mamanotifier.app`

Este es el identificador único que usa Google Play para la app.

## 3. Nombre interno de Flutter
El título de la app dentro de Flutter también se actualizó a:

- `MamaNotifier`

Esto se define en:

- `flutter/lib/main.dart`

## 4. Keystore
El keystore en uso dentro del proyecto es:

- `flutter/android/mama_notifier_keystore.jks`

Respaldo externo creado en:

- `C:\Users\ignam\MamaNotifierKeystoreBackup\mama_notifier_keystore.jks`

> Importante: guarda esta copia en un lugar seguro. Si se pierde, no podrás actualizar la app publicada.

## 5. Contraseñas de firma
Los datos actuales son:

- `storePassword=store_password_mamanotifier`
- `keyPassword=key_password_mamanotifier`
- `keyAlias=alias_key_mamanotifier`

Estos valores se usan en:

- `flutter/android/key.properties`

## 6. Generar APK release
Desde el directorio `flutter/`, ejecuta:

```bash
flutter build apk --release
```

El APK generado estará en:

- `flutter/build/app/outputs/flutter-apk/app-release.apk`

## 7. Verificar la firma (opcional pero recomendado)
Para corroborar que el APK está firmado con el keystore correcto, puedes ejecutar:

```bash
apksigner verify flutter/build/app/outputs/flutter-apk/app-release.apk
```

Si no tienes `apksigner`, viene con el Android SDK en `build-tools`.

## 8. Subir a Google Play
1. Abre Google Play Console.
2. Crea una nueva app o selecciona una existente.
3. Ve a "Release" > "Production" > "Create new release".
4. Sube `app-release.apk`.
5. Completa los datos de la release y guarda.
6. Revisa los requisitos de contenido y privacidad.
7. Envía la release para revisión.

## 9. Recomendaciones finales
- No compartas ni subas el keystore ni `key.properties` a repositorios públicos.
- Mantén la copia de respaldo fuera del proyecto:
  - `C:\Users\ignam\MamaNotifierKeystoreBackup\mama_notifier_keystore.jks`
- Usa siempre el mismo keystore para futuras actualizaciones.
- Si cambias el `applicationId` en el futuro, no podrás actualizar con el mismo paquete anterior.

## 10. Distribución directa del APK
Si no vas a usar Google Play, podés compartir el APK directamente con tus usuarios.

### Qué necesitan tus usuarios
1. Descargar el archivo:
   - `flutter/build/app/outputs/flutter-apk/app-release.apk`
2. Habilitar instalación desde orígenes desconocidos en Android.
   - En Android 8+ se hace por la app que descarga el APK.
   - En versiones antiguas, se activa desde los ajustes de seguridad.
3. Abrir el APK descargado y aceptar la instalación.

### Recomendaciones para compartirlo
- Compartilo por WhatsApp, Telegram, correo o un enlace de descarga en tu web.
- Usa un nombre claro para el archivo, por ejemplo:
  - `MamaNotifier-release.apk`
- Avisá a tus usuarios que la app no viene de Play Store, pero es la misma app que querés distribuir.

### Después de instalar
- La app funcionará normalmente en Android.
- Si querés actualizarla, mandales una nueva versión firmada con el mismo keystore.
- Si el usuario instala una versión con firma distinta, Android no permitirá la actualización.

### Verificar la instalación
- El icono y nombre instalado deben aparecer como:
  - **MamaNotifier**
- Si el instalador muestra un error de firma, revisá que el APK sea el `release` generado con el keystore correcto.

### Mensaje clave para tus usuarios
- "Hola! Te paso el APK de MamaNotifier para que lo instales directamente en tu Android.
Descargá el archivo MamaNotifier-release.apk.
Abrí el archivo y aceptá la instalación desde orígenes desconocidos si te lo pide.
Instalá la app normalmente.
Si después hay una versión nueva, te aviso y la instalás igual con el mismo archivo "
