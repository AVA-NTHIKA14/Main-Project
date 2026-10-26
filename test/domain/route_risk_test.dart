import 'package:flutter_test/flutter_test.dart';
import 'package:road_loop/domain/route_hazard_matcher.dart';
import 'package:road_loop/domain/route_risk.dart';

void main() {
  group('HazardEligibilityFilter', () {
    final now = DateTime(2026, 10, 25, 12);
    const filter = HazardEligibilityFilter();

    test('accepts recent hazard with high confidence', () {
      final hazard = RouteHazardPoint(
        id: 'h1',
        latitude: 12.0,
        longitude: 77.0,
        severityWeight: 3.0,
        confidence: 0.85,
        isVerified: true,
        lastObserved: now.subtract(const Duration(days: 2)),
      );

      expect(filter.isEligible(hazard, now: now), isTrue);
    });

    test('rejects stale hazard older than 7 days', () {
      final staleHazard = RouteHazardPoint(
        id: 'stale',
        latitude: 12.0,
        longitude: 77.0,
        severityWeight: 3.0,
        confidence: 0.95,
        isVerified: true,
        lastObserved: now.subtract(const Duration(days: 8)),
      );

      expect(filter.isEligible(staleHazard, now: now), isFalse);
    });

    test('rejects hazard with confidence below threshold', () {
      final lowConfidenceHazard = RouteHazardPoint(
        id: 'low-conf',
        latitude: 12.0,
        longitude: 77.0,
        severityWeight: 3.0,
        confidence: 0.5,
        isVerified: true,
        lastObserved: now.subtract(const Duration(hours: 4)),
      );

      expect(filter.isEligible(lowConfidenceHazard, now: now), isFalse);
    });
  });

  group('RouteRiskCalculator', () {
    final now = DateTime(2026, 10, 25, 12);
    const calculator = RouteRiskCalculator();

    test('returns zero risk for empty matches', () {
      final risk = calculator.calculateRisk([]);
      expect(risk.score, 0.0);
      expect(risk.eligibleHazards, isEmpty);
      expect(risk.highSeverityCount, 0);
    });

    test('computes relative ranking score as sum(severityWeight * confidence) for eligible hazards only', () {
      final eligibleHigh = RouteHazardMatch(
        hazard: RouteHazardPoint(
          id: 'high-1',
          latitude: 12.0,
          longitude: 77.0,
          severityWeight: 3.0,
          confidence: 0.9, // 3.0 * 0.9 = 2.7
          isVerified: true,
          lastObserved: now.subtract(const Duration(days: 1)),
          severityLabel: 'high',
        ),
        distanceAlongRouteMeters: 200.0,
        distanceToRouteMeters: 5.0,
      );

      final eligibleModerate = RouteHazardMatch(
        hazard: RouteHazardPoint(
          id: 'mod-1',
          latitude: 12.0,
          longitude: 77.0,
          severityWeight: 2.0,
          confidence: 0.8, // 2.0 * 0.8 = 1.6
          isVerified: true,
          lastObserved: now.subtract(const Duration(days: 3)),
          severityLabel: 'moderate',
        ),
        distanceAlongRouteMeters: 500.0,
        distanceToRouteMeters: 10.0,
      );

      final staleIgnored = RouteHazardMatch(
        hazard: RouteHazardPoint(
          id: 'stale-1',
          latitude: 12.0,
          longitude: 77.0,
          severityWeight: 3.0,
          confidence: 0.99,
          isVerified: true,
          lastObserved: now.subtract(const Duration(days: 15)), // Stale
        ),
        distanceAlongRouteMeters: 100.0,
        distanceToRouteMeters: 2.0,
      );

      final risk = calculator.calculateRisk([
        eligibleHigh,
        eligibleModerate,
        staleIgnored,
      ], now: now);

      // Expected score: 2.7 + 1.6 = 4.3
      expect(risk.score, closeTo(4.3, 0.001));
      expect(risk.eligibleHazards.length, 2);
      expect(risk.matchedHazards.length, 3);
      expect(risk.highSeverityCount, 1);
      expect(risk.hasHighSeverityHazard, isTrue);
      expect(risk.firstHazard?.hazard.id, 'high-1');
      expect(risk.firstHighSeverityHazard?.hazard.id, 'high-1');
    });
  });
}
