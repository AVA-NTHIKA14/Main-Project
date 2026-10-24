import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_loop/auth.dart';
import 'package:road_loop/backend.dart';
import 'package:road_loop/detection.dart';
import 'package:road_loop/explore.dart';
import 'package:road_loop/firestore_gateway.dart';
import 'package:road_loop/reports.dart';
import 'package:road_loop/sensors.dart';
import 'package:road_loop/trips.dart';

void main() {
  group('Module 04: User Profile Repository & Identity', () {
    test(
      'User profile uses Firebase UID-based document ID, never email',
      () async {
        final gateway = InMemoryFirebaseGateway();
        final repository = FirebaseUserRepository(gateway);

        final user = await repository.create(
          name: 'Avanthika Driver',
          email: 'avanthika@roadsense.org',
        );

        expect(user.id, startsWith('mock_uid_'));
        expect(user.id.contains('@'), isFalse);
        expect(user.email, 'avanthika@roadsense.org');

        // Check persisted document in users collection
        final rawDoc = await gateway.getDocument(
          BackendCollections.users,
          user.id,
        );
        expect(rawDoc, isNotNull);
        expect(rawDoc!['uid'], user.id);
        expect(rawDoc['displayName'], 'Avanthika Driver');
        expect(rawDoc['role'], 'user');
        expect(rawDoc['email'], 'avanthika@roadsense.org');

        // Fetch by ID
        final retrieved = await repository.findById(user.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.name, 'Avanthika Driver');
        expect(retrieved.email, 'avanthika@roadsense.org');
      },
    );

    test('Rejects invalid UID containing an email address', () async {
      final gateway = InMemoryFirebaseGateway();
      final repository = FirebaseUserRepository(gateway);

      const invalidUser = RoadSenseUser(
        id: 'bad_email@example.com',
        name: 'Bad Actor',
        email: 'bad_email@example.com',
        role: UserRole.user,
      );

      expect(
        () => repository.updateProfile(invalidUser),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'Partial profile update does not overwrite role or creation time',
      () async {
        final gateway = InMemoryFirebaseGateway();
        final repository = FirebaseUserRepository(gateway);

        final user = await repository.create(
          name: 'Original Name',
          email: 'driver@roadsense.org',
        );

        final originalDoc = await gateway.getDocument(
          BackendCollections.users,
          user.id,
        );
        final createdAtStr = originalDoc!['createdAt'];

        // Attempt client profile update with role escalation to administrator
        final escalatedUser = RoadSenseUser(
          id: user.id,
          name: 'Updated Name',
          email: user.email,
          role: UserRole.administrator, // Unauthorized escalation
        );

        await repository.updateProfile(escalatedUser);

        final updatedDoc = await gateway.getDocument(
          BackendCollections.users,
          user.id,
        );
        expect(updatedDoc!['displayName'], 'Updated Name');
        // Role MUST remain unchanged from server-assigned role
        expect(updatedDoc['role'], 'user');
        // CreatedAt must be preserved
        expect(updatedDoc['createdAt'], createdAtStr);
        // UpdatedAt should now be present
        expect(updatedDoc['updatedAt'], isNotNull);
      },
    );
  });

  group('Module 04: Report Repository, Coordinates & Public URLs', () {
    test('Submit report derives UID and validates coordinates', () async {
      final gateway = InMemoryFirebaseGateway();
      final user = await gateway.signUp(
        name: 'Citizen Reporter',
        email: 'citizen@roadsense.org',
        password: 'password123',
      );

      final repository = FirebaseReportRepository(gateway);
      final report = UserReport(
        id: 'report_101',
        userId: user.id,
        tripId: 'trip_501',
        category: ReportCategory.pothole,
        location: const RoadLocation(latitude: 12.9716, longitude: 77.5946),
        severity: HazardSeverity.high,
        submittedAt: DateTime.utc(2026, 10, 24, 8, 30),
        description: 'Large pothole in right lane',
        photoPath:
            'https://storage.googleapis.com/roadsense/photos/pothole1.jpg',
      );

      final saved = await repository.submit(report);
      expect(saved.id, 'report_101');
      expect(saved.userId, user.id);
      expect(saved.category, ReportCategory.pothole);

      // Verify persistence in reports/{reportId}
      final rawDoc = await gateway.getDocument(
        BackendCollections.reports,
        'report_101',
      );
      expect(rawDoc, isNotNull);
      expect(rawDoc!['reporterUid'], user.id);
      expect(rawDoc['latitude'], 12.9716);
      expect(rawDoc['longitude'], 77.5946);
      expect(
        rawDoc['photoUrl'],
        'https://storage.googleapis.com/roadsense/photos/pothole1.jpg',
      );
      expect(rawDoc['status'], 'submitted');

      // Verify reportsForUser
      final userReports = await repository.reportsForUser(user.id);
      expect(userReports.length, 1);
      expect(userReports.first.id, 'report_101');
      expect(userReports.first.location.latitude, 12.9716);
    });

    test('Sanitizes local device file paths from public URL fields', () async {
      final gateway = InMemoryFirebaseGateway();
      final user = await gateway.signUp(
        name: 'Local Driver',
        email: 'driver@roadsense.org',
        password: 'password123',
      );

      final repository = FirebaseReportRepository(gateway);
      final localFileReport = UserReport(
        id: 'report_local_photo',
        userId: user.id,
        tripId: 'trip_502',
        category: ReportCategory.speedBreaker,
        location: const RoadLocation(latitude: 12.97, longitude: 77.59),
        severity: HazardSeverity.moderate,
        submittedAt: DateTime.utc(2026, 10, 24, 8, 35),
        photoPath: '/data/user/0/com.roadsense/cache/local_photo.jpg',
      );

      await repository.submit(localFileReport);

      final rawDoc = await gateway.getDocument(
        BackendCollections.reports,
        'report_local_photo',
      );
      expect(rawDoc!['photoUrl'], isNull);
    });

    test('Rejects invalid coordinates and missing coordinates', () async {
      final gateway = InMemoryFirebaseGateway();
      final user = await gateway.signUp(
        name: 'Coord Tester',
        email: 'coord@roadsense.org',
        password: 'password123',
      );

      final repository = FirebaseReportRepository(gateway);

      // Latitude > 90
      final badLatReport = UserReport(
        id: 'report_bad_lat',
        userId: user.id,
        tripId: 'trip_1',
        category: ReportCategory.pothole,
        location: const RoadLocation(latitude: 95.0, longitude: 77.0),
        severity: HazardSeverity.moderate,
        submittedAt: DateTime.now(),
      );
      expect(
        () => repository.submit(badLatReport),
        throwsA(isA<FormatException>()),
      );

      // Longitude > 180
      final badLngReport = UserReport(
        id: 'report_bad_lng',
        userId: user.id,
        tripId: 'trip_1',
        category: ReportCategory.pothole,
        location: const RoadLocation(latitude: 12.0, longitude: 185.0),
        severity: HazardSeverity.moderate,
        submittedAt: DateTime.now(),
      );
      expect(
        () => repository.submit(badLngReport),
        throwsA(isA<FormatException>()),
      );

      // Latitude NaN
      final nanLatReport = UserReport(
        id: 'report_nan_lat',
        userId: user.id,
        tripId: 'trip_1',
        category: ReportCategory.pothole,
        location: const RoadLocation(latitude: double.nan, longitude: 77.0),
        severity: HazardSeverity.moderate,
        submittedAt: DateTime.now(),
      );
      expect(
        () => repository.submit(nanLatReport),
        throwsA(isA<FormatException>()),
      );
    });

    test('Rejects report write if reporterUid does not match active authenticated user', () async {
      final gateway = InMemoryFirebaseGateway();
      await gateway.signUp(
        name: 'Legit User',
        email: 'legit@roadsense.org',
        password: 'password123',
      );

      final repository = FirebaseReportRepository(gateway);
      final forgedReport = UserReport(
        id: 'report_forged',
        userId: 'other_victim_uid',
        tripId: 'trip_1',
        category: ReportCategory.pothole,
        location: const RoadLocation(latitude: 12.9, longitude: 77.5),
        severity: HazardSeverity.moderate,
        submittedAt: DateTime.now(),
      );

      expect(
        () => repository.submit(forgedReport),
        throwsA(
          isA<BackendException>().having(
            (e) => e.failure,
            'failure',
            BackendFailure.permission,
          ),
        ),
      );
    });
  });

  group('Module 04: Trip History Repository & Bounded Queries', () {
    test('Save trip attaches ownerUid and allows retrieval by ID', () async {
      final gateway = InMemoryFirebaseGateway();
      final user = await gateway.signUp(
        name: 'Trip Maker',
        email: 'trips@roadsense.org',
        password: 'password123',
      );

      final repository = FirebaseTripHistoryRepository(gateway);
      final startTime = DateTime.utc(2026, 10, 24, 7, 0);
      final endTime = DateTime.utc(2026, 10, 24, 7, 45);

      final trip = Trip(
        id: 'trip_2026_01',
        startedAt: startTime,
        endedAt: endTime,
        duration: const Duration(minutes: 45),
        distanceKm: 24.5,
        startLabel: 'MG Road',
        endLabel: 'Whitefield',
        roadQuality: 'Good',
        observations: const [],
        verifiedHazards: const [],
        possibleAnomalies: const [],
        routeSegments: const [],
      );

      await repository.saveTrip(trip);

      // Verify persisted document
      final rawDoc = await gateway.getDocument(
        BackendCollections.trips,
        'trip_2026_01',
      );
      expect(rawDoc, isNotNull);
      expect(rawDoc!['ownerUid'], user.id);
      expect(rawDoc['distanceKm'], 24.5);
      expect(rawDoc['durationSeconds'], 45 * 60);

      // Verify tripById
      final retrieved = await repository.tripById('trip_2026_01');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'trip_2026_01');
      expect(retrieved.startLabel, 'MG Road');
      expect(retrieved.distanceKm, 24.5);

      // Non-existent trip returns null
      final missing = await repository.tripById('trip_missing');
      expect(missing, isNull);
    });

    test(
      'Recent trips returns bounded results ordered by startedAt descending',
      () async {
        final gateway = InMemoryFirebaseGateway();
        await gateway.signUp(
          name: 'Multi Trip Driver',
          email: 'multitrips@roadsense.org',
          password: 'password123',
        );

        final repository = FirebaseTripHistoryRepository(gateway);

        for (int i = 1; i <= 5; i++) {
          final trip = Trip(
            id: 'trip_sequence_$i',
            startedAt: DateTime.utc(2026, 10, 20 + i, 8, 0),
            endedAt: DateTime.utc(2026, 10, 20 + i, 8, 30),
            duration: const Duration(minutes: 30),
            distanceKm: i * 5.0,
            startLabel: 'Start $i',
            endLabel: 'End $i',
            roadQuality: 'Normal',
            observations: const [],
            verifiedHazards: const [],
            possibleAnomalies: const [],
            routeSegments: const [],
          );
          await repository.saveTrip(trip);
        }

        final recent = await repository.recentTrips();
        expect(recent.length, 5);
        // Most recent trip (i=5, Oct 25) should be first
        expect(recent.first.id, 'trip_sequence_5');
        expect(recent.last.id, 'trip_sequence_1');
      },
    );

    test('Save trip rejects unauthenticated callers', () async {
      final gateway = InMemoryFirebaseGateway(); // Not signed in
      final repository = FirebaseTripHistoryRepository(gateway);

      final trip = Trip(
        id: 'trip_unauthed',
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
        duration: Duration.zero,
        distanceKm: 0.0,
        startLabel: 'A',
        endLabel: 'B',
        roadQuality: 'Unknown',
        observations: const [],
        verifiedHazards: const [],
        possibleAnomalies: const [],
        routeSegments: const [],
      );

      expect(
        () => repository.saveTrip(trip),
        throwsA(
          isA<BackendException>().having(
            (e) => e.failure,
            'failure',
            BackendFailure.authentication,
          ),
        ),
      );
    });
  });

  group('Module 04: Hazard Repository, Status Updates & Observations', () {
    test(
      'Save hazard persists verified fields and updateStatus updates partially',
      () async {
        final gateway = InMemoryFirebaseGateway();
        final repository = FirebaseHazardRepository(gateway);

        final hazard = Hazard(
          id: 'hazard_m4_01',
          segmentId: 'seg_blr_01',
          severity: HazardSeverity.high,
          observations: const [],
          status: VerificationStatus.possible,
          type: HazardType.pothole,
          location: const RoadLocation(latitude: 12.9352, longitude: 77.6245),
          confidence: 0.85,
          firstObserved: DateTime.utc(2026, 10, 24, 6, 0),
          lastObserved: DateTime.utc(2026, 10, 24, 7, 0),
        );

        await repository.save(hazard);

        final beforeDoc = await gateway.getDocument(
          BackendCollections.hazards,
          'hazard_m4_01',
        );
        expect(beforeDoc, isNotNull);
        expect(beforeDoc!['status'], 'possible');
        expect(beforeDoc['confidence'], 0.85);
        expect(beforeDoc['latitude'], 12.9352);

        // Partial update to status 'verified'
        await repository.updateStatus(
          'hazard_m4_01',
          VerificationStatus.verified,
        );

        final afterDoc = await gateway.getDocument(
          BackendCollections.hazards,
          'hazard_m4_01',
        );
        expect(afterDoc!['status'], 'verified');
        // Coordinates and confidence must NOT be erased
        expect(afterDoc['latitude'], 12.9352);
        expect(afterDoc['confidence'], 0.85);
        expect(afterDoc['lastConfirmedAt'], isNotNull);
      },
    );

    test('Hazard list filters by status with bounded limits', () async {
      final gateway = InMemoryFirebaseGateway();
      final repository = FirebaseHazardRepository(gateway);

      for (int i = 1; i <= 4; i++) {
        final hazard = Hazard(
          id: 'hazard_status_$i',
          segmentId: 'seg_$i',
          severity: HazardSeverity.moderate,
          observations: const [],
          status: i.isEven
              ? VerificationStatus.verified
              : VerificationStatus.possible,
          type: HazardType.roughSurface,
          location: RoadLocation(
            latitude: 12.0 + i * 0.1,
            longitude: 77.0 + i * 0.1,
          ),
          confidence: 0.6,
          firstObserved: DateTime.now(),
          lastObserved: DateTime.now(),
        );
        await repository.save(hazard);
      }

      final verifiedOnly = await repository.list(
        status: VerificationStatus.verified,
      );
      expect(verifiedOnly.length, 2);
      expect(
        verifiedOnly.every((h) => h.status == VerificationStatus.verified),
        isTrue,
      );

      final allHazards = await repository.list();
      expect(allHazards.length, 4);
    });

    test(
      'Hazard observations save and retrieve by hazardId/segmentId',
      () async {
        final gateway = InMemoryFirebaseGateway();
        final repository = FirebaseHazardObservationRepository(gateway);

        final observation = HazardObservation(
          id: 'obs_1001',
          segmentId: 'hazard_ref_99',
          timestamp: DateTime.utc(2026, 10, 24, 8, 0),
          userId: 'sensor_rig_user',
          tripId: 'trip_rig_01',
          location: const RoadLocation(latitude: 12.95, longitude: 77.65),
          type: HazardType.pothole,
          severity: HazardSeverity.moderate,
        );

        await repository.save(observation);

        final forHazard = await repository.forHazard('hazard_ref_99');
        expect(forHazard.length, 1);
        expect(forHazard.first.id, 'obs_1001');
        expect(forHazard.first.location.latitude, 12.95);
      },
    );
  });

  group('Module 04: Model Predictions Isolation from Public Hazards', () {
    test('Model predictions write exclusively to modelPredictions, never to hazards', () async {
      final gateway = InMemoryFirebaseGateway();
      final repository = FirebaseDetectionEventRepository(gateway);

      final result = DetectionResult(
        classification: DetectionClassification.pothole,
        confidence: 0.92,
        timestamp: DateTime.utc(2026, 10, 24, 8, 15),
        location: GpsReading(
          latitude: 12.971,
          longitude: 77.594,
          accuracy: 4.5,
          speedMps: 12.3,
          timestamp: DateTime.utc(2026, 10, 24, 8, 15),
        ),
        speedMps: 12.3,
        sensorWindowId: 'win_pothole_404',
        modelVersion: 'v2.1-tflite',
        severityEstimate: HazardSeverity.high,
        source: DetectionSource.tensorFlowLite,
      );

      await repository.save(result);

      // Must be present in modelPredictions
      final predDoc = await gateway.getDocument(
        BackendCollections.modelPredictions,
        'win_pothole_404',
      );
      expect(predDoc, isNotNull);
      expect(predDoc!['classification'], 'pothole');
      expect(predDoc['confidence'], 0.92);

      // Must NEVER be written directly to hazards collection
      final hazardDoc = await gateway.getDocument(
        BackendCollections.hazards,
        'win_pothole_404',
      );
      expect(hazardDoc, isNull);

      // Recent predictions should be retrievable
      final recent = await repository.recent(limit: 10);
      expect(recent.length, 1);
      expect(recent.first.sensorWindowId, 'win_pothole_404');
      expect(recent.first.confidence, 0.92);
    });
  });

  group('Module 04: InMemoryFirebaseGateway Mechanics & Error Handling', () {
    test(
      'Gateway supports partial update, full replacement, and delete',
      () async {
        final gateway = InMemoryFirebaseGateway();

        // Create initial doc
        await gateway.setDocument('test_col', 'doc_1', {'a': 1, 'b': 'hello'});
        var doc = await gateway.getDocument('test_col', 'doc_1');
        expect(doc!['a'], 1);
        expect(doc['b'], 'hello');

        // Update partial field
        await gateway.updateDocument('test_col', 'doc_1', {'b': 'world'});
        doc = await gateway.getDocument('test_col', 'doc_1');
        expect(doc!['a'], 1);
        expect(doc['b'], 'world');

        // Update non-existent document throws unavailable
        expect(
          () => gateway.updateDocument('test_col', 'missing_doc', {'x': 10}),
          throwsA(
            isA<BackendException>().having(
              (e) => e.failure,
              'failure',
              BackendFailure.unavailable,
            ),
          ),
        );

        // Full document replacement (merge = false)
        await gateway.setDocument('test_col', 'doc_1', {'c': 99}, merge: false);
        doc = await gateway.getDocument('test_col', 'doc_1');
        expect(doc!['a'], isNull);
        expect(doc['c'], 99);

        // Set with merge = true
        await gateway.setDocument('test_col', 'doc_1', {'d': 100}, merge: true);
        doc = await gateway.getDocument('test_col', 'doc_1');
        expect(doc!['c'], 99);
        expect(doc['d'], 100);

        // Delete document
        await gateway.deleteDocument('test_col', 'doc_1');
        doc = await gateway.getDocument('test_col', 'doc_1');
        expect(doc, isNull);
      },
    );

    test(
      'Query collection supports filters, orderBy, descending, and limits',
      () async {
        final gateway = InMemoryFirebaseGateway();

        await gateway.setDocument('items', '1', {'type': 'A', 'score': 10});
        await gateway.setDocument('items', '2', {'type': 'B', 'score': 20});
        await gateway.setDocument('items', '3', {'type': 'A', 'score': 30});
        await gateway.setDocument('items', '4', {'type': 'A', 'score': 40});

        // Filtered query
        final filtered = await gateway.queryCollection(
          'items',
          filters: {'type': 'A'},
        );
        expect(filtered.length, 3);

        // Sorted descending by score with limit 2
        final sorted = await gateway.queryCollection(
          'items',
          filters: {'type': 'A'},
          orderBy: 'score',
          descending: true,
          limit: 2,
        );
        expect(sorted.length, 2);
        expect(sorted[0]['score'], 40);
        expect(sorted[1]['score'], 30);
      },
    );

    test('Firestore error mapping translates FirebaseException codes into BackendFailure', () {
      final permDenied = FirestoreFirebaseGateway.mapFirebaseException(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'No access',
        ),
      );
      expect(permDenied.failure, BackendFailure.permission);

      final unavail = FirestoreFirebaseGateway.mapFirebaseException(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'Service down',
        ),
      );
      expect(unavail.failure, BackendFailure.network);

      final deadline = FirestoreFirebaseGateway.mapFirebaseException(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'deadline-exceeded',
          message: 'Timeout',
        ),
      );
      expect(deadline.failure, BackendFailure.network);

      final unauth = FirestoreFirebaseGateway.mapFirebaseException(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unauthenticated',
          message: 'Not logged in',
        ),
      );
      expect(unauth.failure, BackendFailure.authentication);

      final invalidArg = FirestoreFirebaseGateway.mapFirebaseException(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'invalid-argument',
          message: 'Bad param',
        ),
      );
      expect(invalidArg.failure, BackendFailure.invalidData);

      final unknown = FirestoreFirebaseGateway.mapFirebaseException(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unknown',
          message: 'Misc error',
        ),
      );
      expect(unknown.failure, BackendFailure.unavailable);
    });
  });
}
