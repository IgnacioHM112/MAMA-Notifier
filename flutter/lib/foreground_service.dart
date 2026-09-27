import 'dart:async';
import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';

class MyForegroundTaskHandler extends TaskHandler {
  Timer? _timer;
  ApiService? _apiService;
  String? _ssid;
  String? _userId;
  String? _deviceId;
  String? _zoneName;

  Future<void> _logToFile(String msg) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/foreground_log.txt');
      await file.writeAsString('${DateTime.now()}: $msg\n', mode: FileMode.append);
    } catch (_) {}
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter taskStarter) async {
    await _logToFile('=== SERVICE STARTED ===');
    try {
      _apiService = ApiService();
      _ssid = await _apiService!.getSafeSsid();
      _userId = await _apiService!.getUserId();
      _deviceId = await _apiService!.getDeviceId();
      _zoneName = await _apiService!.getZoneName() ?? 'Casa';
      
      await _logToFile('Config loaded: ssid=$_ssid, user=$_userId, zone=$_zoneName');
      
      if (_ssid != null && _userId != null && _deviceId != null) {
        // Simple periodic check without WifiMonitor to avoid crashes
        _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
          await _performCheck();
        });
        
        // Initial check
        await _performCheck();
        await _logToFile('Initial check completed');
      } else {
        await _logToFile('Missing config: ssid=$_ssid, user=$_userId, device=$_deviceId');
      }
    } catch (e, stack) {
      await _logToFile('onStart ERROR: $e\n$stack');
    }
  }

  Future<void> _performCheck() async {
    if (_apiService == null || _ssid == null || _userId == null || _deviceId == null) {
      return;
    }
    try {
      await _logToFile('Performing periodic check...');
      // Simple connectivity check without WifiMonitor
      // In a real implementation you'd check WiFi here
      // For now just log that service is alive
      await _logToFile('Periodic check OK - service alive');
    } catch (e, stack) {
      await _logToFile('_performCheck ERROR: $e\n$stack');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _logToFile('Heartbeat');
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _timer?.cancel();
    await _logToFile('=== SERVICE STOPPED (timeout=$isTimeout) ===');
  }
}