import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'backend.dart';
import 'design_system.dart';
import 'explore.dart';
import 'reports.dart';
import 'sensors.dart';

enum SyncState { pending, uploading, synced, failed, quarantined }

enum SyncOperationType { sensorReading, userReport, hazardObservation }

class PendingSyncItem {
  PendingSyncItem({
    required this.id,
    this.type = SyncOperationType.sensorReading,
    this.ownerUid,
    SensorReading? reading,
    this.report,
    this.observation,
    this.state = SyncState.pending,
    this.attempts = 0,
    this.error,
    this.isPermanentFailure = false,
    DateTime? createdAt,
    this.schemaVersion = 1,
  }) : reading = reading ?? _dummyReading,
       createdAt = createdAt ?? DateTime.now().toUtc();

  factory PendingSyncItem.report({
    required String id,
    required UserReport report,
    String? ownerUid,
    SyncState state = SyncState.pending,
    int attempts = 0,
    String? error,
    bool isPermanentFailure = false,
    DateTime? createdAt,
  }) => PendingSyncItem(
    id: id,
    type: SyncOperationType.userReport,
    ownerUid: ownerUid ?? report.userId,
    report: report,
    state: state,
    attempts: attempts,
    error: error,
    isPermanentFailure: isPermanentFailure,
    createdAt: createdAt,
  );

  factory PendingSyncItem.observation({
    required String id,
    required HazardObservation observation,
    String? ownerUid,
    SyncState state = SyncState.pending,
    int attempts = 0,
    String? error,
    bool isPermanentFailure = false,
    DateTime? createdAt,
  }) => PendingSyncItem(
    id: id,
    type: SyncOperationType.hazardObservation,
    ownerUid: ownerUid ?? observation.userId,
    observation: observation,
    state: state,
    attempts: attempts,
    error: error,
    isPermanentFailure: isPermanentFailure,
    createdAt: createdAt,
  );

  final String id;
  final SyncOperationType type;
  final String? ownerUid;
  final SensorReading reading;
  final UserReport? report;
  final HazardObservation? observation;
  SyncState state;
  int attempts;
  String? error;
  bool isPermanentFailure;
  final DateTime createdAt;
  final int schemaVersion;

  static final SensorReading _dummyReading = SensorReading(
    accelerometer: const Vector3(0, 0, 0),
    gyroscope: const Vector3(0, 0, 0),
    gps: GpsReading(
      latitude: 0,
      longitude: 0,
      accuracy: 0,
      speedMps: 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    ),
    speedMps: 0,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    if (ownerUid != null) 'ownerUid': ownerUid,
    'state': state.name,
    'attempts': attempts,
    if (error != null) 'error': error,
    'isPermanentFailure': isPermanentFailure,
    'createdAt': createdAt.toIso8601String(),
    'schemaVersion': schemaVersion,
    if (type == SyncOperationType.sensorReading ||
        (report == null && observation == null))
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
    if (report != null)
      'report': {
        'id': report!.id,
        'userId': report!.userId,
        'tripId': report!.tripId,
        'category': report!.category.name,
        'latitude': report!.location.latitude,
        'longitude': report!.location.longitude,
        'severity': report!.severity.name,
        'submittedAt': report!.submittedAt.toUtc().toIso8601String(),
        if (report!.description != null) 'description': report!.description,
        if (report!.photoPath != null) 'photoPath': report!.photoPath,
      },
    if (observation != null)
      'observation': {
        'id': observation!.id,
        'segmentId': observation!.segmentId,
        'userId': observation!.userId,
        'tripId': observation!.tripId,
        'type': observation!.type.name,
        'severity': observation!.severity.name,
        'latitude': observation!.location.latitude,
        'longitude': observation!.location.longitude,
        'timestamp': observation!.timestamp.toUtc().toIso8601String(),
      },
  };

