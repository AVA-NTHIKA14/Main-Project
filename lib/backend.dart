import 'dart:async';

import 'auth.dart';
import 'detection.dart';
import 'domain/schema/schema_documents.dart';
import 'explore.dart';
import 'reports.dart';
import 'sensors.dart';
import 'trips.dart';
import 'verification.dart';

abstract final class BackendCollections {
  static const users = 'users';
  static const trips = 'trips';
  static const sensorWindows = 'sensorWindows';
  static const hazardObservations = 'hazardObservations';
  static const reports = 'reports';
  static const hazards = 'hazards';
  static const verificationDecisions = 'verificationDecisions';
  static const modelPredictions = 'modelPredictions';
  static const roadSegments = 'roadSegments';

  // Backward-compatible collection path aliases
  static const sensorReadings = 'sensor_readings';
  static const detectionEvents = 'detection_events';
  static const crowdClusters = 'crowd_clusters';
}

enum BackendFailure {
  network,
  authentication,
  permission,
  unavailable,
  invalidData,
}

class BackendException implements Exception {
  const BackendException(this.failure, this.message, {this.cause});

  final BackendFailure failure;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

abstract interface class BackendAuthService implements AuthenticationService {}

abstract interface class BackendUserRepository implements UserRepository {
  Future<RoadSenseUser?> findById(String id);
  Future<void> updateProfile(RoadSenseUser user);
}

abstract interface class BackendTripRepository
    implements TripHistoryRepository {
  Future<void> saveTrip(Trip trip);
}

abstract interface class SensorReadingRepository {
  Future<void> append({required String tripId, required SensorReading reading});
  Future<List<SensorReading>> forTrip(String tripId);
}

abstract interface class DetectionEventRepository {
  Future<void> save(DetectionResult result);
  Future<List<DetectionResult>> recent({int limit = 100});
}

abstract interface class BackendReportRepository implements ReportRepository {}

abstract interface class HazardRepository {
  Future<void> save(Hazard hazard);
  Future<List<Hazard>> list({VerificationStatus? status});
  Future<void> updateStatus(String hazardId, VerificationStatus status);
}

abstract interface class HazardObservationRepository {
  Future<void> save(HazardObservation observation);
  Future<List<HazardObservation>> forHazard(String hazardId);
}

abstract interface class VerificationRepository {
  Future<void> saveCluster(CrowdCluster cluster);
  Future<List<CrowdCluster>> candidateClusters();
  Future<void> recordDecision({
    required String clusterId,
    required VerificationStatus status,
    required String reviewerId,
  });
}

abstract interface class RoadSegmentRepository {
  Future<List<RoadSegment>> list();
}

abstract interface class BackendStorageService {
  Future<String> uploadReportPhoto({
    required String reportId,
    required List<int> bytes,
    required String fileName,
  });
}

abstract interface class BackendFunctionsService {
  Future<void> enqueueVerification(String clusterId);
}

abstract interface class FirebaseGateway {
  Stream<RoadSenseUser?> get authStateChanges;
  RoadSenseUser? get currentUser;
  Future<RoadSenseUser> signIn({
    required String email,
    required String password,
  });
  Future<RoadSenseUser> signUp({
    required String name,
    required String email,
    required String password,
  });
  Future<void> sendPasswordReset(String email);
  Future<void> sendEmailVerification();
  Future<void> signOut();
  Future<Map<String, Object?>?> getDocument(String collection, String id);
  Future<List<Map<String, Object?>>> queryCollection(
    String collection, {
    Map<String, Object?> filters = const {},
    String? orderBy,
    bool descending = false,
    int? limit,
  });
  Future<void> setDocument(
    String collection,
    String id,
    Map<String, Object?> data, {
    bool merge = false,
  });
  Future<void> updateDocument(
    String collection,
    String id,
    Map<String, Object?> data,
  );
  Future<void> deleteDocument(String collection, String id);
  Future<String> uploadFile({required String path, required List<int> bytes});
  Future<void> callFunction(String name, Map<String, Object?> data);
}

class RoadSenseBackend {
  const RoadSenseBackend({
    required this.auth,
    required this.users,
    required this.trips,
    required this.sensorReadings,
    required this.detectionEvents,
    required this.reports,
    required this.hazards,
    required this.hazardObservations,
    required this.verification,
    required this.roadSegments,
    required this.storage,
    required this.functions,
  });

