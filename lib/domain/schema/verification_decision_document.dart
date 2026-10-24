import '../../explore.dart';
import 'schema_helpers.dart';

/// Represents an authoritative verification decision stored at
/// `verificationDecisions/{decisionId}` in Cloud Firestore.
///
/// Records review actions performed on candidate hazard clusters.
/// Normal client users cannot self-authorize verification decisions.
class VerificationDecisionDocument {
  const VerificationDecisionDocument({
    required this.decisionId,
    required this.hazardId,
    required this.reviewerUid,
    required this.status,
    this.reasons = const [],
    this.independentObservationCount = 1,
    this.confidence = 1.0,
    required this.timestamp,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String decisionId;
  final String hazardId;
  final String reviewerUid;
  final VerificationStatus status;
  final List<String> reasons;
  final int independentObservationCount;
  final double confidence;
  final DateTime timestamp;
  final int schemaVersion;

  Map<String, dynamic> toMap() => {
    'decisionId': decisionId,
    'hazardId': hazardId,
    'reviewerUid': reviewerUid,
    'status': status.name,
    'reasons': reasons,
    'independentObservationCount': independentObservationCount,
    'confidence': confidence,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
  };

  factory VerificationDecisionDocument.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    final rawId = (map['decisionId'] ?? map['id'] ?? documentId) as String?;
    if (rawId == null || rawId.trim().isEmpty) {
      throw const FormatException(
        'VerificationDecisionDocument missing required "decisionId".',
      );
    }

    final rawHazardId = (map['hazardId'] ?? map['clusterId']) as String?;
    if (rawHazardId == null || rawHazardId.trim().isEmpty) {
      throw const FormatException(
        'VerificationDecisionDocument missing required "hazardId".',
      );
    }

    final rawReviewerUid = map['reviewerUid'] as String?;
    if (rawReviewerUid == null || rawReviewerUid.trim().isEmpty) {
      throw const FormatException(
        'VerificationDecisionDocument missing required "reviewerUid".',
      );
    }
    final reviewerUid = rawReviewerUid.trim();
    if (reviewerUid.contains('@')) {
      throw FormatException(
        'Invalid reviewerUid: "$reviewerUid". Must use UID, never email.',
      );
    }

    final rawStatus = map['status'] as String?;
    final status = rawStatus != null
        ? VerificationStatus.values.firstWhere(
            (v) => v.name.toLowerCase() == rawStatus.toLowerCase(),
            orElse: () => VerificationStatus.verified,
          )
        : VerificationStatus.verified;

    final reasons =
        (map['reasons'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(growable: false) ??
        const [];

    final rawConfidence = map['confidence'] ?? 1.0;
    if (rawConfidence is! num) {
      throw FormatException('confidence must be numeric, got $rawConfidence.');
    }
    final confidence = rawConfidence.toDouble();
    if (confidence < 0.0 || confidence > 1.0) {
      throw FormatException(
        'confidence must be between 0.0 and 1.0, got $confidence.',
      );
    }

    final independentCount =
        (map['independentObservationCount'] as num?)?.toInt() ?? 1;
    final timestamp = parseTimestamp(map['timestamp'], fieldName: 'timestamp');

    return VerificationDecisionDocument(
      decisionId: rawId.trim(),
      hazardId: rawHazardId.trim(),
      reviewerUid: reviewerUid,
      status: status,
      reasons: reasons,
      independentObservationCount: independentCount,
      confidence: confidence,
      timestamp: timestamp,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
