import 'hazard_type.dart';
import 'severity_level.dart';

class HazardResult {
  const HazardResult({
    required this.type,
    required this.confidence,
    this.severity,
  });

  final HazardType type;
  final double confidence;
  final SeverityLevel? severity;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'confidence': confidence,
    'severity': severity?.name,
  };

  factory HazardResult.fromJson(Map<String, dynamic> json) => HazardResult(
    type: HazardType.values.byName(json['type'] as String),
    confidence: (json['confidence'] as num).toDouble(),
    severity: json['severity'] == null
        ? null
        : SeverityLevel.values.byName(json['severity'] as String),
  );
}
