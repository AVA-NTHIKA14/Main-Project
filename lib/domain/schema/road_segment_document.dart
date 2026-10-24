import 'schema_helpers.dart';

/// Represents road segment metadata stored at `roadSegments/{segmentId}` in Cloud Firestore.
///
/// Provides topological road context for hazard clustering and spatial aggregation.
class RoadSegmentDocument {
  const RoadSegmentDocument({
    required this.segmentId,
    this.name,
    this.points = const [],
    this.hazardCount = 0,
    this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String segmentId;
  final String? name;
  final List<GeoCoordinates> points;
  final int hazardCount;
  final DateTime? updatedAt;
  final int schemaVersion;

  Map<String, dynamic> toMap() => {
    'segmentId': segmentId,
    if (name != null) 'name': name,
    'points': points.map((p) => p.toMap()).toList(),
    'hazardCount': hazardCount,
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
  };

  factory RoadSegmentDocument.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    final rawId = (map['segmentId'] ?? map['id'] ?? documentId) as String?;
    if (rawId == null || rawId.trim().isEmpty) {
      throw const FormatException(
        'RoadSegmentDocument missing required "segmentId".',
      );
    }

    final rawPoints =
        (map['points'] as List<dynamic>?)
            ?.whereType<Map<dynamic, dynamic>>()
            .map((p) => GeoCoordinates.fromMap(p.cast<String, dynamic>()))
            .toList(growable: false) ??
        const [];

    final hazardCount = (map['hazardCount'] as num?)?.toInt() ?? 0;
    final updatedAt = parseNullableTimestamp(
      map['updatedAt'],
      fieldName: 'updatedAt',
    );

    return RoadSegmentDocument(
      segmentId: rawId.trim(),
      name: map['name'] as String?,
      points: rawPoints,
      hazardCount: hazardCount,
      updatedAt: updatedAt,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
