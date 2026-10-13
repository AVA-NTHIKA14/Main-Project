import 'package:flutter/material.dart';

import 'auth.dart';
import 'admin_sensor_data.dart';
import 'admin_detection.dart';
import 'admin_verification.dart';
import 'admin_hazards.dart';
import 'design_system.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key, required this.authenticationService});

  final AuthenticationService authenticationService;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.authenticationService.signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      if (user.role != UserRole.administrator &&
          user.role != UserRole.researcher) {
        setState(
          () => _error = 'This account does not have admin or research access.',
        );
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => AdminDashboard(user: user)),
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Unable to sign in to the operations workspace.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF0F3F2),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Card(
          margin: const EdgeInsets.all(RoadSenseSpacing.lg),
          child: Padding(
            padding: const EdgeInsets.all(RoadSenseSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 40,
                  color: RoadSenseColors.teal,
                ),
                const SizedBox(height: RoadSenseSpacing.md),
                Text(
                  'RoadSense operations',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: RoadSenseSpacing.xs),
                Text(
                  'Administrator and researcher access',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: RoadSenseSpacing.lg),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Work email'),
                ),
                const SizedBox(height: RoadSenseSpacing.md),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: RoadSenseSpacing.md),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: RoadSenseColors.red),
                  ),
                ],
                const SizedBox(height: RoadSenseSpacing.lg),
                ElevatedButton(
                  onPressed: _busy ? null : _login,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Open dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AdminDashboardData {
  const AdminDashboardData({
    required this.sensorRecords,
    required this.activeTrips,
    required this.possibleHazards,
    required this.verifiedHazards,
    required this.resolvedHazards,
    required this.activeUsers,
  });

  final int sensorRecords;
  final int activeTrips;
  final int possibleHazards;
  final int verifiedHazards;
  final int resolvedHazards;
  final int activeUsers;
}

abstract interface class AdminDashboardDataSource {
  AdminDashboardData get overview;
}

class MockAdminDashboardDataSource implements AdminDashboardDataSource {
  const MockAdminDashboardDataSource();

  @override
  AdminDashboardData get overview => const AdminDashboardData(
    sensorRecords: 12840,
    activeTrips: 37,
    possibleHazards: 19,
    verifiedHazards: 6,
    resolvedHazards: 42,
    activeUsers: 214,
  );
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({
    super.key,
    required this.user,
    this.dataSource = const MockAdminDashboardDataSource(),
  });

  final RoadSenseUser user;
  final AdminDashboardDataSource dataSource;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final _pages = const [
    'Overview',
    'Sensor Data',
    'Detection Events',
    'Crowd Verification',
    'Hazards',
    'Dataset',
    'Model Performance',
    'Road Health',
    'Users',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final title = _pages[_selectedIndex];
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F2),
      appBar: AppBar(
        backgroundColor: RoadSenseColors.ink,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.alt_route, color: Color(0xFF83D1C6)),
            const SizedBox(width: RoadSenseSpacing.sm),
            Flexible(child: Text('RoadSense / $title', overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RoadSenseSpacing.md,
            ),
            child: Center(
              child: Text(
                widget.user.role == UserRole.researcher
                    ? 'RESEARCHER'
                    : 'ADMINISTRATOR',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB8DAD5),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: RoadSenseSpacing.md),
            child: Center(
              child: Text(
                'DEMO DATA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFFD28A),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: RoadSenseColors.surface,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            scrollable: true,
            destinations: [
              for (var index = 0; index < _pages.length; index++)
                NavigationRailDestination(
                  icon: Icon(_iconFor(index)),
                  selectedIcon: Icon(_iconFor(index)),
                  label: Text(_pages[index]),
                ),
            ],
          ),
          Expanded(
            child: _selectedIndex == 0
                ? _AdminOverview(data: widget.dataSource.overview)
                : _selectedIndex == 1
                ? const AdminSensorDataScreen()
                : _selectedIndex == 2
                ? const AdminDetectionEventsScreen()
                : _selectedIndex == 3
                ? const AdminVerificationScreen()
                : _selectedIndex == 4
                ? const AdminHazardsScreen()
                : _selectedIndex == 6
                ? const AdminModelPerformanceScreen()
                : _AdminPlaceholderPage(title: title),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(int index) => switch (index) {
    0 => Icons.dashboard_outlined,
    1 => Icons.sensors_outlined,
    2 => Icons.bolt_outlined,
    3 => Icons.hub_outlined,
    4 => Icons.warning_amber_outlined,
    5 => Icons.table_chart_outlined,
    6 => Icons.model_training_outlined,
    7 => Icons.map_outlined,
    8 => Icons.people_outline,
    _ => Icons.settings_outlined,
  };
}

class _AdminOverview extends StatelessWidget {
  const _AdminOverview({required this.data});

  final AdminDashboardData data;

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
                  'Overview',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: RoadSenseSpacing.xs),
                Text(
                  'Research and operations workspace',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const StatusIndicator(label: 'DEMO DATA', tone: StatusTone.warning),
          ],
        ),
        const SizedBox(height: RoadSenseSpacing.lg),
        Wrap(
          spacing: RoadSenseSpacing.md,
          runSpacing: RoadSenseSpacing.md,
          children: [
            _MetricTile(
              label: 'Sensor records',
              value: data.sensorRecords.toString(),
              icon: Icons.sensors_outlined,
            ),
            _MetricTile(
              label: 'Active trips',
              value: data.activeTrips.toString(),
              icon: Icons.route_outlined,
            ),
            _MetricTile(
              label: 'Possible hazards',
              value: data.possibleHazards.toString(),
              icon: Icons.help_outline,
            ),
            _MetricTile(
              label: 'Verified hazards',
              value: data.verifiedHazards.toString(),
              icon: Icons.verified_outlined,
            ),
            _MetricTile(
              label: 'Resolved hazards',
              value: data.resolvedHazards.toString(),
              icon: Icons.check_circle_outline,
            ),
            _MetricTile(
              label: 'Active users',
              value: data.activeUsers.toString(),
              icon: Icons.people_outline,
            ),
          ],
        ),
        const SizedBox(height: RoadSenseSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(RoadSenseSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification pipeline',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: RoadSenseSpacing.md),
                _PipelineRow(
                  label: 'Possible',
                  value: data.possibleHazards,
                  color: RoadSenseColors.amber,
                ),
                _PipelineRow(
                  label: 'Verified',
                  value: data.verifiedHazards,
                  color: RoadSenseColors.red,
                ),
                _PipelineRow(
                  label: 'Resolved',
                  value: data.resolvedHazards,
                  color: RoadSenseColors.teal,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(RoadSenseSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: RoadSenseColors.teal),
            const SizedBox(width: RoadSenseSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PipelineRow extends StatelessWidget {
  const _PipelineRow({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: RoadSenseSpacing.sm),
    child: Row(
      children: [
        SizedBox(width: 90, child: Text(label)),
        Expanded(
          child: LinearProgressIndicator(
            value: value / 50,
            color: color,
            backgroundColor: RoadSenseColors.line,
          ),
        ),
        const SizedBox(width: RoadSenseSpacing.md),
        Text(value.toString(), style: Theme.of(context).textTheme.labelLarge),
      ],
    ),
  );
}

class _AdminPlaceholderPage extends StatelessWidget {
  const _AdminPlaceholderPage({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.construction_outlined,
          size: 44,
          color: RoadSenseColors.muted,
        ),
        const SizedBox(height: RoadSenseSpacing.md),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: RoadSenseSpacing.sm),
        Text(
          'DEMO DATA · Workspace shell ready for integration',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}
