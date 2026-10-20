import 'explore.dart';

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
  });

  final Hazard hazard;
  final RoutePlan currentRoute;
  final RoutePlan? alternativeRoute;

  String get title => 'Road hazard ahead';
  String get detail =>
      'High-severity ${hazardTypeLabel(hazard.type)} · ${hazard.distanceLabel.isEmpty ? 'ahead' : hazard.distanceLabel}';
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

class HazardAwareRoutingService {
  const HazardAwareRoutingService({
    required RoutingService routingService,
    this.minimumConfidence = .8,
  }) : _routingService = routingService;

  final RoutingService _routingService;
  final double minimumConfidence;

  Future<RouteHazardWarning?> checkRoute({
    required List<Hazard> hazards,
  }) async {
    final route = await _routingService.currentRoute();
    final hazard = hazards
        .where(
          (item) =>
              route.segmentIds.contains(item.segmentId) &&
              item.status == VerificationStatus.verified &&
              item.severity == HazardSeverity.high &&
              item.confidence >= minimumConfidence,
        )
        .firstOrNull;
    if (hazard == null) return null;
    return RouteHazardWarning(
      hazard: hazard,
      currentRoute: route,
      alternativeRoute: await _routingService.alternativeRoute(route),
    );
  }

  Future<RoutePlan> reroute(RouteHazardWarning warning) async =>
      warning.alternativeRoute ?? warning.currentRoute;
}

String hazardTypeLabel(HazardType type) => switch (type) {
  HazardType.pothole => 'pothole',
  HazardType.roughSurface => 'rough road',
  HazardType.debris => 'debris',
  HazardType.unknown => 'road hazard',
};
