
import 'package:flutter/material.dart';

import 'auth.dart';
import 'auth_screens.dart';
import 'admin.dart';
import 'design_system.dart';
import 'onboarding.dart';
import 'navigation_services.dart';
import 'permissions.dart';
import 'profile.dart';
import 'route_planning.dart';
import 'trips.dart';

void main() {
  runApp(const RoadSenseApp());
}

class RoadSenseApp extends StatefulWidget {
  const RoadSenseApp({
    super.key,
    this.authenticationService,
    this.permissionService,
  });

  final AuthenticationService? authenticationService;
  final PermissionService? permissionService;

  @override
  State<RoadSenseApp> createState() => _RoadSenseAppState();
}

class _RoadSenseAppState extends State<RoadSenseApp> {
  late final AuthController _authController;
  late final AuthenticationService _authenticationService;

  @override
  void initState() {
    super.initState();

    _authenticationService =
        widget.authenticationService ?? MockAuthenticationService();

    _authController = AuthController(
      service: _authenticationService,
    );
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoadSense',
      theme: buildRoadSenseTheme(),
      home: AuthGate(
        controller: _authController,
        homeBuilder: () => OnboardingGate(
          permissionService:
              widget.permissionService ?? MockPermissionService(),
          homeBuilder: () => RoadSenseShell(
            authenticationService: _authenticationService,
          ),
        ),
      ),
    );
  }
}

class RoadSenseShell extends StatefulWidget {
  const RoadSenseShell({
    super.key,
    required this.authenticationService,
  });

  final AuthenticationService authenticationService;

  @override
  State<RoadSenseShell> createState() => _RoadSenseShellState();
}

class _RoadSenseShellState extends State<RoadSenseShell> {
  int _selectedIndex = 0;

  late final NominatimPlaceSearchService _placeSearchService;
  late final OsrmRouteCalculationService _routeCalculationService;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _placeSearchService = NominatimPlaceSearchService();
    _routeCalculationService = OsrmRouteCalculationService();

    _pages = [
      RoutePlanningScreen(
        placeSearchService: _placeSearchService,
        routeCalculationService: _routeCalculationService,
        recentPlaceStore: RecentPlaceStore(),
      ),
      const _SavedPage(),
      const _TripsPage(),
      const _ProfilePage(),
    ];
  }

  @override
  void dispose() {
    _placeSearchService.close();
    _routeCalculationService.close();
    super.dispose();
  }

  void _showAdminOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'RoadSense Admin',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose an option to access the operations workspace.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('Preview Admin Dashboard'),
                onPressed: () {
                  Navigator.pop(sheetContext);

                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AdminDashboard(
                        user: const RoadSenseUser(
                          id: 'demo-admin',
                          name: 'Demo Administrator',
                          email: 'admin@roadsense.demo',
                          role: UserRole.administrator,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Admin Login'),
                onPressed: () {
                  Navigator.pop(sheetContext);

                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AdminLoginScreen(
                        authenticationService:
                            widget.authenticationService,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Dashboard preview uses sample data. '
                'It does not provide production-secure admin access.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: 'Admin access',
        onPressed: _showAdminOptions,
        child: const Icon(Icons.admin_panel_settings_outlined),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _SavedPage extends StatelessWidget {
  const _SavedPage();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Saved places')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Your saved places and preferred routes will appear here.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}

class _TripsPage extends StatelessWidget {
  const _TripsPage();

  @override
  Widget build(BuildContext context) => const TripsScreen();
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) => const ProfileScreen();
}
