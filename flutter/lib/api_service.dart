import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'event_model.dart';

class ApiService {
  final String baseUrl = "https://straining-fiscally-regulator.ngrok-free.dev/api/v1";
  final _storage = const FlutterSecureStorage();
  String? _cachedToken;

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'] as String?;
        final user = data['user'] as Map<String, dynamic>?;

        if (token != null && user != null) {
          _cachedToken = token;
          await _storage.write(key: 'jwt_token', value: token);
          await _storage.write(key: 'user_id', value: user['id']);
          await _storage.write(key: 'user_name', value: user['full_name']);
          return data;
        }
      }
      return null;
    } catch (e) {
      print('❌ Error de conexión en login: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': name,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'] as String?;
        final user = data['user'] as Map<String, dynamic>?;

        if (token != null && user != null) {
          _cachedToken = token;
          await _storage.write(key: 'jwt_token', value: token);
          await _storage.write(key: 'user_id', value: user['id']);
          await _storage.write(key: 'user_name', value: user['full_name']);
          return data;
        }
      }
      return null;
    } catch (e) {
      print('❌ Error de conexión en registro: $e');
      return null;
    }
  }

  Future<List<dynamic>> getContacts() async {
    try {
      final token = await getStoredToken();
      final response = await http.get(
        Uri.parse('$baseUrl/contacts'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('❌ Error obteniendo contactos: $e');
    }
    return [];
  }

  Future<bool> addContact(String name, String phone, String arrivalMsg, String departureMsg) async {
    try {
      final token = await getStoredToken();
      final response = await http.post(
        Uri.parse('$baseUrl/contacts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'contact_name': name,
          'phone_number': phone,
          'msg_llegada': arrivalMsg,
          'msg_salida': departureMsg,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error añadiendo contacto: $e');
    }
    return false;
  }

  Future<bool> deleteContact(int id) async {
    try {
      final token = await getStoredToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/contacts/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error eliminando contacto: $e');
    }
    return false;
  }

  Future<List<dynamic>> getLogs() async {
    try {
      final token = await getStoredToken();
      final response = await http.get(
        Uri.parse('$baseUrl/logs'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('❌ Error obteniendo logs: $e');
    }
    return [];
  }

  Future<String?> getStoredToken() async {
    if (_cachedToken != null) return _cachedToken;
    _cachedToken = await _storage.read(key: 'jwt_token');
    return _cachedToken;
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: 'user_id');
  }

  Future<String?> getUserName() async {
    return await _storage.read(key: 'user_name');
  }

  Future<String?> getDeviceId() async {
    return await _storage.read(key: 'device_id');
  }

  Future<void> saveDeviceId(String deviceId) async {
    await _storage.write(key: 'device_id', value: deviceId);
  }

  Future<String?> getSafeSsid() async {
    return await _storage.read(key: 'safe_ssid');
  }

  Future<void> saveSafeSsid(String ssid) async {
    await _storage.write(key: 'safe_ssid', value: ssid);
  }

  Future<String?> getZoneName() async {
    return await _storage.read(key: 'zone_name');
  }

  Future<void> saveZoneName(String zoneName) async {
    await _storage.write(key: 'zone_name', value: zoneName);
  }

  Future<bool> sendLocationEvent(EventPayload event) async {
    try {
      final token = await getStoredToken();
      if (token == null) {
        print('❌ No hay token. Debes hacer login primero.');
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/events'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(event.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 202) {
        print('✅ Evento enviado con éxito: ${response.body}');
        return true;
      }

      print('❌ Error en el servidor: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      print('❌ Error de conexión al enviar evento: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _cachedToken = null;
    await _storage.deleteAll();
  }
}
