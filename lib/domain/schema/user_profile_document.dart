import '../../auth.dart';
import 'schema_helpers.dart';

/// Represents a user profile document stored at `users/{uid}` in Cloud Firestore.
///
/// Strictly uses the Firebase Authentication UID as the document ID and identity.
/// Client-editable profile fields cannot grant administrative or researcher privileges.
/// Passwords or authentication secrets are never stored here.
class UserProfileDocument {
  const UserProfileDocument({
    required this.uid,
    required this.displayName,
    required this.email,
    this.role = UserRole.user,
    this.isEmailVerified = false,
    required this.createdAt,
    this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String uid;
  final String displayName;
  final String email;
  final UserRole role;
  final bool isEmailVerified;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int schemaVersion;

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'role': role.name,
    'isEmailVerified': isEmailVerified,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
  };

  factory UserProfileDocument.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    final rawUid = (map['uid'] ?? map['id'] ?? documentId) as String?;
    if (rawUid == null || rawUid.trim().isEmpty) {
      throw const FormatException(
        'UserProfileDocument missing required "uid".',
      );
    }
    final uid = rawUid.trim();

    // Guard against accidentally storing email addresses as user IDs
    if (uid.contains('@')) {
      throw FormatException(
        'Invalid UID: "$uid". Firebase Authentication UID must be used as user ID, never an email address.',
      );
    }

    final email = (map['email'] as String?)?.trim() ?? '';
    final displayName =
        (map['displayName'] ?? map['name'] as String?)?.trim() ??
        (email.contains('@') ? email.split('@').first : 'RoadSense driver');

    // Parse role safely, defaulting to standard user to prevent unauthorized privilege escalation
    final rawRole = map['role'] as String?;
    final role = rawRole != null
        ? UserRole.values.firstWhere(
            (r) => r.name.toLowerCase() == rawRole.toLowerCase(),
            orElse: () => UserRole.user,
          )
        : UserRole.user;

    final isEmailVerified = map['isEmailVerified'] as bool? ?? false;
    final createdAt = parseTimestamp(
      map['createdAt'] ?? map['timestamp'] ?? DateTime.now(),
      fieldName: 'createdAt',
    );
    final updatedAt = parseNullableTimestamp(
      map['updatedAt'],
      fieldName: 'updatedAt',
    );
    final schemaVersion = (map['schemaVersion'] as num?)?.toInt() ?? 1;

    return UserProfileDocument(
      uid: uid,
      displayName: displayName,
      email: email,
      role: role,
      isEmailVerified: isEmailVerified,
      createdAt: createdAt,
      updatedAt: updatedAt,
      schemaVersion: schemaVersion,
    );
  }

  /// Converts this document to the domain [RoadSenseUser].
  RoadSenseUser toDomain() => RoadSenseUser(
    id: uid,
    name: displayName,
    email: email,
    role: role,
    isEmailVerified: isEmailVerified,
  );

  /// Creates a [UserProfileDocument] from the domain [RoadSenseUser].
  factory UserProfileDocument.fromDomain(
    RoadSenseUser user, {
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserProfileDocument(
    uid: user.id,
    displayName: user.name,
    email: user.email,
    role: user.role,
    isEmailVerified: user.isEmailVerified,
    createdAt: createdAt ?? DateTime.now().toUtc(),
    updatedAt: updatedAt,
  );
}
