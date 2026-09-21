class SensorSample {
  const SensorSample({
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.timestamp,
  });

  final double ax;
  final double ay;
  final double az;
  final double gx;
  final double gy;
  final double gz;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'ax': ax,
        'ay': ay,
        'az': az,
        'gx': gx,
        'gy': gy,
        'gz': gz,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SensorSample.fromJson(Map<String, dynamic> json) => SensorSample(
        ax: (json['ax'] as num).toDouble(),
        ay: (json['ay'] as num).toDouble(),
        az: (json['az'] as num).toDouble(),
        gx: (json['gx'] as num).toDouble(),
        gy: (json['gy'] as num).toDouble(),
        gz: (json['gz'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