  static PendingSyncItem fromJson(Map<String, Object?> json) {
    final rawType = json['type'] as String?;
    final type = rawType != null
        ? SyncOperationType.values.firstWhere(
            (t) => t.name == rawType,
            orElse: () => SyncOperationType.sensorReading,
          )
        : SyncOperationType.sensorReading;

    final id = json['id']! as String;
    final state = SyncState.values.byName(json['state']! as String);
    final attempts = (json['attempts'] as num?)?.toInt() ?? 0;
    final error = json['error'] as String?;
    final ownerUid = json['ownerUid'] as String?;
    final isPermanentFailure = json['isPermanentFailure'] as bool? ?? false;
    final createdAt = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt']! as String)?.toUtc()
        : null;
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt() ?? 1;

    SensorReading? reading;
    if (json.containsKey('reading') && json['reading'] is Map) {
      final readingMap = (json['reading']! as Map<Object?, Object?>)
          .cast<String, Object?>();
      final accelerometer = (readingMap['accelerometer']! as List<Object?>)
          .cast<num>();
      final gyroscope = (readingMap['gyroscope']! as List<Object?>).cast<num>();
      reading = SensorReading(
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
          latitude: (readingMap['latitude']! as num).toDouble(),
          longitude: (readingMap['longitude']! as num).toDouble(),
          altitude: (readingMap['altitude'] as num?)?.toDouble(),
          accuracy: (readingMap['accuracy']! as num).toDouble(),
          speedMps: (readingMap['speedMps']! as num).toDouble(),
          timestamp: DateTime.parse(readingMap['timestamp']! as String),
        ),
        speedMps: (readingMap['speedMps']! as num).toDouble(),
        timestamp: DateTime.parse(readingMap['timestamp']! as String),
      );
    }

    UserReport? report;
    if (json.containsKey('report') && json['report'] is Map) {
      final repMap = (json['report']! as Map<Object?, Object?>)
          .cast<String, Object?>();
      report = UserReport(
        id: repMap['id']! as String,
        userId: (repMap['userId'] ?? ownerUid ?? '') as String,
        tripId: (repMap['tripId'] ?? 'offline_trip') as String,
        category: ReportCategory.values.firstWhere(
          (c) => c.name == repMap['category'],
          orElse: () => ReportCategory.other,
        ),
        location: RoadLocation(
          latitude: (repMap['latitude']! as num).toDouble(),
          longitude: (repMap['longitude']! as num).toDouble(),
        ),
        severity: HazardSeverity.values.firstWhere(
          (s) => s.name == repMap['severity'],
          orElse: () => HazardSeverity.moderate,
        ),
        submittedAt: DateTime.parse(repMap['submittedAt']! as String),
        description: repMap['description'] as String?,
        photoPath: repMap['photoPath'] as String?,
      );
    }

    HazardObservation? observation;
    if (json.containsKey('observation') && json['observation'] is Map) {
      final obsMap = (json['observation']! as Map<Object?, Object?>)
          .cast<String, Object?>();
      observation = HazardObservation(
        id: obsMap['id']! as String,
        segmentId: (obsMap['segmentId'] ?? 'unmatched') as String,
        userId: (obsMap['userId'] ?? ownerUid ?? '') as String,
        tripId: (obsMap['tripId'] ?? 'offline_trip') as String,
        type: HazardType.values.firstWhere(
          (t) => t.name == obsMap['type'],
          orElse: () => HazardType.unknown,
        ),
        severity: HazardSeverity.values.firstWhere(
          (s) => s.name == obsMap['severity'],
          orElse: () => HazardSeverity.possible,
        ),
        location: RoadLocation(
          latitude: (obsMap['latitude']! as num).toDouble(),
          longitude: (obsMap['longitude']! as num).toDouble(),
        ),
        timestamp: DateTime.parse(obsMap['timestamp']! as String),
      );
    }

