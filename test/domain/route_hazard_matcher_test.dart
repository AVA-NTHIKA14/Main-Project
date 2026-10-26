import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:road_loop/domain/route_hazard_matcher.dart';

void main() {
  group('RouteHazardMatcher', () {
    const matcher = RouteHazardMatcher();
    final now = DateTime(2026, 10, 24, 12);

    RouteHazardPoint createHazard({
      required String id,
      required double lat,
      required double lon,
      double severityWeight = 2.0,
      double confidence = 0.9,
    }) {
      return RouteHazardPoint(
        id: id,
        latitude: lat,
        longitude: lon,
        severityWeight: severityWeight,
        confidence: confidence,
        isVerified: true,
        lastObserved: now,
      );
    }

    test('handles empty route without throwing', () {
      final hazards = [createHazard(id: 'h1', lat: 12.9716, lon: 77.5946)];

      final result = matcher.match(route: const [], hazards: hazards);
      expect(result, isEmpty);
    });

    test('handles empty hazards list without throwing', () {
      final route = [
        const LatLng(12.9716, 77.5946),
        const LatLng(12.9816, 77.5946),
      ];

      final result = matcher.match(route: route, hazards: const []);
      expect(result, isEmpty);
    });

    test('handles single-point route without throwing', () {
      final route = [const LatLng(12.9716, 77.5946)];
      // Very close hazard (about 5 meters north)
      final closeHazard = createHazard(
        id: 'close',
        lat: 12.971645,
        lon: 77.5946,
      );
      // Far hazard (about 500 meters away)
      final farHazard = createHazard(id: 'far', lat: 12.9760, lon: 77.5946);

      final matches = matcher.match(
        route: route,
        hazards: [closeHazard, farHazard],
        thresholdMeters: 30.0,
      );

      expect(matches.length, 1);
      expect(matches.first.hazard.id, 'close');
      expect(matches.first.distanceAlongRouteMeters, 0.0);
      expect(matches.first.distanceToRouteMeters, lessThan(10.0));
    });

    test('matches hazard located directly on route segment', () {
      // Straight north route from 12.9700 to 12.9800 (approx 1,112 meters)
      final route = [
        const LatLng(12.9700, 77.5900),
        const LatLng(12.9800, 77.5900),
      ];
      // Hazard halfway along the route
      final onRouteHazard = createHazard(
        id: 'on-route',
        lat: 12.9750,
        lon: 77.5900,
      );

      final matches = matcher.match(
        route: route,
        hazards: [onRouteHazard],
        thresholdMeters: 30.0,
      );

      expect(matches.length, 1);
      expect(matches.first.hazard.id, 'on-route');
      expect(matches.first.distanceToRouteMeters, lessThan(0.5));
      // Halfway along ~1,112 m is ~556 m
      expect(matches.first.distanceAlongRouteMeters, closeTo(556.0, 5.0));
    });

    test(
      'matches hazard just inside threshold and excludes hazard just outside',
      () {
        final route = [
          const LatLng(12.9700, 77.5900),
          const LatLng(12.9800, 77.5900),
        ];

        // At lat ~12.975, 1 deg lon is ~6371000 * cos(12.975 deg) * pi/180 ≈ 108,350 meters.
        // 20 meters east: 20 / 108350 ≈ 0.0001846 degrees.
        // 40 meters east: 40 / 108350 ≈ 0.0003692 degrees.
        final insideThreshold = createHazard(
          id: 'inside-20m',
          lat: 12.9750,
          lon: 77.5900 + 0.0001846,
        );
        final outsideThreshold = createHazard(
          id: 'outside-40m',
          lat: 12.9750,
          lon: 77.5900 + 0.0003692,
        );

        final matches = matcher.match(
          route: route,
          hazards: [insideThreshold, outsideThreshold],
          thresholdMeters: 30.0,
        );

        expect(matches.length, 1);
        expect(matches.first.hazard.id, 'inside-20m');
        expect(matches.first.distanceToRouteMeters, closeTo(20.0, 1.5));
      },
    );

    test('matches hazard near a 90-degree corner correctly', () {
      // Route goes North (A -> B), then turns East (B -> C)
      // A: (12.9700, 77.5900)
      // B: (12.9750, 77.5900) (~556m from A)
      // C: (12.9750, 77.5950) (~542m from B)
      final route = [
        const LatLng(12.9700, 77.5900),
        const LatLng(12.9750, 77.5900),
        const LatLng(12.9750, 77.5950),
      ];

      // Hazard placed diagonally outside both segments (North-West of B):
      // 10m north, 10m west gives sqrt(10^2 + 10^2) ≈ 14.1m from corner vertex B
      final cornerVertexHazard = createHazard(
        id: 'corner-vertex',
        lat: 12.9750 + (10.0 / 111195.0),
        lon: 77.5900 - (10.0 / 108350.0),
      );

      final matches = matcher.match(
        route: route,
        hazards: [cornerVertexHazard],
        thresholdMeters: 30.0,
      );

      expect(matches.length, 1);
      expect(matches.first.hazard.id, 'corner-vertex');
      expect(matches.first.distanceToRouteMeters, closeTo(14.1, 2.0));
      // Distance along route should be approximately the length of segment A -> B (~556m)
      expect(matches.first.distanceAlongRouteMeters, closeTo(556.0, 5.0));
    });

    test('orders multiple hazards strictly by distance along route', () {
      final route = [
        const LatLng(12.9700, 77.5900),
        const LatLng(12.9800, 77.5900),
      ];

      // Hazards along the route at different positions:
      final first = createHazard(
        id: 'first',
        lat: 12.9720,
        lon: 77.5900,
      ); // ~222m
      final second = createHazard(
        id: 'second',
        lat: 12.9750,
        lon: 77.5900,
      ); // ~556m
      final third = createHazard(
        id: 'third',
        lat: 12.9780,
        lon: 77.5900,
      ); // ~889m

      // Pass in reverse / unordered order
      final matches = matcher.match(
        route: route,
        hazards: [third, first, second],
        thresholdMeters: 30.0,
      );

      expect(matches.map((m) => m.hazard.id).toList(), [
        'first',
        'second',
        'third',
      ]);
      expect(
        matches[0].distanceAlongRouteMeters,
        lessThan(matches[1].distanceAlongRouteMeters),
      );
      expect(
        matches[1].distanceAlongRouteMeters,
        lessThan(matches[2].distanceAlongRouteMeters),
      );
    });
  });
}
