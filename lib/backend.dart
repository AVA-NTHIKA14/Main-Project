import 'auth.dart';
import 'detection.dart';
import 'explore.dart';
import 'reports.dart';
import 'sensors.dart';
import 'trips.dart';
import 'verification.dart';

abstract final class BackendCollections {
  static const users = 'users';
  static const trips = 'trips';
  static const sensorReadings = 'sensor_readings';
  static const detectionEvents = 'detection_events';
  static const hazards = 'hazards';
  static const hazardObservations = 'hazard_observations';
  static const roadSegments = 'road_segments';
  static const reports = 'reports';
  static const crowdClusters = 'crowd_clusters';
  static const modelPredictions = 'model_predictions';
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
    int? limit,
  });
  Future<void> setDocument(
    String collection,
    String id,
    Map<String, Object?> data,
  );
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
    final user = RoadSenseUser(
      id: email.trim().toLowerCase(),
      name: name.trim(),
      email: email.trim().toLowerCase(),
      role: UserRole.user,
    );
    await updateProfile(user);
    return user;
  }

  @override
  Future<void> updateProfile(RoadSenseUser user) =>
      gateway.setDocument(BackendCollections.users, user.id, {
        'name': user.name,
        'email': user.email,
        'role': user.role.name,
        'isEmailVerified': user.isEmailVerified,
      });
}

class FirebaseSensorReadingRepository implements SensorReadingRepository {
  const FirebaseSensorReadingRepository(this.gateway);
  final FirebaseGateway gateway;
  @override
  Future<void> append({
    required String tripId,
    required SensorReading reading,
  }) => gateway.setDocument(
    BackendCollections.sensorReadings,
    '${tripId}_${reading.timestamp.microsecondsSinceEpoch}',
    _readingData(tripId, reading),
  );
  @override
  Future<List<SensorReading>> forTrip(String tripId) async => const [];
}

class FirebaseTripHistoryRepository implements BackendTripRepository {
  const FirebaseTripHistoryRepository(this.gateway);
  final FirebaseGateway gateway;

  @override
  Future<void> saveTrip(Trip trip) =>
      gateway.setDocument(BackendCollections.trips, trip.id, {
        'startedAt': trip.startedAt.toIso8601String(),
        'endedAt': trip.endedAt.toIso8601String(),
        'durationSeconds': trip.duration.inSeconds,
        'distanceKm': trip.distanceKm,
        'startLabel': trip.startLabel,
        'endLabel': trip.endLabel,
        'roadQuality': trip.roadQuality,
      });

  @override
  Future<List<Trip>> recentTrips() async => const [];

  @override
  Future<Trip?> tripById(String id) async => null;
}

class FirebaseDetectionEventRepository implements DetectionEventRepository {
  const FirebaseDetectionEventRepository(this.gateway);
  final FirebaseGateway gateway;

  @override
  Future<void> save(DetectionResult result) async {
    final data = {
      'classification': result.classification.name,
      'confidence': result.confidence,
      'timestamp': result.timestamp.toIso8601String(),
      'latitude': result.location.latitude,
      'longitude': result.location.longitude,
      'speedMps': result.speedMps,
      'sensorWindowId': result.sensorWindowId,
      'modelVersion': result.modelVersion,
      'severityEstimate': result.severityEstimate.name,
      'source': result.source.name,
    };
    await gateway.setDocument(
      BackendCollections.detectionEvents,
      result.sensorWindowId,
      data,
    );
    await gateway.setDocument(
      BackendCollections.modelPredictions,
      result.sensorWindowId,
      data,
    );
  }

  @override
  Future<List<DetectionResult>> recent({int limit = 100}) async => const [];
}

class FirebaseReportRepository implements BackendReportRepository {
  const FirebaseReportRepository(this.gateway);
  final FirebaseGateway gateway;
  @override
  Future<UserReport> submit(UserReport report) async {
    await gateway.setDocument(BackendCollections.reports, report.id, {
      'userId': report.userId,
      'tripId': report.tripId,
      'category': report.category.name,
      'latitude': report.location.latitude,
      'longitude': report.location.longitude,
      'severity': report.severity.name,
      'submittedAt': report.submittedAt.toIso8601String(),
      'description': report.description,
    });
    return report;
  }

