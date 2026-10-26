import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:road_loop/domain/route_hazard_matcher.dart';
import 'package:road_loop/domain/route_risk.dart';
import 'package:road_loop/map/navigation_controller.dart';
import 'package:road_loop/navigation_services.dart';

void main() {
  // Straight East-West test route along latitude 12.0
  // Each 0.001 deg longitude is approx 108.9m at lat 12.0
  final testPoints = [
    const LatLng(12.0, 77.0),
    const LatLng(12.0, 77.005),
    const LatLng(12.0, 77.010),
  ];

  final initialRoute = CalculatedRoute(
    points: testPoints,
    distanceMeters: 1089.0,
    durationSeconds: 120,
  );

  final destination = const LatLng(12.0, 77.010);

  group('LiveTrackingController', () {
    test(
      'on route: fixes within 40m keep tracking and do not recalculate',
      () async {
        var recalculateCount = 0;
        final controller = LiveTrackingController(
          initialRoute: initialRoute,
          destination: destination,
          routeRecalculator: (from, to) async {
            recalculateCount++;
            return null;
          },
        );

        final streamController = StreamController<NavFix>();
        controller.startTracking(streamController.stream);

        final now = DateTime(2026, 10, 25, 12, 0, 0);

        // Fix directly on the route polyline
        streamController.add(
          NavFix(
            latitude: 12.0,
            longitude: 77.001,
            accuracy: 5.0,
            timestamp: now,
          ),
        );
        await pumpEventQueue();

        expect(controller.status, NavigationStatus.tracking);
        expect(controller.consecutiveOffRouteFixes, 0);
        expect(recalculateCount, 0);

        // Fix 15m away (latitude offset ~ 15m = 0.000135 deg)
        streamController.add(
          NavFix(
            latitude: 12.000135,
            longitude: 77.002,
            accuracy: 8.0,
            timestamp: now.add(const Duration(seconds: 1)),
          ),
        );
        await pumpEventQueue();

        expect(controller.consecutiveOffRouteFixes, 0);
        expect(recalculateCount, 0);

        controller.stopTracking();
        await streamController.close();
        controller.dispose();
      },
    );

    test('off route: 3 consecutive fixes >40m with accuracy <30m triggers recalculation', () async {
      var recalculateCount = 0;
      LatLng? lastRerouteOrigin;

      final reroutedRoute = CalculatedRoute(
        points: [const LatLng(12.001, 77.003), const LatLng(12.0, 77.010)],
        distanceMeters: 800.0,
        durationSeconds: 90,
      );

      final controller = LiveTrackingController(
        initialRoute: initialRoute,
        destination: destination,
        routeRecalculator: (from, to) async {
          recalculateCount++;
          lastRerouteOrigin = from;
          return reroutedRoute;
        },
      );

      final streamController = StreamController<NavFix>();
      controller.startTracking(streamController.stream);

      final now = DateTime(2026, 10, 25, 12, 0, 0);
      // Latitude 0.001 deg is approx 111m North of latitude 12.0 (> 40m threshold)
      const offRouteLat = 12.001;

      // Fix 1: off-route (> 40m), accuracy = 10m (< 30m)
      streamController.add(
        NavFix(
          latitude: offRouteLat,
          longitude: 77.001,
          accuracy: 10.0,
          timestamp: now,
        ),
      );
      await pumpEventQueue();
      expect(controller.consecutiveOffRouteFixes, 1);
      expect(recalculateCount, 0);

      // Fix 2: off-route, accuracy = 12m
      streamController.add(
        NavFix(
          latitude: offRouteLat,
          longitude: 77.002,
          accuracy: 12.0,
          timestamp: now.add(const Duration(seconds: 1)),
        ),
      );
      await pumpEventQueue();
      expect(controller.consecutiveOffRouteFixes, 2);
      expect(recalculateCount, 0);

      // Fix 3: 3rd consecutive off-route fix -> triggers recalculation!
      streamController.add(
        NavFix(
          latitude: offRouteLat,
          longitude: 77.003,
          accuracy: 14.0,
          timestamp: now.add(const Duration(seconds: 2)),
        ),
      );
      await pumpEventQueue();

      expect(recalculateCount, 1);
      expect(lastRerouteOrigin, const LatLng(offRouteLat, 77.003));
      expect(controller.currentRoute.distanceMeters, 800.0);
      expect(controller.consecutiveOffRouteFixes, 0);

      controller.stopTracking();
      await streamController.close();
      controller.dispose();
    });

    test('GPS jitter: fixes with accuracy >=30m or returning on-route do not trigger recalculation', () async {
      var recalculateCount = 0;
      final controller = LiveTrackingController(
        initialRoute: initialRoute,
        destination: destination,
        routeRecalculator: (from, to) async {
          recalculateCount++;
          return null;
        },
      );

      final streamController = StreamController<NavFix>();
      controller.startTracking(streamController.stream);

      final now = DateTime(2026, 10, 25, 12, 0, 0);
      const offRouteLat = 12.001; // ~111m off route

      // Fix 1: off-route but accuracy = 35m (>= 30m, jitter/poor fix) -> ignored
      streamController.add(
        NavFix(
          latitude: offRouteLat,
          longitude: 77.001,
          accuracy: 35.0,
          timestamp: now,
        ),
      );
      await pumpEventQueue();
      expect(controller.consecutiveOffRouteFixes, 0);

      // Fix 2: off-route with good accuracy (10m) -> count = 1
      streamController.add(
        NavFix(
          latitude: offRouteLat,
          longitude: 77.002,
          accuracy: 10.0,
          timestamp: now.add(const Duration(seconds: 1)),
        ),
      );
      await pumpEventQueue();
      expect(controller.consecutiveOffRouteFixes, 1);

      // Fix 3: back on route (latitude 12.0) -> resets counter to 0!
      streamController.add(
        NavFix(
          latitude: 12.0,
          longitude: 77.003,
          accuracy: 8.0,
          timestamp: now.add(const Duration(seconds: 2)),
        ),
      );
      await pumpEventQueue();
      expect(controller.consecutiveOffRouteFixes, 0);

      // Fix 4: off-route but accuracy = 40m -> ignored
      streamController.add(
        NavFix(
          latitude: offRouteLat,
          longitude: 77.004,
          accuracy: 40.0,
          timestamp: now.add(const Duration(seconds: 3)),
        ),
      );
      await pumpEventQueue();
      expect(controller.consecutiveOffRouteFixes, 0);
      expect(recalculateCount, 0);

      controller.stopTracking();
      await streamController.close();
      controller.dispose();
    });

    test(
      'cooldown: prevents recalculation within 15 seconds of last reroute',
      () async {
        var recalculateCount = 0;
        final controller = LiveTrackingController(
          initialRoute: initialRoute,
          destination: destination,
          routeRecalculator: (from, to) async {
            recalculateCount++;
            return initialRoute;
          },
        );

        final streamController = StreamController<NavFix>();
        controller.startTracking(streamController.stream);

        final t0 = DateTime(2026, 10, 25, 12, 0, 0);
        const offRouteLat = 12.001;

        // Send 3 off-route fixes at t0 -> triggers first recalculation
        streamController.add(
          NavFix(
            latitude: offRouteLat,
            longitude: 77.001,
            accuracy: 10.0,
            timestamp: t0,
          ),
        );
        streamController.add(
          NavFix(
            latitude: offRouteLat,
            longitude: 77.001,
            accuracy: 10.0,
            timestamp: t0.add(const Duration(seconds: 1)),
          ),
        );
        streamController.add(
          NavFix(
            latitude: offRouteLat,
            longitude: 77.001,
            accuracy: 10.0,
            timestamp: t0.add(const Duration(seconds: 2)),
          ),
        );
        await pumpEventQueue();
        expect(recalculateCount, 1);

        // Send 3 off-route fixes at t0 + 6s (< 15s cooldown) -> blocked by cooldown
        final tBlocked = t0.add(const Duration(seconds: 6));
        streamController.add(
          NavFix(
            latitude: offRouteLat,
            longitude: 77.002,
            accuracy: 10.0,
            timestamp: tBlocked,
          ),
        );
        streamController.add(
          NavFix(
            latitude: offRouteLat,
            longitude: 77.002,
            accuracy: 10.0,
            timestamp: tBlocked.add(const Duration(seconds: 1)),
          ),
        );
        streamController.add(
          NavFix(
            latitude: offRouteLat,
            longitude: 77.002,
            accuracy: 10.0,
            timestamp: tBlocked.add(const Duration(seconds: 2)),
          ),
        );
        await pumpEventQueue();
        expect(recalculateCount, 1); // Still 1

        // Send 3 off-route fixes at t0 + 16s (> 15s cooldown) -> triggers second recalculation
        final tAllowed = t0.add(const Duration(seconds: 16));
        streamController.add(
          NavFix(
            latitude: offRouteLat,
            longitude: 77.003,
            accuracy: 10.0,
            timestamp: tAllowed,
          ),
        );
        streamController.add(
          NavFix(
            latitude: offRouteLat,
            longitude: 77.003,
            accuracy: 10.0,
            timestamp: tAllowed.add(const Duration(seconds: 1)),
          ),
        );
        streamController.add(
          NavFix(
            latitude: offRouteLat,
            longitude: 77.003,
            accuracy: 10.0,
            timestamp: tAllowed.add(const Duration(seconds: 2)),
          ),
        );
        await pumpEventQueue();
        expect(recalculateCount, 2);

        controller.stopTracking();
        await streamController.close();
        controller.dispose();
      },
    );

    test('hazard ahead: alerts once for high-severity hazard within 300m and does not repeat', () async {
      // Place hazard at longitude 77.004 on route (~435m along route)
      final hazard = RouteHazardPoint(
        id: 'hz-pothole-severe',
        latitude: 12.0,
        longitude: 77.004,
        severityWeight: 0.9, // High severity
        confidence: 0.95,
        isVerified: true,
        lastObserved: DateTime(2026, 10, 24),
        typeLabel: 'severe pothole',
        severityLabel: 'high',
      );

      final controller = LiveTrackingController(
        initialRoute: initialRoute,
        destination: destination,
        routeRecalculator: (from, to) async => null,
        initialHazards: [hazard],
      );

      final streamController = StreamController<NavFix>();
      controller.startTracking(streamController.stream);

      final now = DateTime(2026, 10, 25, 12, 0, 0);

      // Fix 1: at start (longitude 77.0) -> distance ahead ~435m (> 300m threshold) -> no alert
      streamController.add(
        NavFix(latitude: 12.0, longitude: 77.0, accuracy: 5.0, timestamp: now),
      );
      await pumpEventQueue();
      expect(controller.currentAlert, isNull);
      expect(controller.alertedHazardIds, isEmpty);

      // Fix 2: at longitude 77.002 (~218m along route) -> distance ahead ~217m (<= 300m) -> alert!
      streamController.add(
        NavFix(
          latitude: 12.0,
          longitude: 77.002,
          accuracy: 5.0,
          timestamp: now.add(const Duration(seconds: 5)),
        ),
      );
      await pumpEventQueue();

      expect(controller.currentAlert, isNotNull);
      expect(controller.currentAlert!.hazard.id, 'hz-pothole-severe');
      expect(controller.alertedHazardIds.contains('hz-pothole-severe'), isTrue);

      controller.dismissAlert();
      expect(controller.currentAlert, isNull);

      // Fix 3: closer at longitude 77.003 (~326m along route, 109m ahead) -> no second alert
      streamController.add(
        NavFix(
          latitude: 12.0,
          longitude: 77.003,
          accuracy: 5.0,
          timestamp: now.add(const Duration(seconds: 10)),
        ),
      );
      await pumpEventQueue();

      // Ensure no repeat alert was emitted for this hazard
      expect(controller.currentAlert, isNull);

      controller.stopTracking();
      await streamController.close();
      controller.dispose();
    });

    test(
      'GPS loss and network failures are handled gracefully without crashing',
      () async {
        final controller = LiveTrackingController(
          initialRoute: initialRoute,
          destination: destination,
          routeRecalculator: (from, to) async {
            throw Exception('Network unreachable');
          },
        );

        final streamController = StreamController<NavFix>();
        controller.startTracking(streamController.stream);

        // Stream emits an error (e.g. GPS provider disabled)
        streamController.addError('Location provider disabled');
        await pumpEventQueue();

        expect(controller.status, NavigationStatus.gpsLost);
        expect(controller.statusMessage, 'GPS signal lost');

        // Next valid fix recovers tracking status
        final now = DateTime(2026, 10, 25, 12, 0, 0);
        streamController.add(
          NavFix(
            latitude: 12.0,
            longitude: 77.001,
            accuracy: 5.0,
            timestamp: now,
          ),
        );
        await pumpEventQueue();
        expect(controller.status, NavigationStatus.tracking);

        // Trigger recalculation with failing network recalculator
        const offRouteLat = 12.001;
        streamController.add(
          NavFix(
            latitude: offRouteLat,
            longitude: 77.001,
            accuracy: 10.0,
            timestamp: now.add(const Duration(seconds: 1)),
          ),
        );
        streamController.add(
          NavFix(
            latitude: offRouteLat,
            longitude: 77.001,
            accuracy: 10.0,
            timestamp: now.add(const Duration(seconds: 2)),
          ),
        );
        streamController.add(
          NavFix(
            latitude: offRouteLat,
            longitude: 77.001,
            accuracy: 10.0,
            timestamp: now.add(const Duration(seconds: 3)),
          ),
        );
        await pumpEventQueue();

        // Controller caught exception and returned to tracking status with error message
        expect(controller.status, NavigationStatus.tracking);
        expect(controller.statusMessage, contains('network unavailable'));
        expect(
          controller.currentRoute,
          initialRoute,
        ); // Preserves existing route

        controller.stopTracking();
        await streamController.close();
        controller.dispose();
      },
    );
  });
}
