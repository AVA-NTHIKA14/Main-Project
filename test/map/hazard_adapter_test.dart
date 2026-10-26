import 'package:flutter_test/flutter_test.dart';
import 'package:road_loop/explore.dart';
import 'package:road_loop/map/hazard_adapter.dart';

void main() {
  group('hazard_adapter', () {
    final now = DateTime(2026, 10, 24, 10, 30);

    test('converts verified high-severity Hazard to RouteHazardPoint with expected weights', () {
      final hazard = Hazard(
        id: 'hz-high',
        segmentId: 'north',
        severity: HazardSeverity.high,
        status: VerificationStatus.verified,
        type: HazardType.pothole,
        location: const RoadLocation(latitude: 12.9716, longitude: 77.5946),
        confidence: 0.95,
        firstObserved: now.subtract(const Duration(days: 2)),
        lastObserved: now,
        observations: [
          HazardObservation(
            id: 'obs-1',
            segmentId: 'north',
            timestamp: now,
            userId: 'u1',
            tripId: 't1',
            location: const RoadLocation(latitude: 12.9716, longitude: 77.5946),
          ),
          HazardObservation(
            id: 'obs-2',
            segmentId: 'north',
            timestamp: now,
            userId: 'u2',
            tripId: 't2',
            location: const RoadLocation(latitude: 12.9716, longitude: 77.5946),
          ),
        ],
      );

      final point = hazardToRouteHazardPoint(hazard);

      expect(point.id, 'hz-high');
      expect(point.latitude, 12.9716);
      expect(point.longitude, 77.5946);
      expect(point.severityWeight, 3.0);
      expect(point.confidence, 0.95);
      expect(point.isVerified, isTrue);
      expect(point.lastObserved, now);
      expect(point.typeLabel, 'pothole');
      expect(point.severityLabel, 'high');
      expect(point.observationCount, 2);
    });

    test('converts unverified possible Hazard to RouteHazardPoint', () {
      final hazard = Hazard(
        id: 'hz-possible',
        segmentId: 'east',
        severity: HazardSeverity.possible,
        status: VerificationStatus.underVerification,
        type: HazardType.roughSurface,
        location: const RoadLocation(latitude: 13.0, longitude: 77.5),
        confidence: 0.4,
        firstObserved: now,
        lastObserved: now,
        observations: const [],
      );

      final point = hazardToRouteHazardPoint(hazard);

      expect(point.id, 'hz-possible');
      expect(point.severityWeight, 1.0);
      expect(point.isVerified, isFalse);
      expect(point.typeLabel, 'rough road');
      expect(point.severityLabel, 'possible');
      expect(point.observationCount, 0);
    });

    test('converts list of hazards preserving count', () {
      final list = [
        Hazard(
          id: 'h1',
          segmentId: 's1',
          severity: HazardSeverity.moderate,
          status: VerificationStatus.verified,
          type: HazardType.debris,
          location: const RoadLocation(latitude: 12.0, longitude: 77.0),
          confidence: 0.8,
          firstObserved: now,
          lastObserved: now,
          observations: const [],
        ),
      ];

      final points = hazardsToRouteHazardPoints(list);
      expect(points.length, 1);
      expect(points.first.id, 'h1');
      expect(points.first.typeLabel, 'debris');
    });
  });
}
