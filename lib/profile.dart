import 'package:flutter/material.dart';

import 'design_system.dart';
import 'permissions.dart';
import 'sync.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    this.name = 'RoadSense driver',
    this.email = 'driver@example.com',
  });

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) => Material(
    color: RoadSenseColors.canvas,
    child: ListView(
      padding: const EdgeInsets.all(RoadSenseSpacing.md),
      children: [
        Text('Profile', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: RoadSenseSpacing.lg),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: RoadSenseColors.tealSoft,
            child: Icon(Icons.person, color: RoadSenseColors.teal),
          ),
          title: Text(name, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(email),
        ),
        const SizedBox(height: RoadSenseSpacing.lg),
        Text(
          'Contribution summary',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: RoadSenseSpacing.sm),
        const _SummaryRow(
          icon: Icons.route_outlined,
          label: 'Trips',
          value: '2',
        ),
        const _SummaryRow(
          icon: Icons.flag_outlined,
          label: 'Reports',
          value: '1',
        ),
        const _SummaryRow(
          icon: Icons.verified_outlined,
          label: 'Verified contributions',
          value: '1',
        ),
        const SizedBox(height: RoadSenseSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Settings'),
        ),
      ],
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: RoadSenseColors.muted),
    title: Text(label),
    trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.permissionService, this.syncService});

  final PermissionService? permissionService;
  final SyncService? syncService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final PermissionService _permissionService;
  late final SyncService _syncService;
  bool _passiveSensing = true;
  bool _hazardAlerts = true;
  bool _reroutingAlerts = true;
  bool _offlineData = true;
  bool _pendingSync = true;
  String _cacheMessage = '';

  @override
  void initState() {
    super.initState();
    _permissionService =
        widget.permissionService ??
        MockPermissionService(
          initialStates: {
            PermissionType.location: PermissionState.granted,
            PermissionType.motion: PermissionState.granted,
          },
        );
    _syncService =
        widget.syncService ??
        SyncService(
          store: InMemoryPendingSyncStore(),
          backend: MockSyncBackend(),
        );
    _syncService.initialize();
  }

  Future<void> _request(PermissionType permission) async {
    await _permissionService.request(permission);
    if (mounted) setState(() {});
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This removes your RoadSense account request. Local data will also be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion requested')),
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(
        RoadSenseSpacing.md,
        0,
        RoadSenseSpacing.md,
        RoadSenseSpacing.lg,
      ),
      children: [
        _sectionTitle(context, 'Detection'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Passive sensing'),
          subtitle: const Text(
            'RoadSense observes road conditions while you travel normally.',
          ),
          value: _passiveSensing,
          onChanged: (value) => setState(() => _passiveSensing = value),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.tune_outlined),
          title: Text('Sensor preferences'),
          subtitle: Text(
            'Motion and location are used only for road insights.',
          ),
          trailing: Icon(Icons.chevron_right),
        ),
        _sectionTitle(context, 'Privacy'),
        _PermissionTile(
          permission: PermissionType.location,
          service: _permissionService,
          title: 'Location permissions',
          onRequest: _request,
        ),
        _PermissionTile(
          permission: PermissionType.motion,
          service: _permissionService,
          title: 'Motion sensors',
          onRequest: _request,
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline),
          title: Text('Data sharing'),
          subtitle: Text(
            'Your individual trip is not displayed publicly. Shared road insights are reviewed in aggregate.',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_outline, color: RoadSenseColors.red),
          title: const Text('Delete account'),
          subtitle: const Text(
            'Request removal of your account and associated data.',
          ),
          onTap: _deleteAccount,
        ),
        _sectionTitle(context, 'Notifications'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hazard alerts'),
          subtitle: const Text('Get alerts for sufficiently verified hazards.'),
          value: _hazardAlerts,
          onChanged: (value) => setState(() => _hazardAlerts = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Rerouting alerts'),
          subtitle: const Text(
            'Be notified when a safer alternative route is available.',
          ),
          value: _reroutingAlerts,
          onChanged: (value) => setState(() => _reroutingAlerts = value),
        ),
        _sectionTitle(context, 'Data & storage'),
        Align(
          alignment: Alignment.centerLeft,
          child: SyncStatusIndicator(service: _syncService),
        ),
        const SizedBox(height: RoadSenseSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Offline data'),
          subtitle: const Text(
            'Keep recent trip information available without a connection.',
          ),
          value: _offlineData,
          onChanged: (value) => setState(() => _offlineData = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pending synchronization'),
          subtitle: const Text(
            'Allow locally buffered observations to sync when possible.',
          ),
          value: _pendingSync,
          onChanged: (value) => setState(() => _pendingSync = value),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('Clear local cache'),
          subtitle: Text(
            _cacheMessage.isEmpty
                ? 'Remove buffered local data from this device.'
                : _cacheMessage,
          ),
          onTap: () => setState(() => _cacheMessage = 'Local cache cleared'),
        ),
        _sectionTitle(context, 'About'),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('RoadSense'),
          subtitle: Text(
            'A research project for understanding road conditions.',
          ),
          trailing: Text('v1.0.0'),
        ),
      ],
    ),
  );

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(
      top: RoadSenseSpacing.lg,
      bottom: RoadSenseSpacing.sm,
    ),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.permission,
    required this.service,
    required this.title,
    required this.onRequest,
  });
  final PermissionType permission;
  final PermissionService service;
  final String title;
  final Future<void> Function(PermissionType) onRequest;

  @override
  Widget build(BuildContext context) => FutureBuilder<PermissionState>(
    future: service.status(permission),
    builder: (context, snapshot) {
      final state = snapshot.data ?? PermissionState.notRequested;
      final canRequest =
          state == PermissionState.notRequested ||
          state == PermissionState.denied;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.shield_outlined),
        title: Text(title),
        subtitle: Text(permissionStateLabel(state)),
        trailing: canRequest
            ? TextButton(
                onPressed: () => onRequest(permission),
                child: const Text('Allow'),
              )
            : null,
      );
    },
  );
}
