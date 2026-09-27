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
      print('WifiMonitor.isConnectedToSafeWifi: Checking connectivity...');
      final List<ConnectivityResult> status = await Connectivity().checkConnectivity();
      print('WifiMonitor.isConnectedToSafeWifi: Connectivity status=$status');
      if (!status.contains(ConnectivityResult.wifi)) {
        print('WifiMonitor.isConnectedToSafeWifi: Not on WiFi');
        return false;
      }

      String? ssid = await NetworkInfo().getWifiName();
      print('WifiMonitor.isConnectedToSafeWifi: Current SSID=$ssid');
      if (ssid == null) {
        print('WifiMonitor.isConnectedToSafeWifi: SSID is null');
        return false;
      }

      ssid = ssid.replaceAll('"', '');
      final cleanSafeSsid = safeSsid.replaceAll('"', '');
      print('WifiMonitor.isConnectedToSafeWifi: Comparing current="$ssid" vs safe="$cleanSafeSsid"');

      final result = ssid.toLowerCase() == cleanSafeSsid.toLowerCase();
      print('WifiMonitor.isConnectedToSafeWifi: Result=$result');
      return result;
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
      print('WifiMonitor.checkAndSendEvent: START background=$background force=$force connected=$connected');
      final currentSafe = connected ?? await isConnectedToSafeWifi();
      print('WifiMonitor.checkAndSendEvent: currentSafe=$currentSafe');
      final previousSafe = await _getLastSafeState();
      print('WifiMonitor.checkAndSendEvent: previousSafe=$previousSafe');

      bool shouldSend = false;
      if (force) {
        shouldSend = true;
        print('WifiMonitor.checkAndSendEvent: FORCE=true -> shouldSend=true');
      } else if (currentSafe && !previousSafe) {
        shouldSend = true;
        print('WifiMonitor.checkAndSendEvent: TRANSITION connected -> shouldSend=true');
      } else if (!currentSafe && previousSafe) {
        shouldSend = true;
        print('WifiMonitor.checkAndSendEvent: TRANSITION disconnected -> shouldSend=true');
      } else if (!background) {
        print('WifiMonitor.checkAndSendEvent: NO CHANGE. safe=$currentSafe prev=$previousSafe');
      }

      if (shouldSend) {
        print('WifiMonitor.checkAndSendEvent: SENDING event...');
        await _sendEvent(currentSafe ? 'llegada' : 'salida');
        print('WifiMonitor.checkAndSendEvent: Event sent successfully');
      } else {
        print('WifiMonitor.checkAndSendEvent: No event to send');
      }
      
      await _saveLastSafeState(currentSafe);
      print('WifiMonitor.checkAndSendEvent: State saved, currentSafe=$currentSafe');
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
      print('WifiMonitor._sendEvent: START eventType=$eventType');
      final payload = EventPayload(
        userId: userId,
        deviceId: deviceId,
        eventType: eventType,
        zoneName: zoneName,
        timestamp: DateTime.now(),
      );
      print('WifiMonitor._sendEvent: Calling apiService.sendLocationEvent...');
      final success = await apiService.sendLocationEvent(payload);
      print('WifiMonitor._sendEvent: apiService returned success=$success');
      if (!success) {
        print('WifiMonitor._sendEvent: WARNING - API returned false');
      }
    } catch (e, stack) {
      print('WifiMonitor._sendEvent ERROR: $e\n$stack');
    }
  }
}