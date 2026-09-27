import 'dart:async';
import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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

  Future<void> _logToFile(String msg) async {
    try {
      // Try external storage first (visible to user)
      Directory? dir;
      try {
        if (await Permission.storage.isGranted || await Permission.storage.request().isGranted) {
          dir = Directory('/storage/emulated/0/Documents');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
        }
      } catch (_) {}
      
      // Fallback to app private directory
      dir ??= await getApplicationDocumentsDirectory();
      
      final file = File('${dir.path}/foreground_log.txt');
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString('$timestamp: $msg\n', mode: FileMode.append);
    } catch (e) {
      // Silent fail - logging shouldn't crash the service
      print('Log error: $e');
    }
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
      
      await _logToFile('Config loaded: ssid=$_ssid, user=$_userId, device=$_deviceId, zone=$_zoneName');
      
      if (_ssid != null && _userId != null && _deviceId != null) {
        _wifiMonitor = WifiMonitor(
          apiService: _apiService!,
          safeSsid: _ssid!,
          userId: _userId!,
          deviceId: _deviceId!,
          zoneName: _zoneName!,
        );

        // Check every 30 seconds for background monitoring
        _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
          _checkCount++;
          await _logToFile('Periodic check #$_checkCount triggered');
          try {
            await _wifiMonitor?.checkAndSendEvent(background: true);
            await _logToFile('Periodic check #$_checkCount completed');
          } catch (e, stack) {
            await _logToFile('Periodic check #$_checkCount ERROR: $e\n$stack');
          }
        });
        
        // Initial check
        await _logToFile('Running initial check...');
        await _wifiMonitor?.checkAndSendEvent(background: true);
        await _logToFile('Initial check completed');
      } else {
        await _logToFile('Missing config: ssid=$_ssid, user=$_userId, device=$_deviceId');
      }
    } catch (e, stack) {
      await _logToFile('onStart ERROR: $e\n$stack');
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