    return PendingSyncItem(
      id: id,
      type: type,
      ownerUid: ownerUid,
      reading: reading,
      report: report,
      observation: observation,
      state: state,
      attempts: attempts,
      error: error,
      isPermanentFailure: isPermanentFailure,
      createdAt: createdAt,
      schemaVersion: schemaVersion,
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

class FirebaseSyncBackend implements SyncBackend {
  FirebaseSyncBackend({required this.backend, this.currentUserIdProvider});

  final RoadSenseBackend backend;
  final String? Function()? currentUserIdProvider;

  @override
  Future<Set<String>> upload(List<PendingSyncItem> items) async {
    final acknowledged = <String>{};
    final currentUid =
        currentUserIdProvider?.call() ?? backend.auth.currentUser?.id;

    for (final item in items) {
      if (item.ownerUid != null &&
          currentUid != null &&
          item.ownerUid != currentUid) {
        item.state = SyncState.quarantined;
        item.error =
            'Account mismatch: Item owned by ${item.ownerUid}, active user is $currentUid.';
        continue;
      }

      try {
        switch (item.type) {
          case SyncOperationType.userReport:
            if (item.report != null) {
              await backend.reports.submit(item.report!);
              acknowledged.add(item.id);
            }
            break;
          case SyncOperationType.hazardObservation:
            if (item.observation != null) {
              await backend.hazardObservations.save(item.observation!);
              acknowledged.add(item.id);
            }
            break;
          case SyncOperationType.sensorReading:
            final tripId = item.id.contains(':')
                ? item.id.split(':').first
                : 'unassigned_trip';
            await backend.sensorReadings.append(
              tripId: tripId,
              reading: item.reading,
            );
            acknowledged.add(item.id);
            break;
        }
      } on BackendException catch (e) {
        item.error = e.message;
        if (e.failure == BackendFailure.invalidData ||
            e.failure == BackendFailure.permission) {
          item.isPermanentFailure = true;
        }
      } on FormatException catch (e) {
        item.error = e.message;
        item.isPermanentFailure = true;
      } catch (e) {
        item.error = e.toString();
      }
    }
    return acknowledged;
  }
}

abstract interface class ConnectivityService {
  Future<bool> get isConnected;
  Stream<bool> get onConnectivityChanged;
}

class MockConnectivityService implements ConnectivityService {
  MockConnectivityService({bool initialConnected = true})
    : _isConnected = initialConnected;

  bool _isConnected;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isConnected async => _isConnected;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void setConnected(bool connected) {
    if (_isConnected == connected) return;
    _isConnected = connected;
    _controller.add(connected);
  }

  void dispose() {
    _controller.close();
  }
}

class SyncService extends ChangeNotifier implements SensorReadingSink {
  SyncService({
    required this.store,
    required this.backend,
    this.connectivity,
    this.activeUserId,
    this.maxRetryAttempts = 5,
  }) {
    _connectivitySubscription = connectivity?.onConnectivityChanged.listen((
      connected,
    ) {
      if (connected) {
        syncPending();
      }
    });
  }

  final PendingSyncStore store;
  final SyncBackend backend;
  final ConnectivityService? connectivity;
  final int maxRetryAttempts;
  StreamSubscription<bool>? _connectivitySubscription;

  String? activeUserId;

  final Map<String, PendingSyncItem> _items = {};
  SyncState _state = SyncState.synced;
  bool _loaded = false;
  bool _uploading = false;
  DateTime? _lastSyncTime;
  String? _lastError;

  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;
  SyncState get state => _state;
  bool get isSyncing => _uploading;

  int get pendingCount => _items.values
      .where(
        (item) =>
            item.state != SyncState.synced &&
            item.state != SyncState.quarantined,
      )
      .length;

  int get failedCount =>
      _items.values.where((item) => item.state == SyncState.failed).length;
  int get syncedCount =>
      _items.values.where((item) => item.state == SyncState.synced).length;
  int get quarantinedCount =>
      _items.values.where((item) => item.state == SyncState.quarantined).length;

  List<PendingSyncItem> get items => List.unmodifiable(_items.values);

  List<PendingSyncItem> get activeUserItems => List.unmodifiable(
    _items.values.where(
      (item) => item.ownerUid == null || item.ownerUid == activeUserId,
    ),
  );

  List<PendingSyncItem> get quarantinedItems => List.unmodifiable(
    _items.values.where((item) => item.state == SyncState.quarantined),
  );

  void setActiveUser(String? newUserId) {
    if (activeUserId == newUserId) return;
    activeUserId = newUserId;

    for (final item in _items.values) {
      if (item.ownerUid != null &&
          (newUserId == null || item.ownerUid != newUserId)) {
        if (item.state != SyncState.synced) {
          item.state = SyncState.quarantined;
          item.error = newUserId == null
              ? 'User signed out. Item owned by ${item.ownerUid} is quarantined.'
              : 'Account mismatch: Owned by ${item.ownerUid}, active user is $newUserId.';
        }
      } else if (item.ownerUid != null &&
          newUserId != null &&
          item.ownerUid == newUserId) {
        if (item.state == SyncState.quarantined) {
          item.state = item.attempts > 0 ? SyncState.failed : SyncState.pending;
          item.error = null;
        }
      }
    }
    _persist();
    _updateState();
  }

  Future<void> initialize() async {
    if (_loaded) return;
    for (final item in await store.load()) {
      _items[item.id] = item;
    }
    _loaded = true;
    _updateState();
  }

  @override
  Future<void> enqueue(
    SensorReading reading, {
    String? tripId,
    String? ownerUid,
  }) async {
    await initialize();
    final id = _readingId(reading, tripId: tripId);
    if (_items.containsKey(id)) return;
    _items[id] = PendingSyncItem(
      id: id,
      type: SyncOperationType.sensorReading,
      ownerUid: ownerUid ?? activeUserId,
      reading: reading,
    );
    await _persist();
    _updateState();
  }

  Future<void> enqueueReport(UserReport report, {String? ownerUid}) async {
    await initialize();
    if (_items.containsKey(report.id)) return;
    _items[report.id] = PendingSyncItem.report(
      id: report.id,
      report: report,
      ownerUid: ownerUid ?? report.userId,
    );
    await _persist();
    _updateState();
  }

  Future<void> enqueueObservation(
    HazardObservation observation, {
    String? ownerUid,
  }) async {
    await initialize();
    if (_items.containsKey(observation.id)) return;
    _items[observation.id] = PendingSyncItem.observation(
      id: observation.id,
      observation: observation,
      ownerUid: ownerUid ?? observation.userId,
    );
    await _persist();
    _updateState();
  }

  Future<void> retry() async {
    await initialize();
    for (final item in _items.values) {
      if (item.state == SyncState.failed && !item.isPermanentFailure) {
        item.state = SyncState.pending;
      }
    }
    await syncPending();
  }

  Future<void> syncPending() async {
    await initialize();
    if (_uploading) return;

    if (connectivity != null && !(await connectivity!.isConnected)) {
      _state = SyncState.failed;
      _lastError = 'Device is offline.';
      notifyListeners();
      return;
    }

    final eligible = _items.values.where((item) {
      if (item.state == SyncState.synced ||
          item.state == SyncState.quarantined) {
        return false;
      }
      if (item.isPermanentFailure) {
        return false;
      }
      if (item.attempts >= maxRetryAttempts) {
        return false;
      }
      if (item.ownerUid != null &&
          activeUserId != null &&
          item.ownerUid != activeUserId) {
        item.state = SyncState.quarantined;
        return false;
      }
      return true;
    }).toList();

    if (eligible.isEmpty) {
      _updateState();
      return;
    }

    _uploading = true;
    _state = SyncState.uploading;
    for (final item in eligible) {
      item.state = SyncState.uploading;
    }
    notifyListeners();

    try {
      final acknowledged = await backend.upload(eligible);
      for (final item in eligible) {
        if (acknowledged.contains(item.id)) {
          item.state = SyncState.synced;
          item.error = null;
        } else {
          item.state = SyncState.failed;
          item.attempts++;
          item.error ??= 'The server did not acknowledge this record.';
        }
      }
      _lastSyncTime = DateTime.now().toUtc();
      _lastError = null;
    } catch (error) {
      _lastError = error.toString();
      for (final item in eligible) {
        item.state = SyncState.failed;
        item.attempts++;
        item.error = error.toString();
      }
    } finally {
      await _persist();
      _uploading = false;
      _updateState();
    }
  }

  Future<void> clearSynced() async {
    await initialize();
    _items.removeWhere((_, item) => item.state == SyncState.synced);
    await _persist();
    _updateState();
  }

  Future<void> discardItem(String id) async {
    await initialize();
    _items.remove(id);
    await _persist();
    _updateState();
  }

  Future<void> _persist() => store.save(_items.values.toList());

  void _updateState() {
    if (_uploading) {
      _state = SyncState.uploading;
    } else if (_items.values.any((item) => item.state == SyncState.failed)) {
      _state = SyncState.failed;
    } else if (_items.values.any((item) => item.state == SyncState.pending)) {
      _state = SyncState.pending;
    } else if (_items.values.any(
      (item) => item.state == SyncState.quarantined,
    )) {
      _state = SyncState.quarantined;
    } else {
      _state = SyncState.synced;
    }
    notifyListeners();
  }

  String _readingId(SensorReading reading, {String? tripId}) =>
      '${tripId ?? 'trip'}:${reading.timestamp.microsecondsSinceEpoch}:${reading.gps.latitude.toStringAsFixed(6)}:${reading.gps.longitude.toStringAsFixed(6)}';

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
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
        SyncState.failed => 'Sync paused · ${service.failedCount} failed',
        SyncState.quarantined =>
          'Account mismatch · ${service.quarantinedCount} quarantined',
        SyncState.synced => 'Synced',
      };
      return StatusIndicator(
        label: label,
        tone: service.state == SyncState.failed
            ? StatusTone.error
            : service.state == SyncState.quarantined
            ? StatusTone.warning
            : service.state == SyncState.pending
            ? StatusTone.warning
            : StatusTone.good,
      );
    },
  );
}
