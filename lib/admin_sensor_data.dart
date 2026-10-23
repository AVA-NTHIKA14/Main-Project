import 'package:flutter/material.dart';

import 'design_system.dart';
import 'sensors.dart';

enum SensorViewMode { raw, processed, featureWindows }

enum SensorChannel { accelerometer, gyroscope, gps }

class AdminSensorRecord {
  const AdminSensorRecord({
    required this.id,
    required this.userId,
    required this.tripId,
    required this.timestamp,
    required this.accelerometer,
    required this.gyroscope,
    required this.gps,
    required this.processingStatus,
  });

  final String id;
  final String userId;
  final String tripId;
  final DateTime timestamp;
  final Vector3 accelerometer;
  final Vector3 gyroscope;
  final GpsReading gps;
  final String processingStatus;
}

class AdminFeatureWindow {
  const AdminFeatureWindow({
    required this.id,
    required this.tripId,
    required this.start,
    required this.end,
    required this.sampleCount,
    required this.accelerationMagnitude,
    required this.gyroscopeMagnitude,
    required this.status,
  });

  final String id;
  final String tripId;
  final DateTime start;
  final DateTime end;
  final int sampleCount;
  final double accelerationMagnitude;
  final double gyroscopeMagnitude;
  final String status;
}

abstract interface class AdminSensorDataSource {
  List<String> get tripIds;
  List<AdminSensorRecord> get records;
  List<AdminFeatureWindow> get featureWindows;
}

class MockAdminSensorDataSource implements AdminSensorDataSource {
  const MockAdminSensorDataSource();

  static final _base = DateTime(2026, 10, 7, 10);

  @override
  List<String> get tripIds => const ['trip-2026-10-07-a', 'trip-2026-10-07-b'];

  @override
  List<AdminSensorRecord> get records => List.generate(12, (index) {
    final time = _base.add(Duration(seconds: index * 5));
    return AdminSensorRecord(
      id: 'record-${index + 1}',
      userId: 'usr-a7f2',
      tripId: tripIds[index.isEven ? 0 : 1],
      timestamp: time,
      accelerometer: Vector3(
        0.4 + (index % 4) * .7,
        -0.2 + index * .03,
        9.6 + (index % 3) * .2,
      ),
      gyroscope: Vector3(.02 * index, .08 + (index % 3) * .04, -.01),
      gps: GpsReading(
        latitude: 51.500 + index * .0004,
        longitude: -.120 - index * .0003,
        accuracy: 4.2,
        speedMps: 8.4 + index * .2,
        timestamp: time,
      ),
      processingStatus: index < 9 ? 'Processed' : 'Pending',
    );
  });

  @override
  List<AdminFeatureWindow> get featureWindows => List.generate(4, (index) {
    final start = _base.add(Duration(seconds: index * 15));
    return AdminFeatureWindow(
      id: 'window-${index + 1}',
      tripId: tripIds[index.isEven ? 0 : 1],
      start: start,
      end: start.add(const Duration(seconds: 15)),
      sampleCount: 20,
      accelerationMagnitude: 9.8 + index * .6,
      gyroscopeMagnitude: .18 + index * .04,
      status: index == 3 ? 'Queued' : 'Ready',
    );
  });
}

class AdminSensorDataScreen extends StatefulWidget {
  const AdminSensorDataScreen({
    super.key,
    this.dataSource = const MockAdminSensorDataSource(),
  });

  final AdminSensorDataSource dataSource;

  @override
  State<AdminSensorDataScreen> createState() => _AdminSensorDataScreenState();
}

class _AdminSensorDataScreenState extends State<AdminSensorDataScreen> {
  SensorViewMode _mode = SensorViewMode.raw;
  SensorChannel _channel = SensorChannel.accelerometer;
  String? _tripId;
  double _timeline = 1;

