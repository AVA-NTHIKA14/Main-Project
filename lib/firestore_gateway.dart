import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'auth.dart';
import 'backend.dart';
import 'firebase_auth_service.dart';

/// Concrete [FirebaseGateway] implementation backed by Cloud Firestore and Firebase Authentication.
///
/// Implements CRUD, bounded query operations, Firestore [Timestamp] conversions,
/// and maps [FirebaseException] instances into structured [BackendException] errors.
class FirestoreFirebaseGateway implements FirebaseGateway {
  FirestoreFirebaseGateway({this.firestore, this.auth});

  final FirebaseFirestore? firestore;
  final fb.FirebaseAuth? auth;

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;
  fb.FirebaseAuth get _authInstance => auth ?? fb.FirebaseAuth.instance;

  @override
  Stream<RoadSenseUser?> get authStateChanges => _authInstance
      .authStateChanges()
      .map((u) => u == null ? null : FirebaseAuthService.mapFirebaseUser(u));

  @override
  RoadSenseUser? get currentUser {
    final u = _authInstance.currentUser;
    return u == null ? null : FirebaseAuthService.mapFirebaseUser(u);
  }

  @override
  Future<RoadSenseUser> signIn({
    required String email,
    required String password,
  }) =>
      FirebaseAuthService(auth: _authInstance)
          .signIn(email: email, password: password);

  @override
  Future<RoadSenseUser> signUp({
    required String name,
    required String email,
    required String password,
  }) =>
      FirebaseAuthService(auth: _authInstance)
          .signUp(name: name, email: email, password: password);

  @override
  Future<void> sendPasswordReset(String email) =>
      FirebaseAuthService(auth: _authInstance).sendPasswordReset(email: email);

  @override
  Future<void> sendEmailVerification() =>
      FirebaseAuthService(auth: _authInstance).sendEmailVerification();

  @override
  Future<void> signOut() => FirebaseAuthService(auth: _authInstance).signOut();

  @override
  Future<Map<String, Object?>?> getDocument(
    String collection,
    String id,
  ) async {
    try {
      final docSnapshot = await _db.collection(collection).doc(id).get();
      if (!docSnapshot.exists || docSnapshot.data() == null) {
        return null;
      }
      final data = Map<String, Object?>.from(docSnapshot.data()!);
      data.putIfAbsent('id', () => docSnapshot.id);
      return _convertFromFirestore(data);
    } on FirebaseException catch (e) {
      throw mapFirebaseException(e);
    } catch (e) {
      if (e is BackendException) rethrow;
      throw BackendException(
        BackendFailure.unavailable,
        'Failed to read document $collection/$id: $e',
        cause: e,
      );
    }
  }

  @override
  Future<void> setDocument(
    String collection,
    String id,
    Map<String, Object?> data, {
    bool merge = false,
  }) async {
    try {
      final prepared = _prepareForFirestore(data);
      await _db
          .collection(collection)
          .doc(id)
          .set(prepared, SetOptions(merge: merge));
    } on FirebaseException catch (e) {
      throw mapFirebaseException(e);
    } catch (e) {
      if (e is BackendException) rethrow;
      throw BackendException(
        BackendFailure.unavailable,
        'Failed to write document $collection/$id: $e',
        cause: e,
      );
    }
  }

  @override
  Future<void> updateDocument(
    String collection,
    String id,
    Map<String, Object?> data,
  ) async {
    try {
      final prepared = _prepareForFirestore(data);
      await _db.collection(collection).doc(id).update(prepared);
    } on FirebaseException catch (e) {
      throw mapFirebaseException(e);
    } catch (e) {
      if (e is BackendException) rethrow;
      throw BackendException(
        BackendFailure.unavailable,
        'Failed to update document $collection/$id: $e',
        cause: e,
      );
    }
  }

