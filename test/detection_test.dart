import 'package:flutter_test/flutter_test.dart';

import 'package:roadsense/detection.dart';
import 'package:roadsense/explore.dart';
import 'package:roadsense/sensors.dart';

void main() {
  test(
    'mock model marks every prediction as DEMO and never verified',
    () async {
      final result = await const MockDetectionModel().predict(_window());

      expect(result.isDemo, isTrue);
      expect(result.source, DetectionSource.mockDemo);
      expect(result.modelVersion, 'mock-demo-1.0');
      expect(result.displayLabel, 'Possible pothole');
      expect(result.severityEstimate, HazardSeverity.possible);
      expect(result.confidence, .5);
    },
  );

  test('model supports all requested anomaly classifications', () {
    expect(
      DetectionClassification.values,
      containsAll([
        DetectionClassification.pothole,
        DetectionClassification.speedBreaker,
        DetectionClassification.roughRoad,
        DetectionClassification.roadCrack,
        DetectionClassification.waterlogging,
        DetectionClassification.debris,
        DetectionClassification.other,
      ]),
    );
  });

  test('service delegates to a replaceable model', () async {
    final service = DetectionService(model: _FixedModel());
    final result = await service.detect(_window());

    expect(result?.classification, DetectionClassification.debris);
    expect(service.userFacingLabel(result!), 'Possible debris');
    expect(result.source, DetectionSource.tensorFlowLite);
  });

  test('detection result carries sensor window and location context', () async {
    final result = await const MockDetectionModel().predict(_window());

    expect(result.sensorWindowId, 'trip-1-window-1');
    expect(result.location.latitude, 51.5);
    expect(result.location.longitude, -0.12);
    expect(result.speedMps, 10);
    expect(result.timestamp, _window().end);
  });
}

WindowFeatures _window() => WindowFeatures(
  id: 'trip-1-window-1',
  start: DateTime(2026, 10, 7, 10),
  end: DateTime(2026, 10, 7, 10, 0, 2),
  sampleCount: 20,
  averageAccelerationMagnitude: 15,
  averageGyroscopeMagnitude: 2,
  averageSpeedMps: 10,
  location: GpsReading(
    latitude: 51.5,
    longitude: -0.12,
    altitude: 20,
    accuracy: 4,
    speedMps: 10,
    timestamp: DateTime(2026, 10, 7, 10, 0, 2),
  ),
);

class _FixedModel implements DetectionModel {
  @override
  Future<DetectionResult> predict(WindowFeatures featureWindow) async =>
      DetectionResult(
        classification: DetectionClassification.debris,
        confidence: .8,
        timestamp: featureWindow.end,
        location: featureWindow.location,
        speedMps: featureWindow.averageSpeedMps,
        sensorWindowId: featureWindow.id,
        modelVersion: 'test-model',
        severityEstimate: HazardSeverity.moderate,
        source: DetectionSource.tensorFlowLite,
      );
}
