import 'package:flutter/material.dart';

import 'auth.dart';
import 'auth_screens.dart';
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

  @override
  void initState() {
    super.initState();
    _authController = AuthController(
      service: widget.authenticationService ?? MockAuthenticationService(),
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
          homeBuilder: () => const RoadSenseShell(),
        ),
      ),
    );
  }
}

class RoadSenseShell extends StatefulWidget {
  const RoadSenseShell({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: _pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
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
