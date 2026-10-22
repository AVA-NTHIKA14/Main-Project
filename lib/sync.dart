import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'design_system.dart';
import 'sensors.dart';

enum SyncState { pending, uploading, synced, failed }

class PendingSyncItem {
  PendingSyncItem({
    required this.id,
    required this.reading,
    this.state = SyncState.pending,
    this.attempts = 0,
    this.error,
  });

  final String id;
  final SensorReading reading;
  SyncState state;
  int attempts;
  String? error;

  Map<String, Object?> toJson() => {
    'id': id,
    'state': state.name,
    'attempts': attempts,
    'error': error,
    'reading': {
      'accelerometer': [
        reading.accelerometer.x,
        reading.accelerometer.y,
        reading.accelerometer.z,
      ],
      'gyroscope': [
        reading.gyroscope.x,
        reading.gyroscope.y,
        reading.gyroscope.z,
      ],
      'latitude': reading.gps.latitude,
      'longitude': reading.gps.longitude,
      'altitude': reading.gps.altitude,
      'accuracy': reading.gps.accuracy,
      'speedMps': reading.speedMps,
      'timestamp': reading.timestamp.toIso8601String(),
    },
  };

  static PendingSyncItem fromJson(Map<String, Object?> json) {
    final reading = json['reading']! as Map<String, Object?>;
    final accelerometer = (reading['accelerometer']! as List<Object?>)
        .cast<num>();
    final gyroscope = (reading['gyroscope']! as List<Object?>).cast<num>();
    return PendingSyncItem(
      id: json['id']! as String,
      state: SyncState.values.byName(json['state']! as String),
      attempts: json['attempts']! as int,
      error: json['error'] as String?,
      reading: SensorReading(
        accelerometer: Vector3(
          accelerometer[0].toDouble(),
          accelerometer[1].toDouble(),
          accelerometer[2].toDouble(),
        ),
        gyroscope: Vector3(
          gyroscope[0].toDouble(),
          gyroscope[1].toDouble(),
          gyroscope[2].toDouble(),
        ),
        gps: GpsReading(
          latitude: (reading['latitude']! as num).toDouble(),
          longitude: (reading['longitude']! as num).toDouble(),
          altitude: (reading['altitude'] as num?)?.toDouble(),
          accuracy: (reading['accuracy']! as num).toDouble(),
          speedMps: (reading['speedMps']! as num).toDouble(),
          timestamp: DateTime.parse(reading['timestamp']! as String),
        ),
        speedMps: (reading['speedMps']! as num).toDouble(),
        timestamp: DateTime.parse(reading['timestamp']! as String),
      ),
    );
  }
}

abstract interface class PendingSyncStore {
  Future<List<PendingSyncItem>> load();
  Future<void> save(List<PendingSyncItem> items);
}

class InMemoryPendingSyncStore implements PendingSyncStore {
  List<PendingSyncItem> _items = [];

  @override
  Future<List<PendingSyncItem>> load() async =>
      List<PendingSyncItem>.from(_items);

  @override
  Future<void> save(List<PendingSyncItem> items) async =>
      _items = List<PendingSyncItem>.from(items);
}

class JsonFilePendingSyncStore implements PendingSyncStore {
  JsonFilePendingSyncStore(this.file);

  final File file;

  @override
  Future<List<PendingSyncItem>> load() async {
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.trim().isEmpty) return [];
    final decoded = jsonDecode(content) as List<Object?>;
    return decoded
        .map(
          (item) => PendingSyncItem.fromJson(
            (item! as Map<Object?, Object?>).cast<String, Object?>(),
          ),
        )
        .toList();
  }

  @override
  Future<void> save(List<PendingSyncItem> items) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}

abstract interface class SyncBackend {
  Future<Set<String>> upload(List<PendingSyncItem> items);
}

class MockSyncBackend implements SyncBackend {
  MockSyncBackend({this.failUploads = false, Set<String>? acknowledgedIds})
    : acknowledgedIds = acknowledgedIds ?? <String>{};

