import 'package:flutter/foundation.dart';

enum UserRole { user, administrator, researcher }

class RoadSenseUser {
  const RoadSenseUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isEmailVerified = true,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool isEmailVerified;
}

abstract interface class UserRepository {
  Future<RoadSenseUser?> findByEmail(String email);
  Future<RoadSenseUser> create({required String name, required String email});
}

abstract interface class AuthenticationService {
  Future<RoadSenseUser> signIn({
    required String email,
    required String password,
  });
  Future<RoadSenseUser> signUp({
    required String name,
    required String email,
    required String password,
  });
  Future<void> sendPasswordReset({required String email});
  Future<void> sendEmailVerification();
  Future<void> signOut();
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InMemoryUserRepository implements UserRepository {
  final Map<String, RoadSenseUser> _users = {};

  @override
  Future<RoadSenseUser?> findByEmail(String email) async =>
      _users[email.trim().toLowerCase()];

  @override
  Future<RoadSenseUser> create({
    required String name,
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final user = RoadSenseUser(
      id: normalizedEmail,
      name: name.trim(),
      email: normalizedEmail,
      role: UserRole.user,
      isEmailVerified: true,
    );
    _users[normalizedEmail] = user;
    return user;
  }
}

class MockAuthenticationService implements AuthenticationService {
  MockAuthenticationService({UserRepository? repository})
    : _repository = repository ?? InMemoryUserRepository();

  final UserRepository _repository;
  final Map<String, String> _passwords = {};

  @override
  Future<RoadSenseUser> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final user = await _repository.findByEmail(normalizedEmail);
    if (user == null || _passwords[normalizedEmail] != password) {
      throw const AuthException('The email or password is incorrect.');
    }
    return user;
  }

  @override
  Future<RoadSenseUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (await _repository.findByEmail(normalizedEmail) != null) {
      throw const AuthException('An account with this email already exists.');
    }
    final user = await _repository.create(name: name, email: normalizedEmail);
    _passwords[normalizedEmail] = password;
    return user;
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    if (await _repository.findByEmail(email) == null) {
      throw const AuthException(
        'We could not find an account with that email.',
      );
    }
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> signOut() async {}
}

enum AuthStatus {
  checking,
  signedOut,
  signingIn,
  signingUp,
  sendingReset,
  verifying,
  signedIn,
  error,
}

class AuthController extends ChangeNotifier {
  AuthController({required this._service}) {
    _status = AuthStatus.signedOut;
  }

  final AuthenticationService _service;
  AuthStatus _status = AuthStatus.checking;
  RoadSenseUser? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  RoadSenseUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isSignedIn => _status == AuthStatus.signedIn && _user != null;

  Future<void> signIn({required String email, required String password}) async {
    await _run(
      AuthStatus.signingIn,
      () async =>
          _user = await _service.signIn(email: email, password: password),
    );
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await _run(
      AuthStatus.signingUp,
      () async => _user = await _service.signUp(
        name: name,
        email: email,
        password: password,
      ),
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _run(
      AuthStatus.sendingReset,
      () => _service.sendPasswordReset(email: email),
    );
  }

  Future<void> sendVerification() async {
    await _run(AuthStatus.verifying, _service.sendEmailVerification);
  }

  Future<void> signOut() async {
    await _service.signOut();
    _user = null;
    _setStatus(AuthStatus.signedOut);
  }

  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) _setStatus(AuthStatus.signedOut);
  }

  Future<void> _run(
    AuthStatus busyStatus,
    Future<void> Function() action,
  ) async {
    _errorMessage = null;
    _setStatus(busyStatus);
    try {
      await action();
      _setStatus(_user == null ? AuthStatus.signedOut : AuthStatus.signedIn);
    } on AuthException catch (error) {
      _errorMessage = error.message;
      _setStatus(AuthStatus.error);
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
      _setStatus(AuthStatus.error);
    }
  }

  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
