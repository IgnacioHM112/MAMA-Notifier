import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'api_service.dart';
import 'wifi_monitor.dart';

class MyForegroundTaskHandler extends TaskHandler {
  WifiMonitor? _wifiMonitor;
  Timer? _timer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter taskStarter) async {
    print('Servicio Guardián iniciado.');
    
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

      // Revisar cada 30 segundos para máxima velocidad
      _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        await _wifiMonitor?.checkAndSendEvent(background: true);
      });
      
      await _wifiMonitor?.checkAndSendEvent(background: true);
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // No usado
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _timer?.cancel();
    print('Servicio Guardián detenido.');
  }
}