  final BackendAuthService auth;
  final BackendUserRepository users;
  final BackendTripRepository trips;
  final SensorReadingRepository sensorReadings;
  final DetectionEventRepository detectionEvents;
  final BackendReportRepository reports;
  final HazardRepository hazards;
  final HazardObservationRepository hazardObservations;
  final VerificationRepository verification;
  final RoadSegmentRepository roadSegments;
  final BackendStorageService storage;
  final BackendFunctionsService functions;
}

RoadSenseBackend firebaseBackend(FirebaseGateway gateway) => RoadSenseBackend(
  auth: FirebaseBackendAuthService(gateway),
  users: FirebaseUserRepository(gateway),
  trips: FirebaseTripHistoryRepository(gateway),
  sensorReadings: FirebaseSensorReadingRepository(gateway),
  detectionEvents: FirebaseDetectionEventRepository(gateway),
  reports: FirebaseReportRepository(gateway),
  hazards: FirebaseHazardRepository(gateway),
  hazardObservations: FirebaseHazardObservationRepository(gateway),
  verification: FirebaseVerificationRepository(gateway),
  roadSegments: FirebaseRoadSegmentRepository(gateway),
  storage: FirebaseStorageService(gateway),
  functions: FirebaseFunctionsService(gateway),
);

class FirebaseBackendAuthService implements BackendAuthService {
  const FirebaseBackendAuthService(this.gateway);
  final FirebaseGateway gateway;

  @override
  Stream<RoadSenseUser?> get authStateChanges => gateway.authStateChanges;

  @override
  RoadSenseUser? get currentUser => gateway.currentUser;

  @override
  Future<RoadSenseUser> signIn({
    required String email,
    required String password,
  }) => gateway.signIn(email: email, password: password);
  @override
  Future<RoadSenseUser> signUp({
    required String name,
    required String email,
    required String password,
  }) => gateway.signUp(name: name, email: email, password: password);
  @override
  Future<void> sendPasswordReset({required String email}) =>
      gateway.sendPasswordReset(email);
  @override
  Future<void> sendEmailVerification() => gateway.sendEmailVerification();
  @override
  Future<void> signOut() => gateway.signOut();
}

class FirebaseUserRepository implements BackendUserRepository {
  const FirebaseUserRepository(this.gateway);
  final FirebaseGateway gateway;