  final bool failUploads;
  final Set<String> acknowledgedIds;
  final List<String> receivedIds = [];

  @override
  Future<Set<String>> upload(List<PendingSyncItem> items) async {
    if (failUploads) throw const SocketException('Network unavailable');
    final ids = items.map((item) => item.id).toSet();
    receivedIds.addAll(ids);
    acknowledgedIds.addAll(ids);
    return ids;
  }
}

class SyncService extends ChangeNotifier implements SensorReadingSink {
  // Keep the public named parameters while storing dependencies privately.
  SyncService({required PendingSyncStore store, required SyncBackend backend})
    // ignore: prefer_initializing_formals
    : _store = store,
      // ignore: prefer_initializing_formals
      _backend = backend;

  final PendingSyncStore _store;
  final SyncBackend _backend;
  final Map<String, PendingSyncItem> _items = {};
  SyncState _state = SyncState.synced;
  bool _loaded = false;
  bool _uploading = false;

  SyncState get state => _state;
  int get pendingCount =>
      _items.values.where((item) => item.state != SyncState.synced).length;
  List<PendingSyncItem> get items => List.unmodifiable(_items.values);

  Future<void> initialize() async {
    if (_loaded) return;
    for (final item in await _store.load()) {
      _items[item.id] = item;
    }
    _loaded = true;
    _updateState();
  }

  @override
  Future<void> enqueue(SensorReading reading) async {
    await initialize();
    final id = _readingId(reading);
    if (_items.containsKey(id)) return;
    _items[id] = PendingSyncItem(id: id, reading: reading);
    await _persist();
    _updateState();
  }

  Future<void> retry() async {
    await initialize();
    await syncPending();
  }

  Future<void> syncPending() async {
    await initialize();
    if (_uploading) return;
    final pending = _items.values
        .where((item) => item.state != SyncState.synced)
        .toList();
    if (pending.isEmpty) {
      _state = SyncState.synced;
      notifyListeners();
      return;
    }
    _uploading = true;
    _state = SyncState.uploading;
    for (final item in pending) {
      item.state = SyncState.uploading;
    }
    notifyListeners();
    try {
      final acknowledged = await _backend.upload(pending);
      for (final item in pending) {
        if (acknowledged.contains(item.id)) {
          item.state = SyncState.synced;
          item.error = null;
        } else {
          item.state = SyncState.failed;
          item.error = 'The server did not acknowledge this observation.';
        }
      }
      await _persist();
      _state = pending.every((item) => item.state == SyncState.synced)
          ? SyncState.synced
          : SyncState.failed;
    } catch (error) {
      for (final item in pending) {
        item.state = SyncState.failed;
        item.attempts++;
        item.error = error.toString();
      }
      await _persist();
      _state = SyncState.failed;
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  Future<void> clearSynced() async {
    await initialize();
    _items.removeWhere((_, item) => item.state == SyncState.synced);
    await _persist();
    _updateState();
  }

  Future<void> _persist() => _store.save(_items.values.toList());

  void _updateState() {
    _state = _items.values.any((item) => item.state == SyncState.failed)
        ? SyncState.failed
        : _items.values.any((item) => item.state != SyncState.synced)
        ? SyncState.pending
        : SyncState.synced;
    notifyListeners();
  }

  String _readingId(SensorReading reading) =>
      '${reading.timestamp.microsecondsSinceEpoch}:${reading.gps.latitude.toStringAsFixed(6)}:${reading.gps.longitude.toStringAsFixed(6)}';
}

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key, required this.service});

  final SyncService service;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) {
      final label = switch (service.state) {
        SyncState.pending => 'Pending sync · ${service.pendingCount}',
        SyncState.uploading => 'Syncing',
        SyncState.failed => 'Sync paused',
        SyncState.synced => 'Synced',
      };
      return StatusIndicator(
        label: label,
        tone: service.state == SyncState.failed
            ? StatusTone.error
            : service.state == SyncState.pending
            ? StatusTone.warning
            : StatusTone.good,
      );
    },
  );
}
