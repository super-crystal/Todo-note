import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_todo/core/strings.dart';
import 'package:shiguang_todo/data/todo.dart';
import 'package:shiguang_todo/features/todo/state/calendar_state.dart';
import 'package:shiguang_todo/features/todo/ui/task_calendar.dart';

void main() {
  final date = DateTime(2026, 11, 5);
  Finder dotsOn(DateTime day) => find.descendant(
    of: find.byKey(ValueKey('calendar-dots-${day.toIso8601String()}')),
    matching: find.byType(DecoratedBox),
  );

  testWidgets(
    'one dot per dated task, no long-term dots, date remains selectable',
    (tester) async {
      DateTime? selected;
      final longTerm = Todo(id: 'long', title: '长期', createdAt: date);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCalendar(
              calendar: CalendarMonth(date, [
                longTerm,
                Todo(id: 'a', title: 'A', createdAt: date, dueDate: date),
                Todo(
                  id: 'b',
                  title: 'B',
                  createdAt: date,
                  dueDate: date,
                  completedAt: date,
                ),
              ]),
              now: date,
              onSelected: (day) => selected = day,
              onChooseDate: () {},
            ),
          ),
        ),
      );
      expect(dotsOn(date), findsNWidgets(2));
      expect(dotsOn(DateTime(2026, 11, 6)), findsNothing);
      await tester.tap(find.byKey(ValueKey(DateTime(2026, 11, 6))));
      expect(selected, DateTime(2026, 11, 6));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'many dots wrap without truncation or layout overflow on a narrow phone',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TaskCalendar(
                  calendar: CalendarMonth(date, [
                    for (var i = 0; i < 30; i++)
                      Todo(
                        id: '$i',
                        title: '$i',
                        createdAt: date,
                        dueDate: date,
                      ),
                  ]),
                  now: date,
                  onSelected: (_) {},
                  onChooseDate: () {},
                ),
              ),
            ),
          ),
        );
        expect(dotsOn(date), findsNWidgets(30));
        expect(
          find.bySemanticsLabel(S.calendarDay(date, 30, true)),
          findsOneWidget,
        );
        final first = tester.getTopLeft(
          find.byKey(ValueKey('calendar-dot-${date.toIso8601String()}-0')),
        );
        final last = tester.getTopLeft(
          find.byKey(ValueKey('calendar-dot-${date.toIso8601String()}-29')),
        );
        expect(last.dy, greaterThan(first.dy));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
  );
}
