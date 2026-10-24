import '../../explore.dart';
import '../../reports.dart';
import 'schema_helpers.dart';

enum ReportStatus { submitted, underReview, accepted, rejected }

/// Represents a user-submitted road hazard report stored at `reports/{reportId}` in Cloud Firestore.
///
/// Ensures private reporter identity is cleanly isolated from public map displays.
/// Local file paths are sanitized to prevent accidental persistence of device-local storage URIs.
class UserReportDocument {
  const UserReportDocument({
    required this.reportId,
    required this.reporterUid,
    this.tripId,
    required this.category,
    required this.coordinates,
    this.severity = HazardSeverity.moderate,
    required this.submittedAt,
    this.description,
    this.photoUrl,
    this.status = ReportStatus.submitted,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String reportId;
  final String reporterUid;
  final String? tripId;
  final ReportCategory category;
  final GeoCoordinates coordinates;
  final HazardSeverity severity;
  final DateTime submittedAt;
  final String? description;
  final String? photoUrl;
  final ReportStatus status;
  final int schemaVersion;

  Map<String, dynamic> toMap() => {
    'reportId': reportId,
    'reporterUid': reporterUid,
    if (tripId != null) 'tripId': tripId,
    'category': category.name,
    ...coordinates.toMap(),
    'severity': severity.name,
    'submittedAt': submittedAt.toUtc().toIso8601String(),
    if (description != null) 'description': description,
    if (photoUrl != null) 'photoUrl': photoUrl,
    'status': status.name,
    'schemaVersion': schemaVersion,
  };

  factory UserReportDocument.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    final rawId = (map['reportId'] ?? map['id'] ?? documentId) as String?;
    if (rawId == null || rawId.trim().isEmpty) {
      throw const FormatException(
        'UserReportDocument missing required "reportId".',
      );
    }

    final rawReporterUid = (map['reporterUid'] ?? map['userId']) as String?;
    if (rawReporterUid == null || rawReporterUid.trim().isEmpty) {
      throw const FormatException(
        'UserReportDocument missing required "reporterUid".',
      );
    }
    final reporterUid = rawReporterUid.trim();
    if (reporterUid.contains('@')) {
      throw FormatException(
        'Invalid reporterUid: "$reporterUid". Must use UID, never email.',
      );
    }

    final coordinates = GeoCoordinates.fromMap(map);
    final submittedAt = parseTimestamp(
      map['submittedAt'] ?? map['timestamp'],
      fieldName: 'submittedAt',
    );

    final rawCategory = map['category'] as String?;
    final category = rawCategory != null
        ? ReportCategory.values.firstWhere(
            (c) => c.name.toLowerCase() == rawCategory.toLowerCase(),
            orElse: () => ReportCategory.other,
          )
        : ReportCategory.other;

    final rawSeverity = map['severity'] as String?;
    final severity = rawSeverity != null
        ? HazardSeverity.values.firstWhere(
            (s) => s.name.toLowerCase() == rawSeverity.toLowerCase(),
            orElse: () => HazardSeverity.moderate,
          )
        : HazardSeverity.moderate;

    final rawStatus = map['status'] as String?;
    final status = rawStatus != null
        ? ReportStatus.values.firstWhere(
            (s) => s.name.toLowerCase() == rawStatus.toLowerCase(),
            orElse: () => ReportStatus.submitted,
          )
        : ReportStatus.submitted;

    final sanitizedPhotoUrl = sanitizePublicUrl(
      (map['photoUrl'] ?? map['photoPath']) as String?,
    );

    return UserReportDocument(
      reportId: rawId.trim(),
      reporterUid: reporterUid,
      tripId: map['tripId'] as String?,
      category: category,
      coordinates: coordinates,
      severity: severity,
      submittedAt: submittedAt,
      description: map['description'] as String?,
      photoUrl: sanitizedPhotoUrl,
      status: status,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  /// Converts to domain [UserReport].
  UserReport toDomain() => UserReport(
    id: reportId,
    userId: reporterUid,
    tripId: tripId ?? 'unassigned-trip',
    category: category,
    location: RoadLocation(
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    ),
    severity: severity,
    submittedAt: submittedAt,
    description: description,
    photoPath: photoUrl,
  );

  /// Creates from domain [UserReport].
  factory UserReportDocument.fromDomain(
    UserReport report, {
    String? photoUrl,
    ReportStatus status = ReportStatus.submitted,
  }) => UserReportDocument(
    reportId: report.id,
    reporterUid: report.userId,
    tripId: report.tripId,
    category: report.category,
    coordinates: GeoCoordinates.validated(
      latitude: report.location.latitude,
      longitude: report.location.longitude,
    ),
    severity: report.severity,
    submittedAt: report.submittedAt,
    description: report.description,
    photoUrl: sanitizePublicUrl(photoUrl ?? report.photoPath),
    status: status,
  );
}
