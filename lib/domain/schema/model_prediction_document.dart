import '../../detection.dart';
import '../../explore.dart';
import '../../sensors.dart';
import 'schema_helpers.dart';

/// Represents ML inference output stored at `modelPredictions/{predictionId}` in Cloud Firestore.
///
/// Kept strictly isolated from confirmed map hazards ([HazardDocument]).
/// A prediction output is a candidate signal and never automatically treated as a verified hazard.
class ModelPredictionDocument {
  const ModelPredictionDocument({
    required this.predictionId,
    required this.sensorWindowId,
    this.tripId,
    required this.classification,
    required this.confidence,
    this.severityEstimate = HazardSeverity.possible,
    required this.coordinates,
    this.speedMps = 0.0,
    required this.modelVersion,
    this.source = DetectionSource.tensorFlowLite,
    required this.timestamp,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String predictionId;
  final String sensorWindowId;
  final String? tripId;
  final DetectionClassification classification;
  final double confidence;
  final HazardSeverity severityEstimate;
  final GeoCoordinates coordinates;
  final double speedMps;
  final String modelVersion;
  final DetectionSource source;
  final DateTime timestamp;
  final int schemaVersion;

  Map<String, dynamic> toMap() => {
    'predictionId': predictionId,
    'sensorWindowId': sensorWindowId,
    if (tripId != null) 'tripId': tripId,
    'classification': classification.name,
    'confidence': confidence,
    'severityEstimate': severityEstimate.name,
    ...coordinates.toMap(),
    'speedMps': speedMps,
    'modelVersion': modelVersion,
    'source': source.name,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
  };

  factory ModelPredictionDocument.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    final rawId = (map['predictionId'] ?? map['id'] ?? documentId) as String?;
    if (rawId == null || rawId.trim().isEmpty) {
      throw const FormatException(
        'ModelPredictionDocument missing required "predictionId".',
      );
    }

    final rawWindowId = map['sensorWindowId'] as String?;
    if (rawWindowId == null || rawWindowId.trim().isEmpty) {
      throw const FormatException(
        'ModelPredictionDocument missing required "sensorWindowId".',
      );
    }

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

    final coordinates = GeoCoordinates.fromMap(map);
    final timestamp = parseTimestamp(map['timestamp'], fieldName: 'timestamp');

    final rawClassification = map['classification'] as String?;
    final classification = rawClassification != null
        ? DetectionClassification.values.firstWhere(
            (c) => c.name.toLowerCase() == rawClassification.toLowerCase(),
            orElse: () => DetectionClassification.other,
          )
        : DetectionClassification.other;

    final rawSeverity = map['severityEstimate'] as String?;
    final severity = rawSeverity != null
        ? HazardSeverity.values.firstWhere(
            (s) => s.name.toLowerCase() == rawSeverity.toLowerCase(),
            orElse: () => HazardSeverity.possible,
          )
        : HazardSeverity.possible;

    final rawSource = map['source'] as String?;
    final source = rawSource != null
        ? DetectionSource.values.firstWhere(
            (s) => s.name.toLowerCase() == rawSource.toLowerCase(),
            orElse: () => DetectionSource.tensorFlowLite,
          )
        : DetectionSource.tensorFlowLite;

    final speedMps = (map['speedMps'] as num?)?.toDouble() ?? 0.0;
    final modelVersion = (map['modelVersion'] as String?) ?? 'unknown-model';

    return ModelPredictionDocument(
      predictionId: rawId.trim(),
      sensorWindowId: rawWindowId.trim(),
      tripId: map['tripId'] as String?,
      classification: classification,
      confidence: confidence,
      severityEstimate: severity,
      coordinates: coordinates,
      speedMps: speedMps,
      modelVersion: modelVersion,
      source: source,
      timestamp: timestamp,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  /// Converts to domain [DetectionResult].
  DetectionResult toDomain() => DetectionResult(
    classification: classification,
    confidence: confidence,
    timestamp: timestamp,
    location: GpsReading(
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      accuracy: 5.0,
      speedMps: speedMps,
      timestamp: timestamp,
    ),
    speedMps: speedMps,
    sensorWindowId: sensorWindowId,
    modelVersion: modelVersion,
    severityEstimate: severityEstimate,
    source: source,
  );

  /// Creates from domain [DetectionResult].
  factory ModelPredictionDocument.fromDomain(
    DetectionResult result, {
    String? predictionId,
    String? tripId,
  }) => ModelPredictionDocument(
    predictionId: predictionId ?? '${result.sensorWindowId}_pred',
    sensorWindowId: result.sensorWindowId,
    tripId: tripId,
    classification: result.classification,
    confidence: result.confidence,
    severityEstimate: result.severityEstimate,
    coordinates: GeoCoordinates.validated(
      latitude: result.location.latitude,
      longitude: result.location.longitude,
    ),
    speedMps: result.speedMps,
    modelVersion: result.modelVersion,
    source: result.source,
    timestamp: result.timestamp,
  );
}
