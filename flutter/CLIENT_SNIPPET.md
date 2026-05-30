# Snippet de ejemplo para Flutter (autenticación y envío con Authorization)

Este pequeño ejemplo muestra cómo loguear al usuario y enviar eventos incluyendo el header `Authorization: Bearer <token>`.

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

final baseUrl = 'http://tu-servidor:5000/api/v1';

Future<String?> login(String email, String password) async {
  final response = await http.post(
    Uri.parse('\$baseUrl/login'),
    body: jsonEncode({'email': email, 'password': password}),
    headers: {'Content-Type': 'application/json'},
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

Guardá el `access_token` en `flutter_secure_storage` y no en texto plano. Si querés, puedo aplicar este snippet directamente en `flutter/api_service.dart`.
