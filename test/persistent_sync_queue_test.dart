import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:road_loop/backend.dart';
import 'package:road_loop/explore.dart';
import 'package:road_loop/reports.dart';
import 'package:road_loop/sensors.dart';
import 'package:road_loop/sync.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('roadsense_sync_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  SensorReading createReading({DateTime? timestamp}) => SensorReading(
    accelerometer: const Vector3(1, 2, 3),
    gyroscope: const Vector3(0.1, 0.2, 0.3),
    gps: GpsReading(
      latitude: 12.9716,
      longitude: 77.5946,
      accuracy: 5.0,
      speedMps: 12.0,
      timestamp: timestamp ?? DateTime.utc(2026, 10, 24, 9, 0),
    ),
    speedMps: 12.0,
    timestamp: timestamp ?? DateTime.utc(2026, 10, 24, 9, 0),
  );

  UserReport createReport({
    String id = 'report_001',
    String userId = 'user_alice',
    double lat = 12.9716,
    double lng = 77.5946,
  }) => UserReport(
    id: id,
    userId: userId,
    tripId: 'trip_100',
    category: ReportCategory.pothole,
    location: RoadLocation(latitude: lat, longitude: lng),
    severity: HazardSeverity.high,
    submittedAt: DateTime.utc(2026, 10, 24, 9, 0),
    description: 'Deep road depression',
  );

  HazardObservation createObservation({
    String id = 'obs_001',
    String userId = 'user_alice',
  }) => HazardObservation(
    id: id,
    segmentId: 'seg_blr_10',
    timestamp: DateTime.utc(2026, 10, 24, 9, 0),
    userId: userId,
    tripId: 'trip_100',
    location: const RoadLocation(latitude: 12.97, longitude: 77.59),
    type: HazardType.pothole,
    severity: HazardSeverity.moderate,
  );

  group('Module 06: Persistent Queue Survival & Polymorphism', () {
    test('Queued report, observation, and reading survive simulated process restart', () async {
      final queueFile = File('${tempDir.path}/sync_queue.json');
      final store = JsonFilePendingSyncStore(queueFile);
      final backend = MockSyncBackend();

      final service = SyncService(
        store: store,
        backend: backend,
        activeUserId: 'user_alice',
      );
      await service.initialize();

      // Enqueue sensor reading
      await service.enqueue(createReading());

      // Enqueue user report
      await service.enqueueReport(
        createReport(id: 'report_persisted', userId: 'user_alice'),
      );

      // Enqueue hazard observation
      await service.enqueueObservation(
        createObservation(id: 'obs_persisted', userId: 'user_alice'),
      );

      expect(service.pendingCount, 3);
      service.dispose();

      // Simulate App Restart by creating a completely new SyncService from the same file
      final restartedStore = JsonFilePendingSyncStore(queueFile);
      final restartedService = SyncService(
        store: restartedStore,
        backend: backend,
        activeUserId: 'user_alice',
      );
      await restartedService.initialize();

      expect(restartedService.items.length, 3);
      expect(restartedService.pendingCount, 3);

      final reportItem = restartedService.items.firstWhere(
        (i) => i.id == 'report_persisted',
      );
      expect(reportItem.type, SyncOperationType.userReport);
      expect(reportItem.report?.description, 'Deep road depression');
      expect(reportItem.ownerUid, 'user_alice');

      final obsItem = restartedService.items.firstWhere(
        (i) => i.id == 'obs_persisted',
      );
      expect(obsItem.type, SyncOperationType.hazardObservation);
      expect(obsItem.observation?.segmentId, 'seg_blr_10');

      restartedService.dispose();
    });

    test('Malformed queue JSON gracefully falls back to empty or valid items without crashing', () async {
      final queueFile = File('${tempDir.path}/corrupt_queue.json');
      await queueFile.writeAsString(
        '[{"id": "bad_entry", "state": "pending"}]',
      );

      final store = JsonFilePendingSyncStore(queueFile);
      final service = SyncService(store: store, backend: MockSyncBackend());
      await service.initialize();

      expect(service.items.length, 1);
      expect(service.items.first.id, 'bad_entry');
      expect(service.items.first.type, SyncOperationType.sensorReading);
      service.dispose();
    });
  });

  group('Module 06: Synchronization Mechanics, Retries & Idempotency', () {
    test('Successful sync transitions items to synced and does not duplicate on re-sync', () async {
      final store = InMemoryPendingSyncStore();
      final backend = MockSyncBackend();
      final service = SyncService(
        store: store,
        backend: backend,
        activeUserId: 'user_alice',
      );

      await service.enqueueReport(createReport(id: 'rep_1'));
      expect(service.pendingCount, 1);
      expect(service.state, SyncState.pending);

      // Perform sync
      await service.syncPending();
      expect(service.state, SyncState.synced);
      expect(service.pendingCount, 0);
      expect(backend.receivedIds, ['rep_1']);

      // Repeated sync should NOT upload already synced items
      await service.syncPending();
      expect(
        backend.receivedIds.length,
        1,
        reason: 'Must be idempotent; no duplicate upload',
      );
      service.dispose();
    });

    test('Temporary failure retains entry, increments attempts, and recovers on retry', () async {
      final store = InMemoryPendingSyncStore();
      final backend = MockSyncBackend(failUploads: true);
      final service = SyncService(
        store: store,
        backend: backend,
        activeUserId: 'user_alice',
      );

      await service.enqueueReport(createReport(id: 'rep_temp_fail'));
      await service.syncPending();

      expect(service.state, SyncState.failed);
      expect(service.pendingCount, 1);
      expect(service.items.single.attempts, 1);
      expect(service.items.single.error, contains('Network unavailable'));

      // Backend recovers
      final healthyBackend = MockSyncBackend(failUploads: false);
      final recoveredService = SyncService(
        store: store,
        backend: healthyBackend,
        activeUserId: 'user_alice',
      );
      await recoveredService.initialize();
      await recoveredService.retry();

      expect(recoveredService.state, SyncState.synced);
      expect(recoveredService.pendingCount, 0);
      expect(healthyBackend.receivedIds, ['rep_temp_fail']);
      service.dispose();
      recoveredService.dispose();
    });

    test('Permanent validation failure is marked isPermanentFailure and not retried automatically', () async {
      final gateway = InMemoryFirebaseGateway();
      final roadSenseBackend = firebaseBackend(gateway);
      final syncBackend = FirebaseSyncBackend(backend: roadSenseBackend);

      final store = InMemoryPendingSyncStore();
      final service = SyncService(
        store: store,
        backend: syncBackend,
        activeUserId: 'user_alice',
      );

      // Create report with invalid latitude (95.0 > 90.0)
      final badReport = createReport(id: 'rep_bad_coords', lat: 95.0);
      await service.enqueueReport(badReport);

      await service.syncPending();

      final item = service.items.single;
      expect(item.state, SyncState.failed);
      expect(item.isPermanentFailure, isTrue);
      expect(item.error, contains('Latitude must be between -90 and 90'));
      expect(item.attempts, 1);

      // Subsequent syncPending should skip this permanent failure
      await service.syncPending();
      // Attempts should NOT increase because permanent failures are excluded from auto-retry
      expect(item.attempts, 1);
      service.dispose();
    });

    test(
      'Concurrent sync requests do not process the same entry simultaneously',
      () async {
        final store = InMemoryPendingSyncStore();
        final backend = MockSyncBackend();
        final service = SyncService(
          store: store,
          backend: backend,
          activeUserId: 'user_alice',
        );

        await service.enqueueReport(createReport(id: 'rep_concurrent'));

        // Launch two syncs concurrently
        final future1 = service.syncPending();
        final future2 = service.syncPending();

        await Future.wait([future1, future2]);

        expect(
          backend.receivedIds.length,
          1,
          reason: 'Mutex lock must prevent double-upload',
        );
        service.dispose();
      },
    );
  });

  group('Module 06: Account Isolation & Quarantine Policy', () {
    test('Records owned by another account are quarantined on account switch and never uploaded', () async {
      final store = InMemoryPendingSyncStore();
      final backend = MockSyncBackend();
      final service = SyncService(
        store: store,
        backend: backend,
        activeUserId: 'user_alice',
      );

      // Alice creates a report while logged in
      await service.enqueueReport(
        createReport(id: 'alice_report', userId: 'user_alice'),
      );
      expect(service.pendingCount, 1);

      // Alice logs out and Bob logs in
      service.setActiveUser('user_bob');

      // Item should be quarantined
      expect(service.quarantinedCount, 1);
      final quarantinedItem = service.items.single;
      expect(quarantinedItem.state, SyncState.quarantined);
      expect(quarantinedItem.error, contains('Account mismatch'));

      // Bob syncs - Alice report MUST NOT be uploaded!
      await service.syncPending();
      expect(
        backend.receivedIds,
        isEmpty,
        reason: 'Alice records must never be uploaded by Bob',
      );
      expect(quarantinedItem.state, SyncState.quarantined);

      // Bob logs out and Alice logs back in
      service.setActiveUser('user_alice');
      expect(service.quarantinedCount, 0);
      expect(service.pendingCount, 1);

      // Now Alice can sync her report cleanly
      await service.syncPending();
      expect(backend.receivedIds, ['alice_report']);
      expect(service.state, SyncState.synced);
      service.dispose();
    });

    test('Quarantined records are never silently deleted', () async {
      final store = InMemoryPendingSyncStore();
      final backend = MockSyncBackend();
      final service = SyncService(
        store: store,
        backend: backend,
        activeUserId: 'user_alice',
      );

      await service.enqueueReport(
        createReport(id: 'rep_safe', userId: 'user_alice'),
      );
      service.setActiveUser(null); // Sign out

      expect(service.items.length, 1);
      expect(service.items.single.state, SyncState.quarantined);

      // Clear synced should NOT delete quarantined items
      await service.clearSynced();
      expect(service.items.length, 1);
      service.dispose();
    });
  });

  group('Module 06: Connectivity Integration & Real Backend Adapter', () {
    test('Connectivity transition to online automatically triggers synchronization', () async {
      final connectivity = MockConnectivityService(initialConnected: false);
      final store = InMemoryPendingSyncStore();
      final backend = MockSyncBackend();

      final service = SyncService(
        store: store,
        backend: backend,
        connectivity: connectivity,
        activeUserId: 'user_alice',
      );

      await service.enqueueReport(createReport(id: 'rep_online_trigger'));
      expect(backend.receivedIds, isEmpty);

      // While offline, sync fails immediately
      await service.syncPending();
      expect(service.state, SyncState.failed);
      expect(service.lastError, 'Device is offline.');
      expect(backend.receivedIds, isEmpty);

      // Connectivity returns!
      connectivity.setConnected(true);

      // Give event loop a microsecond to dispatch stream
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(backend.receivedIds, ['rep_online_trigger']);
      expect(service.state, SyncState.synced);

      connectivity.dispose();
      service.dispose();
    });

    test(
      'FirebaseSyncBackend dispatches reports to real backend repositories',
      () async {
        final gateway = InMemoryFirebaseGateway();
        final roadSenseBackend = firebaseBackend(gateway);
        final syncBackend = FirebaseSyncBackend(backend: roadSenseBackend);

        final store = InMemoryPendingSyncStore();
        final service = SyncService(
          store: store,
          backend: syncBackend,
          activeUserId: 'user_alice',
        );

        final report = createReport(
          id: 'real_backend_rep',
          userId: 'user_alice',
        );
        await service.enqueueReport(report);

        await service.syncPending();

        expect(service.state, SyncState.synced);

        // Verify report was actually saved into BackendCollections.reports in gateway
        final savedDoc = await gateway.getDocument(
          BackendCollections.reports,
          'real_backend_rep',
        );
        expect(savedDoc, isNotNull);
        expect(savedDoc!['reporterUid'], 'user_alice');
        expect(savedDoc['description'], 'Deep road depression');
        service.dispose();
      },
    );
  });
}
