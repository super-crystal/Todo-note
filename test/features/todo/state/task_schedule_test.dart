import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_todo/data/todo.dart';
import 'package:shiguang_todo/features/todo/state/calendar_state.dart';
import 'package:shiguang_todo/features/todo/state/todo_state.dart';

void main() {
  final today = DateTime(2026, 11, 4, 14);
  Todo daily({List<String> done = const []}) => Todo(
    id: 'daily',
    title: '读书',
    createdAt: today,
    dueDate: dayOnly(today),
    repeatDaily: true,
    completedDays: done,
  );

  test(
    'daily completions persist independently and reset at local midnight',
    () {
      final original = daily();
      final done = Todo.fromMap(original.toggle(today).toMap());
      final tomorrow = DateTime(2026, 11, 5);
      expect(done.isCompletedOn(today), isTrue);
      expect(done.isCompletedOn(tomorrow), isFalse);
      final doneBoth = done.toggle(tomorrow);
      expect(doneBoth.completedDays, ['2026-11-04', '2026-11-05']);
      expect(doneBoth.toggle(today).completedDays, ['2026-11-05']);
      expect(
        () => done.completedDays.add('2026-11-05'),
        throwsUnsupportedError,
      );
      final legacy = original.toMap()
        ..remove('repeatDaily')
        ..remove('completedDays')
        ..remove('reminderLeadMinutes');
      expect(Todo.fromMap(legacy).repeatDaily, isFalse);
      expect(Todo.fromMap(legacy).reminderLeadMinutes, 0);
    },
  );

  test('today includes all pending types and completed today, excludes old completions', () {
    final items = [
      Todo(
        id: 'future',
        title: '申请',
        createdAt: today,
        dueDate: DateTime(2026, 12),
      ),
      Todo(id: 'long', title: '学习英语', createdAt: today),
      daily(done: ['2026-11-04']),
      Todo(
        id: 'old',
        title: '历史',
        createdAt: today,
        completedAt: DateTime(2026, 11, 3),
      ),
      Todo(
        id: 'later',
        title: '下周开始',
        createdAt: today,
        dueDate: DateTime(2026, 11, 10),
        repeatDaily: true,
      ),
    ];
    expect(const TaskQuery().apply(items, today).map((t) => t.id), [
      'future',
      'long',
    ]);
    expect(
      const TaskQuery(completed: true).apply(items, today).single.id,
      'daily',
    );
    final progress = DailyProgress.fromTasks(items, today);
    expect(progress.total, 3);
    expect(progress.completed, 1);
    expect(
      const TaskQuery().apply(items, DateTime(2026, 11, 5)).map((t) => t.id),
      ['daily', 'future', 'long'],
    );
  });

  test(
    'calendar daily dots and selected-day status follow start date and history',
    () {
      final task = daily(done: ['2026-11-05']);
      final selected = DateTime(2026, 11, 5);
      final calendar = CalendarMonth(selected, [task]);
      expect(calendar.countOn(DateTime(2026, 11, 3)), 0);
      expect(calendar.countOn(DateTime(2026, 11, 4)), 1);
      expect(calendar.countOn(DateTime(2026, 11, 30)), 1);
      expect(
        TaskQuery(
          view: TaskView.planned,
          dateFrom: selected,
          dateTo: selected,
          completed: true,
        ).apply([task], today).single.id,
        task.id,
      );
      expect(
        TaskQuery(
          view: TaskView.planned,
          dateFrom: selected,
          dateTo: selected,
        ).apply([task], today),
        isEmpty,
      );
      expect(
        const TaskQuery(
          view: TaskView.all,
          undatedOnly: true,
        ).apply([task], today),
        isEmpty,
      );
    },
  );
}
