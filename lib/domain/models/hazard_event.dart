import 'hazard_status.dart';
import 'hazard_type.dart';
import 'severity_level.dart';

class HazardEvent {
  const HazardEvent({
    required this.id,
    required this.lat,
    required this.lng,
    required this.geohash,
    required this.type,
    this.confidence,
    this.severity,
    required this.reportedBy,
    required this.timestamp,
    this.verificationCount = 0,
    this.status = HazardStatus.unverified,
  });

  final String id;
  final double lat;
  final double lng;
  final String geohash;
  final HazardType type;
  final double? confidence;
  final SeverityLevel? severity;
  final String reportedBy;
  final DateTime timestamp;
  final int verificationCount;
  final HazardStatus status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': lat,
        'lng': lng,
        'geohash': geohash,
        'type': type.name,
        'confidence': confidence,
        'severity': severity?.name,
        'reportedBy': reportedBy,
        'timestamp': timestamp.toIso8601String(),
        'verificationCount': verificationCount,
        'status': status.name,
      };

  factory HazardEvent.fromJson(Map<String, dynamic> json) => HazardEvent(
        id: json['id'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        geohash: json['geohash'] as String,
        type: HazardType.values.byName(json['type'] as String),
        confidence: (json['confidence'] as num?)?.toDouble(),
        severity: json['severity'] == null
            ? null
            : SeverityLevel.values.byName(json['severity'] as String),
        reportedBy: json['reportedBy'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        verificationCount: (json['verificationCount'] as num?)?.toInt() ?? 0,
        status: json['status'] == null
            ? HazardStatus.unverified
            : HazardStatus.values.byName(json['status'] as String),
      );
}
