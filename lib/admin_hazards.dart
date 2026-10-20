import 'package:flutter/material.dart';

import 'design_system.dart';
import 'explore.dart';

class AdminHazardRecord {
  AdminHazardRecord({required this.hazard, required this.area});

  Hazard hazard;
  final String area;
}

abstract interface class AdminHazardDataSource {
  List<AdminHazardRecord> get hazards;
  List<RoadSegment> get segments;
}

class MockAdminHazardDataSource implements AdminHazardDataSource {
  const MockAdminHazardDataSource();

  @override
  List<RoadSegment> get segments => const MockRoadMapDataSource().segments;

  @override
  List<AdminHazardRecord> get hazards => const MockRoadMapDataSource().hazards
      .map(
        (hazard) => AdminHazardRecord(hazard: hazard, area: 'North district'),
      )
      .toList();
}

class AdminHazardsScreen extends StatefulWidget {
  const AdminHazardsScreen({
    super.key,
    this.dataSource = const MockAdminHazardDataSource(),
  });

  final AdminHazardDataSource dataSource;

  @override
  State<AdminHazardsScreen> createState() => _AdminHazardsScreenState();
}

class _AdminHazardsScreenState extends State<AdminHazardsScreen> {
  VerificationStatus? _status;
  HazardSeverity? _severity;
  HazardType? _type;
  String? _area;
  String _dateFilter = 'All dates';
  String? _selectedId;
  late final List<AdminHazardRecord> _records;

  @override
  void initState() {
    super.initState();
    _records = widget.dataSource.hazards
        .map(
          (record) =>
              AdminHazardRecord(hazard: record.hazard, area: record.area),
        )
        .toList();
  }

  List<AdminHazardRecord> get _filtered => _records.where((record) {
    final hazard = record.hazard;
    return (_status == null || hazard.status == _status) &&
        (_severity == null || hazard.severity == _severity) &&
        (_type == null || hazard.type == _type) &&
        (_area == null || record.area == _area) &&
        (_dateFilter == 'All dates' ||
            (_dateFilter == 'Today' && hazard.lastObserved.day == 7));
  }).toList();

