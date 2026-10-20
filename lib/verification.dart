import 'dart:math' as math;

import 'explore.dart';

class VerificationRules {
  const VerificationRules({
    this.minimumIndependentObservations = 5,
    this.spatialRadiusMeters = 35,
    this.temporalWindow = const Duration(minutes: 30),
  });

  final int minimumIndependentObservations;
  final double spatialRadiusMeters;
  final Duration temporalWindow;
}

class CrowdCluster {
  CrowdCluster({required this.id, required this.observations});

  final String id;
  final List<HazardObservation> observations;

  String get segmentId => observations.first.segmentId;
  HazardType get type => observations.first.type;
  int get observationCount => observations.length;
  int get uniqueUserCount =>
      observations.map((item) => item.userId).toSet().length;
  int get uniqueTripCount =>
      observations.map((item) => item.tripId).toSet().length;
  DateTime get firstObserved => observations
      .map((item) => item.timestamp)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime get lastObserved => observations
      .map((item) => item.timestamp)
      .reduce((a, b) => a.isAfter(b) ? a : b);
  RoadLocation get location {
    final latitude =
        observations
            .map((item) => item.location.latitude)
            .reduce((a, b) => a + b) /
        observations.length;
    final longitude =
        observations
            .map((item) => item.location.longitude)
            .reduce((a, b) => a + b) /
        observations.length;
    return RoadLocation(latitude: latitude, longitude: longitude);
  }
}

class VerificationAssessment {
  const VerificationAssessment({
    required this.independentObservationCount,
    required this.confidence,
    required this.qualifies,
    required this.reasons,
  });

  final int independentObservationCount;
  final double confidence;
  final bool qualifies;
  final List<String> reasons;
}

class VerificationService {
  const VerificationService({this.rules = const VerificationRules()});

  final VerificationRules rules;

  List<CrowdCluster> cluster(List<HazardObservation> observations) {
    final clusters = <CrowdCluster>[];
    for (final observation in observations) {
      CrowdCluster? match;
      for (final candidate in clusters) {
        if (_belongsTo(candidate, observation)) {
          match = candidate;
          break;
        }
      }
      if (match == null) {
        clusters.add(
          CrowdCluster(
            id: 'cluster-${clusters.length + 1}',
            observations: [observation],
          ),
        );
      } else {
        match.observations.add(observation);
      }
    }
    return clusters;
  }

  List<Hazard> process(List<HazardObservation> observations) =>
      cluster(observations).map(toHazard).toList(growable: false);

  Hazard toHazard(CrowdCluster cluster) {
    final independentCount = independentObservationCount(cluster);
    final status = independentCount >= rules.minimumIndependentObservations
        ? VerificationStatus.verified
        : cluster.observationCount > 1
        ? VerificationStatus.underVerification
        : VerificationStatus.possible;
    final confidence = math
        .min(1, independentCount / rules.minimumIndependentObservations)
        .toDouble();
    return Hazard(
      id: cluster.id,
      segmentId: cluster.segmentId,
      severity: _severity(cluster.observations),
      observations: List.unmodifiable(cluster.observations),
      status: status,
      type: cluster.type,
      location: cluster.location,
      confidence: confidence,
      firstObserved: cluster.firstObserved,
      lastObserved: cluster.lastObserved,
    );
  }

  int independentObservationCount(CrowdCluster cluster) =>
      _independentObservationCount(cluster.observations);

  VerificationAssessment assess(CrowdCluster cluster) {
    final independentCount = independentObservationCount(cluster);
    final reasons = <String>[
      '${cluster.observationCount} observations',
      '$independentCount independent users',
      'Same road segment',
      'Observed within configured time window',
    ];
    return VerificationAssessment(
      independentObservationCount: independentCount,
      confidence: math
          .min(1, independentCount / rules.minimumIndependentObservations)
          .toDouble(),
      qualifies: independentCount >= rules.minimumIndependentObservations,
      reasons: reasons,
    );
  }

  bool _belongsTo(CrowdCluster cluster, HazardObservation observation) {
    if (cluster.segmentId != observation.segmentId ||
        cluster.type != observation.type) {
      return false;
    }
    return cluster.observations.any(
      (existing) =>
          existing.timestamp.difference(observation.timestamp).abs() <=
              rules.temporalWindow &&
          _distanceMeters(existing.location, observation.location) <=
              rules.spatialRadiusMeters,
    );
  }

  int _independentObservationCount(List<HazardObservation> observations) {
    final edges = <String, Set<String>>{};
    for (final observation in observations) {
      edges
          .putIfAbsent(observation.userId, () => <String>{})
          .add(observation.tripId);
    }
    final tripToUser = <String, String>{};
    var matches = 0;
    bool visit(String user, Set<String> seen) {
      for (final trip in edges[user]!) {
        if (!seen.add(trip)) continue;
        final matchedUser = tripToUser[trip];
        if (matchedUser == null || visit(matchedUser, seen)) {
          tripToUser[trip] = user;
          return true;
        }
      }
      return false;
    }

    for (final user in edges.keys) {
      if (visit(user, <String>{})) matches++;
    }
    return matches;
  }

  HazardSeverity _severity(List<HazardObservation> observations) {
    return observations
        .map((item) => item.severity)
        .reduce((a, b) => a.index >= b.index ? a : b);
  }
}

double _distanceMeters(RoadLocation first, RoadLocation second) {
  const earthRadiusMeters = 6371000.0;
  final latitudeDelta = _radians(second.latitude - first.latitude);
  final longitudeDelta = _radians(second.longitude - first.longitude);
  final latitudeOne = _radians(first.latitude);
  final latitudeTwo = _radians(second.latitude);
  final a =
      math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(latitudeOne) *
          math.cos(latitudeTwo) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _radians(double degrees) => degrees * math.pi / 180;
