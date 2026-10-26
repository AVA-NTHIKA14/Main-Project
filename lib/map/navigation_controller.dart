import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/route_hazard_matcher.dart';
import '../domain/route_risk.dart';
import '../navigation_services.dart';

/// Lightweight representation of a navigation position fix.
///
/// Decoupled from [Position] so tests can pass fake fixes without platform channel mocks.
@immutable
class NavFix {
  const NavFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.heading,
    this.speed,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final double? heading;
  final double? speed;

  LatLng get latLng => LatLng(latitude, longitude);

  /// Creates a [NavFix] from a geolocator [Position].
  factory NavFix.fromPosition(Position pos) => NavFix(
    latitude: pos.latitude,
    longitude: pos.longitude,
    accuracy: pos.accuracy,
    timestamp: pos.timestamp,
    heading: pos.heading,
    speed: pos.speed,
  );

  @override
  String toString() =>
      'NavFix(lat: $latitude, lon: $longitude, acc: ${accuracy.toStringAsFixed(1)}m, time: $timestamp)';
}

/// Navigation tracking session status.
enum NavigationStatus {
  idle,
  tracking,
  rerouting,
  gpsLost,
  permissionDenied,
  stopped,
}

/// Alert emitted when an eligible high-severity hazard is ahead on the route.
@immutable
class HazardAheadAlert {
  const HazardAheadAlert({
    required this.hazard,
    required this.distanceMeters,
    required this.timestamp,
  });

  final RouteHazardPoint hazard;
  final double distanceMeters;
  final DateTime timestamp;

  @override
  String toString() =>
      'HazardAheadAlert(${hazard.typeLabel} in ${distanceMeters.toStringAsFixed(0)}m)';
}

/// Pure Dart controller for live tracking, off-route detection, and hazard-ahead alerts.
///
/// Follows navigation rules:
/// - Off-route: more than 40 m from polyline for 3 consecutive fixes with accuracy under 30 m.
/// - 15 s cooldown between recalculations.
/// - Hazard ahead: within 300 m along the route, one short alert per hazard per trip.
/// - Robust against GPS loss, permission loss, and network failures.
class LiveTrackingController extends ChangeNotifier {
  LiveTrackingController({
    required CalculatedRoute initialRoute,
    required this.destination,
    required this.routeRecalculator,
    List<RouteHazardPoint> initialHazards = const [],
    this.eligibilityFilter = const HazardEligibilityFilter(),
    this.matcher = const RouteHazardMatcher(),
    this.offRouteThresholdMeters = defaultOffRouteThresholdMeters,
    this.maxAccuracyForOffRoute = defaultMaxAccuracyForOffRoute,
    this.consecutiveFixesForOffRoute = defaultConsecutiveFixesForOffRoute,
    this.recalculationCooldown = defaultRecalculationCooldown,
    this.hazardAlertDistanceMeters = defaultHazardAlertDistanceMeters,
  }) : _currentRoute = initialRoute,
       _hazards = List.unmodifiable(initialHazards) {
    _updateEligibleHazards();
  }

  static const double defaultOffRouteThresholdMeters = 40.0;
  static const double defaultMaxAccuracyForOffRoute = 30.0;
  static const int defaultConsecutiveFixesForOffRoute = 3;
  static const Duration defaultRecalculationCooldown = Duration(seconds: 15);
  static const double defaultHazardAlertDistanceMeters = 300.0;

  final LatLng destination;
  final Future<CalculatedRoute?> Function(LatLng from, LatLng to)
  routeRecalculator;
  final HazardEligibilityFilter eligibilityFilter;
  final RouteHazardMatcher matcher;

  final double offRouteThresholdMeters;
  final double maxAccuracyForOffRoute;
  final int consecutiveFixesForOffRoute;
  final Duration recalculationCooldown;
  final double hazardAlertDistanceMeters;

  List<RouteHazardPoint> _hazards;
  CalculatedRoute _currentRoute;
  NavigationStatus _status = NavigationStatus.idle;
  NavFix? _lastFix;
  int _consecutiveOffRouteFixes = 0;
  DateTime? _lastRecalculationTime;
  HazardAheadAlert? _currentAlert;
  String? _statusMessage;

  final Set<String> _alertedHazardIds = {};
  List<RouteHazardMatch> _matchedHazards = [];

  StreamSubscription<NavFix>? _subscription;

  CalculatedRoute get currentRoute => _currentRoute;
  NavigationStatus get status => _status;
  NavFix? get lastFix => _lastFix;
  int get consecutiveOffRouteFixes => _consecutiveOffRouteFixes;
  HazardAheadAlert? get currentAlert => _currentAlert;
  String? get statusMessage => _statusMessage;
  List<RouteHazardPoint> get hazards => _hazards;
  List<RouteHazardMatch> get matchedHazards => _matchedHazards;
  Set<String> get alertedHazardIds => Set.unmodifiable(_alertedHazardIds);

