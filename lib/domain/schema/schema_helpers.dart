/// Common helpers, validation routines, and coordinate types for Firestore schema models.
class GeoCoordinates {
  const GeoCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  /// Creates a [GeoCoordinates] from a map, validating coordinate bounds.
  factory GeoCoordinates.fromMap(
    Map<String, dynamic> map, {
    String prefix = '',
  }) {
    final latKey = prefix.isEmpty ? 'latitude' : '${prefix}Latitude';
    final lngKey = prefix.isEmpty ? 'longitude' : '${prefix}Longitude';

    final rawLat = map[latKey] ?? map['lat'];
    final rawLng = map[lngKey] ?? map['lng'];

    if (rawLat == null || rawLng == null) {
      throw FormatException(
        'Missing required geographic coordinates ($latKey, $lngKey).',
      );
    }

    if (rawLat is! num || rawLng is! num) {
      throw FormatException(
        'Coordinates must be numeric. Got $latKey: $rawLat, $lngKey: $rawLng.',
      );
    }

    return GeoCoordinates.validated(
      latitude: rawLat.toDouble(),
      longitude: rawLng.toDouble(),
    );
  }

  /// Validates that latitude is within [-90.0, 90.0] and longitude is within [-180.0, 180.0].
  factory GeoCoordinates.validated({
    required double latitude,
    required double longitude,
  }) {
    if (latitude.isNaN ||
        latitude.isInfinite ||
        latitude < -90.0 ||
        latitude > 90.0) {
      throw FormatException(
        'Latitude must be between -90 and 90 degrees, got $latitude.',
      );
    }
    if (longitude.isNaN ||
        longitude.isInfinite ||
        longitude < -180.0 ||
        longitude > 180.0) {
      throw FormatException(
        'Longitude must be between -180 and 180 degrees, got $longitude.',
      );
    }
    return GeoCoordinates(latitude: latitude, longitude: longitude);
  }

  Map<String, dynamic> toMap({String prefix = ''}) {
    final latKey = prefix.isEmpty ? 'latitude' : '${prefix}Latitude';
    final lngKey = prefix.isEmpty ? 'longitude' : '${prefix}Longitude';
    return {latKey: latitude, lngKey: longitude};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoCoordinates &&
          runtimeType == other.runtimeType &&
          (latitude - other.latitude).abs() < 1e-9 &&
          (longitude - other.longitude).abs() < 1e-9;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoCoordinates($latitude, $longitude)';
}

/// Parses a required timestamp value from various formats into a UTC [DateTime].
DateTime parseTimestamp(dynamic value, {String fieldName = 'timestamp'}) {
  if (value == null) {
    throw FormatException('Required timestamp field "$fieldName" is missing.');
  }
  if (value is DateTime) return value.toUtc();
  try {
    final dynamic dyn = value;
    if (dyn.toDate is Function) {
      return (dyn.toDate() as DateTime).toUtc();
    }
  } catch (_) {}
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException(
        'Malformed ISO timestamp for "$fieldName": "$value".',
      );
    }
    return parsed.toUtc();
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  if (value is Map) {
    if (value.containsKey('_seconds')) {
      final seconds = (value['_seconds'] as num).toInt();
      final nanoseconds = (value['_nanoseconds'] as num?)?.toInt() ?? 0;
      return DateTime.fromMicrosecondsSinceEpoch(
        seconds * 1000000 + (nanoseconds ~/ 1000),
        isUtc: true,
      );
    }
  }
  throw FormatException(
    'Unsupported timestamp format for "$fieldName": $value (${value.runtimeType}).',
  );
}

/// Parses an optional timestamp value. Returns `null` if the value is missing or null.
DateTime? parseNullableTimestamp(
  dynamic value, {
  String fieldName = 'timestamp',
}) {
  if (value == null) return null;
  return parseTimestamp(value, fieldName: fieldName);
}

/// Sanitizes a photo URL to prevent local device file paths from accidentally
/// being serialized as public web URLs.
String? sanitizePublicUrl(String? input) {
  if (input == null) return null;
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  // Local file patterns: file://, /data/, /var/, C:\, D:\, etc.
  final isLocalPath =
      trimmed.startsWith('file:') ||
      trimmed.startsWith('/') ||
      trimmed.startsWith('\\') ||
      RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(trimmed);

  if (isLocalPath) {
    // Reject local paths from public URL persistence.
    return null;
  }

  // Accept valid remote URLs (https://, http://, gs://)
  if (trimmed.startsWith('https://') ||
      trimmed.startsWith('http://') ||
      trimmed.startsWith('gs://')) {
    return trimmed;
  }

  return null;
}
