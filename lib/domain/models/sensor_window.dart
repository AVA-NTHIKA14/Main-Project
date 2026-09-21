import 'gps_fix.dart';
import 'sensor_sample.dart';

class SensorWindow {
  const SensorWindow({
    required this.samples,
    required this.gpsFix,
    required this.windowStart,
    required this.windowEnd,
  });

  final List<SensorSample> samples;
  final GpsFix gpsFix;
  final DateTime windowStart;
  final DateTime windowEnd;

  Map<String, dynamic> toJson() => {
        'samples': samples.map((sample) => sample.toJson()).toList(),
        'gpsFix': gpsFix.toJson(),
        'windowStart': windowStart.toIso8601String(),
        'windowEnd': windowEnd.toIso8601String(),
      };

  factory SensorWindow.fromJson(Map<String, dynamic> json) => SensorWindow(
        samples: (json['samples'] as List<dynamic>)
            .map((sample) =>
                SensorSample.fromJson(sample as Map<String, dynamic>))
            .toList(growable: false),
        gpsFix: GpsFix.fromJson(json['gpsFix'] as Map<String, dynamic>),
        windowStart: DateTime.parse(json['windowStart'] as String),
        windowEnd: DateTime.parse(json['windowEnd'] as String),
      );
}
