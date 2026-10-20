import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:road_loop/sensors.dart';
import 'package:road_loop/sync.dart';

void main() {
  test('queue prevents duplicate uploads and persists across service restart', () async {
    final file = File(
      '${Directory.systemTemp.path}/roadsense-sync-${DateTime.now().microsecondsSinceEpoch}.json',
    );
    final store = JsonFilePendingSyncStore(file);
    final backend = TestBackend();
    final reading = _reading(DateTime(2026, 10, 7, 10));
    final first = SyncService(store: store, backend: backend);
    await first.enqueue(reading);
    await first.enqueue(reading);
    expect(first.pendingCount, 1);
    await first.syncPending();
    expect(backend.uploadedIds, hasLength(1));

    final restarted = SyncService(store: store, backend: backend);
    await restarted.initialize();
    expect(restarted.items, hasLength(1));
    expect(restarted.items.single.state, SyncState.synced);
    await file.delete();
    first.dispose();
    restarted.dispose();
  });

  test('network failure retains observations for retry', () async {
    final store = InMemoryPendingSyncStore();
    final backend = TestBackend()..fail = true;
    final service = SyncService(store: store, backend: backend);
    await service.enqueue(_reading(DateTime(2026, 10, 7, 11)));
    await service.syncPending();

    expect(service.state, SyncState.failed);
    expect(service.pendingCount, 1);
    expect(service.items.single.attempts, 1);

    backend.fail = false;
    await service.retry();
    expect(service.state, SyncState.synced);
    expect(service.pendingCount, 0);
    service.dispose();
  });

  test('partial upload leaves only unacknowledged items failed', () async {
    final backend = TestBackend()..acknowledgeOnlyFirst = true;
    final service = SyncService(
      store: InMemoryPendingSyncStore(),
      backend: backend,
    );
    await service.enqueue(_reading(DateTime(2026, 10, 7, 12)));
    await service.enqueue(_reading(DateTime(2026, 10, 7, 12, 0, 1)));
    await service.syncPending();

    expect(service.state, SyncState.failed);
    expect(
      service.items.where((item) => item.state == SyncState.synced),
      hasLength(1),
    );
    expect(
      service.items.where((item) => item.state == SyncState.failed),
      hasLength(1),
    );
    service.dispose();
  });
}

SensorReading _reading(DateTime timestamp) => SensorReading(
  accelerometer: const Vector3(1, 2, 3),
  gyroscope: const Vector3(.1, .2, .3),
  gps: GpsReading(
    latitude: 51.5,
    longitude: -.12,
    accuracy: 4,
    speedMps: 10,
    timestamp: timestamp,
  ),
  speedMps: 10,
  timestamp: timestamp,
);

class TestBackend implements SyncBackend {
  bool fail = false;
  bool acknowledgeOnlyFirst = false;
  final uploadedIds = <String>[];

  @override
  Future<Set<String>> upload(List<PendingSyncItem> items) {
    if (fail) throw const SocketException('offline');
    final ids = items.map((item) => item.id).toList();
    uploadedIds.addAll(ids);
    return Future.value((acknowledgeOnlyFirst ? ids.take(1) : ids).toSet());
  }
}
