import 'package:flutter/material.dart';

import 'auth.dart';
import 'auth_screens.dart';
import 'design_system.dart';
import 'explore.dart';
import 'onboarding.dart';
import 'permissions.dart';
import 'profile.dart';
import 'routing.dart';
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

  @override
  Widget build(BuildContext context) {
    const pages = [_ExplorePage(), _TripsPage(), _ProfilePage()];
    return Scaffold(
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
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

class _ExplorePage extends StatelessWidget {
  const _ExplorePage();

  @override
  Widget build(BuildContext context) => const ExploreScreen(
    dataSource: MockRoadMapDataSource(),
    routingService: HazardAwareRoutingService(
      routingService: MockRoutingService(),
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
