import 'package:flutter/material.dart';

import 'design_system.dart';
import 'detection.dart';
import 'explore.dart';

class AdminDetectionEvent {
  const AdminDetectionEvent({
    required this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.speedMps,
    required this.accelerationPeak,
    required this.gyroscopeMagnitude,
    required this.predictedClass,
    required this.confidence,
    required this.modelVersion,
    required this.processingStatus,
  });

  final String id;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double speedMps;
  final double accelerationPeak;
  final double gyroscopeMagnitude;
  final DetectionClassification predictedClass;
  final double confidence;
  final String modelVersion;
  final String processingStatus;

  RoadLocation get location =>
      RoadLocation(latitude: latitude, longitude: longitude);
}

abstract interface class AdminDetectionDataSource {
  List<AdminDetectionEvent> get events;
}

class MockAdminDetectionDataSource implements AdminDetectionDataSource {
  const MockAdminDetectionDataSource();

  @override
  List<AdminDetectionEvent> get events => List.generate(
    8,
    (index) => AdminDetectionEvent(
      id: 'event-${index + 1}',
      timestamp: DateTime(2026, 10, 7, 10, index * 2),
      latitude: 51.500 + index * .0006,
      longitude: -.120 - index * .0004,
      speedMps: 8.2 + index * .3,
      accelerationPeak: 11.4 + (index % 3) * 1.8,
      gyroscopeMagnitude: .22 + (index % 4) * .08,
      predictedClass: DetectionClassification
          .values[index % DetectionClassification.values.length],
      confidence: .5,
      modelVersion: 'mock-demo-1.0',
      processingStatus: index == 7 ? 'Pending' : 'Processed',
    ),
  );
}

class AdminDetectionEventsScreen extends StatelessWidget {
  const AdminDetectionEventsScreen({
    super.key,
    this.dataSource = const MockAdminDetectionDataSource(),
  });

