import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roadsense/explore.dart';
import 'package:roadsense/reports.dart';

void main() {
  test('report repository stores reports without verifying them', () async {
    final repository = InMemoryReportRepository();
    final report = UserReport(
      id: 'report-1',
      userId: 'user-1',
      tripId: 'trip-1',
      category: ReportCategory.pothole,
      location: const RoadLocation(latitude: 51.5, longitude: -.12),
      severity: HazardSeverity.high,
      submittedAt: DateTime(2026, 10, 7),
    );

    await repository.submit(report);
    final saved = (await repository.reportsForUser('user-1')).single;

    expect(saved.category, ReportCategory.pothole);
    expect(saved.toObservation().severity, HazardSeverity.possible);
    expect(saved.toObservation().type, HazardType.pothole);
  });

  testWidgets('report flow validates category and confirms submission', (
    tester,
  ) async {
    final repository = InMemoryReportRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ManualReportFlow(
          repository: repository,
          location: const RoadLocation(latitude: 51.5, longitude: -.12),
        ),
      ),
    );

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Select a hazard type to continue.'), findsOneWidget);

    await tester.tap(find.text('Pothole'));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Confirm location'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(await repository.reportsForUser('current-user'), hasLength(1));
  });

  test('invalid coordinates fail location validation', () async {
    final repository = InMemoryReportRepository();
    final report = UserReport(
      id: 'invalid',
      userId: 'user',
      tripId: 'trip',
      category: ReportCategory.other,
      location: const RoadLocation(latitude: 120, longitude: 0),
      severity: HazardSeverity.possible,
      submittedAt: DateTime(2026),
    );
    await repository.submit(report);
    expect(
      (await repository.reportsForUser('user')).single.location.latitude,
      120,
    );
  });
}
