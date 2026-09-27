import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
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

  Future<void> _logToFile(String msg) async {
    try {
      Directory? dir;
      try {
        dir = Directory('/storage/emulated/0/Documents');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } catch (_) {}
      
      dir ??= await getApplicationDocumentsDirectory();
      
      final file = File('${dir.path}/foreground_log.txt');
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString('$timestamp: $msg\n', mode: FileMode.append);
    } catch (_) {}
  }

  void _log(String msg) {
    print(msg);
    _logToFile('WifiMonitor: $msg');
  }

  WifiMonitor({
    required this.apiService,
    required this.safeSsid,
    required this.userId,
    required this.deviceId,
    this.zoneName = 'Casa',
  });

  Future<bool> isConnectedToSafeWifi() async {
    try {
      _log('isConnectedToSafeWifi: Checking connectivity...');
      final List<ConnectivityResult> status = await Connectivity().checkConnectivity();
      _log('isConnectedToSafeWifi: Connectivity status=$status');
      if (!status.contains(ConnectivityResult.wifi)) {
        _log('isConnectedToSafeWifi: Not on WiFi');
        return false;
      }

      String? ssid = await NetworkInfo().getWifiName();
      _log('isConnectedToSafeWifi: Current SSID=$ssid');
      if (ssid == null) {
        _log('isConnectedToSafeWifi: SSID is null');
        return false;
      }

      ssid = ssid.replaceAll('"', '');
      final cleanSafeSsid = safeSsid.replaceAll('"', '');
      _log('isConnectedToSafeWifi: Comparing current="$ssid" vs safe="$cleanSafeSsid"');

      final result = ssid.toLowerCase() == cleanSafeSsid.toLowerCase();
      _log('isConnectedToSafeWifi: Result=$result');
      return result;
    } catch (e) {
      _log('isConnectedToSafeWifi ERROR: $e');
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
            _log('onConnectivityChanged ERROR: $e\n$stack');
          }
        },
        onError: (err) {
          _log('connectivity stream error: $err');
          _isListening = false;
        },
        onDone: () {
          _log('connectivity stream closed');
          _isListening = false;
        },
      );
      _isListening = true;
      _log('started');
    } catch (e, stack) {
      _log('startForegroundMonitoring ERROR: $e\n$stack');
      _isListening = false;
    }
  }

  Future<void> stopForegroundMonitoring() async {
    try {
      await _subscription?.cancel();
      _subscription = null;
      _isListening = false;
      _log('stopped');
    } catch (e) {
      _log('stop error: $e');
    }
  }

  Future<void> checkAndSendEvent({bool background = false, bool force = false, bool? connected}) async {
    try {
      _log('checkAndSendEvent: START background=$background force=$force connected=$connected');
      final currentSafe = connected ?? await isConnectedToSafeWifi();
      _log('checkAndSendEvent: currentSafe=$currentSafe');
      final previousSafe = await _getLastSafeState();
      _log('checkAndSendEvent: previousSafe=$previousSafe');

      bool shouldSend = false;
      if (force) {
        shouldSend = true;
        _log('FORCE=true -> shouldSend=true');
      } else if (currentSafe && !previousSafe) {
        shouldSend = true;
        _log('TRANSITION connected -> shouldSend=true');
      } else if (!currentSafe && previousSafe) {
        shouldSend = true;
        _log('TRANSITION disconnected -> shouldSend=true');
      } else if (!background) {
        _log('NO CHANGE. safe=$currentSafe prev=$previousSafe');
      }

      if (shouldSend) {
        _log('SENDING event...');
        await _sendEvent(currentSafe ? 'llegada' : 'salida');
        _log('Event sent successfully');
      } else {
        _log('No event to send');
      }
      
      await _saveLastSafeState(currentSafe);
      _log('State saved, currentSafe=$currentSafe');
    } catch (e, stack) {
      _log('checkAndSendEvent ERROR: $e\n$stack');
    }
  }

  Future<bool> _getLastSafeState() async {
    try {
      final stored = await _storage.read(key: 'last_safe_wifi_state');
      return stored == 'true';
    } catch (e) {
      _log('_getLastSafeState ERROR: $e');
      return false;
    }
  }

  Future<void> _saveLastSafeState(bool value) async {
    try {
      await _storage.write(key: 'last_safe_wifi_state', value: value ? 'true' : 'false');
    } catch (e) {
      _log('_saveLastSafeState ERROR: $e');
    }
  }

  Future<void> _sendEvent(String eventType) async {
    try {
      _log('_sendEvent: START eventType=$eventType');
      final payload = EventPayload(
        userId: userId,
        deviceId: deviceId,
        eventType: eventType,
        zoneName: zoneName,
        timestamp: DateTime.now(),
      );
      _log('Calling apiService.sendLocationEvent...');
      final success = await apiService.sendLocationEvent(payload);
      _log('apiService returned success=$success');
      if (!success) {
        _log('WARNING - API returned false');
      }
    } catch (e, stack) {
      _log('_sendEvent ERROR: $e\n$stack');
    }
  }
}