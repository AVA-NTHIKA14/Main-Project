import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'design_system.dart';
import 'routing.dart';
import 'reports.dart';

const _roadSenseTileUrl = String.fromEnvironment(
  'ROAD_TILE_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

enum HazardSeverity { possible, moderate, high }

enum HazardType { pothole, roughSurface, debris, unknown }

enum VerificationStatus {
  possible,
  underVerification,
  verified,
  rejected,
  resolved,
}

class RoadLocation {
  const RoadLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class RoadSegment {
  const RoadSegment({required this.id, required this.points});

  final String id;
  final List<Offset> points;
}

class HazardObservation {
  const HazardObservation({
    required this.id,
    required this.segmentId,
    required this.timestamp,
    required this.userId,
    required this.tripId,
    required this.location,
    this.type = HazardType.unknown,
    this.severity = HazardSeverity.possible,
  });

  final String id;
  final String segmentId;
  final DateTime timestamp;
  final String userId;
  final String tripId;
  final RoadLocation location;
  final HazardType type;
  final HazardSeverity severity;
}

class Hazard {
  const Hazard({
    required this.id,
    required this.segmentId,
    required this.severity,
    required this.observations,
    required this.status,
    required this.type,
    required this.location,
    required this.confidence,
    required this.firstObserved,
    required this.lastObserved,
    this.distanceLabel = '',
  });

  final String id;
  final String segmentId;
  final HazardSeverity severity;
  final List<HazardObservation> observations;
  final VerificationStatus status;
  final HazardType type;
  final RoadLocation location;
  final double confidence;
  final DateTime firstObserved;
  final DateTime lastObserved;
  final String distanceLabel;

  bool get verified => status == VerificationStatus.verified;
  int get observationCount => observations.length;
  int get uniqueUserCount =>
      observations.map((item) => item.userId).toSet().length;
  int get uniqueTripCount =>
      observations.map((item) => item.tripId).toSet().length;
  String get title =>
      verified ? 'Verified road hazard' : 'Possible pothole ahead';
  String get detail => verified
      ? '${severityLabel(severity)} · $observationCount observations'
      : distanceLabel;
}

abstract interface class RoadMapDataSource {
  List<RoadSegment> get segments;
  List<Hazard> get hazards;
}

class MockRoadMapDataSource implements RoadMapDataSource {
  const MockRoadMapDataSource();

  static final _now = DateTime(2026, 10, 7, 10);

  @override
  final segments = const [
    RoadSegment(
      id: 'north',
      points: [
        Offset(.05, .82),
        Offset(.28, .62),
        Offset(.54, .48),
        Offset(.96, .18),
      ],
    ),
    RoadSegment(
      id: 'east',
      points: [Offset(.54, .48), Offset(.72, .58), Offset(.96, .72)],
    ),
    RoadSegment(
      id: 'south',
      points: [Offset(.28, .62), Offset(.34, .84), Offset(.52, 1.05)],
    ),
    RoadSegment(
      id: 'west',
      points: [Offset(-.05, .28), Offset(.22, .38), Offset(.54, .48)],
    ),
  ];

  static final _hazards = [
    Hazard(
      id: 'hazard-possible',
      segmentId: 'east',
      severity: HazardSeverity.possible,
      status: VerificationStatus.possible,
      type: HazardType.pothole,
      location: const RoadLocation(latitude: 51.501, longitude: -0.121),
      confidence: .2,
      firstObserved: _now,
      lastObserved: _now,
      distanceLabel: '350 m ahead',
      observations: [
        HazardObservation(
          id: 'observation-1',
          segmentId: 'east',
          timestamp: _now,
          userId: 'user-1',
          tripId: 'trip-1',
          location: RoadLocation(latitude: 51.501, longitude: -0.121),
          type: HazardType.pothole,
        ),
      ],
    ),
    Hazard(
      id: 'hazard-verified',
      segmentId: 'north',
      severity: HazardSeverity.high,
      status: VerificationStatus.verified,
      type: HazardType.pothole,
      location: const RoadLocation(latitude: 51.503, longitude: -0.12),
      confidence: 1,
      firstObserved: _now,
      lastObserved: _now,
      distanceLabel: '600 m ahead',
      observations: [
        HazardObservation(
          id: 'observation-2',
          segmentId: 'north',
          timestamp: _now,
          userId: 'user-2',
          tripId: 'trip-2',
          location: RoadLocation(latitude: 51.503, longitude: -0.12),
          type: HazardType.pothole,
          severity: HazardSeverity.high,
        ),
        HazardObservation(
          id: 'observation-3',
          segmentId: 'north',
          timestamp: _now,
          userId: 'user-3',
          tripId: 'trip-3',
          location: RoadLocation(latitude: 51.503, longitude: -0.12),
          type: HazardType.pothole,
          severity: HazardSeverity.high,
        ),
        HazardObservation(
          id: 'observation-4',
          segmentId: 'north',
          timestamp: _now,
          userId: 'user-4',
          tripId: 'trip-4',
          location: RoadLocation(latitude: 51.503, longitude: -0.12),
          type: HazardType.pothole,
          severity: HazardSeverity.high,
        ),
        HazardObservation(
          id: 'observation-5',
          segmentId: 'north',
          timestamp: _now,
          userId: 'user-5',
          tripId: 'trip-5',
          location: RoadLocation(latitude: 51.503, longitude: -0.12),
          type: HazardType.pothole,
          severity: HazardSeverity.high,
        ),
        HazardObservation(
          id: 'observation-6',
          segmentId: 'north',
          timestamp: _now,
          userId: 'user-6',
          tripId: 'trip-6',
          location: RoadLocation(latitude: 51.503, longitude: -0.12),
          type: HazardType.pothole,
          severity: HazardSeverity.high,
        ),
        HazardObservation(
          id: 'observation-7',
          segmentId: 'north',
          timestamp: _now,
          userId: 'user-7',
          tripId: 'trip-7',
          location: RoadLocation(latitude: 51.503, longitude: -0.12),
          type: HazardType.pothole,
          severity: HazardSeverity.high,
        ),
        HazardObservation(
          id: 'observation-8',
          segmentId: 'north',
          timestamp: _now,
          userId: 'user-8',
          tripId: 'trip-8',
          location: RoadLocation(latitude: 51.503, longitude: -0.12),
          type: HazardType.pothole,
          severity: HazardSeverity.high,
        ),
        HazardObservation(
          id: 'observation-9',
          segmentId: 'north',
          timestamp: _now,
          userId: 'user-9',
          tripId: 'trip-9',
          location: RoadLocation(latitude: 51.503, longitude: -0.12),
          type: HazardType.pothole,
          severity: HazardSeverity.high,
        ),
      ],
    ),
  ];

  @override
  List<Hazard> get hazards => _hazards;
}

/// Used until a real, seven-day hazard repository is connected.
class EmptyRoadMapDataSource implements RoadMapDataSource {
  const EmptyRoadMapDataSource();

  @override
  List<RoadSegment> get segments => const [];

  @override
  List<Hazard> get hazards => const [];
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.dataSource,
    required this.routingService,
    this.reportRepository,
    this.onOpenProfile,
    this.onPlanRoute,
  });

  final RoadMapDataSource dataSource;
  final HazardAwareRoutingService routingService;
  final ReportRepository? reportRepository;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onPlanRoute;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final MapController _mapController = MapController();
  String? _selectedHazardId;
  ll.LatLng _center = const ll.LatLng(10.7867, 76.6548);
  ll.LatLng? _userLocation;
  double _zoom = 13;
  bool _locating = false;
  bool _tileError = false;
  String? _locationMessage;
  bool _showPossible = true;
  bool _showVerified = true;
  String _mapStyle = 'Standard';
  RouteHazardWarning? _routeWarning;
  RoutePlan? _activeRoute;
  bool _routeChecked = false;
  late final ReportRepository _reportRepository;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _reportRepository = widget.reportRepository ?? InMemoryReportRepository();
    _checkRoute();
  }

  Future<void> _centerOnLocation() async {
    setState(() {
      _locating = true;
      _locationMessage = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationUiException(
          'Turn on Location services to center the map.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _LocationUiException(
          'Location permission was denied. You can enable it in app settings.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      final point = ll.LatLng(position.latitude, position.longitude);
      setState(() {
        _center = point;
        _userLocation = point;
      });
      _mapController.move(point, _zoom);
    } on _LocationUiException catch (error) {
      if (mounted) setState(() => _locationMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationMessage =
              'Could not get your location. Check GPS and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showSensingStatus() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sensing status',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12),
              Text(
                'Ready to start. Road sensing starts only when you explicitly begin a trip.',
              ),
              SizedBox(height: 8),
              Text('No active trip is collecting sensor data.'),
            ],
          ),
        ),
      ),
    );
  }

  void _openSearch() {
    if (widget.onPlanRoute != null) {
      widget.onPlanRoute!();
      return;
    }
    final searchController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search a place or route'),
        content: TextField(
          controller: searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Enter a destination',
            helperText: 'Place search will be available when a geocoding service is connected.',
          ),
          onSubmitted: (_) => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    ).whenComplete(searchController.dispose);
  }

  Future<void> _showMapLayers() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Map style')),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Standard'),
              trailing: _mapStyle == 'Standard'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, 'Standard'),
            ),
            const ListTile(
              leading: Icon(Icons.satellite_alt_outlined),
              title: Text('Satellite unavailable for this map provider'),
            ),
            const ListTile(
              leading: Icon(Icons.terrain_outlined),
              title: Text('Terrain unavailable for this map provider'),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _mapStyle = selected);
  }

  Future<void> _openReport() async {
    final submitted = await showManualReport(
      context,
      repository: _reportRepository,
    );
    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Report submitted')));
    }
  }

  Future<void> _checkRoute() async {
    final warning = await widget.routingService.checkRoute(
      hazards: widget.dataSource.hazards,
    );
    if (!mounted) return;
    setState(() {
      _routeWarning = warning;
      _activeRoute = warning?.currentRoute;
      _routeChecked = true;
    });
  }

  Hazard? get _selectedHazard => _selectedHazardId == null
      ? null
      : _visibleHazards
            .where((hazard) => hazard.id == _selectedHazardId)
            .firstOrNull;

  List<Hazard> get _visibleHazards {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return widget.dataSource.hazards
        .where(
          (hazard) =>
              hazard.lastObserved.isAfter(cutoff) &&
              hazard.status != VerificationStatus.resolved &&
              hazard.status != VerificationStatus.rejected,
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFE7EFEB),
    body: Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _zoom,
              minZoom: 4,
              maxZoom: 18,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) setState(() => _center = camera.center);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _roadSenseTileUrl,
                userAgentPackageName: 'com.roadsense.app',
                maxNativeZoom: 19,
                errorTileCallback: (tile, error, stackTrace) {
                  if (mounted && !_tileError) setState(() => _tileError = true);
                },
              ),
              MarkerLayer(
                markers: [
                  for (final hazard in _visibleHazards)
                    if ((_showVerified && hazard.verified) ||
                        (_showPossible && !hazard.verified))
                      Marker(
                        point: ll.LatLng(
                          hazard.location.latitude,
                          hazard.location.longitude,
                        ),
                        width: 48,
                        height: 56,
                        child: Semantics(
                          button: true,
                          label:
                              '${hazardTypeLabel(hazard.type)}, ${hazardSeverityLabel(hazard.severity)} hazard',
                          child: IconButton(
                            tooltip: hazard.title,
                            onPressed: () =>
                                setState(() => _selectedHazardId = hazard.id),
                            icon: Icon(
                              Icons.location_on,
                              size: 42,
                              color: hazard.verified
                                  ? RoadSenseColors.red
                                  : RoadSenseColors.amber,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
              if (_userLocation != null) ...[
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _userLocation!,
                      radius: 48,
                      useRadiusInMeter: false,
                      color: const Color(0x33287BE0),
                      borderColor: const Color(0x55287BE0),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 28,
                      height: 28,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF287BE0),
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: Colors.white, width: 4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () {},
                  ),
                ],
                alignment: AttributionAlignment.bottomRight,
              ),
            ],
          ),
        ),
        Positioned(
          top: 12,
          left: RoadSenseSpacing.md,
          right: RoadSenseSpacing.md,
          child: Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.white,
                  elevation: 3,
                  borderRadius: BorderRadius.circular(28),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: _openSearch,
                    child: const SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          SizedBox(width: 18),
                          Icon(Icons.search, color: RoadSenseColors.muted),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Search a place or route',
                              style: TextStyle(
                                color: RoadSenseColors.muted,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Icon(Icons.tune, color: RoadSenseColors.ink),
                          SizedBox(width: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: RoadSenseSpacing.sm),
              MapControl(
                icon: Icons.person_outline,
                tooltip: 'Open profile and privacy settings',
                onPressed: widget.onOpenProfile,
              ),
            ],
          ),
        ),
        Positioned(
          top: 82,
          left: RoadSenseSpacing.md,
          child: Row(
            children: [
              if (_activeRoute != null)
                _FloatingChip(
                  icon: Icons.route,
                  label: 'Demo route · ${_activeRoute!.durationMinutes} min',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Route alternatives require a connected routing provider.',
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              _FloatingChip(
                icon: Icons.schedule,
                label: 'Leave now',
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (context) => const SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Departure-time planning is not connected to a routing provider yet.',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 138,
          left: 16,
          child: Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Possible'),
                selected: _showPossible,
                onSelected: (value) => setState(() => _showPossible = value),
              ),
              FilterChip(
                label: const Text('Verified'),
                selected: _showVerified,
                onSelected: (value) => setState(() => _showVerified = value),
              ),
            ],
          ),
        ),
        Positioned(
          right: RoadSenseSpacing.md,
          bottom: 132,
          child: Column(
            children: [
              MapControl(
                icon: Icons.add,
                tooltip: 'Zoom in',
                onPressed: () {
                  _zoom = (_zoom + 1).clamp(4, 18);
                  _mapController.move(_center, _zoom);
                },
              ),
              const SizedBox(height: 4),
              MapControl(
                icon: Icons.remove,
                tooltip: 'Zoom out',
                onPressed: () {
                  _zoom = (_zoom - 1).clamp(4, 18);
                  _mapController.move(_center, _zoom);
                },
              ),
              const SizedBox(height: 8),
              MapControl(
                icon: _locating ? Icons.hourglass_top : Icons.my_location,
                tooltip: 'Center on my location',
                onPressed: _locating ? null : _centerOnLocation,
              ),
              const SizedBox(height: 8),
              MapControl(
                icon: Icons.layers_outlined,
                tooltip: 'Map layers',
                onPressed: _showMapLayers,
              ),
              const SizedBox(height: 8),
              MapControl(
                icon: Icons.flag_outlined,
                tooltip: 'Report a hazard',
                onPressed: _openReport,
              ),
            ],
          ),
        ),
        if (_locationMessage != null)
          Positioned(
            left: 16,
            right: 76,
            bottom: 140,
            child: Material(
              color: Colors.white,
              elevation: 3,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _locationMessage!,
                        style: const TextStyle(color: RoadSenseColors.ink),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      onPressed: () => setState(() => _locationMessage = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          left: 16,
          bottom: 16,
          child: InkWell(
            onTap: _showSensingStatus,
            borderRadius: BorderRadius.circular(24),
            child: const StatusIndicator(
              label: 'Ready to start',
              tone: StatusTone.warning,
            ),
          ),
        ),
        if (_visibleHazards.isEmpty && _routeWarning == null)
          const Positioned(left: 16, bottom: 62, child: _MapNotice()),
        if (_tileError)
          Positioned(
            top: 190,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.white,
              elevation: 3,
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Map tiles could not load. Check your connection.'),
              ),
            ),
          ),
        if (_routeWarning != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _RouteWarningSheet(
              warning: _routeWarning!,
              onContinue: () => setState(() => _routeWarning = null),
              onReroute: () async {
                final warning = _routeWarning;
                if (warning == null) return;
                final route = await widget.routingService.reroute(warning);
                if (!mounted) return;
                setState(() {
                  _activeRoute = route;
                  _routeWarning = null;
                });
              },
            ),
          ),
        if (_routeWarning == null && _selectedHazard != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _HazardSheet(
              hazard: _selectedHazard!,
              onClose: () => setState(() => _selectedHazardId = null),
            ),
          ),
        if (_routeWarning == null &&
            _selectedHazard == null &&
            _routeChecked &&
            _activeRoute != null)
          Positioned(
            top: 92,
            left: RoadSenseSpacing.md,
            child: _RouteLabel(route: _activeRoute!),
          ),
      ],
    ),
  );
}

