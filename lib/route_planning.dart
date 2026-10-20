import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';

import 'design_system.dart';
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
  });

  final PlaceSearchService placeSearchService;
  final RouteCalculationService routeCalculationService;
  final RecentPlaceStore recentPlaceStore;

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
                  subtitle: Text(
                    'Available when RoadSense hazard data is connected.',
                  ),
                  enabled: false,
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
                    child: _RoutePlacesCard(
                      from: _from,
                      to: _to,
                      onChooseFrom: () => _choosePlace(isOrigin: true),
                      onChooseTo: () => _choosePlace(isOrigin: false),
                      onSwap: _swapPlaces,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: _chooseDeparture,
                          icon: const Icon(Icons.schedule),
                          label: Text(_departure),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _showOptions,
                          icon: const Icon(Icons.tune),
                          label: const Text('Route options'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _calculatingRoute ? null : _findRoute,
                        icon: _calculatingRoute
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.near_me),
                        label: Text(
                          _calculatingRoute ? 'Finding route…' : 'Find route',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF087F75),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: RoadSenseColors.red),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                    child: Row(
                      children: [
                        Text(
                          'Recent places',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        if (_recentPlaces.isNotEmpty)
                          TextButton(
                            onPressed: () => _showAllRecentPlaces(),
                            child: const Text('See all'),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _RecentPlacesCard(
                      places: _recentPlaces,
                      loading: _loadingRecentPlaces,
                      onSelect: _selectRecent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 138,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/welcome_road.png',
                          fit: BoxFit.cover,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(right: 16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .9),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_user,
                                  color: Color(0xFF087F75),
                                  size: 30,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Safer journeys\nwith every user.',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Center(
                      child: Text(
                        'Place search © OpenStreetMap contributors',
                        style: TextStyle(
                          fontSize: 11,
                          color: RoadSenseColors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAllRecentPlaces() async {
    final place = await showModalBottomSheet<RoutePlace>(
      context: context,
      showDragHandle: true,
      builder: (context) => SingleChildScrollView(
        child: _RecentPlacesCard(
          places: _recentPlaces,
          loading: false,
          onSelect: (place) => Navigator.pop(context, place),
        ),
      ),
    );
    if (place != null && mounted) _selectRecent(place);
  }
}

class _RoutePlacesCard extends StatelessWidget {
  const _RoutePlacesCard({
    required this.from,
    required this.to,
    required this.onChooseFrom,
    required this.onChooseTo,
    required this.onSwap,
  });

  final RoutePlace? from;
  final RoutePlace? to;
  final VoidCallback onChooseFrom;
  final VoidCallback onChooseTo;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
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
    child: Column(
      children: [
        _PlaceInput(
          label: 'From',
          hint: 'Choose starting point',
          place: from,
          icon: Icons.circle,
          onTap: onChooseFrom,
          trailing: IconButton(
            tooltip: 'Swap start and destination',
            onPressed: onSwap,
            icon: const Icon(Icons.swap_vert),
          ),
        ),
        const Divider(height: 1, indent: 48),
        _PlaceInput(
          label: 'To',
          hint: 'Search destination',
          place: to,
          icon: Icons.place,
          onTap: onChooseTo,
          trailing: const SizedBox(width: 48),
        ),
      ],
    ),
  );
}

class _PlaceInput extends StatelessWidget {
  const _PlaceInput({
    required this.label,
    required this.hint,
    required this.place,
    required this.icon,
    required this.onTap,
    required this.trailing,
  });

  final String label;
  final String hint;
  final RoutePlace? place;
  final IconData icon;
  final VoidCallback onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 76,
    child: Row(
      children: [
        SizedBox(width: 44, child: Icon(icon, color: const Color(0xFF087F75))),
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: RoadSenseColors.muted),
                ),
                Text(
                  place == null ? hint : _placeLabel(place!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: place == null
                        ? RoadSenseColors.muted
                        : RoadSenseColors.ink,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ),
        trailing,
      ],
    ),
  );
}

class _RecentPlacesCard extends StatelessWidget {
  const _RecentPlacesCard({
    required this.places,
    required this.loading,
    required this.onSelect,
  });

  final List<RoutePlace> places;
  final bool loading;
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
  });

  final RoutePlace from;
  final RoutePlace to;
  final List<CalculatedRoute> routes;
  final VoidCallback onBack;

  @override
  State<_RouteResultsScreen> createState() => _RouteResultsScreenState();
}

class _RouteResultsScreenState extends State<_RouteResultsScreen> {
  int _selectedRoute = 0;

  @override
  Widget build(BuildContext context) {
    final allPoints = widget.routes.expand((route) => route.points).toList();
    final bounds = LatLngBounds.fromPoints(allPoints);
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.fromLTRB(36, 100, 36, 300),
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: _roadSenseTileUrl,
                userAgentPackageName: 'com.example.roadsense',
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
                      points: widget.routes[index].points,
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
                ],
              ),
              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution('© OpenStreetMap contributors'),
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
                    for (var index = 0; index < widget.routes.length; index++)
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
                        subtitle: Text(
                          index == 0 ? 'Fastest route' : 'Alternative route',
                        ),
                      ),
                    const Text(
                      'Route calculated by OSRM from OpenStreetMap data. Live traffic and RoadSense hazard scoring are not connected. Follow local road signs.',
                      style: TextStyle(
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
