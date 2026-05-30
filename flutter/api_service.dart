import 'dart:convert';
import 'package:http/http.dart' as http;
import 'event_model.dart';

class ApiService {
  final String baseUrl = "http://localhost:5000/api/v1"; // Cambiar por tu URL de ngrok en producción
  final String apiToken = "seguridad_proyecto_mama_notifier";

  Future<bool> sendLocationEvent(EventPayload event) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/events'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
        },
        body: jsonEncode(event.toJson()),
      );

      if (response.statusCode == 202) {
        print("Evento enviado con éxito: ${response.body}");
        return true;
      } else {
        print("Error en el servidor: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error de conexión: $e");
      return false;
    }
  }
}
