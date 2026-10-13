import 'package:flutter_test/flutter_test.dart';

import 'package:roadsense/explore.dart';
import 'package:roadsense/routing.dart';

void main() {
  test(
    'warns only for verified high-confidence hazards on the route',
    () async {
      final service = HazardAwareRoutingService(
        routingService: const MockRoutingService(),
      );

      final warning = await service.checkRoute(
        hazards: [
          _hazard(
            id: 'possible',
            status: VerificationStatus.possible,
            severity: HazardSeverity.possible,
            segmentId: 'north',
            confidence: 1,
          ),
          _hazard(
            id: 'moderate',
            status: VerificationStatus.verified,
            severity: HazardSeverity.moderate,
            segmentId: 'north',
            confidence: 1,
          ),
          _hazard(
            id: 'off-route',
            status: VerificationStatus.verified,
            severity: HazardSeverity.high,
            segmentId: 'south',
            confidence: 1,
          ),
          _hazard(
            id: 'low-confidence',
            status: VerificationStatus.verified,
            severity: HazardSeverity.high,
            segmentId: 'north',
            confidence: .5,
          ),
          _hazard(
            id: 'eligible',
            status: VerificationStatus.verified,
            severity: HazardSeverity.high,
            segmentId: 'north',
            confidence: .9,
          ),
        ],
      );

      expect(warning, isNotNull);
      expect(warning!.hazard.id, 'eligible');
      expect(warning.title, 'Road hazard ahead');
      expect(warning.detail, contains('High-severity pothole'));
    },
  );

  test('returns alternative route and reroutes only when selected', () async {
    final service = HazardAwareRoutingService(
      routingService: const MockRoutingService(),
    );
    final warning = await service.checkRoute(
      hazards: [
        _hazard(
          id: 'verified',
          status: VerificationStatus.verified,
          severity: HazardSeverity.high,
          segmentId: 'north',
          confidence: 1,
        ),
      ],
    );

    expect(warning!.alternativeLabel, 'Alternative route +3 min');
    expect(warning.currentRoute.id, 'current-route');
    final rerouted = await service.reroute(warning);
    expect(rerouted.id, 'alternative-route');
    expect(rerouted.isAlternative, isTrue);
  });

  test('does not warn when the route has no eligible hazards', () async {
    final service = HazardAwareRoutingService(
      routingService: const MockRoutingService(),
    );
    final warning = await service.checkRoute(
      hazards: [
        _hazard(
          id: 'possible',
          status: VerificationStatus.underVerification,
          severity: HazardSeverity.high,
          segmentId: 'north',
          confidence: 1,
        ),
      ],
    );

    expect(warning, isNull);
  });
}

Hazard _hazard({
  required String id,
  required VerificationStatus status,
  required HazardSeverity severity,
  required String segmentId,
  required double confidence,
}) {
  final time = DateTime(2026, 10, 7, 10);
  return Hazard(
    id: id,
    segmentId: segmentId,
    severity: severity,
    observations: const [],
    status: status,
    type: HazardType.pothole,
    location: const RoadLocation(latitude: 51.5, longitude: -.12),
    confidence: confidence,
    firstObserved: time,
    lastObserved: time,
    distanceLabel: '350 m',
  );
}