  @override
  Future<List<UserReport>> reportsForUser(String userId) async => const [];
}

class FirebaseHazardRepository implements HazardRepository {
  const FirebaseHazardRepository(this.gateway);
  final FirebaseGateway gateway;
  @override
  Future<void> save(Hazard hazard) =>
      gateway.setDocument(BackendCollections.hazards, hazard.id, {
        'segmentId': hazard.segmentId,
        'type': hazard.type.name,
        'severity': hazard.severity.name,
        'status': hazard.status.name,
        'confidence': hazard.confidence,
        'firstObserved': hazard.firstObserved.toIso8601String(),
        'lastObserved': hazard.lastObserved.toIso8601String(),
      });
  @override
  Future<List<Hazard>> list({VerificationStatus? status}) async => const [];
  @override
  Future<void> updateStatus(String hazardId, VerificationStatus status) =>
      gateway.setDocument(BackendCollections.hazards, hazardId, {
        'status': status.name,
      });
}

class FirebaseHazardObservationRepository
    implements HazardObservationRepository {
  const FirebaseHazardObservationRepository(this.gateway);
  final FirebaseGateway gateway;

  @override
  Future<void> save(HazardObservation observation) => gateway.setDocument(
    BackendCollections.hazardObservations,
    observation.id,
    {
      'segmentId': observation.segmentId,
      'userId': observation.userId,
      'tripId': observation.tripId,
      'type': observation.type.name,
      'severity': observation.severity.name,
      'latitude': observation.location.latitude,
      'longitude': observation.location.longitude,
      'timestamp': observation.timestamp.toIso8601String(),
    },
  );

  @override
  Future<List<HazardObservation>> forHazard(String hazardId) async => const [];
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
  }) => gateway.setDocument(BackendCollections.crowdClusters, clusterId, {
    'status': status.name,
    'reviewerId': reviewerId,
  });
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
  RoadSenseUser? _currentUser;

  RoadSenseUser? get currentUser => _currentUser;

  @override
  Future<RoadSenseUser> signIn({
    required String email,
    required String password,
  }) async {
    _requireNetwork();
    final document =
        _collections[BackendCollections.users]?[email.trim().toLowerCase()];
    if (document == null) {
      throw const BackendException(
        BackendFailure.authentication,
        'Account not found.',
      );
    }
    return _userFrom(document)!;
  }

  @override
  Future<RoadSenseUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _requireNetwork();
    final user = RoadSenseUser(
      id: email.trim().toLowerCase(),
      name: name,
      email: email.trim().toLowerCase(),
      role: UserRole.user,
    );
    await setDocument(BackendCollections.users, user.id, {
      'name': user.name,
      'email': user.email,
      'role': user.role.name,
      'isEmailVerified': true,
    });
    _currentUser = user;
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
  Future<void> signOut() async => _currentUser = null;
  @override
  Future<Map<String, Object?>?> getDocument(
    String collection,
    String id,
  ) async {
    _requireNetwork();
    return _collections[collection]?[id];
  }

  @override
  Future<List<Map<String, Object?>>> queryCollection(
    String collection, {
    Map<String, Object?> filters = const {},
    int? limit,
  }) async {
    _requireNetwork();
    var values =
        (_collections[collection]?.values ?? const <Map<String, Object?>>[])
            .where(
              (document) => filters.entries.every(
                (entry) => document[entry.key] == entry.value,
              ),
            )
            .toList();
    if (limit != null) values = values.take(limit).toList();
    return values;
  }

  @override
  Future<void> setDocument(
    String collection,
    String id,
    Map<String, Object?> data,
  ) async {
    _requireNetwork();
    _collections.putIfAbsent(collection, () => {})[id] =
        Map<String, Object?>.from(data);
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
  return RoadSenseUser(
    id: (data['id'] ?? data['email'])! as String,
    name: data['name']! as String,
    email: data['email']! as String,
    role: UserRole.values.byName((data['role'] ?? 'user') as String),
    isEmailVerified: data['isEmailVerified'] as bool? ?? false,
  );
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
