import 'package:flutter/material.dart';

import 'design_system.dart';
import 'explore.dart';
import 'verification.dart';

class AdminClusterReview {
  AdminClusterReview({required this.cluster, required this.status});

  final CrowdCluster cluster;
  VerificationStatus status;
}

abstract interface class AdminVerificationDataSource {
  List<CrowdCluster> get clusters;
  VerificationRules get rules;
}

class MockAdminVerificationDataSource implements AdminVerificationDataSource {
  const MockAdminVerificationDataSource();

  static final _time = DateTime(2026, 10, 7, 10);

  @override
  VerificationRules get rules => const VerificationRules();

  @override
  List<CrowdCluster> get clusters => [
    CrowdCluster(
      id: 'cluster-possible',
      observations: [
        _observation('possible-1', 'usr-a7f2', 'trip-a', 1),
        _observation('possible-2', 'usr-a7f2', 'trip-a', 2),
      ],
    ),
    CrowdCluster(
      id: 'cluster-qualified',
      observations: [
        _observation('qualified-1', 'usr-a7f2', 'trip-a', 1),
        _observation('qualified-2', 'usr-b1c4', 'trip-b', 2),
        _observation('qualified-3', 'usr-c4d9', 'trip-c', 3),
        _observation('qualified-4', 'usr-d8e1', 'trip-d', 4),
        _observation('qualified-5', 'usr-e3f5', 'trip-e', 5),
        _observation('qualified-6', 'usr-f6a2', 'trip-f', 6),
        _observation('qualified-7', 'usr-a7f2', 'trip-a', 7),
        _observation('qualified-8', 'usr-b1c4', 'trip-b', 8),
      ],
    ),
  ];

  static HazardObservation _observation(
    String id,
    String user,
    String trip,
    int offset,
  ) => HazardObservation(
    id: id,
    segmentId: 'north',
    timestamp: _time.add(Duration(minutes: offset)),
    userId: user,
    tripId: trip,
    location: const RoadLocation(latitude: 51.503, longitude: -.12),
    type: HazardType.pothole,
    severity: HazardSeverity.high,
  );
}

class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({
    super.key,
    this.dataSource = const MockAdminVerificationDataSource(),
  });

  final AdminVerificationDataSource dataSource;

  @override
  State<AdminVerificationScreen> createState() =>
      _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  late final VerificationService _service;
  late final List<AdminClusterReview> _reviews;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _service = VerificationService(rules: widget.dataSource.rules);
    _reviews = widget.dataSource.clusters
        .map(
          (cluster) => AdminClusterReview(
            cluster: cluster,
            status: _service.toHazard(cluster).status,
          ),
        )
        .toList();
  }

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
                  'Crowd Verification',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: RoadSenseSpacing.xs),
                Text(
                  'Candidate clusters · DEMO DATA',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const StatusIndicator(
              label: 'AUDIT WORKSPACE',
              tone: StatusTone.warning,
            ),
          ],
        ),
        const SizedBox(height: RoadSenseSpacing.sm),
        Text(
          'Threshold: ${widget.dataSource.rules.minimumIndependentObservations} independent observations. Duplicate observations from one trip do not increase this count.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: RoadSenseSpacing.lg),
        ..._reviews.map(
          (review) => _ClusterCard(
            review: review,
            assessment: _service.assess(review.cluster),
            expanded: _expandedId == review.cluster.id,
            onExpand: () => setState(
              () => _expandedId = _expandedId == review.cluster.id
                  ? null
                  : review.cluster.id,
            ),
            onAction: (status) => setState(() => review.status = status),
            onMerge: () => _showMerge(context, review),
          ),
        ),
      ],
    ),
  );

  void _showMerge(BuildContext context, AdminClusterReview review) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Merge review queued for ${review.cluster.id}')),
    );
  }
}

class _ClusterCard extends StatelessWidget {
  const _ClusterCard({
    required this.review,
    required this.assessment,
    required this.expanded,
    required this.onExpand,
    required this.onAction,
    required this.onMerge,
  });

  final AdminClusterReview review;
  final VerificationAssessment assessment;
  final bool expanded;
  final VoidCallback onExpand;
  final ValueChanged<VerificationStatus> onAction;
  final VoidCallback onMerge;

  @override
  Widget build(BuildContext context) {
    final cluster = review.cluster;
    return Card(
      margin: const EdgeInsets.only(bottom: RoadSenseSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(RoadSenseSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cluster.type.name} · segment ${cluster.segmentId}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: RoadSenseSpacing.xs),
                      Text(
                        '${cluster.observationCount} observations · ${cluster.uniqueUserCount} users · ${cluster.uniqueTripCount} trips',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                StatusIndicator(
                  label: _statusLabel(review.status),
                  tone: review.status == VerificationStatus.verified
                      ? StatusTone.good
                      : review.status == VerificationStatus.rejected
                      ? StatusTone.error
                      : StatusTone.warning,
                ),
              ],
            ),
            const SizedBox(height: RoadSenseSpacing.md),
            Wrap(
              spacing: RoadSenseSpacing.lg,
              runSpacing: RoadSenseSpacing.sm,
              children: [
                _value(
                  'Confidence',
                  '${(assessment.confidence * 100).toStringAsFixed(0)}%',
                ),
                _value('Severity', cluster.observations.first.severity.name),
                _value('First observed', _time(cluster.firstObserved)),
                _value('Latest observed', _time(cluster.lastObserved)),
              ],
            ),
            const SizedBox(height: RoadSenseSpacing.md),
            Container(
              padding: const EdgeInsets.all(RoadSenseSpacing.sm),
              color: RoadSenseColors.canvas,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why this qualifies',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  ...assessment.reasons.map(
                    (reason) => Text(
                      '• $reason',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RoadSenseSpacing.sm),
            Wrap(
              spacing: RoadSenseSpacing.sm,
              children: [
                TextButton(
                  onPressed: onExpand,
                  child: Text(
                    expanded ? 'Hide observations' : 'View observations',
                  ),
                ),
                TextButton(onPressed: onMerge, child: const Text('Merge')),
                TextButton(
                  onPressed: () => _changeSeverity(context),
                  child: const Text('Change severity'),
                ),
                TextButton(
                  onPressed: () => onAction(VerificationStatus.rejected),
                  child: const Text('Reject'),
                ),
                FilledButton(
                  onPressed: assessment.qualifies
                      ? () => onAction(VerificationStatus.verified)
                      : null,
                  child: const Text('Verify'),
                ),
              ],
            ),
            if (expanded) ...[
              const Divider(),
              ...cluster.observations.map(
                (observation) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.radio_button_checked, size: 16),
                  title: Text(observation.id),
                  subtitle: Text(
                    'Internal user ${observation.userId} · trip ${observation.tripId} · ${_time(observation.timestamp)}',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _value(String label, String value) => SizedBox(
    width: 130,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: RoadSenseColors.muted),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Future<void> _changeSeverity(BuildContext context) async {
    final severity = await showDialog<HazardSeverity>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Change severity'),
        children: [
          for (final value in HazardSeverity.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(value.name),
            ),
        ],
      ),
    );
    if (severity != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Severity change queued: ${severity.name}')),
      );
    }
  }

  String _statusLabel(VerificationStatus status) => switch (status) {
    VerificationStatus.possible => 'Possible',
    VerificationStatus.underVerification => 'Under verification',
    VerificationStatus.verified => 'Verified',
    VerificationStatus.rejected => 'Rejected',
    VerificationStatus.resolved => 'Resolved',
  };
}

String _time(DateTime value) =>
    '${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
