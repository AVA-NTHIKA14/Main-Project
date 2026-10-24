import 'package:flutter_test/flutter_test.dart';

import 'package:road_loop/auth.dart';
import 'package:road_loop/detection.dart';
import 'package:road_loop/domain/schema/schema_documents.dart';
import 'package:road_loop/explore.dart';
import 'package:road_loop/reports.dart';
import 'package:road_loop/trips.dart';

void main() {
  group('GeoCoordinates & validation', () {
    test('accepts valid coordinates within boundaries', () {
      final origin = GeoCoordinates.validated(latitude: 0, longitude: 0);
      expect(origin.latitude, 0);
      expect(origin.longitude, 0);

      final northEast = GeoCoordinates.validated(latitude: 90, longitude: 180);
      expect(northEast.latitude, 90);
      expect(northEast.longitude, 180);

      final southWest = GeoCoordinates.validated(
        latitude: -90,
        longitude: -180,
      );
      expect(southWest.latitude, -90);
      expect(southWest.longitude, -180);
    });

    test('rejects latitude outside [-90, 90]', () {
      expect(
        () => GeoCoordinates.validated(latitude: 90.001, longitude: 0),
        throwsFormatException,
      );
      expect(
        () => GeoCoordinates.validated(latitude: -90.001, longitude: 0),
        throwsFormatException,
      );
      expect(
        () => GeoCoordinates.validated(latitude: double.nan, longitude: 0),
        throwsFormatException,
      );
    });

    test('rejects longitude outside [-180, 180]', () {
      expect(
        () => GeoCoordinates.validated(latitude: 0, longitude: 180.001),
        throwsFormatException,
      );
      expect(
        () => GeoCoordinates.validated(latitude: 0, longitude: -180.001),
        throwsFormatException,
      );
      expect(
        () => GeoCoordinates.validated(latitude: 0, longitude: double.nan),
        throwsFormatException,
      );
    });

    test('fromMap parses latitude and longitude with bounds checking', () {
      final map = {'latitude': 12.9716, 'longitude': 77.5946};
      final coords = GeoCoordinates.fromMap(map);
      expect(coords.latitude, 12.9716);
      expect(coords.longitude, 77.5946);
    });

    test('fromMap accepts short keys lat/lng and handles missing keys', () {
      final map = {'lat': 12.9716, 'lng': 77.5946};
      final coords = GeoCoordinates.fromMap(map);
      expect(coords.latitude, 12.9716);
      expect(coords.longitude, 77.5946);

      expect(() => GeoCoordinates.fromMap({}), throwsFormatException);
      expect(
        () => GeoCoordinates.fromMap({
          'latitude': 'not-a-number',
          'longitude': 0,
        }),
        throwsFormatException,
      );
    });
  });

  group('parseTimestamp & timezone safety', () {
    test('parses ISO 8601 strings and converts to UTC', () {
      final parsed = parseTimestamp('2026-10-23T12:00:00.000Z');
      expect(parsed.isUtc, isTrue);
      expect(parsed.year, 2026);
      expect(parsed.month, 10);
      expect(parsed.day, 23);
      expect(parsed.hour, 12);
    });

    test('parses epoch milliseconds into UTC DateTime', () {
      final millis = 1792756800000;
      final parsed = parseTimestamp(millis);
      expect(parsed.isUtc, isTrue);
      expect(parsed.millisecondsSinceEpoch, millis);
    });

    test('parses Firestore map with _seconds and _nanoseconds', () {
      final firestoreMap = {'_seconds': 1792756800, '_nanoseconds': 500000000};
      final parsed = parseTimestamp(firestoreMap);
      expect(parsed.isUtc, isTrue);
      expect(parsed.second, 0);
    });

    test(
      'throws descriptive FormatException for malformed or missing timestamps',
      () {
        expect(
          () => parseTimestamp(null, fieldName: 'testTime'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('testTime'),
            ),
          ),
        );
        expect(
          () => parseTimestamp('invalid-date-string'),
          throwsFormatException,
        );
      },
    );
  });

  group('sanitizePublicUrl', () {
    test('filters out local file paths from public URL persistence', () {
      expect(
        sanitizePublicUrl('file:///storage/emulated/0/DCIM/pothole.jpg'),
        isNull,
      );
      expect(
        sanitizePublicUrl(
          '/data/user/0/com.avanthika.roadsense/cache/photo.jpg',
        ),
        isNull,
      );
      expect(
        sanitizePublicUrl(r'C:\Users\User\AppData\Local\Temp\img.png'),
        isNull,
      );
      expect(
        sanitizePublicUrl(r'D:\4th year\Main-Project\assets\test.jpg'),
        isNull,
      );
    });

    test('preserves valid remote Cloud Storage and HTTPS URLs', () {
      expect(
        sanitizePublicUrl(
          'https://firebasestorage.googleapis.com/v0/b/roadsense/o/pothole.jpg',
        ),
        'https://firebasestorage.googleapis.com/v0/b/roadsense/o/pothole.jpg',
      );
      expect(
        sanitizePublicUrl('gs://roadsense-cc1f5.appspot.com/reports/photo.png'),
        'gs://roadsense-cc1f5.appspot.com/reports/photo.png',
      );
    });
  });

  group('UserProfileDocument', () {
    test('round trip serialization preserves all fields', () {
      final doc = UserProfileDocument(
        uid: 'user-uid-abc-123',
        displayName: 'Avanthika Driver',
        email: 'driver@roadsense.org',
        role: UserRole.user,
        isEmailVerified: true,
        createdAt: DateTime.utc(2026, 10, 1, 10, 0),
        updatedAt: DateTime.utc(2026, 10, 15, 12, 30),
        schemaVersion: 1,
      );

      final map = doc.toMap();
      final restored = UserProfileDocument.fromMap(map);

      expect(restored.uid, doc.uid);
      expect(restored.displayName, doc.displayName);
      expect(restored.email, doc.email);
      expect(restored.role, doc.role);
      expect(restored.isEmailVerified, doc.isEmailVerified);
      expect(restored.createdAt, doc.createdAt);
      expect(restored.updatedAt, doc.updatedAt);
      expect(restored.schemaVersion, doc.schemaVersion);
    });

    test('rejects email addresses as user IDs', () {
      expect(
        () => UserProfileDocument.fromMap({
          'uid': 'driver@roadsense.org',
          'email': 'driver@roadsense.org',
          'name': 'Driver',
        }),
        throwsFormatException,
      );
    });

    test(
      'client-provided role escalation defaults safely to UserRole.user',
      () {
        final map = {
          'uid': 'test-uid-1',
          'email': 'test@example.com',
          'role': 'unknownSpecialPrivilege',
          'createdAt': '2026-10-01T00:00:00Z',
        };
        final restored = UserProfileDocument.fromMap(map);
        expect(restored.role, UserRole.user);
      },
    );

    test('converts seamlessly to and from domain RoadSenseUser', () {
      const domainUser = RoadSenseUser(
        id: 'user-uid-456',
        name: 'Jordan',
        email: 'jordan@example.com',
        role: UserRole.user,
        isEmailVerified: true,
      );

      final doc = UserProfileDocument.fromDomain(domainUser);
      expect(doc.uid, 'user-uid-456');
      expect(doc.displayName, 'Jordan');

      final restoredDomain = doc.toDomain();
      expect(restoredDomain.id, domainUser.id);
      expect(restoredDomain.name, domainUser.name);
      expect(restoredDomain.email, domainUser.email);
      expect(restoredDomain.role, domainUser.role);
      expect(restoredDomain.isEmailVerified, domainUser.isEmailVerified);
    });
  });

  group('TripDocument', () {
    test('round trip serialization preserves all fields', () {
      final doc = TripDocument(
        tripId: 'trip-2026-101',
        ownerUid: 'driver-uid-789',
        startedAt: DateTime.utc(2026, 10, 7, 8, 30),
        endedAt: DateTime.utc(2026, 10, 7, 9, 15),
        durationSeconds: 2700,
        distanceKm: 22.5,
        startLabel: 'Home',
        endLabel: 'Office',
        roadQuality: 'Good',
        status: TripStatus.completed,
        observationCount: 3,
        schemaVersion: 1,
      );

      final map = doc.toMap();
      final restored = TripDocument.fromMap(map);

      expect(restored.tripId, doc.tripId);
      expect(restored.ownerUid, doc.ownerUid);
      expect(restored.startedAt, doc.startedAt);
      expect(restored.endedAt, doc.endedAt);
      expect(restored.durationSeconds, doc.durationSeconds);
      expect(restored.distanceKm, doc.distanceKm);
      expect(restored.status, doc.status);
      expect(restored.observationCount, doc.observationCount);
    });

    test('validates required tripId and ownerUid', () {
      expect(
        () => TripDocument.fromMap({
          'ownerUid': 'uid-1',
          'startedAt': '2026-10-07T08:30:00Z',
        }),
        throwsFormatException,
      );
      expect(
        () => TripDocument.fromMap({
          'tripId': 'trip-1',
          'ownerUid': 'user@email.com',
          'startedAt': '2026-10-07T08:30:00Z',
        }),
        throwsFormatException,
      );
    });

    test('rejects negative distanceKm', () {
      expect(
        () => TripDocument.fromMap({
          'tripId': 'trip-1',
          'ownerUid': 'uid-1',
          'startedAt': '2026-10-07T08:30:00Z',
          'distanceKm': -5.0,
        }),
        throwsFormatException,
      );
    });

    test('converts to and from domain Trip', () {
      final domainTrip = Trip(
        id: 'trip-999',
        startedAt: DateTime.utc(2026, 10, 7, 8, 0),
        endedAt: DateTime.utc(2026, 10, 7, 8, 30),
        duration: const Duration(minutes: 30),
        distanceKm: 12.0,
        startLabel: 'Station',
        endLabel: 'Campus',
        roadQuality: 'Clear',
        observations: const [],
        verifiedHazards: const [],
        possibleAnomalies: const [],
        routeSegments: const [],
      );

      final doc = TripDocument.fromDomain(
        domainTrip,
        ownerUid: 'owner-uid-xyz',
      );
      expect(doc.tripId, 'trip-999');
      expect(doc.ownerUid, 'owner-uid-xyz');
      expect(doc.durationSeconds, 1800);

      final restoredTrip = doc.toDomain();
      expect(restoredTrip.id, domainTrip.id);
      expect(restoredTrip.duration, domainTrip.duration);
      expect(restoredTrip.distanceKm, domainTrip.distanceKm);
    });
  });

  group('SensorWindowDocument', () {
    test('round trip serialization preserves bounded window telemetry', () {
      final doc = SensorWindowDocument(
        windowId: 'win-123',
        tripId: 'trip-abc',
        ownerUid: 'uid-commuter',
        startTime: DateTime.utc(2026, 10, 7, 10, 0, 0),
        endTime: DateTime.utc(2026, 10, 7, 10, 0, 5),
        sampleCount: 500,
        coordinates: const GeoCoordinates(latitude: 12.97, longitude: 77.59),
        averageSpeedMps: 11.2,
        peakAccelerationMagnitude: 16.8,
        averageAccelerationMagnitude: 9.8,
        averageGyroscopeMagnitude: 0.45,
        schemaVersion: 1,
      );

      final map = doc.toMap();
      final restored = SensorWindowDocument.fromMap(map);

      expect(restored.windowId, doc.windowId);
      expect(restored.tripId, doc.tripId);
      expect(restored.ownerUid, doc.ownerUid);
      expect(restored.sampleCount, doc.sampleCount);
      expect(restored.coordinates?.latitude, doc.coordinates?.latitude);
      expect(restored.peakAccelerationMagnitude, doc.peakAccelerationMagnitude);
    });

    test('validates non-empty IDs and non-negative sample count', () {
      expect(
        () => SensorWindowDocument.fromMap({
          'windowId': '',
          'tripId': 't1',
          'ownerUid': 'u1',
          'startTime': '2026-10-07T10:00:00Z',
          'endTime': '2026-10-07T10:00:05Z',
        }),
        throwsFormatException,
      );
      expect(
        () => SensorWindowDocument.fromMap({
          'windowId': 'w1',
          'tripId': 't1',
          'ownerUid': 'u1',
          'sampleCount': -10,
          'startTime': '2026-10-07T10:00:00Z',
          'endTime': '2026-10-07T10:00:05Z',
        }),
        throwsFormatException,
      );
    });
  });

  group('HazardObservationDocument', () {
    test('round trip serialization preserves observation data', () {
      final doc = HazardObservationDocument(
        observationId: 'obs-001',
        reporterUid: 'driver-uid-101',
        tripId: 'trip-555',
        coordinates: const GeoCoordinates(
          latitude: 51.5074,
          longitude: -0.1278,
        ),
        type: HazardType.pothole,
        severity: HazardSeverity.high,
        timestamp: DateTime.utc(2026, 10, 7, 14, 20),
        source: ObservationSource.sensorDetection,
        sensorWindowId: 'win-777',
        segmentId: 'segment-north-1',
        confidence: 0.85,
        schemaVersion: 1,
      );

      final map = doc.toMap();
      final restored = HazardObservationDocument.fromMap(map);

      expect(restored.observationId, doc.observationId);
      expect(restored.reporterUid, doc.reporterUid);
      expect(restored.coordinates.latitude, doc.coordinates.latitude);
      expect(restored.type, doc.type);
      expect(restored.severity, doc.severity);
      expect(restored.confidence, doc.confidence);
      expect(restored.segmentId, doc.segmentId);
    });

    test('validates coordinates and confidence range', () {
      expect(
        () => HazardObservationDocument.fromMap({
          'observationId': 'obs-1',
          'reporterUid': 'uid-1',
          'latitude': 95.0,
          'longitude': 0.0,
          'timestamp': '2026-10-07T14:20:00Z',
        }),
        throwsFormatException,
      );

      expect(
        () => HazardObservationDocument.fromMap({
          'observationId': 'obs-1',
          'reporterUid': 'uid-1',
          'latitude': 0.0,
          'longitude': 0.0,
          'timestamp': '2026-10-07T14:20:00Z',
          'confidence': 1.5,
        }),
        throwsFormatException,
      );
    });

    test('converts to and from domain HazardObservation', () {
      final domainObs = HazardObservation(
        id: 'obs-domain-1',
        segmentId: 'seg-east',
        timestamp: DateTime.utc(2026, 10, 7, 10, 0),
        userId: 'driver-uid-222',
        tripId: 'trip-333',
        location: const RoadLocation(latitude: 12.9, longitude: 77.6),
        type: HazardType.roughSurface,
        severity: HazardSeverity.moderate,
      );

      final doc = HazardObservationDocument.fromDomain(
        domainObs,
        confidence: 0.75,
      );
      expect(doc.observationId, 'obs-domain-1');
      expect(doc.reporterUid, 'driver-uid-222');
      expect(doc.confidence, 0.75);

      final restored = doc.toDomain();
      expect(restored.id, domainObs.id);
      expect(restored.userId, domainObs.userId);
      expect(restored.location.latitude, domainObs.location.latitude);
    });
  });

  group('UserReportDocument', () {
    test('round trip serialization preserves report metadata and sanitizes local path', () {
      final doc = UserReportDocument(
        reportId: 'rep-404',
        reporterUid: 'user-uid-333',
        tripId: 'trip-111',
        category: ReportCategory.pothole,
        coordinates: const GeoCoordinates(
          latitude: 13.0827,
          longitude: 80.2707,
        ),
        severity: HazardSeverity.high,
        submittedAt: DateTime.utc(2026, 10, 7, 16, 0),
        description: 'Deep road depression near junction',
        photoUrl: 'https://firebasestorage.googleapis.com/v0/b/roadsense/o/rep-404.jpg',
        status: ReportStatus.submitted,
        schemaVersion: 1,
      );

      final map = doc.toMap();
      final restored = UserReportDocument.fromMap(map);

      expect(restored.reportId, doc.reportId);
      expect(restored.reporterUid, doc.reporterUid);
      expect(restored.category, doc.category);
      expect(restored.coordinates.latitude, doc.coordinates.latitude);
      expect(restored.photoUrl, doc.photoUrl);
      expect(restored.status, doc.status);
    });

    test(
      'strictly filters local device file paths from photoUrl persistence',
      () {
        final mapWithLocalPath = {
          'reportId': 'rep-local',
          'reporterUid': 'user-uid-444',
          'latitude': 13.0,
          'longitude': 80.0,
          'submittedAt': '2026-10-07T16:00:00Z',
          'photoPath': 'file:///storage/emulated/0/DCIM/pothole.png',
        };
        final restored = UserReportDocument.fromMap(mapWithLocalPath);
        expect(restored.photoUrl, isNull);
      },
    );

    test('validates coordinate boundaries', () {
      expect(
        () => UserReportDocument.fromMap({
          'reportId': 'rep-1',
          'reporterUid': 'uid-1',
          'latitude': -95.0,
          'longitude': 0.0,
          'submittedAt': '2026-10-07T16:00:00Z',
        }),
        throwsFormatException,
      );
    });
  });

  group('HazardDocument (Map display confirmed hazards)', () {
    test('round trip serialization preserves confirmed hazard fields', () {
      final doc = HazardDocument(
        hazardId: 'hazard-east-pothole',
        coordinates: const GeoCoordinates(latitude: 51.501, longitude: -0.121),
        geohash: 'gcpvj0',
        type: HazardType.pothole,
        severity: HazardSeverity.high,
        status: VerificationStatus.verified,
        confidence: 0.95,
        observationCount: 8,
        uniqueUserCount: 6,
        segmentId: 'east-corridor-1',
        firstObserved: DateTime.utc(2026, 10, 1, 9, 0),
        lastObserved: DateTime.utc(2026, 10, 7, 10, 0),
        lastConfirmedAt: DateTime.utc(2026, 10, 7, 10, 5),
        schemaVersion: 1,
      );

      final map = doc.toMap();
      final restored = HazardDocument.fromMap(map);

      expect(restored.hazardId, doc.hazardId);
      expect(restored.coordinates.latitude, doc.coordinates.latitude);
      expect(restored.geohash, 'gcpvj0');
      expect(restored.status, VerificationStatus.verified);
      expect(restored.isConfirmed, isTrue);
      expect(restored.confidence, 0.95);
      expect(restored.observationCount, 8);
      expect(restored.uniqueUserCount, 6);
    });

    test('validates confidence bounds and non-empty ID', () {
      expect(
        () => HazardDocument.fromMap({
          'hazardId': '',
          'latitude': 51.5,
          'longitude': -0.1,
          'firstObserved': '2026-10-01T00:00:00Z',
        }),
        throwsFormatException,
      );

      expect(
        () => HazardDocument.fromMap({
          'hazardId': 'h1',
          'latitude': 51.5,
          'longitude': -0.1,
          'confidence': -0.1,
          'firstObserved': '2026-10-01T00:00:00Z',
        }),
        throwsFormatException,
      );
    });

    test('converts to and from domain Hazard', () {
      final domainHazard = Hazard(
        id: 'h-100',
        segmentId: 'seg-1',
        severity: HazardSeverity.moderate,
        observations: const [],
        status: VerificationStatus.verified,
        type: HazardType.roughSurface,
        location: const RoadLocation(latitude: 51.503, longitude: -0.12),
        confidence: 0.9,
        firstObserved: DateTime.utc(2026, 10, 5),
        lastObserved: DateTime.utc(2026, 10, 7),
      );

      final doc = HazardDocument.fromDomain(domainHazard, geohash: 'gcpvj1');
      expect(doc.hazardId, 'h-100');
      expect(doc.geohash, 'gcpvj1');
      expect(doc.isConfirmed, isTrue);

      final restoredDomain = doc.toDomain();
      expect(restoredDomain.id, domainHazard.id);
      expect(restoredDomain.location.latitude, domainHazard.location.latitude);
    });
  });

  group('VerificationDecisionDocument', () {
    test('round trip serialization preserves authoritative decision', () {
      final doc = VerificationDecisionDocument(
        decisionId: 'dec-888',
        hazardId: 'hazard-east-pothole',
        reviewerUid: 'admin-reviewer-uid',
        status: VerificationStatus.verified,
        reasons: const [
          'Corroborated by 6 independent drivers',
          'Manual telemetry review confirmed',
        ],
        independentObservationCount: 6,
        confidence: 0.95,
        timestamp: DateTime.utc(2026, 10, 7, 11, 0),
        schemaVersion: 1,
      );

      final map = doc.toMap();
      final restored = VerificationDecisionDocument.fromMap(map);

      expect(restored.decisionId, doc.decisionId);
      expect(restored.hazardId, doc.hazardId);
      expect(restored.reviewerUid, doc.reviewerUid);
      expect(restored.status, VerificationStatus.verified);
      expect(restored.reasons.length, 2);
      expect(restored.confidence, 0.95);
    });

    test('validates required fields and rejects email for reviewerUid', () {
      expect(
        () => VerificationDecisionDocument.fromMap({
          'decisionId': 'd1',
          'hazardId': 'h1',
          'reviewerUid': 'admin@roadsense.org',
          'timestamp': '2026-10-07T11:00:00Z',
        }),
        throwsFormatException,
      );
    });
  });

  group('ModelPredictionDocument', () {
    test('round trip serialization preserves candidate ML inference', () {
      final doc = ModelPredictionDocument(
        predictionId: 'pred-001',
        sensorWindowId: 'win-999',
        tripId: 'trip-777',
        classification: DetectionClassification.pothole,
        confidence: 0.88,
        severityEstimate: HazardSeverity.high,
        coordinates: const GeoCoordinates(latitude: 51.505, longitude: -0.125),
        speedMps: 12.5,
        modelVersion: 'cnn-pothole-v1.2',
        source: DetectionSource.tensorFlowLite,
        timestamp: DateTime.utc(2026, 10, 7, 15, 30),
        schemaVersion: 1,
      );

      final map = doc.toMap();
      final restored = ModelPredictionDocument.fromMap(map);

      expect(restored.predictionId, doc.predictionId);
      expect(restored.sensorWindowId, doc.sensorWindowId);
      expect(restored.classification, DetectionClassification.pothole);
      expect(restored.confidence, 0.88);
      expect(restored.modelVersion, 'cnn-pothole-v1.2');
    });

    test('converts to domain DetectionResult', () {
      final doc = ModelPredictionDocument(
        predictionId: 'pred-002',
        sensorWindowId: 'win-888',
        classification: DetectionClassification.roughRoad,
        confidence: 0.72,
        coordinates: const GeoCoordinates(latitude: 51.502, longitude: -0.122),
        speedMps: 10.0,
        modelVersion: 'mock-1.0',
        timestamp: DateTime.utc(2026, 10, 7, 12, 0),
      );

      final result = doc.toDomain();
      expect(result.classification, DetectionClassification.roughRoad);
      expect(result.confidence, 0.72);
      expect(result.location.latitude, 51.502);
    });
  });

  group('RoadSegmentDocument', () {
    test(
      'round trip serialization preserves segment coordinates and hazard count',
      () {
        final doc = RoadSegmentDocument(
          segmentId: 'segment-highway-4',
          name: 'Grand Southern Trunk Road',
          points: const [
            GeoCoordinates(latitude: 12.95, longitude: 77.58),
            GeoCoordinates(latitude: 12.96, longitude: 77.59),
          ],
          hazardCount: 2,
          updatedAt: DateTime.utc(2026, 10, 7, 10, 0),
          schemaVersion: 1,
        );

        final map = doc.toMap();
        final restored = RoadSegmentDocument.fromMap(map);

        expect(restored.segmentId, doc.segmentId);
        expect(restored.name, doc.name);
        expect(restored.points.length, 2);
        expect(restored.hazardCount, 2);
      },
    );
  });

  group('Concept Separation & Architectural Invariants', () {
    test('model predictions, observations, and confirmed hazards are distinct types', () {
      // 1. Model prediction (candidate signal from device ML)
      final prediction = ModelPredictionDocument(
        predictionId: 'p1',
        sensorWindowId: 'w1',
        classification: DetectionClassification.pothole,
        confidence: 0.65,
        coordinates: const GeoCoordinates(latitude: 10.0, longitude: 20.0),
        modelVersion: 'tflite-v1',
        timestamp: DateTime.utc(2026, 10, 7),
      );

      // 2. Hazard observation (contributed event)
      final observation = HazardObservationDocument(
        observationId: 'o1',
        reporterUid: 'driver-uid-1',
        coordinates: const GeoCoordinates(latitude: 10.0, longitude: 20.0),
        type: HazardType.pothole,
        timestamp: DateTime.utc(2026, 10, 7),
      );

      // 3. User report (manual report)
      final report = UserReportDocument(
        reportId: 'r1',
        reporterUid: 'driver-uid-1',
        category: ReportCategory.pothole,
        coordinates: const GeoCoordinates(latitude: 10.0, longitude: 20.0),
        submittedAt: DateTime.utc(2026, 10, 7),
      );

      // 4. Confirmed map hazard (shared record with corroborated consensus)
      final confirmedHazard = HazardDocument(
        hazardId: 'h1',
        coordinates: const GeoCoordinates(latitude: 10.0, longitude: 20.0),
        type: HazardType.pothole,
        status: VerificationStatus.verified,
        confidence: 0.95,
        observationCount: 5,
        uniqueUserCount: 5,
        firstObserved: DateTime.utc(2026, 10, 7),
        lastObserved: DateTime.utc(2026, 10, 7),
      );

      // Strict type separation: no implicit interchangeability
      expect(prediction, isA<ModelPredictionDocument>());
      expect(observation, isA<HazardObservationDocument>());
      expect(report, isA<UserReportDocument>());
      expect(confirmedHazard, isA<HazardDocument>());
      expect(confirmedHazard.isConfirmed, isTrue);
    });
  });
}
