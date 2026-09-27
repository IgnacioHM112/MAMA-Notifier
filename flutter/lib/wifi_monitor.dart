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
  
  // Anti-duplicado / estabilidad - REDUCIDO PARA TESTING
  DateTime? _lastEventTime;
  String? _lastEventType;
  DateTime? _stateStableSince;
  bool? _lastKnownSafe;
  static const Duration _cooldown = Duration(seconds: 5); // Mínimo entre eventos (TEST: 5s)
  static const Duration _stabilityWindow = Duration(seconds: 1); // Estado debe ser estable 1s (TEST: 1s)

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

      // Retry up to 10 times with 1 second delay if SSID is null but we're on WiFi
      String? ssid;
      for (int attempt = 1; attempt <= 10; attempt++) {
        ssid = await NetworkInfo().getWifiName();
        _log('isConnectedToSafeWifi: Attempt $attempt/10 - Current SSID=$ssid');
        if (ssid != null && ssid.isNotEmpty) {
          break;
        }
        if (attempt < 10) {
          _log('isConnectedToSafeWifi: SSID is null/empty, retrying in 1s... (attempt ${attempt + 1}/10)');
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      
      if (ssid == null || ssid.isEmpty) {
        _log('isConnectedToSafeWifi: SSID is null/empty after 10 retries');
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
      final bool? previousSafe = await _getLastSafeState();
      _log('checkAndSendEvent: previousSafe=$previousSafe');

      final now = DateTime.now();
      
      // Ventana de estabilidad: el estado debe ser consistente por _stabilityWindow
      if (currentSafe == _lastKnownSafe) {
        _stateStableSince ??= now;
      } else {
        _stateStableSince = now;
        _lastKnownSafe = currentSafe;
      }
      
      final isStable = _stateStableSince != null && now.difference(_stateStableSince!) >= const Duration(seconds: 5);
      _log('checkAndSendEvent: currentSafe=$currentSafe, isStable=$isStable, stableSince=${_stateStableSince?.toIso8601String()}, lastKnownSafe=$_lastKnownSafe');

      bool shouldSend = false;
      String? eventType;
      
      if (force) {
        shouldSend = true;
        eventType = currentSafe ? 'llegada' : 'salida';
        _log('FORCE=true -> shouldSend=true');
      } else if (previousSafe == null) {
        // FIRST CHECK EVER: establish baseline, send if connected
        if (currentSafe) {
          shouldSend = true;
          eventType = 'llegada';
          _log('FIRST CHECK: establishing baseline, connected -> shouldSend=true');
        } else {
          _log('FIRST CHECK: establishing baseline, disconnected -> no event');
        }
      } else if (currentSafe && !previousSafe && isStable) {
        shouldSend = true;
        eventType = 'llegada';
        _log('TRANSITION connected (stable) -> shouldSend=true');
      } else if (!currentSafe && previousSafe && isStable) {
        shouldSend = true;
        eventType = 'salida';
        _log('TRANSITION disconnected (stable) -> shouldSend=true');
      } else if (!background) {
        _log('NO CHANGE or not stable. safe=$currentSafe prev=$previousSafe isStable=$isStable');
      }

      // Cooldown: no enviar si pasó muy poco tiempo desde el último evento del mismo tipo
      if (shouldSend && eventType != null) {
        final canSend = _lastEventTime == null || 
                       _lastEventType != eventType ||
                       now.difference(_lastEventTime!) >= const Duration(seconds: 30);
        
        if (!canSend) {
          _log('COOLDOWN: skipping $eventType (last $_lastEventType at $_lastEventTime)');
          shouldSend = false;
        }
      }

      if (shouldSend && eventType != null) {
        _log('SENDING event: $eventType');
        await _sendEventWithRetry(eventType!);
        _lastEventTime = DateTime.now();
        _lastEventType = eventType;
        _log('Event sent successfully');
      } else if (!shouldSend && eventType != null) {
        _log('Event suppressed (cooldown or not stable)');
      } else {
        _log('No event to send');
      }
      
      await _saveLastSafeState(currentSafe);
      _log('State saved, currentSafe=$currentSafe');
    } catch (e, stack) {
      _log('checkAndSendEvent ERROR: $e\n$stack');
    }
  }

  Future<bool?> _getLastSafeState() async {
    try {
      final stored = await _storage.read(key: 'last_safe_wifi_state');
      if (stored == null) return null;
      return stored == 'true';
    } catch (e) {
      _log('_getLastSafeState ERROR: $e');
      return null;
    }
  }

  Future<void> _saveLastSafeState(bool value) async {
    try {
      await _storage.write(key: 'last_safe_wifi_state', value: value ? 'true' : 'false');
    } catch (e) {
      _log('_saveLastSafeState ERROR: $e');
    }
  }

  Future<void> _sendEventWithRetry(String eventType) async {
    int maxRetries = 3;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        _log('_sendEvent: START eventType=$eventType (attempt $attempt/3)');
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
        if (success) {
          _log('_sendEvent: SUCCESS on attempt $attempt');
          return;
        } else {
          _log('WARNING - API returned false (attempt $attempt/3)');
        }
      } catch (e, stack) {
        _log('_sendEvent ERROR (attempt $attempt/3): $e\n$stack');
      }
      
      if (attempt < 3) {
        int delayMs = 1000 * attempt; // 1s, 2s, 3s
        _log('Retrying in ${delayMs}ms... (attempt ${attempt + 1}/3)');
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    _log('_sendEvent: FAILED after 3 attempts');
  }
}