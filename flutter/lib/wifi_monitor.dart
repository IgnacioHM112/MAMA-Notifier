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
  bool _isListening = false;

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

      ssid = ssid.replaceAll('"', '');
      final cleanSafeSsid = safeSsid.replaceAll('"', '');

      return ssid.toLowerCase() == cleanSafeSsid.toLowerCase();
    } catch (e) {
      print('⚠️ WifiMonitor.isConnectedToSafeWifi ERROR: $e');
      return false;
    }
  }

  Future<void> startForegroundMonitoring() async {
    if (_isListening) return;
    
    try {
      _subscription = Connectivity().onConnectivityChanged.listen(
        (List<ConnectivityResult> status) async {
          try {
            await checkAndSendEvent();
          } catch (e, stack) {
            print('WifiMonitor onConnectivityChanged ERROR: $e\n$stack');
          }
        },
        onError: (err) {
          print('WifiMonitor connectivity stream error: $err');
          _isListening = false;
        },
        onDone: () {
          print('WifiMonitor connectivity stream closed');
          _isListening = false;
        },
      );
      _isListening = true;
      print('WifiMonitor started');
    } catch (e, stack) {
      print('WifiMonitor.startForegroundMonitoring ERROR: $e\n$stack');
      _isListening = false;
    }
  }

  Future<void> stopForegroundMonitoring() async {
    try {
      await _subscription?.cancel();
      _subscription = null;
      _isListening = false;
      print('WifiMonitor stopped');
    } catch (e) {
      print('WifiMonitor stop error: $e');
    }
  }

  Future<void> checkAndSendEvent({bool background = false, bool force = false, bool? connected}) async {
    try {
      final currentSafe = connected ?? await isConnectedToSafeWifi();
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
    } catch (e, stack) {
      print('WifiMonitor.checkAndSendEvent ERROR: $e\n$stack');
    }
  }

  Future<bool> _getLastSafeState() async {
    try {
      final stored = await _storage.read(key: 'last_safe_wifi_state');
      return stored == 'true';
    } catch (e) {
      print('WifiMonitor._getLastSafeState ERROR: $e');
      return false;
    }
  }

  Future<void> _saveLastSafeState(bool value) async {
    try {
      await _storage.write(key: 'last_safe_wifi_state', value: value ? 'true' : 'false');
    } catch (e) {
      print('WifiMonitor._saveLastSafeState ERROR: $e');
    }
  }

  Future<void> _sendEvent(String eventType) async {
    try {
      final payload = EventPayload(
        userId: userId,
        deviceId: deviceId,
        eventType: eventType,
        zoneName: zoneName,
        timestamp: DateTime.now(),
      );
      final success = await apiService.sendLocationEvent(payload);
      print('📶 Wi-Fi monitor: evento $eventType enviado, success=$success');
    } catch (e, stack) {
      print('WifiMonitor._sendEvent ERROR: $e\n$stack');
    }
  }
}