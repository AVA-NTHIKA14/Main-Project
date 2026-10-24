import '../../explore.dart';
import 'schema_helpers.dart';

enum ObservationSource {
  sensorDetection,
  manualReport,
  crowdCluster,
  verifiedReview,
}

/// Represents an individual hazard observation stored at
/// `hazardObservations/{observationId}` in Cloud Firestore.
///
/// Captures raw sensory evidence or individual user reports contributing toward
/// hazard clustering and verification. Strictly separated from confirmed [HazardDocument].
class HazardObservationDocument {
  const HazardObservationDocument({
    required this.observationId,
    required this.reporterUid,
    this.tripId,
    required this.coordinates,
    required this.type,
    this.severity = HazardSeverity.possible,
    required this.timestamp,
    this.source = ObservationSource.sensorDetection,
    this.sensorWindowId,
    this.segmentId = 'unmatched',
    this.confidence,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String observationId;
  final String reporterUid;
  final String? tripId;
  final GeoCoordinates coordinates;
  final HazardType type;
  final HazardSeverity severity;
  final DateTime timestamp;
  final ObservationSource source;
  final String? sensorWindowId;
  final String segmentId;
  final double? confidence;
  final int schemaVersion;

  Map<String, dynamic> toMap() => {
    'observationId': observationId,
    'reporterUid': reporterUid,
    if (tripId != null) 'tripId': tripId,
    ...coordinates.toMap(),
    'type': type.name,
    'severity': severity.name,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'source': source.name,
    if (sensorWindowId != null) 'sensorWindowId': sensorWindowId,
    'segmentId': segmentId,
    if (segmentId != 'unmatched') 'hazardId': segmentId,
    if (confidence != null) 'confidence': confidence,
    'schemaVersion': schemaVersion,
  };

  factory HazardObservationDocument.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    final rawId = (map['observationId'] ?? map['id'] ?? documentId) as String?;
    if (rawId == null || rawId.trim().isEmpty) {
      throw const FormatException(
        'HazardObservationDocument missing required "observationId".',
      );
    }

    final rawReporterUid = (map['reporterUid'] ?? map['userId']) as String?;
    if (rawReporterUid == null || rawReporterUid.trim().isEmpty) {
      throw const FormatException(
        'HazardObservationDocument missing required "reporterUid".',
      );
    }
    final reporterUid = rawReporterUid.trim();
    if (reporterUid.contains('@')) {
      throw FormatException(
        'Invalid reporterUid: "$reporterUid". Must use UID, never email.',
      );
    }

    final coordinates = GeoCoordinates.fromMap(map);
    final timestamp = parseTimestamp(map['timestamp'], fieldName: 'timestamp');

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

    final rawSource = map['source'] as String?;
    final source = rawSource != null
        ? ObservationSource.values.firstWhere(
            (s) => s.name.toLowerCase() == rawSource.toLowerCase(),
            orElse: () => ObservationSource.sensorDetection,
          )
        : ObservationSource.sensorDetection;

    final rawConfidence = map['confidence'];
    double? confidence;
    if (rawConfidence is num) {
      confidence = rawConfidence.toDouble();
      if (confidence < 0.0 || confidence > 1.0) {
        throw FormatException(
          'confidence must be between 0.0 and 1.0, got $confidence.',
        );
      }
    }

    return HazardObservationDocument(
      observationId: rawId.trim(),
      reporterUid: reporterUid,
      tripId: map['tripId'] as String?,
      coordinates: coordinates,
      type: type,
      severity: severity,
      timestamp: timestamp,
      source: source,
      sensorWindowId: map['sensorWindowId'] as String?,
      segmentId:
          (map['segmentId'] ?? map['hazardId'] as String?) ?? 'unmatched',
      confidence: confidence,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  /// Converts to domain [HazardObservation].
  HazardObservation toDomain() => HazardObservation(
    id: observationId,
    segmentId: segmentId,
    timestamp: timestamp,
    userId: reporterUid,
    tripId: tripId ?? 'unknown-trip',
    location: RoadLocation(
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    ),
    type: type,
    severity: severity,
  );

  /// Creates from domain [HazardObservation].
  factory HazardObservationDocument.fromDomain(
    HazardObservation observation, {
    ObservationSource source = ObservationSource.sensorDetection,
    String? sensorWindowId,
    double? confidence,
  }) => HazardObservationDocument(
    observationId: observation.id,
    reporterUid: observation.userId,
    tripId: observation.tripId,
    coordinates: GeoCoordinates.validated(
      latitude: observation.location.latitude,
      longitude: observation.location.longitude,
    ),
    type: observation.type,
    severity: observation.severity,
    timestamp: observation.timestamp,
    source: source,
    sensorWindowId: sensorWindowId,
    segmentId: observation.segmentId,
    confidence: confidence,
  );
}
