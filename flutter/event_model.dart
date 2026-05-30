class EventPayload {
  final String userId;
  final String deviceId;
  final String eventType;
  final String zoneName;
  final DateTime timestamp;

  EventPayload({
    required this.userId,
    required this.deviceId,
    required this.eventType,
    required this.zoneName,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'device_id': deviceId,
    'event_type': eventType,
    'location_data': {
      'zone_name': zoneName,
      'timestamp': timestamp.toIso8601String(),
    },
  };
}