  @override
  Future<RoadSenseUser?> findByEmail(String email) async => _userFrom(
    await gateway
        .queryCollection(
          BackendCollections.users,
          filters: {'email': email.trim().toLowerCase()},
          limit: 1,
        )
        .then((items) => items.firstOrNull),
  );
  @override
  Future<RoadSenseUser?> findById(String id) async =>
      _userFrom(await gateway.getDocument(BackendCollections.users, id));
  @override
  Future<RoadSenseUser> create({
    required String name,
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final uid =
        gateway.currentUser?.id ?? 'mock_uid_${normalizedEmail.hashCode.abs()}';
    if (uid.contains('@')) {
      throw FormatException('Invalid user UID: $uid. Must not be email.');
    }
    final profile = UserProfileDocument(
      uid: uid,
      displayName: name.trim(),
      email: normalizedEmail,
      role: UserRole.user,
      isEmailVerified: gateway.currentUser?.isEmailVerified ?? false,
      createdAt: DateTime.now().toUtc(),
    );
    await gateway.setDocument(
      BackendCollections.users,
      profile.uid,
      profile.toMap(),
    );
    return profile.toDomain();
  }

  @override
  Future<void> updateProfile(RoadSenseUser user) async {
    if (user.id.contains('@')) {
      throw FormatException('Invalid user UID: ${user.id}. Must not be email.');
    }
    final existing = await gateway.getDocument(
      BackendCollections.users,
      user.id,
    );
    if (existing == null) {
      final profile = UserProfileDocument(
        uid: user.id,
        displayName: user.name.trim(),
        email: user.email.trim().toLowerCase(),
        role: UserRole.user,
        isEmailVerified: user.isEmailVerified,
        createdAt: DateTime.now().toUtc(),
      );
      await gateway.setDocument(
        BackendCollections.users,
        profile.uid,
        profile.toMap(),
      );
    } else {
      await gateway.updateDocument(BackendCollections.users, user.id, {
        'displayName': user.name.trim(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }
}

class FirebaseSensorReadingRepository implements SensorReadingRepository {
  const FirebaseSensorReadingRepository(this.gateway);
  final FirebaseGateway gateway;
  @override
  Future<void> append({
    required String tripId,
    required SensorReading reading,
  }) {
    GeoCoordinates.validated(
      latitude: reading.gps.latitude,
      longitude: reading.gps.longitude,
    );
    return gateway.setDocument(
      BackendCollections.sensorReadings,
      '${tripId}_${reading.timestamp.microsecondsSinceEpoch}',
      _readingData(tripId, reading),
    );
  }

  @override
  Future<List<SensorReading>> forTrip(String tripId) async => const [];
}

class FirebaseTripHistoryRepository implements BackendTripRepository {
  const FirebaseTripHistoryRepository(this.gateway);
  final FirebaseGateway gateway;

  @override
  Future<void> saveTrip(Trip trip) async {
    final activeUser = gateway.currentUser;
    final ownerUid = activeUser?.id;
    if (ownerUid == null || ownerUid.isEmpty || ownerUid.contains('@')) {
      throw const BackendException(
        BackendFailure.authentication,
        'Cannot save trip without an authenticated user UID.',
      );
    }

    final doc = TripDocument.fromDomain(trip, ownerUid: ownerUid);
    await gateway.setDocument(BackendCollections.trips, trip.id, doc.toMap());
  }

  @override
  Future<List<Trip>> recentTrips() async {
    final activeUser = gateway.currentUser;
    final ownerUid = activeUser?.id;
    if (ownerUid == null || ownerUid.isEmpty) {
      return const [];
    }

    final docs = await gateway.queryCollection(
      BackendCollections.trips,
      filters: {'ownerUid': ownerUid},
      orderBy: 'startedAt',
      descending: true,
      limit: 50,
    );

    return docs
        .map(
          (map) => TripDocument.fromMap(
            map,
            documentId: map['id'] as String?,
          ).toDomain(),
        )
        .toList();
  }

  @override
  Future<Trip?> tripById(String id) async {
    final map = await gateway.getDocument(BackendCollections.trips, id);
    if (map == null) return null;
    return TripDocument.fromMap(map, documentId: id).toDomain();
  }
}

class FirebaseDetectionEventRepository implements DetectionEventRepository {
  const FirebaseDetectionEventRepository(this.gateway);
  final FirebaseGateway gateway;

  @override
  Future<void> save(DetectionResult result) async {
    final doc = ModelPredictionDocument.fromDomain(
      result,
      predictionId: result.sensorWindowId,
    );
    await gateway.setDocument(
      BackendCollections.modelPredictions,
      result.sensorWindowId,
      doc.toMap(),
    );
    await gateway.setDocument(
      BackendCollections.detectionEvents,
      result.sensorWindowId,
      doc.toMap(),
    );
  }

  @override
  Future<List<DetectionResult>> recent({int limit = 100}) async {
    final boundedLimit = (limit <= 0 || limit > 100) ? 100 : limit;
    final docs = await gateway.queryCollection(
      BackendCollections.modelPredictions,
      orderBy: 'timestamp',
      descending: true,
      limit: boundedLimit,
    );
    return docs
        .map(
          (map) => ModelPredictionDocument.fromMap(
            map,
            documentId: map['id'] as String?,
          ).toDomain(),
        )
        .toList();
  }
}

class FirebaseReportRepository implements BackendReportRepository {
  const FirebaseReportRepository(this.gateway);
  final FirebaseGateway gateway;
  @override
  Future<UserReport> submit(UserReport report) async {
    final coords = GeoCoordinates.validated(
      latitude: report.location.latitude,
      longitude: report.location.longitude,
    );

    final activeUser = gateway.currentUser;
    final reporterUid = activeUser?.id ?? report.userId;
    if (reporterUid.isEmpty || reporterUid.contains('@')) {
      throw const BackendException(
        BackendFailure.authentication,
        'Cannot submit report without a valid authenticated user UID.',
      );
    }

    if (activeUser != null &&
        report.userId.isNotEmpty &&
        report.userId != activeUser.id) {
      throw const BackendException(
        BackendFailure.permission,
        'Reporter UID does not match currently authenticated user.',
      );
    }

    final sanitizedPhoto = sanitizePublicUrl(report.photoPath);

    final reportDoc = UserReportDocument(
      reportId: report.id,
      reporterUid: reporterUid,
      tripId: report.tripId,
      category: report.category,
      coordinates: coords,
      severity: report.severity,
      submittedAt: report.submittedAt.toUtc(),
      description: report.description,
      photoUrl: sanitizedPhoto,
      status: ReportStatus.submitted,
    );

    await gateway.setDocument(
      BackendCollections.reports,
      report.id,
      reportDoc.toMap(),
    );
    return reportDoc.toDomain();
  }

  @override
  Future<List<UserReport>> reportsForUser(String userId) async {
    if (userId.isEmpty || userId.contains('@')) {
      return const [];
    }

    final rawDocs = await gateway.queryCollection(
      BackendCollections.reports,
      filters: {'reporterUid': userId},
      limit: 100,
    );

    return rawDocs
        .map(
          (map) => UserReportDocument.fromMap(
            map,
            documentId: map['id'] as String?,
          ).toDomain(),
        )
        .toList();
  }
}

class FirebaseHazardRepository implements HazardRepository {
  const FirebaseHazardRepository(this.gateway);
  final FirebaseGateway gateway;
  @override
  Future<void> save(Hazard hazard) {
    final doc = HazardDocument.fromDomain(hazard);
    return gateway.setDocument(
      BackendCollections.hazards,
      hazard.id,
      doc.toMap(),
    );
  }

  @override
  Future<List<Hazard>> list({VerificationStatus? status}) async {
    final filters = <String, Object?>{};
    if (status != null) {
      filters['status'] = status.name;
    }
    final docs = await gateway.queryCollection(
      BackendCollections.hazards,
      filters: filters,
      limit: 100,
    );
    return docs
        .map(
          (map) => HazardDocument.fromMap(
            map,
            documentId: map['id'] as String?,
          ).toDomain(),
        )
        .toList();
  }

  @override
  Future<void> updateStatus(String hazardId, VerificationStatus status) =>
      gateway.updateDocument(BackendCollections.hazards, hazardId, {
        'status': status.name,
        if (status == VerificationStatus.verified)
          'lastConfirmedAt': DateTime.now().toUtc().toIso8601String(),
        if (status == VerificationStatus.resolved)
          'resolvedAt': DateTime.now().toUtc().toIso8601String(),
      });
}

class FirebaseHazardObservationRepository
    implements HazardObservationRepository {
  const FirebaseHazardObservationRepository(this.gateway);
  final FirebaseGateway gateway;

  @override
  Future<void> save(HazardObservation observation) {
    final doc = HazardObservationDocument.fromDomain(observation);
    return gateway.setDocument(
      BackendCollections.hazardObservations,
      observation.id,
      doc.toMap(),
    );
  }

  @override
  Future<List<HazardObservation>> forHazard(String hazardId) async {
    var docs = await gateway.queryCollection(
      BackendCollections.hazardObservations,
      filters: {'segmentId': hazardId},
      limit: 100,
    );
    if (docs.isEmpty) {
      docs = await gateway.queryCollection(
        BackendCollections.hazardObservations,
        filters: {'hazardId': hazardId},
        limit: 100,
      );
    }
    return docs
        .map(
          (map) => HazardObservationDocument.fromMap(
            map,
            documentId: map['id'] as String?,
          ).toDomain(),
        )
        .toList();
  }
}

class FirebaseVerificationRepository implements VerificationRepository {
  const FirebaseVerificationRepository(this.gateway);
  final FirebaseGateway gateway;

  @override
  Future<void> saveCluster(CrowdCluster cluster) =>
      gateway.setDocument(BackendCollections.crowdClusters, cluster.id, {
        'segmentId': cluster.segmentId,
        'observationCount': cluster.observationCount,
        'uniqueUserCount': cluster.uniqueUserCount,
        'uniqueTripCount': cluster.uniqueTripCount,
        'firstObserved': cluster.firstObserved.toIso8601String(),
        'lastObserved': cluster.lastObserved.toIso8601String(),
      });

  @override
  Future<List<CrowdCluster>> candidateClusters() async => const [];

  @override
  Future<void> recordDecision({
    required String clusterId,
    required VerificationStatus status,
    required String reviewerId,
  }) async {
    final decision = VerificationDecisionDocument(
      decisionId: '${clusterId}_${DateTime.now().millisecondsSinceEpoch}',
      hazardId: clusterId,
      reviewerUid: reviewerId,
      status: status,
      timestamp: DateTime.now().toUtc(),
    );
    await gateway.setDocument(
      BackendCollections.verificationDecisions,
      decision.decisionId,
      decision.toMap(),
    );
    await gateway.setDocument(BackendCollections.crowdClusters, clusterId, {
      'status': status.name,
      'reviewerId': reviewerId,
    }, merge: true);
  }
}

class FirebaseRoadSegmentRepository implements RoadSegmentRepository {
  const FirebaseRoadSegmentRepository(this.gateway);
  final FirebaseGateway gateway;

  @override
  Future<List<RoadSegment>> list() async => const [];
}

class FirebaseStorageService implements BackendStorageService {
  const FirebaseStorageService(this.gateway);
  final FirebaseGateway gateway;
  @override
  Future<String> uploadReportPhoto({
    required String reportId,
    required List<int> bytes,
    required String fileName,
  }) => gateway.uploadFile(
    path: '${BackendCollections.reports}/$reportId/$fileName',
    bytes: bytes,
  );
}

class FirebaseFunctionsService implements BackendFunctionsService {
  const FirebaseFunctionsService(this.gateway);
  final FirebaseGateway gateway;
  @override
  Future<void> enqueueVerification(String clusterId) =>
      gateway.callFunction('enqueueVerification', {'clusterId': clusterId});
}

class InMemoryFirebaseGateway implements FirebaseGateway {
  InMemoryFirebaseGateway({this.networkAvailable = true});

  bool networkAvailable;
  final Map<String, Map<String, Map<String, Object?>>> _collections = {};
  final StreamController<RoadSenseUser?> _authStateController =
      StreamController<RoadSenseUser?>.broadcast();
  RoadSenseUser? _currentUser;

  @override
  RoadSenseUser? get currentUser => _currentUser;

  @override
  Stream<RoadSenseUser?> get authStateChanges => _authStateController.stream;

  @override
  Future<RoadSenseUser> signIn({
    required String email,
    required String password,
  }) async {
    _requireNetwork();
    final normalizedEmail = email.trim().toLowerCase();
    final users = await queryCollection(
      BackendCollections.users,
      filters: {'email': normalizedEmail},
      limit: 1,
    );
    final document =
        users.firstOrNull ??
        _collections[BackendCollections.users]?[normalizedEmail];
    if (document == null) {
      throw const BackendException(
        BackendFailure.authentication,
        'Account not found.',
      );
    }
    final user = _userFrom(document)!;
    _currentUser = user;
    _authStateController.add(user);
    return user;
  }

  @override
  Future<RoadSenseUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _requireNetwork();
    final normalizedEmail = email.trim().toLowerCase();
    final user = RoadSenseUser(
      id: 'mock_uid_${normalizedEmail.hashCode.abs()}',
      name: name,
      email: normalizedEmail,
      role: UserRole.user,
    );
    await setDocument(BackendCollections.users, user.id, {
      'id': user.id,
      'uid': user.id,
      'name': user.name,
      'displayName': user.name,
      'email': user.email,
      'role': user.role.name,
      'isEmailVerified': true,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    _currentUser = user;
    _authStateController.add(user);
    return user;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    _requireNetwork();
  }

  @override
  Future<void> sendEmailVerification() async {
    _requireNetwork();
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
  }

  @override
  Future<Map<String, Object?>?> getDocument(
    String collection,
    String id,
  ) async {
    _requireNetwork();
    final doc = _collections[collection]?[id];
    if (doc == null) return null;
    final copy = Map<String, Object?>.from(doc);
    copy.putIfAbsent('id', () => id);
    return copy;
  }

  @override
  Future<List<Map<String, Object?>>> queryCollection(
    String collection, {
    Map<String, Object?> filters = const {},
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    _requireNetwork();
    var values = (_collections[collection]?.entries ?? const [])
        .where(
          (entry) => filters.entries.every(
            (filter) => entry.value[filter.key] == filter.value,
          ),
        )
        .map((entry) {
          final copy = Map<String, Object?>.from(entry.value);
          copy.putIfAbsent('id', () => entry.key);
          return copy;
        })
        .toList();

    if (orderBy != null) {
      values.sort((a, b) {
        final valA = a[orderBy];
        final valB = b[orderBy];
        if (valA == null && valB == null) return 0;
        if (valA == null) return descending ? 1 : -1;
        if (valB == null) return descending ? -1 : 1;
        if (valA is Comparable && valB is Comparable) {
          final comp = valA.compareTo(valB);
          return descending ? -comp : comp;
        }
        return 0;
      });
    }

    if (limit != null && limit > 0) {
      values = values.take(limit).toList();
    }
    return values;
  }

  @override
  Future<void> setDocument(
    String collection,
    String id,
    Map<String, Object?> data, {
    bool merge = false,
  }) async {
    _requireNetwork();
    final col = _collections.putIfAbsent(collection, () => {});
    if (merge && col.containsKey(id)) {
      col[id] = {...col[id]!, ...data};
    } else {
      col[id] = Map<String, Object?>.from(data);
    }
  }

  @override
  Future<void> updateDocument(
    String collection,
    String id,
    Map<String, Object?> data,
  ) async {
    _requireNetwork();
    final col = _collections[collection];
    if (col == null || !col.containsKey(id)) {
      throw const BackendException(
        BackendFailure.unavailable,
        'Document not found for update.',
      );
    }
    col[id] = {...col[id]!, ...data};
  }

  @override
  Future<void> deleteDocument(String collection, String id) async {
    _requireNetwork();
    _collections[collection]?.remove(id);
  }

  @override
  Future<String> uploadFile({
    required String path,
    required List<int> bytes,
  }) async {
    _requireNetwork();
    return 'memory://$path';
  }

  @override
  Future<void> callFunction(String name, Map<String, Object?> data) async {
    _requireNetwork();
  }

  void _requireNetwork() {
    if (!networkAvailable) {
      throw const BackendException(
        BackendFailure.network,
        'Backend network is unavailable.',
      );
    }
  }
}

class InMemoryBackendUserRepository implements BackendUserRepository {
  InMemoryBackendUserRepository({InMemoryFirebaseGateway? gateway})
    : _gateway = gateway ?? InMemoryFirebaseGateway();
  final InMemoryFirebaseGateway _gateway;
  @override
  Future<RoadSenseUser?> findByEmail(String email) =>
      FirebaseUserRepository(_gateway).findByEmail(email);
  @override
  Future<RoadSenseUser?> findById(String id) =>
      FirebaseUserRepository(_gateway).findById(id);
  @override
  Future<RoadSenseUser> create({required String name, required String email}) =>
      FirebaseUserRepository(_gateway).create(name: name, email: email);
  @override
  Future<void> updateProfile(RoadSenseUser user) =>
      FirebaseUserRepository(_gateway).updateProfile(user);
}

RoadSenseUser? _userFrom(Map<String, Object?>? data) {
  if (data == null) return null;
  return UserProfileDocument.fromMap(data).toDomain();
}

Map<String, Object?> _readingData(String tripId, SensorReading reading) => {
  'tripId': tripId,
  'accelerometer': [
    reading.accelerometer.x,
    reading.accelerometer.y,
    reading.accelerometer.z,
  ],
  'gyroscope': [reading.gyroscope.x, reading.gyroscope.y, reading.gyroscope.z],
  'latitude': reading.gps.latitude,
  'longitude': reading.gps.longitude,
  'altitude': reading.gps.altitude,
  'accuracy': reading.gps.accuracy,
  'speedMps': reading.speedMps,
  'timestamp': reading.timestamp.toIso8601String(),
};
