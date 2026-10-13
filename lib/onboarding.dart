import 'package:flutter/material.dart';

import 'design_system.dart';
import 'permissions.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    super.key,
    required this.permissionService,
    required this.homeBuilder,
  });

  final PermissionService permissionService;
  final Widget Function() homeBuilder;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool _complete = false;

  @override
  Widget build(BuildContext context) {
    if (_complete) return widget.homeBuilder();
    return OnboardingFlow(
      permissionService: widget.permissionService,
      onComplete: () => setState(() => _complete = true),
    );
  }
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.permissionService,
    required this.onComplete,
  });

  final PermissionService permissionService;
  final VoidCallback onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final PageController _pageController;
  late final PermissionController _permissions;
  int _page = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _permissions = PermissionController(service: widget.permissionService);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _permissions.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    setState(() => _busy = true);
    final permission = switch (_page) {
      2 => PermissionType.motion,
      3 => PermissionType.location,
      4 => PermissionType.notifications,
      _ => null,
    };
    if (permission != null) await _permissions.request(permission);
    if (!mounted) return;
    if (_page == _pages.length - 1) {
      widget.onComplete();
    } else {
      setState(() => _busy = false);
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
  }

  void _back() {
    if (_page == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  static const _pages = [
    _OnboardingCopy(
      icon: Icons.explore_outlined,
      title: 'Welcome to RoadSense',
      body: 'Know the road around you. RoadSense helps reveal useful road conditions while you travel normally.',
    ),
    _OnboardingCopy(
      icon: Icons.directions_car_outlined,
      title: 'Sensing in the background',
      body: 'RoadSense quietly observes motion and road conditions while you travel. You do not need to continuously interact with the app.',
    ),
    _OnboardingCopy(
      icon: Icons.screen_rotation_outlined,
      title: 'Motion sensors',
      body: 'The accelerometer and gyroscope notice movement and changes in motion, helping identify possible road anomalies.',
    ),
    _OnboardingCopy(
      icon: Icons.location_on_outlined,
      title: 'Location and speed',
      body: 'GPS, speed, and timestamp help place a road event in the right context and time.',
    ),
    _OnboardingCopy(
      icon: Icons.groups_outlined,
      title: 'Community verification',
      body: 'RoadSense compares anonymous signals so useful road insights can be checked before they are shared.',
    ),
    _OnboardingCopy(
      icon: Icons.lock_outline,
      title: 'Privacy comes first',
      body: 'Your individual trip is not displayed publicly. RoadSense uses only what is needed to understand road conditions.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RoadSenseSpacing.sm,
              RoadSenseSpacing.sm,
              RoadSenseSpacing.md,
              0,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _page == 0 ? null : _back,
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                ),
                const Spacer(),
                Text(
                  '${_page + 1} of ${_pages.length}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pages.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) => _OnboardingPage(
                copy: _pages[index],
                permissionState: _permissionStateFor(index),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(RoadSenseSpacing.md),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => Container(
                      width: index == _page ? 22 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == _page
                            ? RoadSenseColors.teal
                            : RoadSenseColors.line,
                        borderRadius: BorderRadius.circular(
                          RoadSenseRadius.pill,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: RoadSenseSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _next,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _page == _pages.length - 1
                                ? 'Start exploring'
                                : _buttonLabel,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  String get _buttonLabel => switch (_page) {
    2 => 'Allow motion access',
    3 => 'Allow location access',
    4 => 'Allow notifications',
    _ => 'Continue',
  };

  PermissionState? _permissionStateFor(int index) => switch (index) {
    2 => _permissions.stateFor(PermissionType.motion),
    3 => _permissions.stateFor(PermissionType.location),
    4 => _permissions.stateFor(PermissionType.notifications),
    _ => null,
  };
}

class _OnboardingCopy {
  const _OnboardingCopy({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.copy, required this.permissionState});

  final _OnboardingCopy copy;
  final PermissionState? permissionState;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: RoadSenseSpacing.lg),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            color: RoadSenseColors.tealSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(copy.icon, size: 44, color: RoadSenseColors.teal),
        ),
        const SizedBox(height: RoadSenseSpacing.xl),
        Text(
          copy.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: RoadSenseSpacing.md),
        Text(
          copy.body,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (permissionState != null &&
            permissionState != PermissionState.notRequested) ...[
          const SizedBox(height: RoadSenseSpacing.lg),
          StatusIndicator(
            label: permissionStateLabel(permissionState!),
            tone: permissionState == PermissionState.granted
                ? StatusTone.good
                : StatusTone.warning,
          ),
        ],
      ],
    ),
  );
}
