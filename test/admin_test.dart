import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:road_loop/admin.dart';
import 'package:road_loop/auth.dart';

void main() {
  const admin = RoadSenseUser(
    id: 'admin-1',
    name: 'Research Admin',
    email: 'admin@example.com',
    role: UserRole.administrator,
  );

  testWidgets(
    'admin dashboard shows demo overview and all workspace sections',
    (tester) async {
      tester.view
        ..physicalSize = const Size(1600, 1000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: AdminDashboard(user: admin)),
      );

      expect(find.text('DEMO DATA'), findsWidgets);
      expect(find.text('Sensor records'), findsOneWidget);
      expect(find.text('Verified hazards'), findsOneWidget);

      await tester.tap(find.text('Sensor Data'));
      await tester.pump();
      expect(find.text('Raw signal timeline'), findsOneWidget);
      expect(find.text('Accelerometer'), findsOneWidget);
      expect(find.text('DEMO DATA'), findsWidgets);

      await tester.tap(find.text('Crowd Verification'));
      await tester.pump();
      expect(find.text('Crowd Verification'), findsAtLeastNWidgets(1));
      expect(find.textContaining('8 observations'), findsAtLeastNWidgets(1));
      expect(find.textContaining('6 users'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Same road segment'), findsWidgets);
      expect(
        find.textContaining('Observed within configured time window'),
        findsWidgets,
      );
      await tester.scrollUntilVisible(
        find.text('View observations').last,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('View observations').last);
      await tester.pump();
      expect(
        find.textContaining('Internal user usr-a7f2 · trip trip-a'),
        findsWidgets,
      );
      await tester.tap(find.text('Verify').last);
      await tester.pump();
      expect(find.text('Verified'), findsWidgets);
      await tester.tap(find.text('Detection Events'));
      await tester.pump();
      expect(find.text('Detection Events'), findsAtLeastNWidgets(1));
      expect(
        find.text(
          'Predictions are model outputs only. They are not verified hazards.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Model Performance'));
      await tester.pump();
      expect(
        find.textContaining('Evaluation data not available.'),
        findsOneWidget,
      );
      expect(find.text('Accelerometer + Gyroscope + Speed'), findsOneWidget);

      await tester.tap(find.text('Hazards'));
      await tester.pump();
      expect(
        find.text('Segment-level hazard management · DEMO DATA'),
        findsOneWidget,
      );
      expect(find.byTooltip('Mark resolved'), findsWidgets);
      expect(find.byTooltip('Change severity'), findsWidgets);
    },
  );

  testWidgets('admin login rejects a normal user role', (tester) async {
    final service = _FakeAuthenticationService(
      const RoadSenseUser(
        id: 'user-1',
        name: 'User',
        email: 'user@example.com',
        role: UserRole.user,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: AdminLoginScreen(authenticationService: service)),
    );

    await tester.tap(find.text('Open dashboard'));
    await tester.pump();
    expect(
      find.text('This account does not have admin or research access.'),
      findsOneWidget,
    );
  });
}

class _FakeAuthenticationService implements AuthenticationService {
  const _FakeAuthenticationService(this.user);
  final RoadSenseUser user;
  @override
  Stream<RoadSenseUser?> get authStateChanges => Stream.value(user);
  @override
  RoadSenseUser? get currentUser => user;
  @override
  Future<RoadSenseUser> signIn({
    required String email,
    required String password,
  }) async => user;
  @override
  Future<RoadSenseUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async => user;
  @override
  Future<void> sendPasswordReset({required String email}) async {}
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<void> signOut() async {}
}
