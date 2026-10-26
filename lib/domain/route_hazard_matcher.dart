import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

/// An immutable representation of a hazard point for route analysis.
///
/// Decouples route matching and risk scoring from specific backend or explore
/// hazard representations.
@immutable
class RouteHazardPoint {
  const RouteHazardPoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.severityWeight,
    required this.confidence,
    required this.isVerified,
    required this.lastObserved,
    this.typeLabel = 'road hazard',
    this.severityLabel = 'moderate',
    this.observationCount = 1,
  });

  final String id;
  final double latitude;
  final double longitude;
  final double severityWeight;
  final double confidence;
  final bool isVerified;
  final DateTime lastObserved;

  /// Human-readable type description (e.g. 'pothole', 'rough road').
  final String typeLabel;

  /// Human-readable severity description (e.g. 'high', 'moderate').
  final String severityLabel;

  /// Number of recorded observations for this hazard.
  final int observationCount;

  LatLng get point => LatLng(latitude, longitude);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteHazardPoint &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'RouteHazardPoint(id: $id, lat: $latitude, lon: $longitude, severityWeight: $severityWeight, conf: $confidence, verified: $isVerified)';
}

/// Represents a hazard matched to a route polyline.
@immutable
class RouteHazardMatch {
  const RouteHazardMatch({
    required this.hazard,
    required this.distanceAlongRouteMeters,
    required this.distanceToRouteMeters,
  });

  /// The matched hazard point.
  final RouteHazardPoint hazard;

  /// Traveled distance along the route polyline from its start to the closest
  /// projected point on the route (in meters).
  final double distanceAlongRouteMeters;

  /// Perpendicular or vertex distance from the hazard to the closest point
  /// on the route polyline (in meters).
  final double distanceToRouteMeters;

  @override
  String toString() =>
      'RouteHazardMatch(hazard: ${hazard.id}, along: ${distanceAlongRouteMeters.toStringAsFixed(1)}m, dist: ${distanceToRouteMeters.toStringAsFixed(1)}m)';
}

/// Result of projecting a geographic point onto a polyline.
@immutable
class RoutePointProjection {
  const RoutePointProjection({
    required this.distanceToRouteMeters,
    required this.distanceAlongRouteMeters,
  });

  /// Distance from the query point to the closest point on the route (in meters).
  final double distanceToRouteMeters;

  /// Traveled distance along the route from start to the projection point (in meters).
  final double distanceAlongRouteMeters;

  @override
  String toString() =>
      'RoutePointProjection(distToRoute: ${distanceToRouteMeters.toStringAsFixed(1)}m, along: ${distanceAlongRouteMeters.toStringAsFixed(1)}m)';
}

/// Geometry matcher that projects hazards onto a route polyline using a local
/// equirectangular projection around each segment.
class RouteHazardMatcher {
  const RouteHazardMatcher({this.thresholdMeters = defaultThresholdMeters});

  /// Default distance threshold (in meters) for considering a hazard on-route.
  static const double defaultThresholdMeters = 30.0;

  /// Mean Earth radius in meters (WGS84).
  static const double _earthRadiusMeters = 6371000.0;

  final double thresholdMeters;

  /// Matches [hazards] against [route] within [thresholdMeters].
  ///
  /// Returns a list of [RouteHazardMatch] sorted by distance along the route.
  /// Handles empty and single-point routes without throwing.
  List<RouteHazardMatch> match({
    required List<LatLng> route,
    required List<RouteHazardPoint> hazards,
    double? thresholdMeters,
  }) {
    final effectiveThreshold = thresholdMeters ?? this.thresholdMeters;
    if (route.isEmpty || hazards.isEmpty) {
      return const [];
    }

    if (route.length == 1) {
      return _matchSinglePointRoute(
        point: route.first,
        hazards: hazards,
        thresholdMeters: effectiveThreshold,
      );
    }

    return _matchPolylineRoute(
      route: route,
      hazards: hazards,
      thresholdMeters: effectiveThreshold,
    );
  }

