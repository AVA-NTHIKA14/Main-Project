import 'package:road_loop/domain/models/gps_fix.dart';
import 'package:road_loop/domain/models/hazard_event.dart';
import 'package:road_loop/domain/models/hazard_result.dart';
import 'package:road_loop/domain/models/hazard_status.dart';
import 'package:road_loop/domain/models/hazard_type.dart';
import 'package:road_loop/domain/models/sensor_sample.dart';
import 'package:road_loop/domain/models/sensor_window.dart';
import 'package:road_loop/domain/models/severity_level.dart';
import 'package:test/test.dart';

void main() {
  final timestamp = DateTime.utc(2026, 9, 21, 10, 20, 30);

  group('model JSON serialization', () {
    test('GpsFix round trips', () {
      final model = GpsFix(
        lat: 12.9716,
        lng: 77.5946,
        speed: 8.5,
        timestamp: timestamp,
      );
      final decoded = GpsFix.fromJson(model.toJson());

      expect(decoded.lat, model.lat);
      expect(decoded.lng, model.lng);
      expect(decoded.speed, model.speed);
      expect(decoded.timestamp, model.timestamp);
    });

    test('SensorSample round trips', () {
      final model = SensorSample(
        ax: 1.0,
        ay: 2.0,
        az: 9.8,
        gx: 0.1,
        gy: 0.2,
        gz: 0.3,
        timestamp: timestamp,
      );
      final decoded = SensorSample.fromJson(model.toJson());

      expect(decoded.toJson(), model.toJson());
    });

    test('SensorWindow round trips', () {
      final model = SensorWindow(
        samples: [
          SensorSample(
            ax: 1,
            ay: 2,
            az: 3,
            gx: 4,
            gy: 5,
            gz: 6,
            timestamp: timestamp,
          ),
        ],
        gpsFix: GpsFix(lat: 1, lng: 2, speed: 3, timestamp: timestamp),
        windowStart: timestamp,
        windowEnd: timestamp.add(const Duration(seconds: 1)),
      );
      final decoded = SensorWindow.fromJson(model.toJson());

      expect(decoded.toJson(), model.toJson());
    });

    test('HazardResult round trips with nullable severity', () {
      final model = const HazardResult(
        type: HazardType.pothole,
        confidence: 0.91,
        severity: SeverityLevel.high,
      );
      final decoded = HazardResult.fromJson(model.toJson());

      expect(decoded.toJson(), model.toJson());
    });

    test('HazardEvent round trips with defaults and nullable fields', () {
      final model = HazardEvent(
        id: 'event-1',
        lat: 12.9,
        lng: 77.5,
        geohash: 'tdr1',
        type: HazardType.speedBump,
        reportedBy: 'user-1',
        timestamp: timestamp,
      );
      final decoded = HazardEvent.fromJson(model.toJson());

      expect(decoded.toJson(), model.toJson());
      expect(decoded.verificationCount, 0);
      expect(decoded.status, HazardStatus.unverified);
    });

    test('enum values serialize using stable names', () {
      expect(HazardType.unclassified.name, 'unclassified');
      expect(SeverityLevel.medium.name, 'medium');
      expect(HazardStatus.repaired.name, 'repaired');
    });
  });
}
