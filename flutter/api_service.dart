import 'dart:convert';
import 'package:http/http.dart' as http;
import 'event_model.dart';

// TODO: En producción, usa flutter_secure_storage en lugar de una variable global
// Instalá con: flutter pub add flutter_secure_storage
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// final storage = FlutterSecureStorage();

class ApiService {
  final String baseUrl = "http://localhost:5000/api/v1"; // Cambiar por tu URL de ngrok en producción
  
  String? _cachedToken; // Cache de token en memoria. En producción, guardalo en flutter_secure_storage

  // === PASO 1: LOGIN (obtener token JWT) ===
  Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _cachedToken = data['access_token'];
        print("✅ Login exitoso. Token guardado.");
        
        // TODO: Guardar en secure storage:
        // await storage.write(key: 'jwt_token', value: _cachedToken);
        
        return _cachedToken;
      } else {
        print("❌ Error de login: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("❌ Error de conexión en login: $e");
      return null;
    }
  }

  // === PASO 2: Cargar token guardado (si existe) ===
  Future<String?> getStoredToken() async {
    if (_cachedToken != null) return _cachedToken;
    
    // TODO: En producción, cargar desde secure storage:
    // _cachedToken = await storage.read(key: 'jwt_token');
    
    return _cachedToken;
  }

  // === PASO 3: Enviar evento con Authorization Bearer ===
  Future<bool> sendLocationEvent(EventPayload event) async {
    try {
      // Asegurar que tenemos un token
      final token = await getStoredToken();
      if (token == null) {
        print("❌ No hay token. Debes hacer login primero.");
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/events'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // ← La magia está aquí
        },
        body: jsonEncode(event.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 202) {
        print("✅ Evento enviado con éxito: ${response.body}");
        return true;
      } else {
        print("❌ Error en el servidor: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Error de conexión: $e");
      return false;
    }
  }

  // === Bonus: Logout (limpiar token) ===
  Future<void> logout() async {
    _cachedToken = null;
    // TODO: Eliminar de secure storage:
    // await storage.delete(key: 'jwt_token');
    print("🚪 Token eliminado.");
  }
}
