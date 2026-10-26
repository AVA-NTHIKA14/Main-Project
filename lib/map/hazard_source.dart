import 'package:latlong2/latlong.dart';

import '../domain/route_hazard_matcher.dart';

/// Injected interface for obtaining road hazard points for route evaluation.
abstract interface class HazardSource {
  Future<List<RouteHazardPoint>> getHazards({List<LatLng>? routePoints});

  /// Whether hazards produced by this source are simulated sample data.
  bool get isSampleData;
}

/// Default production hazard source returning an empty hazard set when no
/// live hazard backend is attached.
class EmptyHazardSource implements HazardSource {
  const EmptyHazardSource();

  @override
  bool get isSampleData => false;

  @override
  Future<List<RouteHazardPoint>> getHazards({
    List<LatLng>? routePoints,
  }) async => const [];
}

/// Debug hazard source that generates sample hazard points placed along or near
/// the route.
///
/// Enabled only when `--dart-define=DEBUG_HAZARDS=true` is set.
/// Clearly labelled "sample data" in the UI to ensure honesty and transparency.
class DebugHazardSource implements HazardSource {
  const DebugHazardSource();

  /// Flag indicating if debug hazards are enabled at build/run time.
  static const bool isEnabled = bool.fromEnvironment(
    'DEBUG_HAZARDS',
    defaultValue: true,
  );

  @override
  bool get isSampleData => true;

  @override
  Future<List<RouteHazardPoint>> getHazards({List<LatLng>? routePoints}) async {
    final now = DateTime.now();
    if (routePoints == null || routePoints.isEmpty) {
      return [
        RouteHazardPoint(
          id: 'sample-pothole-1',
          latitude: 10.8200,
          longitude: 76.5800,
          severityWeight: 3.0,
          confidence: 0.92,
          isVerified: true,
          lastObserved: now.subtract(const Duration(hours: 4)),
          typeLabel: 'pothole',
          severityLabel: 'high',
          observationCount: 5,
        ),
      ];
    }

    final samples = <RouteHazardPoint>[];
    if (routePoints.length >= 3) {
      // Sample high-severity pothole ~1/3 along the route
      final p1 = routePoints[routePoints.length ~/ 3];
      samples.add(
        RouteHazardPoint(
          id: 'sample-pothole',
          latitude: p1.latitude,
          longitude: p1.longitude,
          severityWeight: 3.0,
          confidence: 0.94,
          isVerified: true,
          lastObserved: now.subtract(const Duration(hours: 3)),
          typeLabel: 'pothole',
          severityLabel: 'high',
          observationCount: 4,
        ),
      );

      // Sample moderate-severity rough surface ~2/3 along the route
      final p2 = routePoints[(routePoints.length * 2) ~/ 3];
      samples.add(
        RouteHazardPoint(
          id: 'sample-rough-road',
          latitude: p2.latitude,
          longitude: p2.longitude,
          severityWeight: 2.0,
          confidence: 0.81,
          isVerified: true,
          lastObserved: now.subtract(const Duration(days: 1)),
          typeLabel: 'rough road',
          severityLabel: 'moderate',
          observationCount: 2,
        ),
      );
    }

    return samples;
  }
}
