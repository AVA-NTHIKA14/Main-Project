import '../../explore.dart';
import '../../trips.dart';
import 'schema_helpers.dart';

enum TripStatus { inProgress, completed, cancelled }

/// Represents a trip record stored at `trips/{tripId}` in Cloud Firestore.
///
/// Contains stable trip metadata and explicit user ownership ([ownerUid]).
/// High-frequency sensor samples are NOT stored here directly.
class TripDocument {
  const TripDocument({
    required this.tripId,
    required this.ownerUid,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.distanceKm,
    this.startLabel,
    this.endLabel,
    this.roadQuality,
    this.status = TripStatus.completed,
    this.observationCount = 0,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String tripId;
  final String ownerUid;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final double? distanceKm;
  final String? startLabel;
  final String? endLabel;
  final String? roadQuality;
  final TripStatus status;
  final int observationCount;
  final int schemaVersion;

  Map<String, dynamic> toMap() => {
    'tripId': tripId,
    'ownerUid': ownerUid,
    'startedAt': startedAt.toUtc().toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toUtc().toIso8601String(),
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (distanceKm != null) 'distanceKm': distanceKm,
    if (startLabel != null) 'startLabel': startLabel,
    if (endLabel != null) 'endLabel': endLabel,
    if (roadQuality != null) 'roadQuality': roadQuality,
    'status': status.name,
    'observationCount': observationCount,
    'schemaVersion': schemaVersion,
  };

  factory TripDocument.fromMap(Map<String, dynamic> map, {String? documentId}) {
    final rawTripId = (map['tripId'] ?? map['id'] ?? documentId) as String?;
    if (rawTripId == null || rawTripId.trim().isEmpty) {
      throw const FormatException('TripDocument missing required "tripId".');
    }
    final tripId = rawTripId.trim();

    final rawOwnerUid = (map['ownerUid'] ?? map['userId']) as String?;
    if (rawOwnerUid == null || rawOwnerUid.trim().isEmpty) {
      throw const FormatException('TripDocument missing required "ownerUid".');
    }
    final ownerUid = rawOwnerUid.trim();
    if (ownerUid.contains('@')) {
      throw FormatException(
        'Invalid ownerUid: "$ownerUid". Must use UID, never email.',
      );
    }

    final startedAt = parseTimestamp(map['startedAt'], fieldName: 'startedAt');
    final endedAt = parseNullableTimestamp(
      map['endedAt'],
      fieldName: 'endedAt',
    );

    final rawDuration = map['durationSeconds'] ?? map['duration'];
    int? durationSeconds;
    if (rawDuration is num) {
      durationSeconds = rawDuration.toInt();
    } else if (rawDuration is Duration) {
      durationSeconds = rawDuration.inSeconds;
    }

    final rawDistance = map['distanceKm'];
    double? distanceKm;
    if (rawDistance is num) {
      distanceKm = rawDistance.toDouble();
      if (distanceKm < 0) {
        throw FormatException(
          'distanceKm must be non-negative, got $distanceKm.',
        );
      }
    }

    final rawStatus = map['status'] as String?;
    final status = rawStatus != null
        ? TripStatus.values.firstWhere(
            (s) => s.name.toLowerCase() == rawStatus.toLowerCase(),
            orElse: () => TripStatus.completed,
          )
        : (endedAt != null ? TripStatus.completed : TripStatus.inProgress);

    final observationCount = (map['observationCount'] as num?)?.toInt() ?? 0;
    final schemaVersion = (map['schemaVersion'] as num?)?.toInt() ?? 1;

    return TripDocument(
      tripId: tripId,
      ownerUid: ownerUid,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: durationSeconds,
      distanceKm: distanceKm,
      startLabel: map['startLabel'] as String?,
      endLabel: map['endLabel'] as String?,
      roadQuality: map['roadQuality'] as String?,
      status: status,
      observationCount: observationCount,
      schemaVersion: schemaVersion,
    );
  }

  /// Converts to domain [Trip].
  Trip toDomain({
    List<TripObservation> observations = const [],
    List<TripObservation> verifiedHazards = const [],
    List<TripObservation> possibleAnomalies = const [],
    List<RoadSegment> routeSegments = const [],
  }) {
    final effectiveEnd =
        endedAt ?? startedAt.add(Duration(seconds: durationSeconds ?? 0));
    final duration = durationSeconds != null
        ? Duration(seconds: durationSeconds!)
        : effectiveEnd.difference(startedAt);

    return Trip(
      id: tripId,
      startedAt: startedAt,
      endedAt: effectiveEnd,
      duration: duration,
      distanceKm: distanceKm ?? 0.0,
      startLabel: startLabel ?? 'Trip start',
      endLabel: endLabel ?? 'Trip destination',
      roadQuality: roadQuality ?? 'Unknown',
      observations: observations,
      verifiedHazards: verifiedHazards,
      possibleAnomalies: possibleAnomalies,
      routeSegments: routeSegments,
    );
  }

  /// Creates a [TripDocument] from the domain [Trip].
  factory TripDocument.fromDomain(
    Trip trip, {
    required String ownerUid,
    TripStatus status = TripStatus.completed,
  }) => TripDocument(
    tripId: trip.id,
    ownerUid: ownerUid,
    startedAt: trip.startedAt,
    endedAt: trip.endedAt,
    durationSeconds: trip.duration.inSeconds,
    distanceKm: trip.distanceKm,
    startLabel: trip.startLabel,
    endLabel: trip.endLabel,
    roadQuality: trip.roadQuality,
    status: status,
    observationCount: trip.observations.length,
  );
}
