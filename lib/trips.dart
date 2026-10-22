import 'package:flutter/material.dart';

import 'design_system.dart';
import 'explore.dart';

class TripObservation {
  const TripObservation({
    required this.id,
    required this.label,
    required this.location,
    required this.isVerified,
    this.isPossible = false,
  });

  final String id;
  final String label;
  final RoadLocation location;
  final bool isVerified;
  final bool isPossible;
}

class Trip {
  const Trip({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.distanceKm,
    required this.startLabel,
    required this.endLabel,
    required this.roadQuality,
    required this.observations,
    required this.verifiedHazards,
    required this.possibleAnomalies,
    required this.routeSegments,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration duration;
  final double distanceKm;
  final String startLabel;
  final String endLabel;
  final String roadQuality;
  final List<TripObservation> observations;
  final List<TripObservation> verifiedHazards;
  final List<TripObservation> possibleAnomalies;
  final List<RoadSegment> routeSegments;

  String get dateLabel =>
      '${startedAt.day}/${startedAt.month}/${startedAt.year}';
  String get durationLabel =>
      '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  String get distanceLabel => '${distanceKm.toStringAsFixed(1)} km';
}

abstract interface class TripHistoryRepository {
  Future<List<Trip>> recentTrips();
  Future<Trip?> tripById(String id);
}

class MockTripHistoryRepository implements TripHistoryRepository {
  const MockTripHistoryRepository();

  static final _today = DateTime(2026, 10, 7, 8, 20);
  static final _segments = [
    const RoadSegment(
      id: 'trip-start',
      points: [
        Offset(.08, .78),
        Offset(.32, .55),
        Offset(.57, .4),
        Offset(.92, .2),
      ],
    ),
    const RoadSegment(
      id: 'trip-end',
      points: [Offset(.57, .4), Offset(.7, .62), Offset(.9, .84)],
    ),
  ];

  static final _trips = [
    Trip(
      id: 'trip-today',
      startedAt: _today,
      endedAt: _today.add(const Duration(minutes: 42)),
      duration: const Duration(minutes: 42),
      distanceKm: 18.4,
      startLabel: 'Home',
      endLabel: 'Central district',
      roadQuality: 'Mostly clear',
      routeSegments: _segments,
      observations: [
        TripObservation(
          id: 'trip-observation-1',
          label: 'Possible rough road',
          location: const RoadLocation(latitude: 51.501, longitude: -.121),
          isVerified: false,
          isPossible: true,
        ),
        TripObservation(
          id: 'trip-observation-2',
          label: 'Verified pothole',
          location: const RoadLocation(latitude: 51.503, longitude: -.12),
          isVerified: true,
        ),
      ],
      verifiedHazards: [
        TripObservation(
          id: 'trip-hazard-1',
          label: 'High-severity pothole',
          location: const RoadLocation(latitude: 51.503, longitude: -.12),
          isVerified: true,
        ),
      ],
      possibleAnomalies: [
        TripObservation(
          id: 'trip-possible-1',
          label: 'Possible rough road',
          location: const RoadLocation(latitude: 51.501, longitude: -.121),
          isVerified: false,
          isPossible: true,
        ),
      ],
    ),
    Trip(
      id: 'trip-yesterday',
      startedAt: DateTime(2026, 10, 6, 17, 10),
      endedAt: DateTime(2026, 10, 6, 17, 52),
      duration: const Duration(minutes: 42),
      distanceKm: 14.8,
      startLabel: 'Central district',
      endLabel: 'Home',
      roadQuality: 'Good',
      routeSegments: _segments,
      observations: const [],
      verifiedHazards: const [],
      possibleAnomalies: const [],
    ),
  ];

  @override
  Future<List<Trip>> recentTrips() async => List.unmodifiable(_trips);

  @override
  Future<Trip?> tripById(String id) async =>
      _trips.where((trip) => trip.id == id).firstOrNull;
}

class TripsScreen extends StatefulWidget {
  const TripsScreen({
    super.key,
    this.repository = const MockTripHistoryRepository(),
  });

  final TripHistoryRepository repository;

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  late Future<List<Trip>> _trips;

  @override
  void initState() {
    super.initState();
    _trips = widget.repository.recentTrips();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(RoadSenseSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trips', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: RoadSenseSpacing.xs),
        Text(
          'Your recent journeys and road notes',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: RoadSenseSpacing.lg),
        Expanded(
          child: FutureBuilder<List<Trip>>(
            future: _trips,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const RoadSenseLoadingState(label: 'Loading trips');
              }
              final trips = snapshot.data ?? const <Trip>[];
              if (trips.isEmpty) {
                return const RoadSenseEmptyState(
                  title: 'No trips yet',
                  message: 'Trips are created automatically as you travel.',
                  icon: Icons.route_outlined,
                );
              }
              return ListView.separated(
                itemCount: trips.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) => _TripListItem(
                  trip: trips[index],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TripDetailsScreen(trip: trips[index]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _TripListItem extends StatelessWidget {
  const _TripListItem({required this.trip, required this.onTap});

  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(
        vertical: RoadSenseSpacing.sm,
      ),
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: RoadSenseColors.tealSoft,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.route, color: RoadSenseColors.teal),
      ),
      title: Text(
        trip.dateLabel,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${trip.startLabel} to ${trip.endLabel}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Wrap(
            spacing: RoadSenseSpacing.xs,
            children: [
              Text(
                trip.durationLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                trip.distanceLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '${trip.verifiedHazards.length} verified hazards',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class TripDetailsScreen extends StatelessWidget {
  const TripDetailsScreen({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trip details')),
    body: ListView(
      padding: const EdgeInsets.all(RoadSenseSpacing.md),
      children: [
        Text(trip.dateLabel, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: RoadSenseSpacing.xs),
        Text(
          '${trip.startLabel} to ${trip.endLabel}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: RoadSenseSpacing.md),
        SizedBox(
          height: 240,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(RoadSenseRadius.lg),
            child: RoadMapCanvas(
              segments: trip.routeSegments,
              hazards: const [],
              selectedHazardId: null,
              zoom: 1,
              recentered: false,
              onHazardSelected: (_) {},
            ),
          ),
        ),
        const SizedBox(height: RoadSenseSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _DetailMetric(
                label: 'Duration',
                value: trip.durationLabel,
              ),
            ),
            Expanded(
              child: _DetailMetric(
                label: 'Distance',
                value: trip.distanceLabel,
              ),
            ),
            Expanded(
              child: _DetailMetric(
                label: 'Road quality',
                value: trip.roadQuality,
              ),
            ),
          ],
        ),
        const SizedBox(height: RoadSenseSpacing.lg),
        _DetailSection(
          title: 'Verified hazards',
          items: trip.verifiedHazards,
          emptyLabel: 'No verified hazards on this trip',
        ),
        const SizedBox(height: RoadSenseSpacing.md),
        _DetailSection(
          title: 'Possible anomalies',
          items: trip.possibleAnomalies,
          emptyLabel: 'No possible anomalies recorded',
        ),
      ],
    ),
  );
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: RoadSenseSpacing.xs),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.items,
    required this.emptyLabel,
  });
  final String title;
  final List<TripObservation> items;
  final String emptyLabel;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: RoadSenseSpacing.sm),
      if (items.isEmpty)
        Text(emptyLabel, style: Theme.of(context).textTheme.bodyMedium)
      else
        ...items.map(
          (item) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              item.isVerified ? Icons.verified_outlined : Icons.help_outline,
              color: item.isVerified
                  ? RoadSenseColors.teal
                  : RoadSenseColors.amber,
            ),
            title: Text(item.label),
            subtitle: Text(
              item.isVerified ? 'Community verified' : 'Still being reviewed',
            ),
          ),
        ),
    ],
  );
}
