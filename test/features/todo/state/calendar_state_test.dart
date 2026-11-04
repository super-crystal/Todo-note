import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_todo/data/todo.dart';
import 'package:shiguang_todo/features/todo/state/calendar_state.dart';

void main() {
  test(
    'month uses Monday first and marks pending and completed tasks by day',
    () {
      final day = DateTime(2026, 11, 4);
      final month = CalendarMonth(day, [
        Todo(id: 'a', title: 'a', createdAt: day, dueDate: day),
        Todo(
          id: 'b',
          title: 'b',
          createdAt: day,
          dueDate: day,
          completedAt: day,
        ),
        Todo(id: 'c', title: 'c', createdAt: day),
      ]);
      expect(month.leadingDays, 6);
      expect(month.cellCount, 42);
      expect(month.dateAt(0), isNull);
      expect(month.dateAt(6), DateTime(2026, 11, 1));
      expect(month.dateAt(35), DateTime(2026, 11, 30));
      expect(month.dateAt(36), isNull);
      expect(month.countOn(day), 2);
      expect(month.countOn(DateTime(2026, 11, 5)), 0);
    },
  );

  test('month navigation clamps last day and supports leap years and year boundaries', () {
    expect(
      CalendarMonth(DateTime(2024, 1, 31), []).shiftMonth(1),
      DateTime(2024, 2, 29),
    );
    expect(
      CalendarMonth(DateTime(2025, 1, 31), []).shiftMonth(1),
      DateTime(2025, 2, 28),
    );
    expect(
      CalendarMonth(DateTime(2026, 12, 31), []).shiftMonth(1),
      DateTime(2027, 1, 31),
    );
    expect(
      CalendarMonth(DateTime(2026, 1, 31), []).shiftMonth(-1),
      DateTime(2025, 12, 31),
    );
  });
}