class _RouteLabel extends StatelessWidget {
  const _RouteLabel({required this.route});

  final RoutePlan route;

  @override
  Widget build(BuildContext context) => Material(
    color: RoadSenseColors.surface,
    elevation: 2,
    borderRadius: BorderRadius.circular(RoadSenseRadius.pill),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.route, size: 16, color: RoadSenseColors.teal),
          const SizedBox(width: 6),
          Text(
            '${route.durationMinutes} min route',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    ),
  );
}

class _RouteWarningSheet extends StatelessWidget {
  const _RouteWarningSheet({
    required this.warning,
    required this.onContinue,
    required this.onReroute,
  });

  final RouteHazardWarning warning;
  final VoidCallback onContinue;
  final VoidCallback onReroute;

  @override
  Widget build(BuildContext context) => RoadSenseBottomSheet(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: RoadSenseColors.red,
              size: 28,
            ),
            const SizedBox(width: RoadSenseSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    warning.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: RoadSenseSpacing.xs),
                  Text(
                    warning.detail,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: RoadSenseSpacing.md),
        Text(
          warning.alternativeLabel,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: RoadSenseSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onContinue,
                child: const Text('Continue'),
              ),
            ),
            const SizedBox(width: RoadSenseSpacing.sm),
            Expanded(
              child: ElevatedButton(
                onPressed: warning.alternativeRoute == null ? null : onReroute,
                child: const Text('Reroute'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class RoadMapCanvas extends StatelessWidget {
  const RoadMapCanvas({
    super.key,
    required this.segments,
    required this.hazards,
    required this.selectedHazardId,
    required this.zoom,
    required this.recentered,
    required this.onHazardSelected,
  });

  final List<RoadSegment> segments;
  final List<Hazard> hazards;
  final String? selectedHazardId;
  final double zoom;
  final bool recentered;
  final ValueChanged<String?> onHazardSelected;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapUp: (details) {
      final size = context.size;
      if (size == null) return;
      final point = Offset(
        details.localPosition.dx / size.width,
        details.localPosition.dy / size.height,
      );
      for (final hazard in hazards) {
        final segment = segments.firstWhere(
          (item) => item.id == hazard.segmentId,
        );
        if (_nearSegment(segment, point)) {
          onHazardSelected(hazard.id);
          return;
        }
      }
      onHazardSelected(null);
    },
    child: CustomPaint(
      painter: _MapPainter(
        segments: segments,
        hazards: hazards,
        selectedHazardId: selectedHazardId,
        zoom: zoom,
        recentered: recentered,
      ),
      child: const SizedBox.expand(),
    ),
  );
}

class _MapPainter extends CustomPainter {
  const _MapPainter({
    required this.segments,
    required this.hazards,
    required this.selectedHazardId,
    required this.zoom,
    required this.recentered,
  });

  final List<RoadSegment> segments;
  final List<Hazard> hazards;
  final String? selectedHazardId;
  final double zoom;
  final bool recentered;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE9F0EC),
    );
    canvas.save();
    final center = Offset(size.width / 2, size.height / 2);
    canvas.translate(center.dx, center.dy);
    canvas.scale(zoom);
    canvas.translate(
      -center.dx + (recentered ? 12 : 0),
      -center.dy + (recentered ? 10 : 0),
    );
    final minor = Paint()
      ..color = const Color(0xFFD0DED9)
      ..strokeWidth = 1.5;
    for (var x = -size.height; x < size.width + size.height; x += 68) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        minor,
      );
    }
    for (final segment in segments) {
      _drawSegment(canvas, size, segment, _segmentColor(segment.id));
    }
    final location = Offset(size.width * .54, size.height * .48);
    canvas.drawCircle(
      location,
      19,
      Paint()..color = RoadSenseColors.teal.withValues(alpha: .16),
    );
    canvas.drawCircle(location, 8, Paint()..color = RoadSenseColors.teal);
    canvas.drawCircle(location, 4, Paint()..color = Colors.white);
    canvas.restore();
  }

  Color _segmentColor(String id) {
    final hazard = hazards.where((item) => item.segmentId == id).firstOrNull;
    if (hazard == null) return RoadSenseColors.teal;
    if (hazard.id == selectedHazardId) return RoadSenseColors.ink;
    return switch (hazard.severity) {
      HazardSeverity.possible => RoadSenseColors.amber,
      HazardSeverity.moderate => const Color(0xFFE18427),
      HazardSeverity.high => RoadSenseColors.red,
    };
  }

  void _drawSegment(
    Canvas canvas,
    Size size,
    RoadSegment segment,
    Color color,
  ) {
    final path = Path()
      ..moveTo(
        segment.points.first.dx * size.width,
        segment.points.first.dy * size.height,
      );
    for (final point in segment.points.skip(1)) {
      path.lineTo(point.dx * size.width, point.dy * size.height);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB8C8C1)
        ..strokeWidth = 18
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 12
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      oldDelegate.selectedHazardId != selectedHazardId ||
      oldDelegate.zoom != zoom ||
      oldDelegate.recentered != recentered;
}

