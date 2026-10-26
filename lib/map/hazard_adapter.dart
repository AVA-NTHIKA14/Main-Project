import '../domain/route_hazard_matcher.dart';
import '../explore.dart';

/// Default severity weights for converting [HazardSeverity] to numeric weights.
///
/// Note: These weights are relative ranking aids for route comparison and do
/// NOT represent validated physical collision or damage probabilities.
const Map<HazardSeverity, double> defaultHazardSeverityWeights = {
  HazardSeverity.high: 3.0,
  HazardSeverity.moderate: 2.0,
  HazardSeverity.possible: 1.0,
};

/// Human-readable label for a [HazardSeverity].
String hazardSeverityLabel(HazardSeverity severity) => switch (severity) {
  HazardSeverity.high => 'high',
  HazardSeverity.moderate => 'moderate',
  HazardSeverity.possible => 'possible',
};

/// Human-readable label for a [HazardType].
String hazardTypeLabel(HazardType type) => switch (type) {
  HazardType.pothole => 'pothole',
  HazardType.roughSurface => 'rough road',
  HazardType.debris => 'debris',
  HazardType.unknown => 'road hazard',
};

/// Converts a shared [Hazard] into an immutable [RouteHazardPoint].
///
/// Decouples route matching and navigation logic from the shared explore model.
RouteHazardPoint hazardToRouteHazardPoint(
  Hazard hazard, {
  Map<HazardSeverity, double> severityWeights = defaultHazardSeverityWeights,
}) {
  return RouteHazardPoint(
    id: hazard.id,
    latitude: hazard.location.latitude,
    longitude: hazard.location.longitude,
    severityWeight: severityWeights[hazard.severity] ?? 1.0,
    confidence: hazard.confidence,
    isVerified: hazard.status == VerificationStatus.verified,
    lastObserved: hazard.lastObserved,
    typeLabel: hazardTypeLabel(hazard.type),
    severityLabel: hazardSeverityLabel(hazard.severity),
    observationCount: hazard.observations.length,
  );
}

/// Converts a list of [Hazard]s into [RouteHazardPoint]s.
List<RouteHazardPoint> hazardsToRouteHazardPoints(
  Iterable<Hazard> hazards, {
  Map<HazardSeverity, double> severityWeights = defaultHazardSeverityWeights,
}) {
  return hazards
      .map((h) => hazardToRouteHazardPoint(h, severityWeights: severityWeights))
      .toList(growable: false);
}
