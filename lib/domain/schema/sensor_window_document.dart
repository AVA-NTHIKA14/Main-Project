import 'schema_helpers.dart';

/// Represents a bounded sensor window stored in subcollection
/// `trips/{tripId}/sensorWindows/{windowId}` in Cloud Firestore.
///
/// Bounded windows store extracted statistical features and summary GPS fixes.
/// Raw high-frequency sensor samples are provisional and optional pending Person 3's ML requirements.
class SensorWindowDocument {
  const SensorWindowDocument({
    required this.windowId,
    required this.tripId,
    required this.ownerUid,
    required this.startTime,
    required this.endTime,
    required this.sampleCount,
    this.coordinates,
    this.averageSpeedMps,
    this.peakAccelerationMagnitude,
    this.averageAccelerationMagnitude,
    this.averageGyroscopeMagnitude,
    this.retainedSamples,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String windowId;
  final String tripId;
  final String ownerUid;
  final DateTime startTime;
  final DateTime endTime;
  final int sampleCount;
  final GeoCoordinates? coordinates;
  final double? averageSpeedMps;
  final double? peakAccelerationMagnitude;
  final double? averageAccelerationMagnitude;
  final double? averageGyroscopeMagnitude;
  final List<Map<String, dynamic>>? retainedSamples;
  final int schemaVersion;

  Map<String, dynamic> toMap() => {
    'windowId': windowId,
    'tripId': tripId,
    'ownerUid': ownerUid,
    'startTime': startTime.toUtc().toIso8601String(),
    'endTime': endTime.toUtc().toIso8601String(),
    'sampleCount': sampleCount,
    if (coordinates != null) ...coordinates!.toMap(),
    if (averageSpeedMps != null) 'averageSpeedMps': averageSpeedMps,
    if (peakAccelerationMagnitude != null)
      'peakAccelerationMagnitude': peakAccelerationMagnitude,
    if (averageAccelerationMagnitude != null)
      'averageAccelerationMagnitude': averageAccelerationMagnitude,
    if (averageGyroscopeMagnitude != null)
      'averageGyroscopeMagnitude': averageGyroscopeMagnitude,
    if (retainedSamples != null) 'retainedSamples': retainedSamples,
    'schemaVersion': schemaVersion,
  };

  factory SensorWindowDocument.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    final rawWindowId = (map['windowId'] ?? map['id'] ?? documentId) as String?;
    if (rawWindowId == null || rawWindowId.trim().isEmpty) {
      throw const FormatException(
        'SensorWindowDocument missing required "windowId".',
      );
    }

    final rawTripId = map['tripId'] as String?;
    if (rawTripId == null || rawTripId.trim().isEmpty) {
      throw const FormatException(
        'SensorWindowDocument missing required "tripId".',
      );
    }

    final rawOwnerUid = map['ownerUid'] as String?;
    if (rawOwnerUid == null || rawOwnerUid.trim().isEmpty) {
      throw const FormatException(
        'SensorWindowDocument missing required "ownerUid".',
      );
    }
    if (rawOwnerUid.contains('@')) {
      throw FormatException(
        'Invalid ownerUid: "$rawOwnerUid". Must use UID, never email.',
      );
    }

    final startTime = parseTimestamp(map['startTime'], fieldName: 'startTime');
    final endTime = parseTimestamp(map['endTime'], fieldName: 'endTime');

    final sampleCount = (map['sampleCount'] as num?)?.toInt() ?? 0;
    if (sampleCount < 0) {
      throw FormatException(
        'sampleCount cannot be negative, got $sampleCount.',
      );
    }

    GeoCoordinates? coordinates;
    if (map.containsKey('latitude') || map.containsKey('lat')) {
      coordinates = GeoCoordinates.fromMap(map);
    }

    final retained = (map['retainedSamples'] as List<dynamic>?)
        ?.whereType<Map<dynamic, dynamic>>()
        .map((m) => m.cast<String, dynamic>())
        .toList();

    return SensorWindowDocument(
      windowId: rawWindowId.trim(),
      tripId: rawTripId.trim(),
      ownerUid: rawOwnerUid.trim(),
      startTime: startTime,
      endTime: endTime,
      sampleCount: sampleCount,
      coordinates: coordinates,
      averageSpeedMps: (map['averageSpeedMps'] as num?)?.toDouble(),
      peakAccelerationMagnitude: (map['peakAccelerationMagnitude'] as num?)
          ?.toDouble(),
      averageAccelerationMagnitude:
          (map['averageAccelerationMagnitude'] as num?)?.toDouble(),
      averageGyroscopeMagnitude: (map['averageGyroscopeMagnitude'] as num?)
          ?.toDouble(),
      retainedSamples: retained,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
