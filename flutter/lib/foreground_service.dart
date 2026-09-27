import 'dart:async';
import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'api_service.dart';
import 'wifi_monitor.dart';

class MyForegroundTaskHandler extends TaskHandler {
  Timer? _timer;
  WifiMonitor? _wifiMonitor;
  ApiService? _apiService;
  String? _ssid;
  String? _userId;
  String? _deviceId;
  String? _zoneName;
  int _checkCount = 0;
  bool _lastWifiState = false;

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

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter taskStarter) async {
    await _logToFile('=== SERVICE STARTED === timestamp=$timestamp');
    try {
      _apiService = ApiService();
      _ssid = await _apiService!.getSafeSsid();
      _userId = await _apiService!.getUserId();
      _deviceId = await _apiService!.getDeviceId();
      _zoneName = await _apiService!.getZoneName() ?? 'Casa';
      
      await _logToFile('Config loaded: ssid=$_ssid, user=$_userId, zone=$_zoneName');
      
      if (_ssid != null && _userId != null && _deviceId != null) {
        _wifiMonitor = WifiMonitor(
          apiService: _apiService!,
          safeSsid: _ssid!,
          userId: _userId!,
          deviceId: _deviceId!,
          zoneName: _zoneName!,
        );

        // Initial check
        await _performCheck();

        // Check every 20 seconds for background monitoring (more frequent)
        _timer = Timer.periodic(const Duration(seconds: 20), (timer) async {
          await _performCheck();
        });
        
        await _logToFile('Initial check completed, periodic checks started (20s interval)');
      } else {
        await _logToFile('Missing config: ssid=$_ssid, user=$_userId, device=$_deviceId');
      }
    } catch (e, stack) {
      await _logToFile('onStart ERROR: $e\n$stack');
    }
  }

  Future<void> _performCheck() async {
    _checkCount++;
    if (_wifiMonitor == null || _apiService == null || _ssid == null || _userId == null || _deviceId == null) {
      await _logToFile('Periodic check #$_checkCount: Missing config, skipping');
      return;
    }
    try {
      await _logToFile('Periodic check #$_checkCount triggered');
      
      // Check WiFi state with retries
      bool currentWifi = false;
      for (int attempt = 1; attempt <= 5; attempt++) {
        final status = await Connectivity().checkConnectivity();
        if (status.contains(ConnectivityResult.wifi)) {
          String? ssid;
          for (int ssidAttempt = 1; ssidAttempt <= 3; ssidAttempt++) {
            final ssid = await NetworkInfo().getWifiName();
            if (ssid != null && ssid.isNotEmpty) {
              final connected = ssid.replaceAll('"', '').toLowerCase() == _ssid!.replaceAll('"', '').toLowerCase();
              if (connected) {
                currentWifi = true;
                break;
              }
            }
            if (ssidAttempt < 3) {
              await Future.delayed(const Duration(milliseconds: 500));
            }
          }
        }
        
        if (currentWifi || !await Connectivity().checkConnectivity().then((s) => s.contains(ConnectivityResult.wifi))) {
          break; // Not on WiFi or we got a result
        }
        
        if (attempt < 5) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      
      await _logToFile('Periodic check #$_checkCount: WiFi connected to safe network = $currentWifi');
      
      // Only send event if state changed
      if (currentWifi != _lastWifiState) {
        await _logToFile('Periodic check #$_checkCount: WiFi state changed! current=$currentWifi, previous=$_lastWifiState');
        _lastWifiState = currentWifi;
        
        // Recreate WifiMonitor with proper config and send event
        if (_wifiMonitor == null) {
          _wifiMonitor = WifiMonitor(
            apiService: _apiService!,
            safeSsid: _ssid!,
            userId: _userId!,
            deviceId: _deviceId!,
            zoneName: _zoneName ?? 'Casa',
          );
        }
        await _wifiMonitor!.checkAndSendEvent(
          background: true,
          force: false,
          connected: currentWifi,
        );
      }
      
      await _logToFile('Periodic check #$_checkCount completed');
    } catch (e, stack) {
      await _logToFile('Periodic check #$_checkCount ERROR: $e\n$stack');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _logToFile('Heartbeat received at $timestamp');
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _timer?.cancel();
    await _logToFile('=== SERVICE STOPPED (timeout=$isTimeout) timestamp=$timestamp ===');
  }
}