  @override
  Widget build(BuildContext context) {
    final records = _filtered;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(RoadSenseSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: RoadSenseSpacing.md,
            runSpacing: RoadSenseSpacing.sm,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hazards',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: RoadSenseSpacing.xs),
                  Text(
                    'Segment-level hazard management · DEMO DATA',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const StatusIndicator(
                label: 'DEMO DATA',
                tone: StatusTone.warning,
              ),
            ],
          ),
          const SizedBox(height: RoadSenseSpacing.lg),
          _filters(context),
          const SizedBox(height: RoadSenseSpacing.md),
          SizedBox(
            height: 260,
            child: Card(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(RoadSenseRadius.md),
                child: RoadMapCanvas(
                  segments: widget.dataSource.segments,
                  hazards: records.map((record) => record.hazard).toList(),
                  selectedHazardId: _selectedId,
                  zoom: 1,
                  recentered: false,
                  onHazardSelected: (id) => setState(() => _selectedId = id),
                ),
              ),
            ),
          ),
          const SizedBox(height: RoadSenseSpacing.md),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Hazard')),
                  DataColumn(label: Text('Location')),
                  DataColumn(label: Text('Severity')),
                  DataColumn(label: Text('Confidence')),
                  DataColumn(label: Text('Observations')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('First observed')),
                  DataColumn(label: Text('Last observed')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: records.map((record) => _row(context, record)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(RoadSenseSpacing.md),
      child: Wrap(
        spacing: RoadSenseSpacing.md,
        runSpacing: RoadSenseSpacing.sm,
        children: [
          _dropdown<VerificationStatus>(
            'Status',
            _status,
            VerificationStatus.values,
            (value) => setState(() => _status = value),
            _statusLabel,
          ),
          _dropdown<HazardSeverity>(
            'Severity',
            _severity,
            HazardSeverity.values,
            (value) => setState(() => _severity = value),
            (value) => value.name,
          ),
          _dropdown<HazardType>(
            'Hazard type',
            _type,
            HazardType.values,
            (value) => setState(() => _type = value),
            (value) => value.name,
          ),
          _dropdown<String>(
            'Road area',
            _area,
            const ['North district'],
            (value) => setState(() => _area = value),
            (value) => value,
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: _dateFilter,
              decoration: const InputDecoration(labelText: 'Date'),
              items: const [
                DropdownMenuItem(value: 'All dates', child: Text('All dates')),
                DropdownMenuItem(value: 'Today', child: Text('Today')),
              ],
              onChanged: (value) =>
                  setState(() => _dateFilter = value ?? 'All dates'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _dropdown<T>(
    String label,
    T? value,
    List<T> values,
    ValueChanged<T?> onChanged,
    String Function(T) text,
  ) => SizedBox(
    width: 170,
    child: DropdownButtonFormField<T>(
      isExpanded: true,
      value: value,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<T>(
          value: null,
          child: Text('All $label'.toLowerCase()),
        ),
        ...values.map(
          (item) => DropdownMenuItem<T>(value: item, child: Text(text(item))),
        ),
      ],
      onChanged: onChanged,
    ),
  );

  DataRow _row(BuildContext context, AdminHazardRecord record) {
    final hazard = record.hazard;
    return DataRow(
      selected: hazard.id == _selectedId,
      cells: [
        DataCell(Text(hazard.type.name)),
        DataCell(
          Text(
            '${hazard.location.latitude.toStringAsFixed(4)}, ${hazard.location.longitude.toStringAsFixed(4)}\n${hazard.segmentId}',
          ),
        ),
        DataCell(Text(hazard.severity.name)),
        DataCell(Text('${(hazard.confidence * 100).toStringAsFixed(0)}%')),
        DataCell(Text('${hazard.observationCount}')),
        DataCell(Text(_statusLabel(hazard.status))),
        DataCell(Text(_date(hazard.firstObserved))),
        DataCell(Text(_date(hazard.lastObserved))),
        DataCell(
          Row(
            children: [
              IconButton(
                tooltip: 'Verify',
                onPressed: () =>
                    _setStatus(record, VerificationStatus.verified),
                icon: const Icon(Icons.verified_outlined),
              ),
              IconButton(
                tooltip: 'Reject',
                onPressed: () =>
                    _setStatus(record, VerificationStatus.rejected),
                icon: const Icon(Icons.block_outlined),
              ),
              IconButton(
                tooltip: 'Merge',
                onPressed: () => _message('Merge queued'),
                icon: const Icon(Icons.merge_outlined),
              ),
              IconButton(
                tooltip: 'Change severity',
                onPressed: () => _changeSeverity(record),
                icon: const Icon(Icons.tune),
              ),
              IconButton(
                tooltip: 'Mark resolved',
                onPressed: () =>
                    _setStatus(record, VerificationStatus.resolved),
                icon: const Icon(Icons.check_circle_outline),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _setStatus(AdminHazardRecord record, VerificationStatus status) {
    setState(
      () => record.hazard = Hazard(
        id: record.hazard.id,
        segmentId: record.hazard.segmentId,
        severity: record.hazard.severity,
        observations: record.hazard.observations,
        status: status,
        type: record.hazard.type,
        location: record.hazard.location,
        confidence: record.hazard.confidence,
        firstObserved: record.hazard.firstObserved,
        lastObserved: record.hazard.lastObserved,
        distanceLabel: record.hazard.distanceLabel,
      ),
    );
    _message('Status changed to ${_statusLabel(status)}');
  }

  Future<void> _changeSeverity(AdminHazardRecord record) async {
    final value = await showDialog<HazardSeverity>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Change severity'),
        children: [
          for (final severity in HazardSeverity.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, severity),
              child: Text(severity.name),
            ),
        ],
      ),
    );
    if (value != null && mounted) {
      final old = record.hazard;
      setState(
        () => record.hazard = Hazard(
          id: old.id,
          segmentId: old.segmentId,
          severity: value,
          observations: old.observations,
          status: old.status,
          type: old.type,
          location: old.location,
          confidence: old.confidence,
          firstObserved: old.firstObserved,
          lastObserved: old.lastObserved,
          distanceLabel: old.distanceLabel,
        ),
      );
      _message('Severity changed to ${value.name}');
    }
  }

  void _message(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
  String _statusLabel(VerificationStatus value) => switch (value) {
    VerificationStatus.possible => 'Possible',
    VerificationStatus.underVerification => 'Under verification',
    VerificationStatus.verified => 'Verified',
    VerificationStatus.rejected => 'Rejected',
    VerificationStatus.resolved => 'Resolved',
  };
  String _date(DateTime value) =>
      '${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
