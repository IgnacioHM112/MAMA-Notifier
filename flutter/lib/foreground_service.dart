import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'api_service.dart';
import 'wifi_monitor.dart';

class MyForegroundTaskHandler extends TaskHandler {
  WifiMonitor? _wifiMonitor;
  Timer? _timer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter taskStarter) async {
    print('✅ Foreground service STARTED (full)');
    
    final apiService = ApiService();
    final ssid = await apiService.getSafeSsid();
    final userId = await apiService.getUserId();
    final deviceId = await apiService.getDeviceId();
    final zoneName = await apiService.getZoneName() ?? 'Casa';

    if (ssid != null && userId != null && deviceId != null) {
      _wifiMonitor = WifiMonitor(
        apiService: apiService,
        safeSsid: ssid,
        userId: userId,
        deviceId: deviceId,
        zoneName: zoneName,
      );

      // Check every 30 seconds for background monitoring
      _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        await _wifiMonitor?.checkAndSendEvent(background: true);
      });
      
      // Initial check
      await _wifiMonitor?.checkAndSendEvent(background: true);
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Heartbeat - just log we're alive
    print('💓 Foreground service heartbeat');
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _timer?.cancel();
    print('🛑 Foreground service STOPPED');
  }
}