  final AdminDetectionDataSource dataSource;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(RoadSenseSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          context,
          'Detection Events',
          'Model predictions from sensor feature windows · DEMO DATA',
        ),
        const SizedBox(height: RoadSenseSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(RoadSenseSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: RoadSenseColors.teal),
                const SizedBox(width: RoadSenseSpacing.sm),
                Expanded(
                  child: Text(
                    'Predictions are model outputs only. They are not verified hazards.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: RoadSenseSpacing.md),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Timestamp')),
                DataColumn(label: Text('Location')),
                DataColumn(label: Text('Speed')),
                DataColumn(label: Text('Accel peak')),
                DataColumn(label: Text('Gyro magnitude')),
                DataColumn(label: Text('Predicted class')),
                DataColumn(label: Text('Confidence')),
                DataColumn(label: Text('Model')),
                DataColumn(label: Text('Status')),
              ],
              rows: dataSource.events
                  .map(
                    (event) => DataRow(
                      cells: [
                        DataCell(Text(_time(event.timestamp))),
                        DataCell(
                          Text(
                            '${event.latitude.toStringAsFixed(4)}, ${event.longitude.toStringAsFixed(4)}',
                          ),
                        ),
                        DataCell(
                          Text('${event.speedMps.toStringAsFixed(1)} m/s'),
                        ),
                        DataCell(
                          Text(event.accelerationPeak.toStringAsFixed(2)),
                        ),
                        DataCell(
                          Text(event.gyroscopeMagnitude.toStringAsFixed(2)),
                        ),
                        DataCell(
                          Text(classificationLabel(event.predictedClass)),
                        ),
                        DataCell(
                          Text(
                            '${(event.confidence * 100).toStringAsFixed(0)}%',
                          ),
                        ),
                        DataCell(Text(event.modelVersion)),
                        DataCell(Text(event.processingStatus)),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _heading(BuildContext context, String title, String subtitle) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const StatusIndicator(
                label: 'DEMO DATA',
                tone: StatusTone.warning,
              ),
            ],
          ),
          const SizedBox(height: RoadSenseSpacing.xs),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class ModelMetricSet {
  const ModelMetricSet({
    required this.accuracy,
    required this.precision,
    required this.recall,
    required this.f1,
  });

  final double? accuracy;
  final double? precision;
  final double? recall;
  final double? f1;

  bool get isAvailable =>
      accuracy != null || precision != null || recall != null || f1 != null;
}

class ModelPerformanceRecord {
  const ModelPerformanceRecord({
    required this.sensorInputs,
    required this.modelVersion,
    required this.evaluationDataset,
    required this.metrics,
  });

  final String sensorInputs;
  final String modelVersion;
  final String evaluationDataset;
  final ModelMetricSet metrics;
}

abstract interface class ModelPerformanceDataSource {
  List<ModelPerformanceRecord> get records;
}

class MockModelPerformanceDataSource implements ModelPerformanceDataSource {
  const MockModelPerformanceDataSource();

  @override
  List<ModelPerformanceRecord> get records => const [
    ModelPerformanceRecord(
      sensorInputs: 'Accelerometer',
      modelVersion: 'mock-demo-1.0',
      evaluationDataset: 'Not evaluated',
      metrics: ModelMetricSet(
        accuracy: null,
        precision: null,
        recall: null,
        f1: null,
      ),
    ),
    ModelPerformanceRecord(
      sensorInputs: 'Accelerometer + Gyroscope',
      modelVersion: 'mock-demo-1.0',
      evaluationDataset: 'Not evaluated',
      metrics: ModelMetricSet(
        accuracy: null,
        precision: null,
        recall: null,
        f1: null,
      ),
    ),
    ModelPerformanceRecord(
      sensorInputs: 'Accelerometer + Gyroscope + Speed',
      modelVersion: 'mock-demo-1.0',
      evaluationDataset: 'Not evaluated',
      metrics: ModelMetricSet(
        accuracy: null,
        precision: null,
        recall: null,
        f1: null,
      ),
    ),
  ];
}

class AdminModelPerformanceScreen extends StatelessWidget {
  const AdminModelPerformanceScreen({
    super.key,
    this.dataSource = const MockModelPerformanceDataSource(),
  });

  final ModelPerformanceDataSource dataSource;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(RoadSenseSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Model Performance',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const StatusIndicator(label: 'DEMO DATA', tone: StatusTone.warning),
          ],
        ),
        const SizedBox(height: RoadSenseSpacing.xs),
        Text(
          'Evaluation metrics will appear after a labeled evaluation dataset is available.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: RoadSenseSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(RoadSenseSpacing.md),
            child: Row(
              children: [
                const Icon(
                  Icons.fact_check_outlined,
                  color: RoadSenseColors.amber,
                ),
                const SizedBox(width: RoadSenseSpacing.sm),
                Expanded(
                  child: Text(
                    'Evaluation data not available. No accuracy, precision, recall, or F1 results are claimed.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: RoadSenseSpacing.md),
        ...dataSource.records.map((record) => _PerformanceCard(record: record)),
      ],
    ),
  );
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.record});

  final ModelPerformanceRecord record;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: RoadSenseSpacing.md),
    child: Padding(
      padding: const EdgeInsets.all(RoadSenseSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.sensorInputs,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: RoadSenseSpacing.xs),
          Text(
            '${record.modelVersion} · ${record.evaluationDataset}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Divider(height: RoadSenseSpacing.lg),
          Wrap(
            spacing: RoadSenseSpacing.lg,
            runSpacing: RoadSenseSpacing.sm,
            children: [
              _metric('Accuracy', record.metrics.accuracy),
              _metric('Precision', record.metrics.precision),
              _metric('Recall', record.metrics.recall),
              _metric('F1 score', record.metrics.f1),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _metric(String label, double? value) => SizedBox(
    width: 100,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: RoadSenseColors.muted, fontSize: 12),
        ),
        const SizedBox(height: RoadSenseSpacing.xs),
        Text(
          value == null
              ? 'Not available'
              : '${(value * 100).toStringAsFixed(1)}%',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
