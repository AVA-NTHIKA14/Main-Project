import 'package:flutter_test/flutter_test.dart';

import 'package:road_loop/backend.dart';
import 'package:road_loop/detection.dart';
import 'package:road_loop/explore.dart';
import 'package:road_loop/sensors.dart';

void main() {
  test('backend composition exposes replaceable repositories and services', () {
    final backend = firebaseBackend(InMemoryFirebaseGateway());

    expect(backend.auth, isA<BackendAuthService>());
    expect(backend.users, isA<BackendUserRepository>());
    expect(backend.sensorReadings, isA<SensorReadingRepository>());
    expect(backend.hazardObservations, isA<HazardObservationRepository>());
    expect(backend.verification, isA<VerificationRepository>());
  });

  test(
    'in-memory Firebase-shaped gateway stores profiles and sensor readings',
    () async {
      final gateway = InMemoryFirebaseGateway();
      final users = FirebaseUserRepository(gateway);
      final user = await users.create(
        name: 'Research User',
        email: 'research@example.com',
      );
      final found = await users.findById(user.id);
      expect(found?.email, 'research@example.com');

      final sensors = FirebaseSensorReadingRepository(gateway);
      await sensors.append(tripId: 'trip-1', reading: _reading());
      final document = await gateway.getDocument(
        BackendCollections.sensorReadings,
        'trip-1_${_reading().timestamp.microsecondsSinceEpoch}',
      );
      expect(document?['tripId'], 'trip-1');
    },
  );

  test(
    'detection event adapter writes event and model prediction collections',
    () async {
      final gateway = InMemoryFirebaseGateway();
      final repository = FirebaseDetectionEventRepository(gateway);
      final result = DetectionResult(
        classification: DetectionClassification.pothole,
        confidence: .5,
        timestamp: _reading().timestamp,
        location: _reading().gps,
        speedMps: 10,
        sensorWindowId: 'window-1',
        modelVersion: 'mock-demo-1.0',
        severityEstimate: HazardSeverity.possible,
        source: DetectionSource.mockDemo,
      );

      await repository.save(result);

      expect(
        await gateway.getDocument(
          BackendCollections.detectionEvents,
          'window-1',
        ),
        isNotNull,
      );
      expect(
        await gateway.getDocument(
          BackendCollections.modelPredictions,
          'window-1',
        ),
        isNotNull,
      );
    },
  );

  test(
    'network errors are explicit and do not look like auth errors',
    () async {
      final gateway = InMemoryFirebaseGateway()..networkAvailable = false;

      expect(
        () => gateway.queryCollection(BackendCollections.users),
        throwsA(isA<BackendException>()),
      );
      try {
        await gateway.queryCollection(BackendCollections.users);
      } on BackendException catch (error) {
        expect(error.failure, BackendFailure.network);
      }
    },
  );
}

SensorReading _reading() => SensorReading(
  accelerometer: const Vector3(1, 2, 3),
  gyroscope: const Vector3(.1, .2, .3),
  gps: GpsReading(
    latitude: 51.5,
    longitude: -.12,
    accuracy: 4,
    speedMps: 10,
    timestamp: DateTime(2026, 10, 7, 10),
  ),
  speedMps: 10,
  timestamp: DateTime(2026, 10, 7, 10),
);
