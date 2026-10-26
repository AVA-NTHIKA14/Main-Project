// ignore_for_file: prefer_initializing_formals
import 'domain/route_risk.dart';
import 'explore.dart';
import 'map/hazard_adapter.dart';

export 'map/hazard_adapter.dart';

class RoutePlan {
  const RoutePlan({
    required this.id,
    required this.segmentIds,
    required this.durationMinutes,
    required this.distanceKm,
    this.isAlternative = false,
  });

  final String id;
  final List<String> segmentIds;
  final int durationMinutes;
  final double distanceKm;
  final bool isAlternative;
}

class RouteHazardWarning {
  const RouteHazardWarning({
    required this.hazard,
    required this.currentRoute,
    this.alternativeRoute,
    this.distanceAlongRouteMeters,
  });

  final Hazard hazard;
  final RoutePlan currentRoute;
  final RoutePlan? alternativeRoute;
  final double? distanceAlongRouteMeters;

  String get title => 'Road hazard ahead';
  String get detail {
    final distanceStr = distanceAlongRouteMeters != null
        ? '${distanceAlongRouteMeters!.round()} m ahead'
        : (hazard.distanceLabel.isEmpty ? 'ahead' : hazard.distanceLabel);
    return 'High-severity ${hazardTypeLabel(hazard.type)} · $distanceStr';
  }

  String get alternativeLabel => alternativeRoute == null
      ? 'No alternative route available'
      : 'Alternative route +${alternativeRoute!.durationMinutes - currentRoute.durationMinutes} min';
}

abstract interface class RoutingService {
  Future<RoutePlan> currentRoute();
  Future<RoutePlan?> alternativeRoute(RoutePlan currentRoute);
}

class MockRoutingService implements RoutingService {
  const MockRoutingService();

  @override
  Future<RoutePlan> currentRoute() async => const RoutePlan(
    id: 'current-route',
    segmentIds: ['west', 'north', 'east'],
    durationMinutes: 18,
    distanceKm: 5.2,
  );

  @override
  Future<RoutePlan?> alternativeRoute(RoutePlan currentRoute) async =>
      const RoutePlan(
        id: 'alternative-route',
        segmentIds: ['west', 'south', 'east'],
        durationMinutes: 21,
        distanceKm: 5.8,
        isAlternative: true,
      );
}

/// Service that evaluates road hazards against active routes to generate warnings
/// and recommend safer alternative routes.
class HazardAwareRoutingService {
  const HazardAwareRoutingService({
    required RoutingService routingService,
    this.minimumConfidence = .8,
    this.eligibilityFilter,
  }) : _routingService = routingService;

  final RoutingService _routingService;
  final double minimumConfidence;
  final HazardEligibilityFilter? eligibilityFilter;

  Future<RouteHazardWarning?> checkRoute({
    required List<Hazard> hazards,
  }) async {
    final route = await _routingService.currentRoute();

    // Find eligible high-severity hazards matching the route
    final matchedHazard = hazards
        .where(
          (item) =>
              route.segmentIds.contains(item.segmentId) &&
              item.status == VerificationStatus.verified &&
              item.severity == HazardSeverity.high &&
              item.confidence >= minimumConfidence &&
              (eligibilityFilter == null ||
                  eligibilityFilter!.isEligible(
                    hazardToRouteHazardPoint(item),
                  )),
        )
        .firstOrNull;

    if (matchedHazard == null) return null;

    return RouteHazardWarning(
      hazard: matchedHazard,
      currentRoute: route,
      alternativeRoute: await _routingService.alternativeRoute(route),
    );
  }

  Future<RoutePlan> reroute(RouteHazardWarning warning) async =>
      warning.alternativeRoute ?? warning.currentRoute;
}
