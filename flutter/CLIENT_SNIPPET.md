# Snippet de ejemplo para Flutter (autenticación, envío y monitoreo Wi-Fi)

Este ejemplo muestra cómo loguear al usuario, enviar eventos al backend y supervisar el estado del Wi-Fi seguro.

## Paquetes necesarios

Agregá estas dependencias a tu `pubspec.yaml`:

```yaml
dependencies:
  http: any
  connectivity_plus: any
  network_info_plus: any
  flutter_secure_storage: any
```

## Uso básico

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

final baseUrl = 'http://tu-servidor:5000/api/v1';

Future<String?> login(String email, String password) async {
  final response = await http.post(
    Uri.parse('\$baseUrl/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body)['access_token'];
  }
  return null;
}

Future<bool> sendLocationEvent(Map<String, dynamic> event, String token) async {
  final response = await http.post(
    Uri.parse('\$baseUrl/events'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer '
          '\$token',
    },
    body: jsonEncode(event),
  );
  return response.statusCode == 200 || response.statusCode == 202;
}
```

## Monitoreo automático de Wi-Fi

Creá un archivo `flutter/wifi_monitor.dart` con la clase `WifiMonitor` y usala para que la app detecte sola si está en el Wi-Fi seguro.

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'api_service.dart';
import 'event_model.dart';

class WifiMonitor {
  final ApiService apiService;
  final String safeSsid;
  final String userId;
  final String deviceId;
  final String zoneName;

  WifiMonitor({
    required this.apiService,
    required this.safeSsid,
    required this.userId,
    required this.deviceId,
    this.zoneName = 'Casa',
  });

  // Inicia el monitoreo de cambios en la red Wi-Fi.
  Future<void> start() async {
    final connectivity = Connectivity();
    final currentStatus = await connectivity.checkConnectivity();
    await _evaluateConnection(currentStatus);
    connectivity.onConnectivityChanged.listen(_evaluateConnection);
  }

  Future<void> _evaluateConnection(ConnectivityResult status) async {
    final ssid = await NetworkInfo().getWifiName();
    final isSafeWifi = status == ConnectivityResult.wifi &&
        ssid != null &&
        ssid.toLowerCase() == safeSsid.toLowerCase();

    if (isSafeWifi) {
      await _sendEvent('llegada');
    } else {
      await _sendEvent('salida');
    }
  }

  Future<void> _sendEvent(String eventType) async {
    final payload = EventPayload(
      userId: userId,
      deviceId: deviceId,
      eventType: eventType,
      zoneName: zoneName,
      timestamp: DateTime.now(),
    );
    await apiService.sendLocationEvent(payload);
  }
}
```

## Cómo usar en tu app

1. Logueá al usuario y guardá el token.
2. Inicializá `ApiService` y `WifiMonitor`.
3. Llamá a `start()` cuando la app se abra o el usuario inicie sesión.

```dart
final apiService = ApiService();
final monitor = WifiMonitor(
  apiService: apiService,
  safeSsid: 'MiWifiSeguro',
  userId: 'usuario-id',
  deviceId: 'telefono-01',
);
await monitor.start();
```

Con esto, tu app podrá hacer el trabajo de MacroDroid dentro del teléfono: detectar el Wi-Fi seguro y enviar los eventos de `llegada` / `salida` al backend.
