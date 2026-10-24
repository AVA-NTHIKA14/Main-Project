import '../../explore.dart';
import 'schema_helpers.dart';

/// Represents a shared hazard record stored at `hazards/{hazardId}` in Cloud Firestore.
///
/// Designed for map rendering and active navigation warning queries.
/// Strictly separated from raw model predictions and unconfirmed individual observations.
/// Lifecycle status, confirmation rules, and closure criteria remain provisional pending Person 4.
class HazardDocument {
  const HazardDocument({
    required this.hazardId,
    required this.coordinates,
    this.geohash,
    required this.type,
    this.severity = HazardSeverity.possible,
    this.status = VerificationStatus.possible,
    this.confidence = 0.0,
    this.observationCount = 1,
    this.uniqueUserCount = 1,
    this.segmentId = 'unmatched',
    required this.firstObserved,
    required this.lastObserved,
    this.lastConfirmedAt,
    this.resolvedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String hazardId;
  final GeoCoordinates coordinates;
  final String? geohash;
  final HazardType type;
  final HazardSeverity severity;
  final VerificationStatus status;
  final double confidence;
  final int observationCount;
  final int uniqueUserCount;
  final String segmentId;
  final DateTime firstObserved;
  final DateTime lastObserved;
  final DateTime? lastConfirmedAt;
  final DateTime? resolvedAt;
  final int schemaVersion;

  bool get isConfirmed => status == VerificationStatus.verified;
  bool get isResolved => status == VerificationStatus.resolved;

  Map<String, dynamic> toMap() => {
    'hazardId': hazardId,
    ...coordinates.toMap(),
    if (geohash != null) 'geohash': geohash,
    'type': type.name,
    'severity': severity.name,
    'status': status.name,
    'confidence': confidence,
    'observationCount': observationCount,
    'uniqueUserCount': uniqueUserCount,
    'segmentId': segmentId,
    'firstObserved': firstObserved.toUtc().toIso8601String(),
    'lastObserved': lastObserved.toUtc().toIso8601String(),
    if (lastConfirmedAt != null)
      'lastConfirmedAt': lastConfirmedAt!.toUtc().toIso8601String(),
    if (resolvedAt != null) 'resolvedAt': resolvedAt!.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
  };

  factory HazardDocument.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    final rawId = (map['hazardId'] ?? map['id'] ?? documentId) as String?;
    if (rawId == null || rawId.trim().isEmpty) {
      throw const FormatException(
        'HazardDocument missing required "hazardId".',
      );
    }

    final coordinates = GeoCoordinates.fromMap(map);

    final rawType = map['type'] as String?;
    final type = rawType != null
        ? HazardType.values.firstWhere(
            (t) => t.name.toLowerCase() == rawType.toLowerCase(),
            orElse: () => HazardType.unknown,
          )
        : HazardType.unknown;

    final rawSeverity = map['severity'] as String?;
    final severity = rawSeverity != null
        ? HazardSeverity.values.firstWhere(
            (s) => s.name.toLowerCase() == rawSeverity.toLowerCase(),
            orElse: () => HazardSeverity.possible,
          )
        : HazardSeverity.possible;

    final rawStatus = map['status'] as String?;
    final status = rawStatus != null
        ? VerificationStatus.values.firstWhere(
            (v) => v.name.toLowerCase() == rawStatus.toLowerCase(),
            orElse: () => VerificationStatus.possible,
          )
        : VerificationStatus.possible;

    final rawConfidence = map['confidence'] ?? 0.0;
    if (rawConfidence is! num) {
      throw FormatException('confidence must be numeric, got $rawConfidence.');
    }
    final confidence = rawConfidence.toDouble();
    if (confidence < 0.0 || confidence > 1.0) {
      throw FormatException(
        'confidence must be between 0.0 and 1.0, got $confidence.',
      );
    }

    final observationCount = (map['observationCount'] as num?)?.toInt() ?? 1;
    final uniqueUserCount = (map['uniqueUserCount'] as num?)?.toInt() ?? 1;
    final segmentId = (map['segmentId'] as String?) ?? 'unmatched';

    final firstObserved = parseTimestamp(
      map['firstObserved'] ?? map['timestamp'] ?? DateTime.now(),
      fieldName: 'firstObserved',
    );
    final lastObserved = parseTimestamp(
      map['lastObserved'] ?? firstObserved,
      fieldName: 'lastObserved',
    );
    final lastConfirmedAt = parseNullableTimestamp(
      map['lastConfirmedAt'],
      fieldName: 'lastConfirmedAt',
    );
    final resolvedAt = parseNullableTimestamp(
      map['resolvedAt'],
      fieldName: 'resolvedAt',
    );

    return HazardDocument(
      hazardId: rawId.trim(),
      coordinates: coordinates,
      geohash: map['geohash'] as String?,
      type: type,
      severity: severity,
      status: status,
      confidence: confidence,
      observationCount: observationCount,
      uniqueUserCount: uniqueUserCount,
      segmentId: segmentId,
      firstObserved: firstObserved,
      lastObserved: lastObserved,
      lastConfirmedAt: lastConfirmedAt,
      resolvedAt: resolvedAt,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  /// Converts to domain [Hazard] for map presentation.
  Hazard toDomain({List<HazardObservation> observations = const []}) => Hazard(
    id: hazardId,
    segmentId: segmentId,
    severity: severity,
    observations: observations,
    status: status,
    type: type,
    location: RoadLocation(
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    ),
    confidence: confidence,
    firstObserved: firstObserved,
    lastObserved: lastObserved,
  );

  /// Creates from domain [Hazard].
  factory HazardDocument.fromDomain(
    Hazard hazard, {
    String? geohash,
    DateTime? lastConfirmedAt,
    DateTime? resolvedAt,
  }) => HazardDocument(
    hazardId: hazard.id,
    coordinates: GeoCoordinates.validated(
      latitude: hazard.location.latitude,
      longitude: hazard.location.longitude,
    ),
    geohash: geohash,
    type: hazard.type,
    severity: hazard.severity,
    status: hazard.status,
    confidence: hazard.confidence,
    observationCount: hazard.observationCount,
    uniqueUserCount: hazard.uniqueUserCount,
    segmentId: hazard.segmentId,
    firstObserved: hazard.firstObserved,
    lastObserved: hazard.lastObserved,
    lastConfirmedAt: lastConfirmedAt,
    resolvedAt: resolvedAt,
  );
}
