import 'dart:async';
import 'package:flutter/services.dart';

class NativeWifiListener {
  static const EventChannel _channel = EventChannel('mama_notifier/wifi_events');
  StreamSubscription? _subscription;
  bool _isListening = false;

  void start(Function(bool) onChange) {
    if (_isListening) return;
    
    try {
      _subscription = _channel.receiveBroadcastStream().listen(
        (event) {
          try {
            final isConnected = event == 'connected';
            onChange(isConnected);
          } catch (e) {
            print('NativeWifiListener onData error: $e');
          }
        },
        onError: (err) {
          print('NativeWifiListener stream error: $err');
          _isListening = false;
        },
        onDone: () {
          print('NativeWifiListener stream closed');
          _isListening = false;
        },
      );
      _isListening = true;
      print('NativeWifiListener started');
    } catch (e, stack) {
      print('NativeWifiListener start ERROR: $e\n$stack');
      _isListening = false;
    }
  }

  void stop() {
    try {
      _subscription?.cancel();
      _subscription = null;
      _isListening = false;
      print('NativeWifiListener stopped');
    } catch (e) {
      print('NativeWifiListener stop error: $e');
    }
  }
}