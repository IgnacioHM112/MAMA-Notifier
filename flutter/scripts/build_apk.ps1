# Powershell script para construir la APK de release de Mama-Notifier
# Ejecute desde la carpeta flutter después de haber configurado el SDK de Flutter y Android.

param()

Write-Host "1) Asegurando que Flutter esté disponible..."
flutter --version

Write-Host "2) Instalando dependencias..."
flutter pub get

Write-Host "3) Construyendo APK release..."
flutter build apk --release

Write-Host "4) APK generado en: build\app\outputs\flutter-apk\app-release.apk"