class _HazardSheet extends StatelessWidget {
  const _HazardSheet({required this.hazard, required this.onClose});

  final Hazard hazard;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => RoadSenseBottomSheet(
    child: Row(
      children: [
        Icon(
          hazard.verified ? Icons.warning_amber_rounded : Icons.help_outline,
          color: hazard.verified ? RoadSenseColors.red : RoadSenseColors.amber,
          size: 28,
        ),
        const SizedBox(width: RoadSenseSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hazard.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: RoadSenseSpacing.xs),
              Text(
                '${hazardTypeLabel(hazard.type)} · ${severityLabel(hazard.severity)} · ${hazard.verified ? 'Verified' : 'Unverified'}\n${hazard.observationCount} reports · last reported ${hazard.lastObserved.toLocal()}${hazard.distanceLabel.isEmpty ? '' : ' · ${hazard.distanceLabel}'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          tooltip: 'Close hazard details',
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}

String severityLabel(HazardSeverity severity) => switch (severity) {
  HazardSeverity.possible => 'Possible anomaly',
  HazardSeverity.moderate => 'Moderate severity',
  HazardSeverity.high => 'High severity',
};

class _FloatingChip extends StatelessWidget {
  const _FloatingChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 3,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: RoadSenseColors.ink),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: RoadSenseColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MapNotice extends StatelessWidget {
  const _MapNotice();

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .94),
    borderRadius: BorderRadius.circular(14),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Text('No recent hazards in this area'),
    ),
  );
}

class _LocationUiException implements Exception {
  const _LocationUiException(this.message);
  final String message;
}

String hazardSeverityLabel(HazardSeverity severity) => switch (severity) {
  HazardSeverity.possible => 'possible',
  HazardSeverity.moderate => 'moderate',
  HazardSeverity.high => 'high severity',
};

bool _nearSegment(RoadSegment segment, Offset point) =>
    segment.points.any((roadPoint) => (roadPoint - point).distance < .1);
