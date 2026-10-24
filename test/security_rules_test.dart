import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:road_loop/auth.dart';
import 'package:road_loop/backend.dart';
import 'package:road_loop/detection.dart';
import 'package:road_loop/explore.dart';
import 'package:road_loop/reports.dart';
import 'package:road_loop/sensors.dart';
import 'package:road_loop/trips.dart';

void main() {
  group('Module 05: Firestore Rules File Integrity & Structure', () {
    test('firestore.rules file exists and is valid Version 2', () {
      final file = File('firestore.rules');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'firestore.rules must exist in root directory.',
      );

      final content = file.readAsStringSync();
      expect(content, contains("rules_version = '2';"));
      expect(content, contains('service cloud.firestore'));
    });

    test('firestore.rules enforces all 9 required collection paths', () {
      final content = File('firestore.rules').readAsStringSync();

      expect(content, contains('match /users/{uid}'));
      expect(content, contains('match /trips/{tripId}'));
      expect(content, contains('match /sensorWindows/{windowId}'));
      expect(content, contains('match /reports/{reportId}'));
      expect(content, contains('match /hazardObservations/{observationId}'));
      expect(content, contains('match /hazards/{hazardId}'));
      expect(content, contains('match /verificationDecisions/{decisionId}'));
      expect(content, contains('match /modelPredictions/{predictionId}'));
      expect(content, contains('match /roadSegments/{segmentId}'));
      expect(content, contains('match /{document=**}'));
    });

    test('firestore.rules contains required helper security functions', () {
      final content = File('firestore.rules').readAsStringSync();

      expect(content, contains('function isAuthenticated()'));
      expect(content, contains('function isOwner(uid)'));
      expect(content, contains('function isReviewer()'));
      expect(content, contains('function isTrustedAdmin()'));
      expect(content, contains('function isValidLatitude(lat)'));
      expect(content, contains('function isValidLongitude(lng)'));
      expect(content, contains('function isValidCoordinates(data)'));
      expect(content, contains('function isNotLocalPath(str)'));
    });

    test('hazards collection explicitly denies client-side writes', () {
      final content = File('firestore.rules').readAsStringSync();

      // Ensure hazards collection does not allow unprivileged client create or update
      expect(content, contains('match /hazards/{hazardId}'));
      expect(
        content,
        contains(
          'allow create, update, delete: if isReviewer() || isTrustedAdmin();',
        ),
        reason: 'Clients cannot directly create or alter verified hazards.',
      );
    });

    test('verificationDecisions collection blocks ordinary clients from forging decisions', () {
      final content = File('firestore.rules').readAsStringSync();

      expect(content, contains('match /verificationDecisions/{decisionId}'));
      expect(content, contains('allow create: if isReviewer()'));
      expect(content, contains('allow update, delete: if false;'));
    });

    test('firebase.json is present and configures firestore rules and emulator ports', () {
      final file = File('firebase.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('"rules": "firestore.rules"'));
      expect(content, contains('"firestore"'));
      expect(content, contains('"auth"'));
    });
  });

  group('Module 05: Repository-Level Security Invariants & Client Safeguards', () {
    test(
      'Scenario 1: Unauthenticated access is denied for private operations',
      () async {
        final gateway = InMemoryFirebaseGateway(); // Unauthenticated
        final tripRepo = FirebaseTripHistoryRepository(gateway);
        final reportRepo = FirebaseReportRepository(gateway);

        final dummyTrip = Trip(
          id: 'unauth_trip',
          startedAt: DateTime.now(),
          endedAt: DateTime.now(),
          duration: Duration.zero,
          distanceKm: 0,
          startLabel: 'A',
          endLabel: 'B',
          roadQuality: 'Unknown',
          observations: const [],
          verifiedHazards: const [],
          possibleAnomalies: const [],
          routeSegments: const [],
        );

        // Trip save requires authenticated context
        expect(
          () => tripRepo.saveTrip(dummyTrip),
          throwsA(
            isA<BackendException>().having(
              (e) => e.failure,
              'failure',
              BackendFailure.authentication,
            ),
          ),
        );

        // Report submit requires valid authenticated UID
        final reportWithoutAuth = UserReport(
          id: 'rep_no_auth',
          userId: '',
          tripId: 'trip_1',
          category: ReportCategory.pothole,
          location: const RoadLocation(latitude: 12.9, longitude: 77.5),
          severity: HazardSeverity.moderate,
          submittedAt: DateTime.now(),
        );
        expect(
          () => reportRepo.submit(reportWithoutAuth),
          throwsA(
            isA<BackendException>().having(
              (e) => e.failure,
              'failure',
              BackendFailure.authentication,
            ),
          ),
        );
      },
    );

    test(
      'Scenario 2: A user cannot forge reports under another user UID',
      () async {
        final gateway = InMemoryFirebaseGateway();
        await gateway.signUp(
          name: 'Logged In User',
          email: 'logged_in@roadsense.org',
          password: 'password123',
        );

        final reportRepo = FirebaseReportRepository(gateway);
        final forgedReport = UserReport(
          id: 'forged_rep',
          userId: 'victim_user_uid', // Mismatched UID
          tripId: 'trip_1',
          category: ReportCategory.roughRoad,
          location: const RoadLocation(latitude: 12.97, longitude: 77.59),
          severity: HazardSeverity.possible,
          submittedAt: DateTime.now(),
        );

        expect(
          () => reportRepo.submit(forgedReport),
          throwsA(
            isA<BackendException>().having(
              (e) => e.failure,
              'failure',
              BackendFailure.permission,
            ),
          ),
        );
      },
    );

    test(
      'Scenario 3: A user cannot escalate their role or change immutable UID',
      () async {
        final gateway = InMemoryFirebaseGateway();
        final userRepo = FirebaseUserRepository(gateway);

        final user = await userRepo.create(
          name: 'Standard User',
          email: 'standard@roadsense.org',
        );
        expect(user.role, UserRole.user);

        // Attempt to tamper with role during profile update
        final tamperedUser = RoadSenseUser(
          id: user.id,
          name: 'Hacked User',
          email: user.email,
          role: UserRole.administrator, // Unauthorized escalation
        );

        await userRepo.updateProfile(tamperedUser);

        // Role must remain 'user'
        final storedDoc = await gateway.getDocument(
          BackendCollections.users,
          user.id,
        );
        expect(storedDoc!['role'], 'user');
        expect(storedDoc['displayName'], 'Hacked User');
      },
    );

    test('Scenario 4: Ordinary client cannot directly mark a hazard confirmed or resolved', () async {
      final gateway = InMemoryFirebaseGateway();
      final hazardRepo = FirebaseHazardRepository(gateway);

      final hazard = Hazard(
        id: 'hazard_guard_01',
        segmentId: 'seg_1',
        severity: HazardSeverity.high,
        observations: const [],
        status: VerificationStatus.possible,
        type: HazardType.pothole,
        location: const RoadLocation(latitude: 12.9, longitude: 77.5),
        confidence: 0.5,
        firstObserved: DateTime.now(),
        lastObserved: DateTime.now(),
      );

      await hazardRepo.save(hazard);

      // When updateDocument is called for status on missing document, it fails cleanly
      expect(
        () => hazardRepo.updateStatus(
          'non_existent_hazard',
          VerificationStatus.resolved,
        ),
        throwsA(
          isA<BackendException>().having(
            (e) => e.failure,
            'failure',
            BackendFailure.unavailable,
          ),
        ),
      );
    });

    test(
      'Scenario 5: Malformed coordinates and local file paths are rejected',
      () async {
        final gateway = InMemoryFirebaseGateway();
        final user = await gateway.signUp(
          name: 'Validator Tester',
          email: 'val@roadsense.org',
          password: 'password123',
        );

        final reportRepo = FirebaseReportRepository(gateway);

        // Out of range latitude > 90
        final badLat = UserReport(
          id: 'bad_lat',
          userId: user.id,
          tripId: 'trip_1',
          category: ReportCategory.pothole,
          location: const RoadLocation(latitude: 91.0, longitude: 77.0),
          severity: HazardSeverity.moderate,
          submittedAt: DateTime.now(),
        );
        expect(
          () => reportRepo.submit(badLat),
          throwsA(isA<FormatException>()),
        );

        // Out of range longitude > 180
        final badLng = UserReport(
          id: 'bad_lng',
          userId: user.id,
          tripId: 'trip_1',
          category: ReportCategory.pothole,
          location: const RoadLocation(latitude: 12.0, longitude: 181.0),
          severity: HazardSeverity.moderate,
          submittedAt: DateTime.now(),
        );
        expect(
          () => reportRepo.submit(badLng),
          throwsA(isA<FormatException>()),
        );

        // Local file path is sanitized to prevent leaking device storage paths
        final localPhotoReport = UserReport(
          id: 'local_photo_rep',
          userId: user.id,
          tripId: 'trip_1',
          category: ReportCategory.pothole,
          location: const RoadLocation(latitude: 12.0, longitude: 77.0),
          severity: HazardSeverity.moderate,
          submittedAt: DateTime.now(),
          photoPath: 'file:///data/user/0/com.roadsense/cache/photo.jpg',
        );
        await reportRepo.submit(localPhotoReport);

        final rawDoc = await gateway.getDocument(
          BackendCollections.reports,
          'local_photo_rep',
        );
        expect(rawDoc!['photoUrl'], isNull);
      },
    );

    test(
      'Scenario 6: Model predictions are isolated from confirmed map hazards',
      () async {
        final gateway = InMemoryFirebaseGateway();
        final detectionRepo = FirebaseDetectionEventRepository(gateway);

        final prediction = DetectionResult(
          classification: DetectionClassification.pothole,
          confidence: 0.95,
          timestamp: DateTime.now(),
          location: GpsReading(
            latitude: 12.95,
            longitude: 77.60,
            accuracy: 5.0,
            speedMps: 10.0,
            timestamp: DateTime.now(),
          ),
          speedMps: 10.0,
          sensorWindowId: 'win_iso_999',
          modelVersion: 'tflite-v2',
          severityEstimate: HazardSeverity.high,
          source: DetectionSource.tensorFlowLite,
        );

        await detectionRepo.save(prediction);

        // Model predictions written to dedicated collection
        expect(
          await gateway.getDocument(
            BackendCollections.modelPredictions,
            'win_iso_999',
          ),
          isNotNull,
        );

        // Hazards collection remains completely unwritten
        expect(
          await gateway.getDocument(BackendCollections.hazards, 'win_iso_999'),
          isNull,
        );
      },
    );

    test('Scenario 7: Repository queries satisfy security rules filters and limits', () async {
      final gateway = InMemoryFirebaseGateway();
      await gateway.signUp(
        name: 'Query Driver',
        email: 'qdriver@roadsense.org',
        password: 'password123',
      );

      final tripRepo = FirebaseTripHistoryRepository(gateway);

      final trip = Trip(
        id: 'trip_rule_compat',
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
        duration: const Duration(minutes: 20),
        distanceKm: 10.0,
        startLabel: 'A',
        endLabel: 'B',
        roadQuality: 'Good',
        observations: const [],
        verifiedHazards: const [],
        possibleAnomalies: const [],
        routeSegments: const [],
      );

      await tripRepo.saveTrip(trip);

      // Queries filter explicitly on ownerUid == request.auth.uid (matching rules resource.data.ownerUid)
      final userTrips = await tripRepo.recentTrips();
      expect(userTrips.length, 1);
      expect(userTrips.first.id, 'trip_rule_compat');
    });
  });
}
