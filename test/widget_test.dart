// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roadsense/auth.dart';
import 'package:roadsense/main.dart';
import 'package:roadsense/permissions.dart';

void main() {
  testWidgets('RoadSense opens on the branded welcome flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RoadSenseApp());
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Know the road around you.'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Start Detection'), findsNothing);
  });

  testWidgets('Sign up validates fields and reaches the authenticated shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RoadSenseApp());
    await tester.pump(const Duration(milliseconds: 800));

    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(find.text('Enter your name'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Sam Driver',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'sam@example.com',
    );
    final passwordFields = find.byType(TextFormField);
    await tester.enterText(passwordFields.at(2), 'road sense 123');
    await tester.enterText(passwordFields.at(3), 'road sense 123');
    await tester.tap(find.text('Create account'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Preparing your account'), findsOneWidget);
    await tester.tap(find.text('Continue to RoadSense'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Welcome to RoadSense'), findsOneWidget);
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
    await tester.pumpAndSettle();
    expect(find.byType(RoadSenseShell), findsOneWidget);
  });

  testWidgets('login rejects invalid email and password', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RoadSenseApp());
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text('Log in'));
    await tester.pump();
    await tester.tap(find.text('Log in'));
    await tester.pump();
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  test(
    'mock authentication keeps administrator roles out of the user shell',
    () async {
      final repository = InMemoryUserRepository();
      final service = MockAuthenticationService(repository: repository);
      final user = await service.signUp(
        name: 'Researcher',
        email: 'researcher@example.com',
        password: 'password123',
      );

      expect(user.role, UserRole.user);
    },
  );

  test('permission service reports progressive permission states', () async {
    final service = MockPermissionService();

    expect(
      await service.status(PermissionType.location),
      PermissionState.notRequested,
    );
    expect(
      await service.request(PermissionType.location),
      PermissionState.granted,
    );
    expect(
      await service.status(PermissionType.location),
      PermissionState.granted,
    );
  });
}
