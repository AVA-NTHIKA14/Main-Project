import 'package:flutter_test/flutter_test.dart';

import 'package:road_loop/explore.dart';
import 'package:road_loop/verification.dart';

final origin = DateTime(2026, 10, 7, 10);

void main() {
  test('duplicate observations from one trip do not verify a hazard', () {
    final service = VerificationService();
    final observations = List.generate(
      8,
      (index) => _observation(
        id: 'duplicate-$index',
        userId: 'user-1',
        tripId: 'trip-1',
        minutesAfter: index,
      ),
    );

    final hazard = service.process(observations).single;

    expect(hazard.observationCount, 8);
    expect(hazard.uniqueUserCount, 1);
    expect(hazard.uniqueTripCount, 1);
    expect(hazard.status, VerificationStatus.underVerification);
    expect(hazard.confidence, .2);
  });

  test('same user across multiple trips remains one independent source', () {
    final service = VerificationService();
    final observations = List.generate(
      6,
      (index) => _observation(
        id: 'same-user-$index',
        userId: 'user-1',
        tripId: 'trip-$index',
      ),
    );

    final hazard = service.process(observations).single;

    expect(hazard.uniqueUserCount, 1);
    expect(hazard.uniqueTripCount, 6);
    expect(hazard.status, VerificationStatus.underVerification);
  });

  test('independent users and trips verify at the configured threshold', () {
    final service = VerificationService();
    final observations = List.generate(
      5,
      (index) => _observation(
        id: 'independent-$index',
        userId: 'user-$index',
        tripId: 'trip-$index',
      ),
    );

    final hazard = service.process(observations).single;

    expect(hazard.status, VerificationStatus.verified);
    expect(hazard.uniqueUserCount, 5);
    expect(hazard.uniqueTripCount, 5);
    expect(hazard.confidence, 1);
  });

  test('observations outside the spatial radius form separate clusters', () {
    final service = VerificationService();
    final observations = [
      _observation(id: 'near', userId: 'user-1', tripId: 'trip-1'),
      _observation(
        id: 'far',
        userId: 'user-2',
        tripId: 'trip-2',
        latitude: 51.51,
      ),
    ];

    final clusters = service.cluster(observations);

    expect(clusters, hasLength(2));
  });

  test('threshold is configurable', () {
    final service = VerificationService(
      rules: const VerificationRules(minimumIndependentObservations: 2),
    );
    final observations = [
      _observation(id: 'one', userId: 'user-1', tripId: 'trip-1'),
      _observation(id: 'two', userId: 'user-2', tripId: 'trip-2'),
    ];

    expect(
      service.process(observations).single.status,
      VerificationStatus.verified,
    );
  });

  test('different road segments do not share a cluster', () {
    final service = VerificationService();
    final observations = [
      _observation(id: 'north', userId: 'user-1', tripId: 'trip-1'),
      _observation(
        id: 'east',
        userId: 'user-2',
        tripId: 'trip-2',
        segmentId: 'east',
      ),
    ];

    expect(service.cluster(observations), hasLength(2));
  });
}

HazardObservation _observation({
  required String id,
  required String userId,
  required String tripId,
  String segmentId = 'north',
  double latitude = 51.5007,
  int minutesAfter = 0,
}) {
  return HazardObservation(
    id: id,
    segmentId: segmentId,
    timestamp: origin.add(Duration(minutes: minutesAfter)),
    userId: userId,
    tripId: tripId,
    location: RoadLocation(latitude: latitude, longitude: -0.1246),
    type: HazardType.pothole,
    severity: HazardSeverity.moderate,
  );
}
