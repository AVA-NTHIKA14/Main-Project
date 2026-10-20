import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:road_loop/admin_hazards.dart';
import 'package:road_loop/explore.dart';

void main() {
  test('mock hazard source includes segment-backed statuses and metadata', () {
    const source = MockAdminHazardDataSource();
    expect(source.segments, isNotEmpty);
    expect(source.hazards, isNotEmpty);
    expect(source.hazards.first.hazard.status, VerificationStatus.possible);
    expect(
      source.hazards.any(
        (record) => record.hazard.status == VerificationStatus.verified,
      ),
      isTrue,
    );
  });

  testWidgets('hazard management shows segment map and lifecycle actions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AdminHazardsScreen()));
    await tester.pump();

    expect(find.text('Hazards'), findsOneWidget);
    expect(
      find.text('Segment-level hazard management · DEMO DATA'),
      findsOneWidget,
    );
    expect(find.byTooltip('Verify'), findsWidgets);
    expect(find.byTooltip('Reject'), findsWidgets);
    expect(find.byTooltip('Merge'), findsWidgets);
    expect(find.byTooltip('Mark resolved'), findsWidgets);
  });
}
