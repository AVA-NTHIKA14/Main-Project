import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roadsense/profile.dart';

void main() {
  testWidgets(
    'profile shows a compact contribution summary and opens settings',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));

      expect(find.text('Contribution summary'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Verified contributions'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Passive sensing'), findsOneWidget);
      expect(
        find.text(
          'Your individual trip is not displayed publicly. Shared road insights are reviewed in aggregate.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('settings toggles and cache action are available', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    final sensing = find.byType(SwitchListTile).first;
    expect(tester.widget<SwitchListTile>(sensing).value, isTrue);
    await tester.tap(sensing);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(sensing).value, isFalse);

    await tester.scrollUntilVisible(
      find.text('Clear local cache'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Clear local cache'));
    await tester.pump();
    expect(find.text('Local cache cleared'), findsOneWidget);
  });
}
