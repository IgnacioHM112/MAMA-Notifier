import 'dart:async';
import 'package:flutter/services.dart';

class NativeWifiListener {
  static const EventChannel _channel = EventChannel('mama_notifier/wifi_events');
  StreamSubscription? _subscription;

  void start(Function(bool) onChange) {
    _subscription = _channel.receiveBroadcastStream().listen((event) {
      final isConnected = event == 'connected';
      onChange(isConnected);
    }, onError: (err) {
      print('NativeWifiListener error: $err');
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}