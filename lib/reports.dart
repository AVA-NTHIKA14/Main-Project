import 'package:flutter/material.dart';

import 'design_system.dart';
import 'explore.dart';

class UserReport {
  const UserReport({
    required this.id,
    required this.userId,
    required this.tripId,
    required this.category,
    required this.location,
    required this.severity,
    required this.submittedAt,
    this.description,
    this.photoPath,
  });

  final String id;
  final String userId;
  final String tripId;
  final ReportCategory category;
  final RoadLocation location;
  final HazardSeverity severity;
  final DateTime submittedAt;
  final String? description;
  final String? photoPath;

  HazardObservation toObservation() => HazardObservation(
    id: id,
    segmentId: 'unmatched',
    timestamp: submittedAt,
    userId: userId,
    tripId: tripId,
    location: location,
    type: category.hazardType,
    severity: HazardSeverity.possible,
  );
}

enum ReportCategory {
  pothole,
  speedBreaker,
  roughRoad,
  roadCrack,
  openManhole,
  waterlogging,
  debris,
  other,
}

extension ReportCategoryLabel on ReportCategory {
  String get label => switch (this) {
    ReportCategory.pothole => 'Pothole',
    ReportCategory.speedBreaker => 'Speed breaker',
    ReportCategory.roughRoad => 'Rough road',
    ReportCategory.roadCrack => 'Road crack',
    ReportCategory.openManhole => 'Open manhole',
    ReportCategory.waterlogging => 'Waterlogging',
    ReportCategory.debris => 'Debris',
    ReportCategory.other => 'Other',
  };

  HazardType get hazardType => switch (this) {
    ReportCategory.pothole => HazardType.pothole,
    ReportCategory.roughRoad => HazardType.roughSurface,
    ReportCategory.debris => HazardType.debris,
    _ => HazardType.unknown,
  };
}

abstract interface class ReportRepository {
  Future<UserReport> submit(UserReport report);
  Future<List<UserReport>> reportsForUser(String userId);
}

class InMemoryReportRepository implements ReportRepository {
  final List<UserReport> _reports = [];

  @override
  Future<UserReport> submit(UserReport report) async {
    _reports.add(report);
    return report;
  }

  @override
  Future<List<UserReport>> reportsForUser(String userId) async =>
      List.unmodifiable(_reports.where((report) => report.userId == userId));
}

class ManualReportFlow extends StatefulWidget {
  const ManualReportFlow({
    super.key,
    required this.repository,
    required this.location,
  });

  final ReportRepository repository;
  final RoadLocation location;

  @override
  State<ManualReportFlow> createState() => _ManualReportFlowState();
}

class _ManualReportFlowState extends State<ManualReportFlow> {
  int _step = 0;
  ReportCategory? _category;
  HazardSeverity _severity = HazardSeverity.moderate;
  String? _photoPath;
  final _description = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  bool get _validLocation =>
      widget.location.latitude >= -90 &&
      widget.location.latitude <= 90 &&
      widget.location.longitude >= -180 &&
      widget.location.longitude <= 180;