  List<AdminSensorRecord> get _records => widget.dataSource.records
      .where((record) => _tripId == null || record.tripId == _tripId)
      .toList();
  List<AdminFeatureWindow> get _windows => widget.dataSource.featureWindows
      .where((window) => _tripId == null || window.tripId == _tripId)
      .toList();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(RoadSenseSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sensor Data',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: RoadSenseSpacing.xs),
                Text(
                  'Research inspection workspace · DEMO DATA',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const StatusIndicator(label: 'DEMO DATA', tone: StatusTone.warning),
          ],
        ),
        const SizedBox(height: RoadSenseSpacing.lg),
        _filters(context),
        const SizedBox(height: RoadSenseSpacing.md),
        _modeSelector(context),
        const SizedBox(height: RoadSenseSpacing.md),
        if (_mode == SensorViewMode.featureWindows)
          _featureWindowView(context)
        else
          _signalView(context),
      ],
    ),
  );

  Widget _filters(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(RoadSenseSpacing.md),
      child: Wrap(
        spacing: RoadSenseSpacing.md,
        runSpacing: RoadSenseSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 230,
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _tripId,
              decoration: const InputDecoration(labelText: 'Trip selection'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All trips'),
                ),
                ...widget.dataSource.tripIds.map(
                  (id) => DropdownMenuItem<String?>(value: id, child: Text(id)),
                ),
              ],
              onChanged: (value) => setState(() => _tripId = value),
            ),
          ),
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<SensorChannel>(
              isExpanded: true,
              initialValue: _channel,
              decoration: const InputDecoration(labelText: 'Sensor selection'),
              items: SensorChannel.values
                  .map(
                    (channel) => DropdownMenuItem(
                      value: channel,
                      child: Text(_channelLabel(channel)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(
                () => _channel = value ?? SensorChannel.accelerometer,
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timeline: ${(_timeline * 100).round()}%',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Slider(
                  value: _timeline,
                  onChanged: (value) => setState(() => _timeline = value),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _modeSelector(BuildContext context) => SegmentedButton<SensorViewMode>(
    segments: const [
      ButtonSegment(value: SensorViewMode.raw, label: Text('Raw data')),
      ButtonSegment(
        value: SensorViewMode.processed,
        label: Text('Processed data'),
      ),
      ButtonSegment(
        value: SensorViewMode.featureWindows,
        label: Text('Feature windows'),
      ),
    ],
    selected: {_mode},
    onSelectionChanged: (value) => setState(() => _mode = value.first),
  );

  Widget _signalView(BuildContext context) {
    final records = _records;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(RoadSenseSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _mode == SensorViewMode.raw
                      ? 'Raw signal timeline'
                      : 'Processed signal timeline',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: RoadSenseSpacing.xs),
                Text(
                  _mode == SensorViewMode.raw
                      ? 'Directly buffered sensor samples.'
                      : 'Samples after synchronization and orientation handling.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: RoadSenseSpacing.md),
                SizedBox(
                  height: 180,
                  child: CustomPaint(
                    painter: _SignalPainter(
                      records: records,
                      channel: _channel,
                      processed: _mode == SensorViewMode.processed,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: RoadSenseSpacing.md),
        _recordsTable(context, records),
      ],
    );
  }

  Widget _recordsTable(BuildContext context, List<AdminSensorRecord> records) =>
      Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(RoadSenseSpacing.md),
              child: Text(
                'Record metadata',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Timestamp')),
                  DataColumn(label: Text('Internal user')),
                  DataColumn(label: Text('Trip ID')),
                  DataColumn(label: Text('X / Lat')),
                  DataColumn(label: Text('Y / Long')),
                  DataColumn(label: Text('Z / Speed')),
                  DataColumn(label: Text('Accuracy')),
                  DataColumn(label: Text('Status')),
                ],
                rows: records
                    .map(
                      (record) => DataRow(
                        cells: [
                          DataCell(Text(_time(record.timestamp))),
                          DataCell(Text(record.userId)),
                          DataCell(Text(record.tripId)),
                          DataCell(Text(_xOrLat(record))),
                          DataCell(Text(_yOrLong(record))),
                          DataCell(Text(_zOrSpeed(record))),
                          DataCell(
                            Text('${record.gps.accuracy.toStringAsFixed(1)} m'),
                          ),
                          DataCell(Text(record.processingStatus)),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      );

  Widget _featureWindowView(BuildContext context) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(RoadSenseSpacing.md),
          child: Text(
            'Feature windows',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const Divider(height: 1),
        ..._windows.map(
          (window) => ListTile(
            leading: const Icon(
              Icons.auto_graph_outlined,
              color: RoadSenseColors.teal,
            ),
            title: Text(window.id),
            subtitle: Text(
              '${window.sampleCount} samples · acceleration ${window.accelerationMagnitude.toStringAsFixed(2)} · gyro ${window.gyroscopeMagnitude.toStringAsFixed(2)}',
            ),
            trailing: Text(window.status),
          ),
        ),
      ],
    ),
  );

  String _channelLabel(SensorChannel channel) => switch (channel) {
    SensorChannel.accelerometer => 'Accelerometer',
    SensorChannel.gyroscope => 'Gyroscope',
    SensorChannel.gps => 'GPS',
  };
  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
  String _xOrLat(AdminSensorRecord record) => _channel == SensorChannel.gps
      ? record.gps.latitude.toStringAsFixed(5)
      : (_channel == SensorChannel.accelerometer
                ? record.accelerometer.x
                : record.gyroscope.x)
            .toStringAsFixed(3);
  String _yOrLong(AdminSensorRecord record) => _channel == SensorChannel.gps
      ? record.gps.longitude.toStringAsFixed(5)
      : (_channel == SensorChannel.accelerometer
                ? record.accelerometer.y
                : record.gyroscope.y)
            .toStringAsFixed(3);
  String _zOrSpeed(AdminSensorRecord record) => _channel == SensorChannel.gps
      ? '${record.gps.speedMps.toStringAsFixed(1)} m/s'
      : (_channel == SensorChannel.accelerometer
                ? record.accelerometer.z
                : record.gyroscope.z)
            .toStringAsFixed(3);
}

class _SignalPainter extends CustomPainter {
  const _SignalPainter({
    required this.records,
    required this.channel,
    required this.processed,
  });
  final List<AdminSensorRecord> records;
  final SensorChannel channel;
  final bool processed;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF7F9F8),
    );
    final grid = Paint()
      ..color = RoadSenseColors.line
      ..strokeWidth = 1;
    for (var index = 1; index < 5; index++) {
      canvas.drawLine(
        Offset(0, size.height * index / 5),
        Offset(size.width, size.height * index / 5),
        grid,
      );
    }
    if (records.length < 2) return;
    final paths = [Path(), Path(), Path()];
    for (var index = 0; index < records.length; index++) {
      final x = index / (records.length - 1) * size.width;
      final values = _values(records[index]);
      for (var axis = 0; axis < 3; axis++) {
        final normalized = ((values[axis] / (processed ? 12 : 15)) + 1) / 2;
        final point = Offset(x, size.height * (1 - normalized.clamp(0, 1)));
        if (index == 0) {
          paths[axis].moveTo(point.dx, point.dy);
        } else {
          paths[axis].lineTo(point.dx, point.dy);
        }
      }
    }
    final colors = [
      RoadSenseColors.teal,
      RoadSenseColors.amber,
      RoadSenseColors.red,
    ];
    for (var index = 0; index < paths.length; index++) {
      canvas.drawPath(
        paths[index],
        Paint()
          ..color = colors[index]
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  List<double> _values(AdminSensorRecord record) => switch (channel) {
    SensorChannel.accelerometer => [
      record.accelerometer.x,
      record.accelerometer.y,
      record.accelerometer.z,
    ],
    SensorChannel.gyroscope => [
      record.gyroscope.x,
      record.gyroscope.y,
      record.gyroscope.z,
    ],
    SensorChannel.gps => [
      record.gps.latitude - 51.5,
      record.gps.longitude + .12,
      record.gps.speedMps,
    ],
  };

  @override
  bool shouldRepaint(covariant _SignalPainter oldDelegate) =>
      oldDelegate.channel != channel ||
      oldDelegate.records != records ||
      oldDelegate.processed != processed;
}
