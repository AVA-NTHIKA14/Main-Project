import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:road_loop/auth.dart';
import 'package:road_loop/backend.dart';
import 'package:road_loop/firebase_auth_service.dart';
import 'package:road_loop/main.dart';
import 'package:road_loop/permissions.dart';

class _FakeFirebaseUser extends Fake implements fb.User {
  _FakeFirebaseUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.emailVerified = false,
  });

  @override
  final String uid;

  @override
  final String? email;

  @override
  final String? displayName;

  @override
  final bool emailVerified;
}

void main() {
  group('MockAuthenticationService', () {
    late MockAuthenticationService service;

    setUp(() {
      service = MockAuthenticationService();
    });

    tearDown(() {
      service.dispose();
    });

    test(
      'sign up creates user with unique non-email ID and default user role',
      () async {
        final user = await service.signUp(
          name: 'Taylor Swift',
          email: 'taylor@example.com',
          password: 'password123',
        );

        expect(user.email, 'taylor@example.com');
        expect(user.name, 'Taylor Swift');
        expect(user.role, UserRole.user);
        // Ensures email address is never used as the user ID.
        expect(user.id, isNot(contains('@')));
        expect(user.id, isNot('taylor@example.com'));
        expect(service.currentUser?.id, user.id);
      },
    );

    test('sign up rejects duplicate email registrations', () async {
      await service.signUp(
        name: 'Alex',
        email: 'alex@example.com',
        password: 'password123',
      );

      expect(
        () => service.signUp(
          name: 'Alex',
          email: 'alex@example.com',
          password: 'password123',
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'An account with this email already exists.',
          ),
        ),
      );
    });

    test(
      'sign in succeeds with valid credentials and emits auth state',
      () async {
        await service.signUp(
          name: 'Jordan',
          email: 'jordan@example.com',
          password: 'correct-password',
        );

        final states = <RoadSenseUser?>[];
        final subscription = service.authStateChanges.listen(states.add);

        final signedIn = await service.signIn(
          email: 'jordan@example.com',
          password: 'correct-password',
        );

        expect(signedIn.email, 'jordan@example.com');
        expect(service.currentUser?.email, 'jordan@example.com');

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(states.isNotEmpty, isTrue);
        expect(states.last?.email, 'jordan@example.com');
        await subscription.cancel();
      },
    );

    test(
      'sign in fails with wrong password and maps to user-facing error',
      () async {
        await service.signUp(
          name: 'Jordan',
          email: 'jordan@example.com',
          password: 'correct-password',
        );

        expect(
          () => service.signIn(
            email: 'jordan@example.com',
            password: 'wrong-password',
          ),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              'The email or password is incorrect.',
            ),
          ),
        );
      },
    );

    test(
      'sign in fails for unregistered email without leaking existence',
      () async {
        expect(
          () => service.signIn(
            email: 'nonexistent@example.com',
            password: 'password123',
          ),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              'The email or password is incorrect.',
            ),
          ),
        );
      },
    );

    test('sign out clears authenticated state and emits null', () async {
      await service.signUp(
        name: 'Morgan',
        email: 'morgan@example.com',
        password: 'password123',
      );
      expect(service.currentUser, isNotNull);

      final states = <RoadSenseUser?>[];
      final subscription = service.authStateChanges.listen(states.add);

      await service.signOut();

      expect(service.currentUser, isNull);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(states.last, isNull);
      await subscription.cancel();
    });

    test('password reset validates account existence', () async {
      await service.signUp(
        name: 'Pat',
        email: 'pat@example.com',
        password: 'password123',
      );

      await expectLater(
        service.sendPasswordReset(email: 'pat@example.com'),
        completes,
      );

      expect(
        () => service.sendPasswordReset(email: 'unknown@example.com'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('FirebaseAuthService adapter & mapping', () {
    test('implements both AuthenticationService and BackendAuthService', () {
      final service = FirebaseAuthService();
      expect(service, isA<AuthenticationService>());
      expect(service, isA<BackendAuthService>());
    });

    test(
      'mapFirebaseUser maps UID to RoadSenseUser ID and never uses email',
      () {
        final fakeUser = _FakeFirebaseUser(
          uid: 'firebase-uid-abc-123',
          email: 'driver@roadsense.org',
          displayName: 'Avanthika Driver',
          emailVerified: true,
        );

        final user = FirebaseAuthService.mapFirebaseUser(fakeUser);

        expect(user.id, 'firebase-uid-abc-123');
        expect(user.id, isNot('driver@roadsense.org'));
        expect(user.name, 'Avanthika Driver');
        expect(user.email, 'driver@roadsense.org');
        expect(user.role, UserRole.user);
        expect(user.isEmailVerified, isTrue);
      },
    );

    test('mapFirebaseUser defaults role to safe UserRole.user', () {
      final fakeUser = _FakeFirebaseUser(
        uid: 'uid-456',
        email: 'admin-attempt@roadsense.org',
      );

      final user = FirebaseAuthService.mapFirebaseUser(fakeUser);

      // Ensures client-side Firebase mapping never fabricates admin/researcher role
      expect(user.role, UserRole.user);
      expect(user.role, isNot(UserRole.administrator));
      expect(user.role, isNot(UserRole.researcher));
    });

    test(
      'mapFirebaseUser uses fallbackName or email prefix when name is absent',
      () {
        final fakeUser = _FakeFirebaseUser(
          uid: 'uid-789',
          email: 'cadence@roadsense.org',
          displayName: null,
        );

        final userWithFallback = FirebaseAuthService.mapFirebaseUser(
          fakeUser,
          fallbackName: 'Cadence',
        );
        expect(userWithFallback.name, 'Cadence');

        final userWithoutFallback = FirebaseAuthService.mapFirebaseUser(
          fakeUser,
        );
        expect(userWithoutFallback.name, 'cadence');
      },
    );

    test('error mapper maps Firebase Auth codes to user-friendly messages', () {
      expect(
        FirebaseAuthService.mapFirebaseAuthErrorCode('user-not-found'),
        'The email or password is incorrect.',
      );
      expect(
        FirebaseAuthService.mapFirebaseAuthErrorCode('wrong-password'),
        'The email or password is incorrect.',
      );
      expect(
        FirebaseAuthService.mapFirebaseAuthErrorCode('invalid-credential'),
        'The email or password is incorrect.',
      );
      expect(
        FirebaseAuthService.mapFirebaseAuthErrorCode('email-already-in-use'),
        'An account with this email already exists.',
      );
      expect(
        FirebaseAuthService.mapFirebaseAuthErrorCode('invalid-email'),
        'Enter a valid email address.',
      );
      expect(
        FirebaseAuthService.mapFirebaseAuthErrorCode('weak-password'),
        'The password is too weak. Use at least 8 characters.',
      );
      expect(
        FirebaseAuthService.mapFirebaseAuthErrorCode('operation-not-allowed'),
        'Email and password sign-in is not enabled. Please contact support.',
      );
      expect(
        FirebaseAuthService.mapFirebaseAuthErrorCode('user-disabled'),
        'This account has been disabled. Please contact support.',
      );
      expect(
        FirebaseAuthService.mapFirebaseAuthErrorCode('too-many-requests'),
        'Too many unsuccessful attempts. Please try again later.',
      );
      expect(
        FirebaseAuthService.mapFirebaseAuthErrorCode('network-request-failed'),
        'Network connection issue. Please check your internet connection.',
      );
      expect(
        FirebaseAuthService.mapFirebaseAuthErrorCode('unknown-error-code'),
        'Authentication failed. Please check your details and try again.',
      );
    });
  });

  group('AuthController', () {
    test('initializes as signedOut when no cached user exists', () {
      final service = MockAuthenticationService();
      final controller = AuthController(service: service);

      expect(controller.status, AuthStatus.signedOut);
      expect(controller.user, isNull);
      expect(controller.isSignedIn, isFalse);
      expect(controller.errorMessage, isNull);
      controller.dispose();
      service.dispose();
    });

    test('restores session when service provides currentUser', () {
      const existingUser = RoadSenseUser(
        id: 'restored-uid-1',
        name: 'Restored Driver',
        email: 'restored@example.com',
        role: UserRole.user,
      );
      final service = MockAuthenticationService(initialUser: existingUser);
      final controller = AuthController(service: service);

      expect(controller.status, AuthStatus.signedIn);
      expect(controller.user?.id, 'restored-uid-1');
      expect(controller.isSignedIn, isTrue);
      controller.dispose();
      service.dispose();
    });

    test('signIn succeeds and transitions to signedIn state', () async {
      final service = MockAuthenticationService();
      await service.signUp(
        name: 'Riley',
        email: 'riley@example.com',
        password: 'password123',
      );
      await service.signOut();

      final controller = AuthController(service: service);
      expect(controller.isSignedIn, isFalse);

      await controller.signIn(
        email: 'riley@example.com',
        password: 'password123',
      );

      expect(controller.status, AuthStatus.signedIn);
      expect(controller.isSignedIn, isTrue);
      expect(controller.user?.email, 'riley@example.com');
      controller.dispose();
      service.dispose();
    });

    test(
      'signIn fails with invalid password and transitions to error state',
      () async {
        final service = MockAuthenticationService();
        await service.signUp(
          name: 'Riley',
          email: 'riley@example.com',
          password: 'password123',
        );
        await service.signOut();

        final controller = AuthController(service: service);

        await controller.signIn(
          email: 'riley@example.com',
          password: 'wrong-password',
        );

        expect(controller.status, AuthStatus.error);
        expect(controller.isSignedIn, isFalse);
        expect(controller.errorMessage, 'The email or password is incorrect.');

        controller.clearError();
        expect(controller.errorMessage, isNull);
        expect(controller.status, AuthStatus.signedOut);
        controller.dispose();
        service.dispose();
      },
    );

    test('signOut clears user and returns to signedOut state', () async {
      const existingUser = RoadSenseUser(
        id: 'uid-morgan',
        name: 'Morgan',
        email: 'morgan@example.com',
        role: UserRole.user,
      );
      final service = MockAuthenticationService(initialUser: existingUser);
      final controller = AuthController(service: service);
      expect(controller.isSignedIn, isTrue);

      await controller.signOut();

      expect(controller.status, AuthStatus.signedOut);
      expect(controller.isSignedIn, isFalse);
      expect(controller.user, isNull);
      controller.dispose();
      service.dispose();
    });
  });

  group('App Routing and Integration', () {
    testWidgets(
      'signed-out launch shows splash then welcome screen with login/signup',
      (tester) async {
        final service = MockAuthenticationService();

        await tester.pumpWidget(RoadSenseApp(authenticationService: service));

        // Initially splash brand is visible
        expect(find.text('Know the road around you.'), findsOneWidget);

        // Advance past the 700ms splash delay
        await tester.pump(const Duration(milliseconds: 800));

        expect(find.text('A safer journey\nwith every user.'), findsOneWidget);
        expect(find.text('Create account'), findsOneWidget);
        expect(find.text('Log in'), findsOneWidget);
        expect(find.byType(RoadSenseShell), findsNothing);
      },
    );

    testWidgets(
      'restored session automatically navigates past welcome to app shell',
      (tester) async {
        const restoredUser = RoadSenseUser(
          id: 'active-session-uid',
          name: 'Active Commuter',
          email: 'active@commuter.com',
          role: UserRole.user,
        );
        final service = MockAuthenticationService(initialUser: restoredUser);

        await tester.pumpWidget(
          RoadSenseApp(
            authenticationService: service,
            permissionService: MockPermissionService(
              initialStates: {
                PermissionType.location: PermissionState.granted,
                PermissionType.motion: PermissionState.granted,
                PermissionType.notifications: PermissionState.granted,
              },
            ),
          ),
        );

        // Advance timer; because user is signed in, it bypasses Welcome screen
        await tester.pump(const Duration(milliseconds: 800));

        // Complete onboarding to reach the shell
        await _completeOnboarding(tester);

        // Reaches the application shell
        expect(find.byType(RoadSenseShell), findsOneWidget);
        expect(find.text('Plan'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
      },
    );

    testWidgets('sign-out from Profile screen returns to welcome flow', (
      tester,
    ) async {
      const restoredUser = RoadSenseUser(
        id: 'signout-test-uid',
        name: 'Jordan Traveler',
        email: 'jordan@traveler.com',
        role: UserRole.user,
      );
      final service = MockAuthenticationService(initialUser: restoredUser);

      await tester.pumpWidget(
        RoadSenseApp(
          authenticationService: service,
          permissionService: MockPermissionService(
            initialStates: {
              PermissionType.location: PermissionState.granted,
              PermissionType.motion: PermissionState.granted,
              PermissionType.notifications: PermissionState.granted,
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 800));
      await _completeOnboarding(tester);

      expect(find.byType(RoadSenseShell), findsOneWidget);

      // Switch to Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Jordan Traveler'), findsOneWidget);
      expect(find.text('jordan@traveler.com'), findsOneWidget);

      // Tap Sign out button in Profile screen
      final signOutButton = find.widgetWithText(OutlinedButton, 'Sign out');
      expect(signOutButton, findsOneWidget);
      await tester.tap(signOutButton);
      await tester.pump(const Duration(milliseconds: 300));

      // Confirm dialog appears
      expect(find.text('Sign out?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pump(const Duration(milliseconds: 300));

      // App routes back to the welcome screen
      expect(find.text('A safer journey\nwith every user.'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.byType(RoadSenseShell), findsNothing);
    });
  });
}

Future<void> _completeOnboarding(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Allow motion access'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Allow location access'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Allow notifications'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start exploring'));
  await tester.pump(const Duration(milliseconds: 400));
}
