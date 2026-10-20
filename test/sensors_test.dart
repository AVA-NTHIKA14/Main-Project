import 'package:flutter_test/flutter_test.dart';

import 'package:road_loop/sensors.dart';

void main() {
  final timestamp = DateTime(2026, 10, 7, 10);

  test('fuses accelerometer, gyroscope, GPS, speed, and timestamp into a trip buffer', () async {
    final sensors = MockSensorService();
    final gps = MockGPSService();
    final repository = InMemoryTripRepository();
    final fusion = SensorFusionService(
      sensorService: sensors,
      gpsService: gps,
      tripRepository: repository,
      windowSize: 2,
    );
    final readings = <SensorReading>[];
    fusion.readings.listen(readings.add);

    await fusion.start(tripId: 'trip-1');
    sensors.emitAccelerometer(const Vector3(1, 0, 0));
    sensors.emitGyroscope(const Vector3(0, 1, 0));
    gps.emit(
      GpsReading(
        latitude: 51.5,
        longitude: -0.12,
        altitude: 22,
        accuracy: 4,
        speedMps: 12,
        timestamp: timestamp,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(readings, isNotEmpty);
    expect(readings.last.speedMps, 12);
    expect(readings.last.gps.altitude, 22);
    expect((await repository.readingsFor('trip-1')), isNotEmpty);
    await fusion.dispose();
  });

  test('window features are emitted without claiming classification', () async {
    final sensors = MockSensorService();
    final gps = MockGPSService();
    final fusion = SensorFusionService(
      sensorService: sensors,
      gpsService: gps,
      tripRepository: InMemoryTripRepository(),
      windowSize: 2,
    );
    final features = <WindowFeatures>[];
    final classifications = <ClassificationResult>[];
    fusion.features.listen(features.add);
    fusion.classifications.listen(classifications.add);
    await fusion.start(tripId: 'trip-2');

    for (var index = 0; index < 2; index++) {
      sensors.emitAccelerometer(const Vector3(3, 0, 0));
      sensors.emitGyroscope(const Vector3(0, 4, 0));
      gps.emit(
        GpsReading(
          latitude: 51.5,
          longitude: -0.12,
          accuracy: 4,
          speedMps: 8,
          timestamp: timestamp.add(Duration(seconds: index)),
        ),
      );
    }
    await Future<void>.delayed(Duration.zero);

    expect(features, hasLength(2));
    expect(features.every((item) => item.sampleCount == 2), isTrue);
    expect(
      features.every((item) => item.averageAccelerationMagnitude == 3),
      isTrue,
    );
    expect(
      features.every((item) => item.averageGyroscopeMagnitude == 4),
      isTrue,
    );
    expect(classifications, isEmpty);
    await fusion.dispose();
  });

  test('pause prevents collection and resume restores it', () async {
    final sensors = MockSensorService();
    final gps = MockGPSService();
    final fusion = SensorFusionService(
      sensorService: sensors,
      gpsService: gps,
      tripRepository: InMemoryTripRepository(),
    );
    final readings = <SensorReading>[];
    fusion.readings.listen(readings.add);
    await fusion.start(tripId: 'trip-3');
    await fusion.pause();
    sensors.emitAccelerometer(const Vector3(1, 0, 0));
    sensors.emitGyroscope(const Vector3(0, 1, 0));
    gps.emit(
      GpsReading(
        latitude: 51.5,
        longitude: -0.12,
        accuracy: 4,
        speedMps: 5,
        timestamp: timestamp,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(readings, isEmpty);

    await fusion.resume();
    sensors.emitAccelerometer(const Vector3(1, 0, 0));
    sensors.emitGyroscope(const Vector3(0, 1, 0));
    gps.emit(
      GpsReading(
        latitude: 51.5,
        longitude: -0.12,
        accuracy: 4,
        speedMps: 5,
        timestamp: timestamp,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(readings, isNotEmpty);
    await fusion.dispose();
  });

  test(
    'permission and unavailable failures are surfaced without touching UI',
    () async {
      final denied = SensorFusionService(
        sensorService: MockSensorService(permissionGranted: false),
        gpsService: MockGPSService(),
        tripRepository: InMemoryTripRepository(),
      );
      expect(
        () => denied.start(tripId: 'trip-denied'),
        throwsA(isA<SensorServiceException>()),
      );

      final unavailableGps = SensorFusionService(
        sensorService: MockSensorService(),
        gpsService: MockGPSService(available: false),
        tripRepository: InMemoryTripRepository(),
      );
      expect(
        () => unavailableGps.start(tripId: 'trip-gps'),
        throwsA(isA<SensorServiceException>()),
      );
    },
  );

  test('orientation handling and low battery mode are explicit', () async {
    final handler = const DefaultOrientationHandler();
    final transformed = handler.transform(
      const Vector3(1, 2, 3),
      DeviceOrientationMode.landscapeLeft,
    );
    expect(transformed.x, 2);
    expect(transformed.y, -1);

    final fusion = SensorFusionService(
      sensorService: MockSensorService(),
      gpsService: MockGPSService(),
      tripRepository: InMemoryTripRepository(),
    );
    fusion.updateBatteryLevel(10);
    expect(fusion.lowBatteryMode, isTrue);
    fusion.updateBatteryLevel(80);
    expect(fusion.lowBatteryMode, isFalse);
    await fusion.dispose();
  });
}
