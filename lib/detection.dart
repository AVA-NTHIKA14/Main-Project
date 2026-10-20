import 'sensors.dart';

import 'explore.dart';

enum DetectionClassification {
  pothole,
  speedBreaker,
  roughRoad,
  roadCrack,
  waterlogging,
  debris,
  other,
}

enum DetectionSource { mockDemo, tensorFlowLite }

class DetectionResult {
  const DetectionResult({
    required this.classification,
    required this.confidence,
    required this.timestamp,
    required this.location,
    required this.speedMps,
    required this.sensorWindowId,
    required this.modelVersion,
    required this.severityEstimate,
    required this.source,
  });

  final DetectionClassification classification;
  final double confidence;
  final DateTime timestamp;
  final GpsReading location;
  final double speedMps;
  final String sensorWindowId;
  final String modelVersion;
  final HazardSeverity severityEstimate;
  final DetectionSource source;

  bool get isDemo => source == DetectionSource.mockDemo;

  String get displayLabel => 'Possible ${classificationLabel(classification)}';
}

abstract interface class DetectionModel {
  Future<DetectionResult?> predict(WindowFeatures featureWindow);
}

class MockDetectionModel implements DetectionModel {
  const MockDetectionModel();

  @override
  Future<DetectionResult> predict(WindowFeatures featureWindow) async {
    return DetectionResult(
      classification: _classify(featureWindow),
      confidence: _demoConfidence(featureWindow),
      timestamp: featureWindow.end,
      location: featureWindow.location,
      speedMps: featureWindow.averageSpeedMps,
      sensorWindowId: featureWindow.id,
      modelVersion: 'mock-demo-1.0',
      severityEstimate: HazardSeverity.possible,
      source: DetectionSource.mockDemo,
    );
  }

  DetectionClassification _classify(WindowFeatures features) {
    if (features.averageAccelerationMagnitude > 14) {
      return DetectionClassification.pothole;
    }
    if (features.averageGyroscopeMagnitude > 4) {
      return DetectionClassification.roughRoad;
    }
    return DetectionClassification.other;
  }

  double _demoConfidence(WindowFeatures features) {
    if (features.averageAccelerationMagnitude > 14) return .5;
    if (features.averageGyroscopeMagnitude > 4) return .5;
    return .5;
  }
}

class DetectionService {
  DetectionService({required DetectionModel model}) : _model = model;

  final DetectionModel _model;

  Future<DetectionResult?> detect(WindowFeatures featureWindow) =>
      _model.predict(featureWindow);

  String userFacingLabel(DetectionResult result) => result.displayLabel;
}

String classificationLabel(DetectionClassification classification) =>
    switch (classification) {
      DetectionClassification.pothole => 'pothole',
      DetectionClassification.speedBreaker => 'speed breaker',
      DetectionClassification.roughRoad => 'rough road',
      DetectionClassification.roadCrack => 'road crack',
      DetectionClassification.waterlogging => 'waterlogging',
      DetectionClassification.debris => 'debris',
      DetectionClassification.other => 'road anomaly',
    };
