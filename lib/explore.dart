import 'package:flutter/material.dart';

import 'design_system.dart';
import 'routing.dart';
import 'reports.dart';

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

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.dataSource,
    required this.routingService,
    this.reportRepository,
  });

  final RoadMapDataSource dataSource;
  final HazardAwareRoutingService routingService;
  final ReportRepository? reportRepository;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String? _selectedHazardId;
  double _zoom = 1;
  bool _recentered = false;
  RouteHazardWarning? _routeWarning;
  RoutePlan? _activeRoute;
  bool _routeChecked = false;
  late final ReportRepository _reportRepository;

  @override
  void initState() {
    super.initState();
    _reportRepository = widget.reportRepository ?? InMemoryReportRepository();
    _checkRoute();
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
      : widget.dataSource.hazards
            .where((hazard) => hazard.id == _selectedHazardId)
            .firstOrNull;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        Positioned.fill(
          child: RoadMapCanvas(
            segments: widget.dataSource.segments,
            hazards: widget.dataSource.hazards,
            selectedHazardId: _selectedHazardId,
            zoom: _zoom,
            recentered: _recentered,
            onHazardSelected: (id) => setState(() => _selectedHazardId = id),
          ),
        ),
        Positioned(
          top: RoadSenseSpacing.md,
          left: RoadSenseSpacing.md,
          right: RoadSenseSpacing.md,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  readOnly: true,
                  onTap: () {},
                  decoration: const InputDecoration(
                    hintText: 'Search a place or route',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: RoadSenseSpacing.sm),
              MapControl(
                icon: Icons.person_outline,
                tooltip: 'Open profile',
                onPressed: () {},
              ),
            ],
          ),
        ),
        Positioned(
          right: RoadSenseSpacing.md,
          bottom: _selectedHazard == null ? RoadSenseSpacing.lg : 150,
          child: Column(
            children: [
              MapControl(
                icon: Icons.add,
                tooltip: 'Zoom in',
                onPressed: () =>
                    setState(() => _zoom = (_zoom + .2).clamp(1, 1.8)),
              ),
              const SizedBox(height: RoadSenseSpacing.xs),
              MapControl(
                icon: Icons.remove,
                tooltip: 'Zoom out',
                onPressed: () =>
                    setState(() => _zoom = (_zoom - .2).clamp(1, 1.8)),
              ),
              const SizedBox(height: RoadSenseSpacing.sm),
              MapControl(
                icon: Icons.my_location_outlined,
                tooltip: 'Recenter map',
                onPressed: () => setState(() => _recentered = !_recentered),
              ),
              const SizedBox(height: RoadSenseSpacing.sm),
              MapControl(
                icon: Icons.flag_outlined,
                tooltip: 'Report a hazard',
                onPressed: _openReport,
              ),
            ],
          ),
        ),
        const Positioned(
          left: RoadSenseSpacing.md,
          bottom: RoadSenseSpacing.md,
          child: StatusIndicator(label: 'Monitoring', tone: StatusTone.good),
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
                hazard.detail,
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

bool _nearSegment(RoadSegment segment, Offset point) =>
    segment.points.any((roadPoint) => (roadPoint - point).distance < .1);
