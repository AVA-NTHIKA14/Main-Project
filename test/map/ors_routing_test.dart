import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:road_loop/domain/route_hazard_matcher.dart';
import 'package:road_loop/navigation_services.dart';

void main() {
  const fromPlace = RoutePlace(
    name: 'Origin',
    subtitle: 'Start',
    latitude: 12.9716,
    longitude: 77.5946,
  );

  const toPlace = RoutePlace(
    name: 'Destination',
    subtitle: 'End',
    latitude: 13.0827,
    longitude: 80.2707,
  );

  final fallbackRoute = CalculatedRoute(
    distanceMeters: 345000.0,
    durationSeconds: 21600.0,
    points: [fromPlace.point, toPlace.point],
  );

  group('OrsRouteCalculationService', () {
    test('falls back immediately to OSRM when ORS_API_KEY is empty', () async {
      var fallbackCalled = false;
      final fallbackService = _FakeFallbackService(
        onCalculate: () {
          fallbackCalled = true;
          return [fallbackRoute];
        },
      );

      final orsService = OrsRouteCalculationService(
        apiKey: '', // Empty key
        fallbackService: fallbackService,
      );

      final routes = await orsService.calculate(
        from: fromPlace,
        to: toPlace,
        includeAlternatives: false,
      );

      expect(fallbackCalled, isTrue);
      expect(routes.length, 1);
      expect(routes.first.distanceMeters, 345000.0);
    });

    test(
      'successfully parses ORS GeoJSON response with distance and duration',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.headers['Authorization'], 'test-ors-api-key');
          expect(request.url.path, contains('/directions/driving-car/geojson'));

          final responseJson = {
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'geometry': {
                  'type': 'LineString',
                  'coordinates': [
                    [77.5946, 12.9716],
                    [78.5000, 13.0000],
                    [80.2707, 13.0827],
                  ],
                },
                'properties': {
                  'summary': {'distance': 348500.5, 'duration': 21200.0},
                },
              },
            ],
          };

          return http.Response(
            jsonEncode(responseJson),
            200,
            headers: {'content-type': 'application/geo+json'},
          );
        });

        final orsService = OrsRouteCalculationService(
          apiKey: 'test-ors-api-key',
          client: mockClient,
        );

        final routes = await orsService.calculate(
          from: fromPlace,
          to: toPlace,
          includeAlternatives: false,
        );

        expect(routes.length, 1);
        expect(routes.first.distanceMeters, 348500.5);
        expect(routes.first.durationSeconds, 21200.0);
        expect(routes.first.points.length, 3);
        expect(routes.first.points.first, const LatLng(12.9716, 77.5946));
        expect(routes.first.points.last, const LatLng(13.0827, 80.2707));
      },
    );

    test(
      'adds avoid_polygons for severe hazards (severityWeight >= 0.8)',
      () async {
        String? sentBody;
        final mockClient = MockClient((request) async {
          sentBody = request.body;
          final responseJson = {
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'geometry': {
                  'type': 'LineString',
                  'coordinates': [
                    [77.5946, 12.9716],
                    [80.2707, 13.0827],
                  ],
                },
                'properties': {
                  'summary': {'distance': 350000.0, 'duration': 22000.0},
                },
              },
            ],
          };
          return http.Response(jsonEncode(responseJson), 200);
        });

        final severeHazard = RouteHazardPoint(
          id: 'hz-severe-1',
          latitude: 13.0,
          longitude: 78.5,
          severityWeight: 0.9, // Severe
          confidence: 0.9,
          isVerified: true,
          lastObserved: DateTime(2026, 10, 25),
        );

        final minorHazard = RouteHazardPoint(
          id: 'hz-minor-2',
          latitude: 13.01,
          longitude: 78.51,
          severityWeight: 0.4, // Minor
          confidence: 0.8,
          isVerified: true,
          lastObserved: DateTime(2026, 10, 25),
        );

        final orsService = OrsRouteCalculationService(
          apiKey: 'test-ors-api-key',
          client: mockClient,
          avoidHazards: [severeHazard, minorHazard],
        );

        await orsService.calculate(
          from: fromPlace,
          to: toPlace,
          includeAlternatives: false,
        );

        expect(sentBody, isNotNull);
        final parsed = jsonDecode(sentBody!) as Map<String, dynamic>;
        final options = parsed['options'] as Map<String, dynamic>?;
        expect(options, isNotNull);
        final avoidPolygons =
            options!['avoid_polygons'] as Map<String, dynamic>?;
        expect(avoidPolygons, isNotNull);
        expect(avoidPolygons!['type'], 'MultiPolygon');

        final coordinates = avoidPolygons['coordinates'] as List<dynamic>;
        // Only the 1 severe hazard should produce an avoid polygon
        expect(coordinates.length, 1);
        final ring =
            (coordinates.first as List<dynamic>).first as List<dynamic>;
        // Closed 8-point polygon has 9 coordinates (first == last)
        expect(ring.length, 9);
        expect(ring.first, ring.last);
      },
    );

    test(
      'falls back gracefully to OSRM when ORS returns 503 outage or error',
      () async {
        var fallbackCalled = false;
        final fallbackService = _FakeFallbackService(
          onCalculate: () {
            fallbackCalled = true;
            return [fallbackRoute];
          },
        );

        final mockClient = MockClient((request) async {
          // Simulates 503 Service Unavailable (e.g. PHP incident / outage)
          return http.Response('Service Unavailable: PHP backend error', 503);
        });

        final orsService = OrsRouteCalculationService(
          apiKey: 'test-ors-api-key',
          client: mockClient,
          fallbackService: fallbackService,
        );

        final routes = await orsService.calculate(
          from: fromPlace,
          to: toPlace,
          includeAlternatives: false,
        );

        expect(fallbackCalled, isTrue);
        expect(routes.length, 1);
        expect(routes.first.distanceMeters, 345000.0);
      },
    );

    test('falls back gracefully to OSRM on rate limit (HTTP 429)', () async {
      var fallbackCalled = false;
      final fallbackService = _FakeFallbackService(
        onCalculate: () {
          fallbackCalled = true;
          return [fallbackRoute];
        },
      );

      final mockClient = MockClient((request) async {
        return http.Response('{"error":"Rate limit exceeded"}', 429);
      });

      final orsService = OrsRouteCalculationService(
        apiKey: 'test-ors-api-key',
        client: mockClient,
        fallbackService: fallbackService,
      );

      final routes = await orsService.calculate(
        from: fromPlace,
        to: toPlace,
        includeAlternatives: false,
      );

      expect(fallbackCalled, isTrue);
      expect(routes.length, 1);
    });

    test('falls back gracefully to OSRM on network exception', () async {
      var fallbackCalled = false;
      final fallbackService = _FakeFallbackService(
        onCalculate: () {
          fallbackCalled = true;
          return [fallbackRoute];
        },
      );

      final mockClient = MockClient((request) async {
        throw http.ClientException('Network connection failed');
      });

      final orsService = OrsRouteCalculationService(
        apiKey: 'test-ors-api-key',
        client: mockClient,
        fallbackService: fallbackService,
      );

      final routes = await orsService.calculate(
        from: fromPlace,
        to: toPlace,
        includeAlternatives: false,
      );

      expect(fallbackCalled, isTrue);
      expect(routes.length, 1);
    });
  });
}

class _FakeFallbackService implements RouteCalculationService {
  _FakeFallbackService({required this.onCalculate});

  final List<CalculatedRoute> Function() onCalculate;

  @override
  Future<List<CalculatedRoute>> calculate({
    required RoutePlace from,
    required RoutePlace to,
    required bool includeAlternatives,
  }) async {
    return onCalculate();
  }
}
