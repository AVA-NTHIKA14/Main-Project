import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth.dart';
import 'auth_screens.dart';
import 'admin.dart';
import 'design_system.dart';
import 'firebase_auth_service.dart';
import 'onboarding.dart';
import 'navigation_services.dart';
import 'permissions.dart';
import 'profile.dart';
import 'route_planning.dart';
import 'trips.dart';

/// Initializes Firebase with diagnostic error handling.
///
/// Returns the initialized [FirebaseApp] if successful, or `null` if
/// initialization fails or platform options are unavailable.
Future<FirebaseApp?> initializeFirebase({FirebaseOptions? options}) async {
  try {
    if (Firebase.apps.isNotEmpty) {
      debugPrint('[RoadSense] Firebase already initialized.');
      return Firebase.app();
    }
    final app = options != null
        ? await Firebase.initializeApp(options: options)
        : await Firebase.initializeApp();
    debugPrint('[RoadSense] Firebase initialized successfully (${app.name}).');
    return app;
  } catch (error) {
    debugPrint('[RoadSense] Firebase initialization diagnostic: $error');
    return null;
  }
}

const FirebaseOptions roadSenseWebFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyBX8Rf1Cs3KLQUADtEcOPagkiyotafZXeY',
  appId: '1:1078799114478:android:5a8fb776c00259447a13ff',
  messagingSenderId: '1078799114478',
  projectId: 'roadsense-cc1f5',
  authDomain: 'roadsense-cc1f5.firebaseapp.com',
  storageBucket: 'roadsense-cc1f5.firebasestorage.app',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = await initializeFirebase(
    options: kIsWeb ? roadSenseWebFirebaseOptions : null,
  );
  runApp(
    RoadSenseApp(
      authenticationService: app != null
          ? FirebaseAuthService()
          : MockAuthenticationService(),
    ),
  );
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
        widget.authenticationService ??
        (Firebase.apps.isNotEmpty
            ? FirebaseAuthService()
            : MockAuthenticationService());

    _authController = AuthController(service: _authenticationService);
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
            authController: _authController,
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
    this.authController,
  });

  final AuthenticationService authenticationService;
  final AuthController? authController;

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
      _ProfilePage(
        authController: widget.authController,
        authenticationService: widget.authenticationService,
        onSignOut: _signOut,
      ),
    ];
  }

  Future<void> _signOut() async {
    if (widget.authController != null) {
      await widget.authController!.signOut();
    } else {
      await widget.authenticationService.signOut();
    }
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
                        authenticationService: widget.authenticationService,
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
        child: IndexedStack(index: _selectedIndex, children: _pages),
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
  const _ProfilePage({
    this.authController,
    this.authenticationService,
    this.onSignOut,
  });

  final AuthController? authController;
  final AuthenticationService? authenticationService;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    final user = authController?.user ?? authenticationService?.currentUser;
    return ProfileScreen(
      name: user?.name.isNotEmpty == true ? user!.name : 'RoadSense driver',
      email: user?.email.isNotEmpty == true
          ? user!.email
          : 'driver@example.com',
      onSignOut: onSignOut,
    );
  }
}
