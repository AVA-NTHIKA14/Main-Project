import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class RoutePlace {
  const RoutePlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.subtitle = '',
  });

  final String name;
  final double latitude;
  final double longitude;
  final String subtitle;

  LatLng get point => LatLng(latitude, longitude);

  factory RoutePlace.fromJson(Map<String, dynamic> json) => RoutePlace(
    name: json['name'] as String,
    subtitle: json['subtitle'] as String? ?? '',
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );

  Map<String, Object> toJson() => {
    'name': name,
    'subtitle': subtitle,
    'latitude': latitude,
    'longitude': longitude,
  };
}

abstract interface class PlaceSearchService {
  Future<List<RoutePlace>> search(String query);
}

/// User-submitted queries only; Nominatim does not permit client-side autocomplete.
class NominatimPlaceSearchService implements PlaceSearchService {
  NominatimPlaceSearchService({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      _baseUri =
          baseUri ??
          Uri.parse(
            const String.fromEnvironment(
              'ROADSENSE_GEOCODER_URL',
              defaultValue: 'https://nominatim.openstreetmap.org',
            ),
          );

  final http.Client _client;
  final Uri _baseUri;
  final Map<String, List<RoutePlace>> _cache = {};
  static DateTime? _lastRequestAt;
  static Future<void> _requestQueue = Future<void>.value();

  void close() => _client.close();

  @override
  Future<List<RoutePlace>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    if (_cache.containsKey(normalized)) return _cache[normalized]!;

    final uri = _baseUri.replace(
      path: '/search',
      queryParameters: {
        'q': query.trim(),
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '6',
      },
    );
    final response = await _requestAtMostOncePerSecond(
      () => _client
          .get(
            uri,
            headers: const {
              'User-Agent': 'RoadSense/1.0 (com.example.roadsense)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12)),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Place search is temporarily unavailable (${response.statusCode}).',
      );
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    final places = rows
        .map((row) {
          final item = row as Map<String, dynamic>;
          final displayName = item['display_name'] as String? ?? query.trim();
          final parts = displayName.split(',');
          return RoutePlace(
            name: parts.first.trim(),
            subtitle: parts.skip(1).take(3).join(',').trim(),
            latitude: double.parse(item['lat'] as String),
            longitude: double.parse(item['lon'] as String),
          );
        })
        .toList(growable: false);
    _cache[normalized] = places;
    return places;
  }

  Future<T> _requestAtMostOncePerSecond<T>(Future<T> Function() request) {
    final previous = _requestQueue;
    final next = Completer<void>();
    _requestQueue = next.future;
    return previous.then((_) async {
      try {
        final last = _lastRequestAt;
        if (last != null) {
          final wait =
              const Duration(seconds: 1) - DateTime.now().difference(last);
          if (wait > Duration.zero) await Future<void>.delayed(wait);
        }
        _lastRequestAt = DateTime.now();
        return await request();
      } finally {
        next.complete();
      }
    });
  }
}

@immutable
class CalculatedRoute {
  const CalculatedRoute({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
  });

  final double distanceMeters;
  final double durationSeconds;
  final List<LatLng> points;

  String get distanceLabel => distanceMeters >= 1000
      ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
      : '${distanceMeters.round()} m';

  String get durationLabel {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60} hr ${minutes % 60} min';
  }
}

abstract interface class RouteCalculationService {
  Future<List<CalculatedRoute>> calculate({
    required RoutePlace from,
    required RoutePlace to,
    required bool includeAlternatives,
  });
}

/// OSRM demo endpoint for user-driven development traffic. Replace with a
/// contracted or self-hosted endpoint before production deployment.
class OsrmRouteCalculationService implements RouteCalculationService {
  OsrmRouteCalculationService({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      _baseUri =
          baseUri ??
          Uri.parse(
            const String.fromEnvironment(
              'ROADSENSE_ROUTER_URL',
              defaultValue: 'https://router.project-osrm.org',
            ),
          );

  final http.Client _client;
  final Uri _baseUri;
  static DateTime? _lastRequestAt;
  static Future<void> _requestQueue = Future<void>.value();

  void close() => _client.close();

  @override
  Future<List<CalculatedRoute>> calculate({
    required RoutePlace from,
    required RoutePlace to,
    required bool includeAlternatives,
  }) async {
    final coordinates =
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    final uri = _baseUri.replace(
      path: '/route/v1/driving/$coordinates',
      queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
        'alternatives': includeAlternatives ? 'true' : 'false',
      },
    );
    final response = await _requestAtMostOncePerSecond(
      () => _client
          .get(
            uri,
            headers: const {
              'User-Agent': 'RoadSense/1.0 (com.example.roadsense)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20)),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Route service is temporarily unavailable (${response.statusCode}).',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['code'] != 'Ok') {
      throw Exception('No drivable route was found between these places.');
    }
    final rows = body['routes'] as List<dynamic>;
    return rows
        .map((row) {
          final route = row as Map<String, dynamic>;
          final geometry = route['geometry'] as Map<String, dynamic>;
          final coordinates = geometry['coordinates'] as List<dynamic>;
          return CalculatedRoute(
            distanceMeters: (route['distance'] as num).toDouble(),
            durationSeconds: (route['duration'] as num).toDouble(),
            points: coordinates
                .map((point) {
                  final pair = point as List<dynamic>;
                  return LatLng(
                    (pair[1] as num).toDouble(),
                    (pair[0] as num).toDouble(),
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  Future<T> _requestAtMostOncePerSecond<T>(Future<T> Function() request) {
    final previous = _requestQueue;
    final next = Completer<void>();
    _requestQueue = next.future;
    return previous.then((_) async {
      try {
        final last = _lastRequestAt;
        if (last != null) {
          final wait =
              const Duration(seconds: 1) - DateTime.now().difference(last);
          if (wait > Duration.zero) await Future<void>.delayed(wait);
        }
        _lastRequestAt = DateTime.now();
        return await request();
      } finally {
        next.complete();
      }
    });
  }
}

class RecentPlaceStore {
  static const _storageKey = 'roadsense.recentPlaces.v1';

  Future<List<RoutePlace>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList(_storageKey) ?? const [];
    return raw
        .map(
          (entry) =>
              RoutePlace.fromJson(jsonDecode(entry) as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<void> add(RoutePlace place) async {
    final preferences = await SharedPreferences.getInstance();
    final existing = await load();
    final updated = [
      place,
      ...existing.where(
        (item) =>
            item.latitude != place.latitude ||
            item.longitude != place.longitude,
      ),
    ].take(8);
    await preferences.setStringList(
      _storageKey,
      updated.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }
}
