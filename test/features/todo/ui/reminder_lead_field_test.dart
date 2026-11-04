import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_todo/core/strings.dart';
import 'package:shiguang_todo/features/todo/ui/reminder_lead_field.dart';

void main() {
  testWidgets(
    'custom lead validates, saves and cancellation keeps the previous value',
    (tester) async {
      var minutes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ReminderLeadField(
                minutes: minutes,
                onChanged: (value) => setState(() => minutes = value),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('reminder-lead')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.customLead).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.confirm));
      await tester.pumpAndSettle();
      expect(find.text(S.invalidLead), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('lead-days')), '1');
      await tester.enterText(find.byKey(const ValueKey('lead-hours')), '2');
      await tester.enterText(find.byKey(const ValueKey('lead-minutes')), '30');
      await tester.tap(find.text(S.confirm));
      await tester.pumpAndSettle();
      expect(minutes, 1590);
      expect(find.text(S.reminderLead(1590)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reminder-lead')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.customLead).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.cancel));
      await tester.pumpAndSettle();
      expect(minutes, 1590);
      expect(find.text(S.reminderLead(1590)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reminder-lead')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.reminderLead(1440)).last);
      await tester.pumpAndSettle();
      expect(minutes, 1440);
      expect(tester.takeException(), isNull);
    },
  );
}
