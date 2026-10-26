import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';

import 'design_system.dart';
import 'domain/route_hazard_matcher.dart';
import 'domain/route_risk.dart';
import 'map/hazard_source.dart';
import 'map/navigation_controller.dart';
import 'navigation_services.dart';

const _roadSenseTileUrl = String.fromEnvironment(
  'ROAD_TILE_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

class RoutePlanningScreen extends StatefulWidget {
  const RoutePlanningScreen({
    super.key,
    required this.placeSearchService,
    required this.routeCalculationService,
    required this.recentPlaceStore,
    this.hazardSource,
    this.positionStream,
  });

  final PlaceSearchService placeSearchService;

  final RecentPlaceStore recentPlaceStore;
  final HazardSource? hazardSource;
  final Stream<NavFix>? positionStream;
  final RouteCalculationService routeCalculationService;

  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen> {
  RoutePlace? _from;
  RoutePlace? _to;
  List<RoutePlace> _recentPlaces = const [];
  List<CalculatedRoute>? _routes;
  String _departure = 'Leave now';
  bool _includeAlternatives = true;
  bool _loadingRecentPlaces = true;
  bool _locating = false;
  bool _calculatingRoute = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecentPlaces();
  }

  Future<void> _loadRecentPlaces() async {
    try {
      final places = await widget.recentPlaceStore.load();
      if (mounted) setState(() => _recentPlaces = places);
    } catch (_) {
      if (mounted) setState(() => _recentPlaces = const []);
    } finally {
      if (mounted) setState(() => _loadingRecentPlaces = false);
    }
  }

  Future<void> _choosePlace({required bool isOrigin}) async {
    final place = await showDialog<RoutePlace>(
      context: context,
      builder: (context) =>
          _PlaceSearchDialog(searchService: widget.placeSearchService),
    );
    if (!mounted || place == null) return;
    setState(() {
      if (isOrigin) {
        _from = place;
      } else {
        _to = place;
      }
    });
    try {
      await widget.recentPlaceStore.add(place);
      await _loadRecentPlaces();
    } catch (_) {
      // Search and route calculation still work if local storage is unavailable.
    }
  }

  void _selectRecent(RoutePlace place) {
    setState(() => _to = place);
  }

  void _swapPlaces() {
    setState(() {
      final place = _from;
      _from = _to;
      _to = place;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _errorMessage = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Turn on Location services and try again.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is required to use your location.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      setState(() {
        _from = RoutePlace(
          name: 'Current location',
          subtitle: 'GPS position',
          latitude: position.latitude,
          longitude: position.longitude,
        );
      });
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _cleanError(error));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _chooseDeparture() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Departure time')),
            ListTile(
              title: const Text('Leave now'),
              trailing: _departure == 'Leave now'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, 'Leave now'),
            ),
            ListTile(
              title: const Text('Depart at a time'),
              trailing: _departure == 'Leave now' ? null : Text(_departure),
              onTap: () => Navigator.pop(context, 'Choose a time'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'Choose a time') {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null && mounted) {
        setState(() => _departure = 'Depart at ${time.format(context)}');
      }
    } else {
      setState(() => _departure = choice);
    }
  }

  Future<void> _showOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(title: Text('Route options')),
                SwitchListTile(
                  title: const Text('Show alternative routes'),
                  value: _includeAlternatives,
                  onChanged: (value) {
                    setState(() => _includeAlternatives = value);
                    setSheetState(() {});
                  },
                ),
                const ListTile(
                  leading: Icon(Icons.shield_outlined),
                  title: Text('Hazard-aware route scoring'),
                  subtitle: Text('Active with RoadSense geometry matcher.'),
                  enabled: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _findRoute() async {
    FocusScope.of(context).unfocus();
    if (_from == null || _to == null) {
      setState(
        () => _errorMessage = 'Choose both a starting point and a destination.',
      );
      return;
    }
    if (_from!.latitude == _to!.latitude &&
        _from!.longitude == _to!.longitude) {
      setState(() => _errorMessage = 'Choose two different places.');
      return;
    }
    setState(() {
      _calculatingRoute = true;
      _errorMessage = null;
      _routes = null;
    });
    try {
      final routes = await widget.routeCalculationService.calculate(
        from: _from!,
        to: _to!,
        includeAlternatives: _includeAlternatives,
      );
      if (!mounted) return;
      if (routes.isEmpty) {
        throw Exception('No route was found for these places.');
      }
      setState(() => _routes = routes);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _cleanError(error));
    } finally {
      if (mounted) setState(() => _calculatingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routes = _routes;
    if (routes != null && _from != null && _to != null) {
      return _RouteResultsScreen(
        from: _from!,
        to: _to!,
        routes: routes,
        onBack: () => setState(() => _routes = null),
        hazardSource: widget.hazardSource,
        routeCalculationService: widget.routeCalculationService,
        positionStream: widget.positionStream,
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.route, color: Color(0xFF087F75)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Plan your route',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Plan a route with RoadSense',
                                style: TextStyle(color: RoadSenseColors.muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Use my current location',
                          onPressed: _locating ? null : _useCurrentLocation,
                          icon: _locating
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 18,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _PlaceField(
                              label: 'Starting point',
                              place: _from,
                              icon: Icons.trip_origin,
                              iconColor: const Color(0xFF087F75),
                              onTap: () => _choosePlace(isOrigin: true),
                            ),
                            const Divider(height: 1),
                            _PlaceField(
                              label: 'Destination',
                              place: _to,
                              icon: Icons.location_on,
                              iconColor: const Color(0xFFE53935),
                              onTap: () => _choosePlace(isOrigin: false),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.schedule),
                                    label: Text(
                                      _departure,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onPressed: _chooseDeparture,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.outlined(
                                  tooltip: 'Swap places',
                                  onPressed: _from != null && _to != null
                                      ? _swapPlaces
                                      : null,
                                  icon: const Icon(Icons.swap_vert),
                                ),
                                const SizedBox(width: 8),
                                IconButton.outlined(
                                  tooltip: 'Route options',
                                  onPressed: _showOptions,
                                  icon: const Icon(Icons.tune),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton.icon(
                      icon: _calculatingRoute
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.directions_car),
                      label: Text(
                        _calculatingRoute ? 'Finding route...' : 'Find route',
                      ),
                      onPressed: _calculatingRoute ? null : _findRoute,
                    ),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFCDD2)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: RoadSenseColors.red),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent places',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_recentPlaces.isNotEmpty)
                          Text(
                            '${_recentPlaces.length} saved',
                            style: const TextStyle(
                              color: RoadSenseColors.muted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _RecentPlacesSection(
                      loading: _loadingRecentPlaces,
                      places: _recentPlaces,
                      onSelect: _selectRecent,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceField extends StatelessWidget {
  const _PlaceField({
    required this.label,
    required this.place,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final RoutePlace? place;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: RoadSenseColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place != null ? _placeLabel(place!) : 'Choose a place',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: place != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: place != null
                          ? RoadSenseColors.ink
                          : RoadSenseColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: RoadSenseColors.muted),
          ],
        ),
      ),
    );
  }
}

class _RecentPlacesSection extends StatelessWidget {
  const _RecentPlacesSection({
    required this.loading,
    required this.places,
    required this.onSelect,
  });

  final bool loading;
  final List<RoutePlace> places;
  final ValueChanged<RoutePlace> onSelect;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (places.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Text(
          'Places you search for will be saved here on this device.',
          textAlign: TextAlign.center,
          style: TextStyle(color: RoadSenseColors.muted),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (var i = 0; i < places.length; i++) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _recentIcon(i),
                  color: RoadSenseColors.ink,
                  size: 28,
                ),
                title: Text(
                  places[i].name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(places[i].subtitle),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: RoadSenseColors.muted,
                ),
                onTap: () => onSelect(places[i]),
              ),
              if (i != places.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }

  IconData _recentIcon(int index) => switch (index % 4) {
    0 => Icons.home_outlined,
    1 => Icons.bookmark_border,
    2 => Icons.place_outlined,
    _ => Icons.apartment_outlined,
  };
}

class _PlaceSearchDialog extends StatefulWidget {
  const _PlaceSearchDialog({required this.searchService});

  final PlaceSearchService searchService;

  @override
  State<_PlaceSearchDialog> createState() => _PlaceSearchDialogState();
}

class _PlaceSearchDialogState extends State<_PlaceSearchDialog> {
  final _controller = TextEditingController();
  List<RoutePlace> _results = const [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _error = null;
      _results = const [];
    });
    try {
      final results = await widget.searchService.search(query);
      if (mounted) setState(() => _results = results);
      if (mounted && results.isEmpty) {
        setState(
          () => _error = 'No places found. Try a nearby town or landmark.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _cleanError(error));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Search a place'),
    content: SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Town, address, or landmark',
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: _searching ? null : _search,
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          if (_searching) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: RoadSenseColors.red),
              ),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final place = _results[index];
                return ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    place.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(context, place),
                );
              },
            ),
          ),
          const Text(
            'Search by OpenStreetMap. Results load when you submit a query.',
            style: TextStyle(fontSize: 11, color: RoadSenseColors.muted),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}

class _RouteResultsScreen extends StatefulWidget {
  const _RouteResultsScreen({
    required this.from,
    required this.to,
    required this.routes,
    required this.onBack,
    this.routeCalculationService,
    this.hazardSource,
    this.positionStream,
  });

  final RoutePlace from;
  final RoutePlace to;
  final List<CalculatedRoute> routes;
  final VoidCallback onBack;
  final HazardSource? hazardSource;
  final Stream<NavFix>? positionStream;
  final RouteCalculationService? routeCalculationService;

  @override
  State<_RouteResultsScreen> createState() => _RouteResultsScreenState();
}

class _RouteResultsScreenState extends State<_RouteResultsScreen> {
  int _selectedRoute = 0;
  late final HazardSource _hazardSource;
  final RouteHazardMatcher _matcher = const RouteHazardMatcher();
  final RouteRiskCalculator _riskCalculator = const RouteRiskCalculator();
  final MapController _mapController = MapController();
  LiveTrackingController? _trackingController;
  List<RouteHazardPoint> _loadedHazards = const [];

  bool _loadingHazards = true;
  String? _hazardError;
  Map<int, RouteRisk> _routeRisks = {};
  Map<int, RouteTradeOff> _tradeOffs = {};

  @override
  void initState() {
    super.initState();
    _hazardSource =
        widget.hazardSource ??
        (DebugHazardSource.isEnabled
            ? const DebugHazardSource()
            : const EmptyHazardSource());
    _loadHazards();
  }

  Future<void> _loadHazards() async {
    setState(() {
      _loadingHazards = true;
      _hazardError = null;
    });
    try {
      final allPoints = widget.routes.expand((r) => r.points).toList();
      final hazards = await _hazardSource.getHazards(routePoints: allPoints);

      final risks = <int, RouteRisk>{};
      for (var i = 0; i < widget.routes.length; i++) {
        final matches = _matcher.match(
          route: widget.routes[i].points,
          hazards: hazards,
        );
        risks[i] = _riskCalculator.calculateRisk(matches);
      }

      final tradeOffs = <int, RouteTradeOff>{};
      if (widget.routes.isNotEmpty) {
        final baselineRisk = risks[0] ?? RouteRisk.zero;
        final baselineDuration = widget.routes[0].durationSeconds;
        for (var i = 1; i < widget.routes.length; i++) {
          tradeOffs[i] = _riskCalculator.evaluateTradeOff(
            routeIndex: i,
            baselineDurationSeconds: baselineDuration,
            baselineRisk: baselineRisk,
            alternativeDurationSeconds: widget.routes[i].durationSeconds,
            alternativeRisk: risks[i] ?? RouteRisk.zero,
          );
        }
      }

      if (mounted) {
        setState(() {
          _loadedHazards = hazards;
          _routeRisks = risks;
          _tradeOffs = tradeOffs;
          _loadingHazards = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hazardError = e.toString();
          _loadingHazards = false;
        });
      }
    }
  }

  bool get _isNavigating =>
      _trackingController != null &&
      _trackingController!.status != NavigationStatus.stopped &&
      _trackingController!.status != NavigationStatus.idle;

  void _startNavigation() {
    final route = widget.routes[_selectedRoute];
    final controller = LiveTrackingController(
      initialRoute: route,
      destination: widget.to.point,
      routeRecalculator: (from, to) async {
        if (widget.routeCalculationService != null) {
          final res = await widget.routeCalculationService!.calculate(
            from: RoutePlace(
              name: 'Current location',
              subtitle: '',
              latitude: from.latitude,
              longitude: from.longitude,
            ),
            to: widget.to,
            includeAlternatives: false,
          );
          return res.isNotEmpty ? res.first : null;
        }
        return null;
      },
      initialHazards: _loadedHazards,
    );

    controller.addListener(() {
      if (mounted) setState(() {});
    });

    final stream =
        widget.positionStream ??
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).map(NavFix.fromPosition);

    controller.startTracking(stream);
    setState(() => _trackingController = controller);
  }

  void _stopNavigation() {
    _trackingController?.stopTracking();
    _trackingController?.dispose();
    setState(() => _trackingController = null);
  }

  void _recenter() {
    final fix = _trackingController?.lastFix;
    if (fix != null) {
      _mapController.move(fix.latLng, 16.0);
    }
  }

  @override
  void dispose() {
    _trackingController?.stopTracking();
    _trackingController?.dispose();
    super.dispose();
  }

  void _showHazardDetails(RouteHazardPoint hazard) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: hazard.severityLabel.toLowerCase() == 'high'
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFFF57C00),
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hazard.typeLabel.toUpperCase(),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_hazardSource.isSampleData)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFE082)),
                      ),
                      child: const Text(
                        'Sample data',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF57F17),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.speed),
                title: const Text('Severity'),
                trailing: Text(
                  hazard.severityLabel.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: hazard.severityLabel.toLowerCase() == 'high'
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFFF57C00),
                  ),
                ),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('Last observed'),
                trailing: Text(
                  '${DateTime.now().difference(hazard.lastObserved).inHours} hours ago',
                ),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Observations'),
                trailing: Text('${hazard.observationCount} reports'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hazard scores are relative ranking aids and not validated probabilities. Never assume a route is free of hazards.',
                style: TextStyle(fontSize: 11, color: RoadSenseColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPoints = widget.routes.expand((route) => route.points).toList();
    final bounds = LatLngBounds.fromPoints(allPoints);
    final currentRisk = _routeRisks[_selectedRoute] ?? RouteRisk.zero;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.fromLTRB(36, 100, 36, 300),
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: _roadSenseTileUrl,
                userAgentPackageName: 'com.avanthika.roadsense',
                maxNativeZoom: 19,
              ),
              PolylineLayer(
                polylines: [
                  for (
                    var index = widget.routes.length - 1;
                    index >= 0;
                    index--
                  )
                    Polyline(
                      points: (_isNavigating && index == _selectedRoute)
                          ? _trackingController!.currentRoute.points
                          : widget.routes[index].points,
                      color: index == _selectedRoute
                          ? const Color(0xFF087F75)
                          : const Color(0xAA71818A),
                      strokeWidth: index == _selectedRoute ? 7 : 4,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.from.point,
                    width: 44,
                    height: 44,
                    child: const Icon(
                      Icons.trip_origin,
                      color: Color(0xFF087F75),
                      size: 32,
                    ),
                  ),
                  Marker(
                    point: widget.to.point,
                    width: 44,
                    height: 44,
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFF087F75),
                      size: 40,
                    ),
                  ),
                  if (_trackingController?.lastFix != null)
                    Marker(
                      point: _trackingController!.lastFix!.latLng,
                      width: 42,
                      height: 42,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1976D2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 6),
                          ],
                        ),
                        child: const Icon(
                          Icons.navigation,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  for (final match in currentRisk.eligibleHazards)
                    Marker(
                      point: match.hazard.point,
                      width: 38,
                      height: 38,
                      child: GestureDetector(
                        onTap: () => _showHazardDetails(match.hazard),
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                match.hazard.severityLabel.toLowerCase() ==
                                    'high'
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFFF57C00),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            match.hazard.severityLabel.toLowerCase() == 'high'
                                ? Icons.warning_amber_rounded
                                : Icons.report_problem_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution('Ãƒâ€šÃ‚Â© OpenStreetMap contributors'),
                ],
                alignment: AttributionAlignment.bottomRight,
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 16,
            child: Material(
              color: Colors.white,
              elevation: 3,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Back to route planner',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          if (_trackingController?.currentAlert != null)
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: Material(
                color: const Color(0xFFD32F2F),
                elevation: 6,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Hazard Ahead',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${_trackingController!.currentAlert!.hazard.typeLabel} in ${_trackingController!.currentAlert!.distanceMeters.toStringAsFixed(0)} m',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Dismiss alert',
                        onPressed: _trackingController!.dismissAlert,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isNavigating)
            Positioned(
              right: 16,
              bottom: 300,
              child: Material(
                color: Colors.white,
                elevation: 4,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Recenter on location',
                  color: const Color(0xFF087F75),
                  icon: const Icon(Icons.my_location),
                  onPressed: _recenter,
                ),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.white,
              elevation: 5,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Route to ${widget.to.name}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.from.name} to ${widget.to.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    if (_loadingHazards)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (_hazardError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Hazard data unavailable: $_hazardError',
                          style: const TextStyle(
                            fontSize: 11,
                            color: RoadSenseColors.muted,
                          ),
                        ),
                      ),
                    if (currentRisk.firstHighSeverityHazard != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFB74D)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_rounded,
                              color: Color(0xFFE65100),
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Hazard ahead: high-severity ${currentRisk.firstHighSeverityHazard!.hazard.typeLabel} Ãƒâ€šÃ‚Â· ${currentRisk.firstHighSeverityHazard!.distanceAlongRouteMeters.round()} m along route${_hazardSource.isSampleData ? ' (Sample data)' : ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFBF360C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    for (
                      var index = 0;
                      index < widget.routes.length;
                      index++
                    ) ...[
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        selected: index == _selectedRoute,
                        onTap: () => setState(() => _selectedRoute = index),
                        leading: Icon(
                          Icons.route,
                          color: index == _selectedRoute
                              ? const Color(0xFF087F75)
                              : RoadSenseColors.muted,
                        ),
                        title: Text(
                          '${widget.routes[index].durationLabel} - ${widget.routes[index].distanceLabel}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              index == 0
                                  ? 'Fastest route'
                                  : 'Alternative route',
                            ),
                            if (_tradeOffs.containsKey(index))
                              Text(
                                _tradeOffs[index]!.isRecommended
                                    ? '${_tradeOffs[index]!.tradeOffText} (Recommended)'
                                    : _tradeOffs[index]!.tradeOffText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _tradeOffs[index]!.isRecommended
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: _tradeOffs[index]!.isRecommended
                                      ? const Color(0xFF087F75)
                                      : RoadSenseColors.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (!_isNavigating)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _startNavigation,
                          icon: const Icon(Icons.navigation),
                          label: const Text('Start Navigation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF087F75),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _recenter,
                              icon: const Icon(Icons.my_location),
                              label: const Text('Recenter'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _stopNavigation,
                              icon: const Icon(Icons.stop),
                              label: const Text('Stop navigation'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD32F2F),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_trackingController?.statusMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _trackingController!.statusMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF087F75),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _hazardSource.isSampleData
                          ? 'Route calculated by OSRM. RoadSense hazard scoring active with sample data. Follow local road signs.'
                          : (_routeRisks.values.any((r) => r.hasHazards)
                                ? 'Route calculated by OSRM. RoadSense hazard scoring active. Follow local road signs.'
                                : 'Route calculated by OSRM. No known hazards reported on this route. Follow local road signs.'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: RoadSenseColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _placeLabel(RoutePlace place) =>
    place.subtitle.isEmpty ? place.name : '${place.name}, ${place.subtitle}';

String _cleanError(Object error) => error
    .toString()
    .replaceFirst('Exception: ', '')
    .replaceFirst('Bad state: ', '');