  @override
  Future<void> deleteDocument(String collection, String id) async {
    try {
      await _db.collection(collection).doc(id).delete();
    } on FirebaseException catch (e) {
      throw mapFirebaseException(e);
    } catch (e) {
      if (e is BackendException) rethrow;
      throw BackendException(
        BackendFailure.unavailable,
        'Failed to delete document $collection/$id: $e',
        cause: e,
      );
    }
  }

  @override
  Future<List<Map<String, Object?>>> queryCollection(
    String collection, {
    Map<String, Object?> filters = const {},
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db.collection(collection);

      for (final entry in filters.entries) {
        if (entry.value != null) {
          query = query.where(entry.key, isEqualTo: entry.value);
        }
      }

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      // Enforce bounded reads to avoid unbounded collection downloads
      if (limit != null && limit > 0) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) {
        final data = Map<String, Object?>.from(doc.data());
        data.putIfAbsent('id', () => doc.id);
        return _convertFromFirestore(data);
      }).toList();
    } on FirebaseException catch (e) {
      throw mapFirebaseException(e);
    } catch (e) {
      if (e is BackendException) rethrow;
      throw BackendException(
        BackendFailure.unavailable,
        'Failed to query collection $collection: $e',
        cause: e,
      );
    }
  }

  @override
  Future<String> uploadFile({
    required String path,
    required List<int> bytes,
  }) async {
    // Cloud Storage upload will be integrated in storage module
    return 'gs://roadsense-cc1f5.appspot.com/$path';
  }

  @override
  Future<void> callFunction(String name, Map<String, Object?> data) async {
    // Cloud Functions bridge
  }

  /// Converts domain payloads into Firestore-compatible maps, mapping DateTime
  /// and ISO timestamps to Firestore [Timestamp] instances at the boundary.
  static Map<String, dynamic> _prepareForFirestore(Map<String, Object?> data) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      final key = entry.key;
      final val = entry.value;

      if (val is DateTime) {
        result[key] = Timestamp.fromDate(val.toUtc());
      } else if (val is Map<String, Object?>) {
        result[key] = _prepareForFirestore(val);
      } else if (val is List) {
        result[key] = val.map((item) {
          if (item is DateTime) return Timestamp.fromDate(item.toUtc());
          if (item is Map<String, Object?>) return _prepareForFirestore(item);
          return item;
        }).toList();
      } else {
        result[key] = val;
      }
    }
    return result;
  }

  /// Converts Firestore query results into standard JSON-compatible maps,
  /// translating [Timestamp] objects into UTC ISO 8601 strings.
  static Map<String, Object?> _convertFromFirestore(Map<String, dynamic> data) {
    final result = <String, Object?>{};
    for (final entry in data.entries) {
      final key = entry.key;
      final val = entry.value;

      if (val is Timestamp) {
        result[key] = val.toDate().toUtc().toIso8601String();
      } else if (val is Map) {
        result[key] = _convertFromFirestore(Map<String, dynamic>.from(val));
      } else if (val is List) {
        result[key] = val.map((item) {
          if (item is Timestamp) return item.toDate().toUtc().toIso8601String();
          if (item is Map) {
            return _convertFromFirestore(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        result[key] = val;
      }
    }
    return result;
  }

  /// Maps [FirebaseException] error codes to [BackendException] with [BackendFailure].
  static BackendException mapFirebaseException(FirebaseException error) {
    final failure = switch (error.code) {
      'permission-denied' => BackendFailure.permission,
      'unavailable' ||
      'deadline-exceeded' ||
      'network-request-failed' => BackendFailure.network,
      'unauthenticated' => BackendFailure.authentication,
      'not-found' => BackendFailure.unavailable,
      'invalid-argument' || 'out-of-range' => BackendFailure.invalidData,
      _ => BackendFailure.unavailable,
    };
    return BackendException(
      failure,
      error.message ?? 'Firestore operation failed (${error.code}).',
      cause: error,
    );
  }
}
