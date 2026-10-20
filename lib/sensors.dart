import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum SensorLifecycle { stopped, running, paused }

enum SensorFailure { permissionDenied, unavailable, streamError }

enum DeviceOrientationMode {
  portrait,
  landscapeLeft,
  portraitUpsideDown,
  landscapeRight,
}

class SensorServiceException implements Exception {
  const SensorServiceException(this.failure, this.message);

  final SensorFailure failure;
  final String message;

  @override
  String toString() => message;
}

class Vector3 {
  const Vector3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double get magnitude => math.sqrt(x * x + y * y + z * z);
}

class GpsReading {
  const GpsReading({
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.accuracy,
    required this.speedMps,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double? altitude;
  final double accuracy;
  final double speedMps;
  final DateTime timestamp;
}

class SensorReading {
  const SensorReading({
    required this.accelerometer,
    required this.gyroscope,
    required this.gps,
    required this.speedMps,
    required this.timestamp,
  });

  final Vector3 accelerometer;
  final Vector3 gyroscope;
  final GpsReading gps;
  final double speedMps;
  final DateTime timestamp;
}

abstract interface class SensorService {
  Stream<Vector3> get accelerometerStream;
  Stream<Vector3> get gyroscopeStream;
  Future<void> start();
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
  SensorLifecycle get lifecycle;
}

abstract interface class GPSService {
  Stream<GpsReading> get positionStream;
  Future<void> start();
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
  SensorLifecycle get lifecycle;
}

abstract interface class TripRepository {
  Future<void> append(String tripId, SensorReading reading);
  Future<List<SensorReading>> readingsFor(String tripId);
  Future<void> clear(String tripId);
}

abstract interface class SensorReadingSink {
  Future<void> enqueue(SensorReading reading);
}

class InMemoryTripRepository implements TripRepository {
  final Map<String, List<SensorReading>> _trips = {};

  @override
  Future<void> append(String tripId, SensorReading reading) async =>
      _trips.putIfAbsent(tripId, () => []).add(reading);

  @override
  Future<List<SensorReading>> readingsFor(String tripId) async =>
      List.unmodifiable(_trips[tripId] ?? const []);

  @override
  Future<void> clear(String tripId) async => _trips.remove(tripId);
}

class MockSensorService implements SensorService {
  MockSensorService({this.available = true, this.permissionGranted = true});

  final bool available;
  final bool permissionGranted;
  final _accelerometer = StreamController<Vector3>.broadcast();
  final _gyroscope = StreamController<Vector3>.broadcast();
  SensorLifecycle _lifecycle = SensorLifecycle.stopped;

  @override
  Stream<Vector3> get accelerometerStream => _accelerometer.stream;

  @override
  Stream<Vector3> get gyroscopeStream => _gyroscope.stream;

  @override
  SensorLifecycle get lifecycle => _lifecycle;

  void emitAccelerometer(Vector3 value) => _accelerometer.add(value);
  void emitGyroscope(Vector3 value) => _gyroscope.add(value);

  @override
  Future<void> start() async {
    _ensureUsable();
    _lifecycle = SensorLifecycle.running;
  }

  @override
  Future<void> stop() async => _lifecycle = SensorLifecycle.stopped;

  @override
  Future<void> pause() async => _lifecycle = SensorLifecycle.paused;

  @override
  Future<void> resume() async {
    _ensureUsable();
    _lifecycle = SensorLifecycle.running;
  }

  Future<void> dispose() async {
    await _accelerometer.close();
    await _gyroscope.close();
  }

  void _ensureUsable() {
    if (!permissionGranted) {
      throw const SensorServiceException(
        SensorFailure.permissionDenied,
        'Motion sensor permission was denied.',
      );
    }
    if (!available) {
      throw const SensorServiceException(
        SensorFailure.unavailable,
        'Motion sensors are unavailable.',
      );
    }
  }
}

class MockGPSService implements GPSService {
  MockGPSService({this.available = true, this.permissionGranted = true});

  final bool available;
  final bool permissionGranted;
  final _positions = StreamController<GpsReading>.broadcast();
  SensorLifecycle _lifecycle = SensorLifecycle.stopped;

  @override
  Stream<GpsReading> get positionStream => _positions.stream;

  @override
  SensorLifecycle get lifecycle => _lifecycle;

  void emit(GpsReading value) => _positions.add(value);

  @override
  Future<void> start() async {
    _ensureUsable();
    _lifecycle = SensorLifecycle.running;
  }

  @override
  Future<void> stop() async => _lifecycle = SensorLifecycle.stopped;

  @override
  Future<void> pause() async => _lifecycle = SensorLifecycle.paused;

  @override
  Future<void> resume() async {
    _ensureUsable();
    _lifecycle = SensorLifecycle.running;
  }

  Future<void> dispose() => _positions.close();

  void _ensureUsable() {
    if (!permissionGranted) {
      throw const SensorServiceException(
        SensorFailure.permissionDenied,
        'Location permission was denied.',
      );
    }
    if (!available) {
      throw const SensorServiceException(
        SensorFailure.unavailable,
        'GPS is unavailable.',
      );
    }
  }
}

abstract interface class OrientationHandler {
  Vector3 transform(Vector3 value, DeviceOrientationMode orientation);
}

class DefaultOrientationHandler implements OrientationHandler {
  const DefaultOrientationHandler();

  @override
  Vector3 transform(
    Vector3 value,
    DeviceOrientationMode orientation,
  ) => switch (orientation) {
    DeviceOrientationMode.portrait => value,
    DeviceOrientationMode.landscapeLeft => Vector3(value.y, -value.x, value.z),
    DeviceOrientationMode.portraitUpsideDown => Vector3(
      -value.x,
      -value.y,
      value.z,
    ),
    DeviceOrientationMode.landscapeRight => Vector3(-value.y, value.x, value.z),
  };
}

class WindowFeatures {
  const WindowFeatures({
    required this.id,
    required this.start,
    required this.end,
    required this.sampleCount,
    required this.averageAccelerationMagnitude,
    required this.averageGyroscopeMagnitude,
    required this.location,
    required this.averageSpeedMps,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final int sampleCount;
  final double averageAccelerationMagnitude;
  final double averageGyroscopeMagnitude;
  final GpsReading location;
  final double averageSpeedMps;
}

class ClassificationResult {
  const ClassificationResult({required this.label, required this.confidence});

  final String label;
  final double confidence;
}

abstract interface class SensorClassifier {
  Future<ClassificationResult?> classify(WindowFeatures features);
}

class NoOpSensorClassifier implements SensorClassifier {
  const NoOpSensorClassifier();

  @override
  Future<ClassificationResult?> classify(WindowFeatures features) async => null;
}

class SensorFusionService {
  SensorFusionService({
    required this._sensorService,
    required this._gpsService,
    required this._tripRepository,
    this._syncSink,
    this._classifier = const NoOpSensorClassifier(),
    this._orientationHandler = const DefaultOrientationHandler(),
    this.windowSize = 20,
    this.lowBatteryThreshold = 15,
  });

  final SensorService _sensorService;
  final GPSService _gpsService;
  final TripRepository _tripRepository;
  final SensorReadingSink? _syncSink;
  final SensorClassifier _classifier;
  final OrientationHandler _orientationHandler;
  final int windowSize;
  final int lowBatteryThreshold;
  final _readings = StreamController<SensorReading>.broadcast();
  final _features = StreamController<WindowFeatures>.broadcast();
  final _classifications = StreamController<ClassificationResult>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _window = <SensorReading>[];
  Vector3? _latestAccelerometer;
  Vector3? _latestGyroscope;
  GpsReading? _latestGps;
  String? _tripId;
  DeviceOrientationMode _orientation = DeviceOrientationMode.portrait;
  SensorLifecycle _lifecycle = SensorLifecycle.stopped;
  bool _lowBattery = false;

  Stream<SensorReading> get readings => _readings.stream;
  Stream<WindowFeatures> get features => _features.stream;
  Stream<ClassificationResult> get classifications => _classifications.stream;
  SensorLifecycle get lifecycle => _lifecycle;
  bool get lowBatteryMode => _lowBattery;

  Future<void> start({required String tripId}) async {
    if (_lifecycle == SensorLifecycle.running) return;
    _tripId = tripId;
    await _sensorService.start();
    try {
      await _gpsService.start();
    } catch (_) {
      await _sensorService.stop();
      rethrow;
    }
    _subscriptions.add(
      _sensorService.accelerometerStream.listen(
        _onAccelerometer,
        onError: _onStreamError,
      ),
    );
    _subscriptions.add(
      _sensorService.gyroscopeStream.listen(
        _onGyroscope,
        onError: _onStreamError,
      ),
    );
    _subscriptions.add(
      _gpsService.positionStream.listen(_onGps, onError: _onStreamError),
    );
    _lifecycle = SensorLifecycle.running;
    _log('Sensor fusion started for trip $tripId');
  }

  Future<void> stop() async {
    await _cancelSubscriptions();
    await _sensorService.stop();
    await _gpsService.stop();
    _lifecycle = SensorLifecycle.stopped;
    _latestAccelerometer = null;
    _latestGyroscope = null;
    _latestGps = null;
    _window.clear();
    _tripId = null;
  }

  Future<void> pause() async {
    if (_lifecycle != SensorLifecycle.running) return;
    await _sensorService.pause();
    await _gpsService.pause();
    _lifecycle = SensorLifecycle.paused;
    _log('Sensor fusion paused');
  }

  Future<void> resume() async {
    if (_lifecycle != SensorLifecycle.paused) return;
    await _sensorService.resume();
    await _gpsService.resume();
    _lifecycle = SensorLifecycle.running;
    _log('Sensor fusion resumed');
  }

  void setOrientation(DeviceOrientationMode orientation) =>
      _orientation = orientation;

  void updateBatteryLevel(int percentage) {
    _lowBattery = percentage <= lowBatteryThreshold;
    _log(
      _lowBattery ? 'Low battery mode enabled' : 'Normal battery mode restored',
    );
  }

  Future<void> dispose() async {
    await stop();
    await _readings.close();
    await _features.close();
    await _classifications.close();
  }

  void _onAccelerometer(Vector3 value) {
    _latestAccelerometer = _orientationHandler.transform(value, _orientation);
    _synchronize(DateTime.now());
  }

  void _onGyroscope(Vector3 value) {
    _latestGyroscope = _orientationHandler.transform(value, _orientation);
    _synchronize(DateTime.now());
  }

  void _onGps(GpsReading value) {
    _latestGps = value;
    _synchronize(value.timestamp);
  }

  void _synchronize(DateTime timestamp) {
    if (_lifecycle != SensorLifecycle.running ||
        _latestAccelerometer == null ||
        _latestGyroscope == null ||
        _latestGps == null ||
        _tripId == null) {
      return;
    }
    final reading = SensorReading(
      accelerometer: _latestAccelerometer!,
      gyroscope: _latestGyroscope!,
      gps: _latestGps!,
      speedMps: _latestGps!.speedMps,
      timestamp: timestamp,
    );
    _readings.add(reading);
    _tripRepository.append(_tripId!, reading);
    _syncSink?.enqueue(reading);
    _window.add(reading);
    if (_window.length >= windowSize) _flushWindow();
  }

  void _flushWindow() {
    final window = List<SensorReading>.from(_window);
    _window.clear();
    final result = WindowFeatures(
      id: '$_tripId-${window.first.timestamp.microsecondsSinceEpoch}',
      start: window.first.timestamp,
      end: window.last.timestamp,
      sampleCount: window.length,
      averageAccelerationMagnitude:
          window
              .map((item) => item.accelerometer.magnitude)
              .reduce((a, b) => a + b) /
          window.length,
      averageGyroscopeMagnitude:
          window
              .map((item) => item.gyroscope.magnitude)
              .reduce((a, b) => a + b) /
          window.length,
      location: window.last.gps,
      averageSpeedMps:
          window.map((item) => item.speedMps).reduce((a, b) => a + b) /
          window.length,
    );
    _features.add(result);
    _classifier.classify(result).then((classification) {
      if (classification != null) _classifications.add(classification);
    });
  }

  Future<void> _cancelSubscriptions() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  void _onStreamError(Object error, StackTrace stackTrace) =>
      _log('Sensor stream error: $error');
  void _log(String message) {
    if (kDebugMode) debugPrint('[RoadSense sensors] $message');
  }
}
