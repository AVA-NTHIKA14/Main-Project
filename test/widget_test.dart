// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:road_loop/auth.dart';
import 'package:road_loop/main.dart';
import 'package:road_loop/permissions.dart';

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

    final welcomeCreate = find.text('Create account');
    await tester.ensureVisible(welcomeCreate);
    await tester.tap(welcomeCreate);
    await tester.pump();
    final createButton = find.text('Create account');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pump();
    expect(find.text('Enter your name'), findsOneWidget);

    final nameField = find.widgetWithText(TextFormField, 'Name');
    await tester.ensureVisible(nameField);
    await tester.enterText(nameField, 'Sam Driver');
    final emailField = find.widgetWithText(TextFormField, 'Email');
    await tester.ensureVisible(emailField);
    await tester.enterText(emailField, 'sam@example.com');
    final passwordFields = find.byType(TextFormField);
    await tester.ensureVisible(passwordFields.at(2));
    await tester.enterText(passwordFields.at(2), 'road sense 123');
    await tester.ensureVisible(passwordFields.at(3));
    await tester.enterText(passwordFields.at(3), 'road sense 123');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
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
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RoadSenseShell), findsOneWidget);
  });

  testWidgets('login rejects invalid email and password', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RoadSenseApp());
    await tester.pump(const Duration(milliseconds: 800));
    final welcomeLogin = find.text('Log in');
    await tester.ensureVisible(welcomeLogin);
    await tester.tap(welcomeLogin);
    await tester.pump();
    final loginButton = find.text('Log in');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pump();
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);

    final emailField = find.widgetWithText(TextFormField, 'Email');
    await tester.ensureVisible(emailField);
    await tester.enterText(emailField, 'not-an-email');
    final passwordField = find.widgetWithText(TextFormField, 'Password');
    await tester.ensureVisible(passwordField);
    await tester.enterText(passwordField, 'wrong-password');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);

    await tester.ensureVisible(emailField);
    await tester.enterText(emailField, 'sam@example.com');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pump();
    await tester.pump();
    expect(find.text('The email or password is incorrect.'), findsOneWidget);
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