  List<RouteHazardMatch> _matchSinglePointRoute({
    required LatLng point,
    required List<RouteHazardPoint> hazards,
    required double thresholdMeters,
  }) {
    final matches = <RouteHazardMatch>[];
    for (final hazard in hazards) {
      final distance = _equirectangularDistance(
        lat1: point.latitude,
        lon1: point.longitude,
        lat2: hazard.latitude,
        lon2: hazard.longitude,
      );
      if (distance <= thresholdMeters) {
        matches.add(
          RouteHazardMatch(
            hazard: hazard,
            distanceAlongRouteMeters: 0.0,
            distanceToRouteMeters: distance,
          ),
        );
      }
    }
    // Sort deterministically
    matches.sort(
      (a, b) => a.distanceToRouteMeters.compareTo(b.distanceToRouteMeters),
    );
    return matches;
  }

  List<RouteHazardMatch> _matchPolylineRoute({
    required List<LatLng> route,
    required List<RouteHazardPoint> hazards,
    required double thresholdMeters,
  }) {
    // Precalculate segment lengths and cumulative distances
    final segmentCount = route.length - 1;
    final segmentLengths = List<double>.filled(segmentCount, 0.0);
    final cumulativeDistances = List<double>.filled(route.length, 0.0);

    for (var i = 0; i < segmentCount; i++) {
      final p1 = route[i];
      final p2 = route[i + 1];
      final length = _equirectangularDistance(
        lat1: p1.latitude,
        lon1: p1.longitude,
        lat2: p2.latitude,
        lon2: p2.longitude,
      );
      segmentLengths[i] = length;
      cumulativeDistances[i + 1] = cumulativeDistances[i] + length;
    }

    final matches = <RouteHazardMatch>[];

    for (final hazard in hazards) {
      var minDistanceToSegment = double.infinity;
      var distanceAlongRoute = 0.0;

      for (var i = 0; i < segmentCount; i++) {
        final a = route[i];
        final b = route[i + 1];

        // Local equirectangular projection centered on segment mean latitude
        final meanLatRad =
            ((a.latitude + b.latitude + hazard.latitude) / 3.0) *
            (math.pi / 180.0);
        final cosMeanLat = math.cos(meanLatRad);

        // Vector A -> B in meters
        final xB =
            (b.longitude - a.longitude) *
            (math.pi / 180.0) *
            cosMeanLat *
            _earthRadiusMeters;
        final yB =
            (b.latitude - a.latitude) * (math.pi / 180.0) * _earthRadiusMeters;
        final segLengthSq = (xB * xB) + (yB * yB);

        // Vector A -> Hazard in meters
        final xH =
            (hazard.longitude - a.longitude) *
            (math.pi / 180.0) *
            cosMeanLat *
            _earthRadiusMeters;
        final yH =
            (hazard.latitude - a.latitude) *
            (math.pi / 180.0) *
            _earthRadiusMeters;

        double tClamped;
        double distToSeg;
        if (segLengthSq <= 0.00001) {
          // Degenerate segment
          tClamped = 0.0;
          distToSeg = math.sqrt((xH * xH) + (yH * yH));
        } else {
          final dot = (xH * xB) + (yH * yB);
          final t = dot / segLengthSq;
          tClamped = t.clamp(0.0, 1.0);
          final xProj = tClamped * xB;
          final yProj = tClamped * yB;
          final dx = xH - xProj;
          final dy = yH - yProj;
          distToSeg = math.sqrt((dx * dx) + (dy * dy));
        }

        if (distToSeg < minDistanceToSegment) {
          minDistanceToSegment = distToSeg;
          distanceAlongRoute =
              cumulativeDistances[i] + (tClamped * segmentLengths[i]);
        }
      }

      if (minDistanceToSegment <= thresholdMeters) {
        matches.add(
          RouteHazardMatch(
            hazard: hazard,
            distanceAlongRouteMeters: distanceAlongRoute,
            distanceToRouteMeters: minDistanceToSegment,
          ),
        );
      }
    }

    // Sort strictly by distance along route ascending; break ties by distanceToRouteMeters
    matches.sort((a, b) {
      final cmp = a.distanceAlongRouteMeters.compareTo(
        b.distanceAlongRouteMeters,
      );
      if (cmp != 0) return cmp;
      return a.distanceToRouteMeters.compareTo(b.distanceToRouteMeters);
    });

    return matches;
  }

