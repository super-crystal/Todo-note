import '../../../data/todo.dart';

class CalendarMonth {
  CalendarMonth(DateTime selectedDate, List<Todo> tasks)
    : selectedDate = dayOnly(selectedDate),
      month = DateTime(selectedDate.year, selectedDate.month),
      taskCounts = _countTasks(tasks, selectedDate);

  final DateTime selectedDate;
  final DateTime month;
  final Map<DateTime, int> taskCounts;

  int get leadingDays => month.weekday - DateTime.monday;
  int get daysInMonth => DateTime(month.year, month.month + 1, 0).day;
  int get cellCount => ((leadingDays + daysInMonth + 6) ~/ 7) * 7;

  DateTime? dateAt(int index) {
    final day = index - leadingDays + 1;
    if (day < 1 || day > daysInMonth) return null;
    return DateTime(month.year, month.month, day);
  }

  int countOn(DateTime day) => taskCounts[dayOnly(day)] ?? 0;

  DateTime shiftMonth(int offset) {
    final next = DateTime(month.year, month.month + offset);
    final lastDay = DateTime(next.year, next.month + 1, 0).day;
    return DateTime(
      next.year,
      next.month,
      selectedDate.day > lastDay ? lastDay : selectedDate.day,
    );
  }

  static Map<DateTime, int> _countTasks(List<Todo> tasks, DateTime selected) {
    final counts = <DateTime, int>{};
    for (final task in tasks) {
      if (task.repeatDaily) {
        final last = DateTime(selected.year, selected.month + 1, 0).day;
        for (var d = 1; d <= last; d++) {
          final day = DateTime(selected.year, selected.month, d);
          if (task.occursOn(day)) {
            counts.update(day, (count) => count + 1, ifAbsent: () => 1);
          }
        }
        continue;
      }
      if (task.dueDate == null) continue;
      final day = dayOnly(task.dueDate!);
      counts.update(day, (count) => count + 1, ifAbsent: () => 1);
    }
    return Map.unmodifiable(counts);
  }
}
