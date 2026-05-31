import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';
import 'event_model.dart';

class WifiMonitor {
  final ApiService apiService;
  final String safeSsid;
  final String userId;
  final String deviceId;
  final String zoneName;
  final _storage = const FlutterSecureStorage();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  WifiMonitor({
    required this.apiService,
    required this.safeSsid,
    required this.userId,
    required this.deviceId,
    this.zoneName = 'Casa',
  });

  Future<bool> isConnectedToSafeWifi() async {
    try {
      final List<ConnectivityResult> status = await Connectivity().checkConnectivity();
      if (!status.contains(ConnectivityResult.wifi)) {
        return false;
      }

      String? ssid = await NetworkInfo().getWifiName();
      if (ssid == null) {
        return false;
      }

      // Limpiar comillas que algunos teléfonos agregan al SSID
      ssid = ssid.replaceAll('"', '');
      final cleanSafeSsid = safeSsid.replaceAll('"', '');

      return ssid.toLowerCase() == cleanSafeSsid.toLowerCase();
    } catch (e) {
      print('⚠️ Error al leer el estado Wi-Fi: $e');
      return false;
    }
  }

  Future<void> startForegroundMonitoring() async {
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> status) async {
      await checkAndSendEvent();
    });
  }

  Future<void> stopForegroundMonitoring() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> checkAndSendEvent({bool background = false, bool force = false}) async {
    final currentSafe = await isConnectedToSafeWifi();
    final previousSafe = await _getLastSafeState();

    bool shouldSend = false;
    if (force) {
      shouldSend = true;
    } else if (currentSafe && !previousSafe) {
      shouldSend = true;
    } else if (!currentSafe && previousSafe) {
      shouldSend = true;
    } else if (!background) {
      print('No hay cambio de estado Wi-Fi seguro. safe=$currentSafe prev=$previousSafe');
    }

    if (shouldSend) {
      await _sendEvent(currentSafe ? 'llegada' : 'salida');
    }
    
    await _saveLastSafeState(currentSafe);
  }

  Future<bool> _getLastSafeState() async {
    final stored = await _storage.read(key: 'last_safe_wifi_state');
    return stored == 'true';
  }

  Future<void> _saveLastSafeState(bool value) async {
    await _storage.write(key: 'last_safe_wifi_state', value: value ? 'true' : 'false');
  }

  Future<void> _sendEvent(String eventType) async {
    final payload = EventPayload(
      userId: userId,
      deviceId: deviceId,
      eventType: eventType,
      zoneName: zoneName,
      timestamp: DateTime.now(),
    );
    final success = await apiService.sendLocationEvent(payload);
    print('📶 Wi-Fi monitor: evento $eventType enviado, success=$success');
  }
}
