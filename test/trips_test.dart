import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:roadsense/trips.dart';

void main() {
  test(
    'mock repository returns automatically created trip summaries',
    () async {
      const repository = MockTripHistoryRepository();
      final trips = await repository.recentTrips();

      expect(trips, hasLength(2));
      expect(trips.first.durationLabel, '0h 42m');
      expect(trips.first.distanceLabel, '18.4 km');
      expect(trips.first.verifiedHazards, hasLength(1));
      expect(trips.first.possibleAnomalies, hasLength(1));
    },
  );

  test('trip details are available by id', () async {
    const repository = MockTripHistoryRepository();

    expect(
      (await repository.tripById('trip-today'))?.endLabel,
      'Central district',
    );
    expect(await repository.tripById('missing'), isNull);
  });

  testWidgets('Trips screen progressively opens trip details', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TripsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('18.4 km'), findsOneWidget);
    await tester.tap(find.text('7/10/2026'));
    await tester.pumpAndSettle();

    expect(find.text('Trip details'), findsOneWidget);
    expect(find.text('Verified hazards'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Possible anomalies'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Possible anomalies'), findsOneWidget);
  });
}