  /// Starts listening to a stream of position fixes.
  void startTracking(Stream<NavFix> positionStream) {
    stopTracking();
    _status = NavigationStatus.tracking;
    _consecutiveOffRouteFixes = 0;
    _statusMessage = null;
    notifyListeners();

    _subscription = positionStream.listen(
      _onPositionFix,
      onError: (Object error) {
        // Handle GPS loss or permission revocation without crashing
        final msg = error.toString().toLowerCase();
        if (msg.contains('permission') || msg.contains('denied')) {
          _status = NavigationStatus.permissionDenied;
          _statusMessage = 'Location permission unavailable';
        } else {
          _status = NavigationStatus.gpsLost;
          _statusMessage = 'GPS signal lost';
        }
        notifyListeners();
      },
      onDone: () {
        if (_status == NavigationStatus.tracking) {
          _status = NavigationStatus.stopped;
          notifyListeners();
        }
      },
      cancelOnError: false,
    );
  }

  /// Ingests a single position fix. Can be called directly in tests.
  void handleFix(NavFix fix) {
    _onPositionFix(fix);
  }

  void _onPositionFix(NavFix fix) {
    _lastFix = fix;
    if (_status == NavigationStatus.gpsLost ||
        _status == NavigationStatus.permissionDenied) {
      _status = NavigationStatus.tracking;
      _statusMessage = null;
    }

    final projection = matcher.projectPoint(
      route: _currentRoute.points,
      point: fix.latLng,
    );

    // 1. Off-route detection:
    // Only fixes with accuracy under maxAccuracyForOffRoute (30m) count.
    if (fix.accuracy > 0 && fix.accuracy < maxAccuracyForOffRoute) {
      if (projection.distanceToRouteMeters > offRouteThresholdMeters) {
        _consecutiveOffRouteFixes++;
        if (_consecutiveOffRouteFixes >= consecutiveFixesForOffRoute) {
          _checkAndTriggerReroute(fix);
        }
      } else {
        _consecutiveOffRouteFixes = 0;
      }
    }

    // 2. Hazard ahead alert:
    // Check eligible high-severity hazards within 300m along route.
    _checkHazardAhead(projection.distanceAlongRouteMeters, fix.timestamp);

    notifyListeners();
  }

  Future<void> _checkAndTriggerReroute(NavFix fix) async {
    final now = fix.timestamp;
    if (_lastRecalculationTime != null &&
        now.difference(_lastRecalculationTime!) < recalculationCooldown) {
      // Cooldown in effect; do not trigger recalculation
      return;
    }

    _lastRecalculationTime = now;
    _consecutiveOffRouteFixes = 0;
    _status = NavigationStatus.rerouting;
    _statusMessage = 'Off route. Recalculating...';
    notifyListeners();

    try {
      final newRoute = await routeRecalculator(fix.latLng, destination);
      if (newRoute != null) {
        _currentRoute = newRoute;
        _updateEligibleHazards();
        _status = NavigationStatus.tracking;
        _statusMessage = 'Route updated';
      } else {
        _status = NavigationStatus.tracking;
        _statusMessage = 'Recalculation returned no route';
      }
    } catch (e) {
      // Handle network failure without crashing
      _status = NavigationStatus.tracking;
      _statusMessage = 'Recalculation failed: network unavailable';
    } finally {
      notifyListeners();
    }
  }

  void _checkHazardAhead(double userAlongRouteMeters, DateTime now) {
    for (final match in _matchedHazards) {
      // High severity hazard check (severityWeight >= 0.8)
      if (match.hazard.severityWeight >= 0.8) {
        final distanceAhead =
            match.distanceAlongRouteMeters - userAlongRouteMeters;
        if (distanceAhead >= 0 && distanceAhead <= hazardAlertDistanceMeters) {
          if (!_alertedHazardIds.contains(match.hazard.id)) {
            _alertedHazardIds.add(match.hazard.id);
            _currentAlert = HazardAheadAlert(
              hazard: match.hazard,
              distanceMeters: distanceAhead,
              timestamp: now,
            );
            return;
          }
        }
      }
    }
  }

  /// Dismisses the currently displayed hazard alert.
  void dismissAlert() {
    _currentAlert = null;
    notifyListeners();
  }

  /// Updates active hazards.
  void updateHazards(List<RouteHazardPoint> newHazards) {
    _hazards = List.unmodifiable(newHazards);
    _updateEligibleHazards();
    notifyListeners();
  }

  void _updateEligibleHazards() {
    final eligible = _hazards.where(eligibilityFilter.isEligible).toList();
    _matchedHazards = matcher.match(
      route: _currentRoute.points,
      hazards: eligible,
    );
  }

  /// Stops tracking and cancels stream subscription.
  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
    _status = NavigationStatus.stopped;
    _currentAlert = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