  /// Projects [point] onto [route] using local equirectangular projections.
  ///
  /// Returns a [RoutePointProjection] with perpendicular distance to the route
  /// and cumulative distance along the route to the projection point.
  /// If [route] is empty, returns infinite distance and 0.0 distance along route.
  RoutePointProjection projectPoint({
    required List<LatLng> route,
    required LatLng point,
  }) {
    if (route.isEmpty) {
      return const RoutePointProjection(
        distanceToRouteMeters: double.infinity,
        distanceAlongRouteMeters: 0.0,
      );
    }
    if (route.length == 1) {
      final d = _equirectangularDistance(
        lat1: route.first.latitude,
        lon1: route.first.longitude,
        lat2: point.latitude,
        lon2: point.longitude,
      );
      return RoutePointProjection(
        distanceToRouteMeters: d,
        distanceAlongRouteMeters: 0.0,
      );
    }

    final segmentCount = route.length - 1;
    final segmentLengths = List<double>.filled(segmentCount, 0.0);
    final cumulativeDistances = List<double>.filled(route.length, 0.0);

    for (var i = 0; i < segmentCount; i++) {
      final p1 = route[i];
      final p2 = route[i + 1];
      final length = _equirectangularDistance(
        lat1: p1.latitude,
        lon1: p1.longitude,
        lat2: p2.latitude,
        lon2: p2.longitude,
      );
      segmentLengths[i] = length;
      cumulativeDistances[i + 1] = cumulativeDistances[i] + length;
    }

    var minDistanceToSegment = double.infinity;
    var distanceAlongRoute = 0.0;

    for (var i = 0; i < segmentCount; i++) {
      final a = route[i];
      final b = route[i + 1];

      final meanLatRad =
          ((a.latitude + b.latitude + point.latitude) / 3.0) *
          (math.pi / 180.0);
      final cosMeanLat = math.cos(meanLatRad);

      final xB =
          (b.longitude - a.longitude) *
          (math.pi / 180.0) *
          cosMeanLat *
          _earthRadiusMeters;
      final yB =
          (b.latitude - a.latitude) * (math.pi / 180.0) * _earthRadiusMeters;
      final segLengthSq = (xB * xB) + (yB * yB);

      final xP =
          (point.longitude - a.longitude) *
          (math.pi / 180.0) *
          cosMeanLat *
          _earthRadiusMeters;
      final yP =
          (point.latitude - a.latitude) *
          (math.pi / 180.0) *
          _earthRadiusMeters;

      double tClamped;
      double distToSeg;
      if (segLengthSq <= 0.00001) {
        tClamped = 0.0;
        distToSeg = math.sqrt((xP * xP) + (yP * yP));
      } else {
        final dot = (xP * xB) + (yP * yB);
        final t = dot / segLengthSq;
        tClamped = t.clamp(0.0, 1.0);
        final xProj = tClamped * xB;
        final yProj = tClamped * yB;
        final dx = xP - xProj;
        final dy = yP - yProj;
        distToSeg = math.sqrt((dx * dx) + (dy * dy));
      }

      if (distToSeg < minDistanceToSegment) {
        minDistanceToSegment = distToSeg;
        distanceAlongRoute =
            cumulativeDistances[i] + (tClamped * segmentLengths[i]);
      }
    }

    return RoutePointProjection(
      distanceToRouteMeters: minDistanceToSegment,
      distanceAlongRouteMeters: distanceAlongRoute,
    );
  }

  static double _equirectangularDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final meanLatRad = ((lat1 + lat2) / 2.0) * (math.pi / 180.0);
    final x =
        (lon2 - lon1) *
        (math.pi / 180.0) *
        math.cos(meanLatRad) *
        _earthRadiusMeters;
    final y = (lat2 - lat1) * (math.pi / 180.0) * _earthRadiusMeters;
    return math.sqrt((x * x) + (y * y));
  }
}