  Future<void> _submit() async {
    if (!_validLocation || _category == null) return;
    setState(() => _submitting = true);
    final report = UserReport(
      id: 'report-${DateTime.now().microsecondsSinceEpoch}',
      userId: 'current-user',
      tripId: 'current-trip',
      category: _category!,
      location: widget.location,
      severity: _severity,
      submittedAt: DateTime.now(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      photoPath: _photoPath,
    );
    await widget.repository.submit(report);
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop(true);
  }

  void _next() {
    if (_step == 0 && _category == null) {
      setState(() => _error = 'Select a hazard type to continue.');
      return;
    }
    if (_step == 1 && !_validLocation) {
      setState(() => _error = 'We could not validate this location.');
      return;
    }
    setState(() {
      _error = null;
      _step++;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Report a hazard'),
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Close report',
        icon: const Icon(Icons.close),
      ),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(RoadSenseSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Step ${_step + 1} of 4',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: RoadSenseSpacing.sm),
            LinearProgressIndicator(value: (_step + 1) / 4),
            const SizedBox(height: RoadSenseSpacing.lg),
            Expanded(child: _content()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: RoadSenseSpacing.sm),
                child: Text(
                  _error!,
                  style: const TextStyle(color: RoadSenseColors.red),
                ),
              ),
            if (_step < 3)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: const Text('Continue'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit report'),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _content() => switch (_step) {
    0 => _categoryStep(),
    1 => _locationStep(),
    2 => _severityStep(),
    _ => _detailsStep(),
  };

  Widget _categoryStep() => ListView(
    children: [
      Text(
        'What did you notice?',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: RoadSenseSpacing.sm),
      Text(
        'A report helps the community review a possible road issue.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: RoadSenseSpacing.md),
      RadioGroup<ReportCategory>(
        groupValue: _category,
        onChanged: (value) => setState(() => _category = value),
        child: Column(
          children: ReportCategory.values
              .map(
                (category) => RadioListTile<ReportCategory>(
                  value: category,
                  title: Text(category.label),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );

  Widget _locationStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Confirm location', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: RoadSenseSpacing.sm),
      Text(
        'We will attach this report to your current map location.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: RoadSenseSpacing.lg),
      Container(
        height: 180,
        decoration: BoxDecoration(
          color: RoadSenseColors.tealSoft,
          borderRadius: BorderRadius.circular(RoadSenseRadius.lg),
        ),
        child: const Center(
          child: Icon(Icons.location_on, color: RoadSenseColors.teal, size: 42),
        ),
      ),
      const SizedBox(height: RoadSenseSpacing.md),
      Row(
        children: [
          const Icon(Icons.my_location_outlined, color: RoadSenseColors.teal),
          const SizedBox(width: RoadSenseSpacing.sm),
          Text(
            '${widget.location.latitude.toStringAsFixed(4)}, ${widget.location.longitude.toStringAsFixed(4)}',
          ),
        ],
      ),
      if (!_validLocation)
        const Padding(
          padding: EdgeInsets.only(top: RoadSenseSpacing.sm),
          child: Text(
            'Location unavailable',
            style: TextStyle(color: RoadSenseColors.red),
          ),
        ),
    ],
  );

  Widget _severityStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('How serious is it?', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: RoadSenseSpacing.sm),
      Text(
        'This is your estimate. Other observations are needed before verification.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: RoadSenseSpacing.md),
      RadioGroup<HazardSeverity>(
        groupValue: _severity,
        onChanged: (value) =>
            setState(() => _severity = value ?? HazardSeverity.moderate),
        child: Column(
          children:
              [
                    HazardSeverity.possible,
                    HazardSeverity.moderate,
                    HazardSeverity.high,
                  ]
                  .map(
                    (severity) => RadioListTile<HazardSeverity>(
                      value: severity,
                      title: Text(_severityLabel(severity)),
                    ),
                  )
                  .toList(),
        ),
      ),
    ],
  );

  Widget _detailsStep() => ListView(
    children: [
      Text('Add details', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: RoadSenseSpacing.sm),
      Text(
        'Photos and notes are optional. Please report only when safely stopped.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: RoadSenseSpacing.md),
      TextField(
        controller: _description,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Description (optional)',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: RoadSenseSpacing.md),
      OutlinedButton.icon(
        onPressed: () => setState(
          () => _photoPath = _photoPath == null ? 'pending-photo' : null,
        ),
        icon: Icon(
          _photoPath == null ? Icons.add_a_photo_outlined : Icons.check,
        ),
        label: Text(
          _photoPath == null ? 'Add photo (optional)' : 'Photo added',
        ),
      ),
    ],
  );

  String _severityLabel(HazardSeverity severity) => switch (severity) {
    HazardSeverity.possible => 'Possible issue',
    HazardSeverity.moderate => 'Moderate',
    HazardSeverity.high => 'High severity',
  };
}

Future<bool?> showManualReport(
  BuildContext context, {
  required ReportRepository repository,
  RoadLocation location = const RoadLocation(
    latitude: 51.501,
    longitude: -.121,
  ),
}) => Navigator.of(context).push<bool>(
  MaterialPageRoute(
    builder: (_) =>
        ManualReportFlow(repository: repository, location: location),
  ),
);
