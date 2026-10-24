class GpsFix {
  const GpsFix({
    required this.lat,
    required this.lng,
    required this.speed,
    required this.timestamp,
  });

  final double lat;
  final double lng;
  final double speed;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'speed': speed,
    'timestamp': timestamp.toIso8601String(),
  };

  factory GpsFix.fromJson(Map<String, dynamic> json) => GpsFix(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    speed: (json['speed'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
