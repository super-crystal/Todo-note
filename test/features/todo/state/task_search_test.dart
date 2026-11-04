import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_todo/data/todo.dart';
import 'package:shiguang_todo/features/todo/state/task_filters.dart';
import 'package:shiguang_todo/features/todo/state/todo_state.dart';

void main() {
  final now = DateTime(2026, 11, 4);
  final tasks = [
    Todo(
      id: 'a',
      title: '买苹果',
      note: 'Fruit',
      tags: ['周末'],
      createdAt: now,
      dueDate: now,
      category: TaskCategory.personal,
      priority: TaskPriority.high,
    ),
    Todo(
      id: 'b',
      title: '买苹果',
      tags: ['工作'],
      createdAt: now,
      dueDate: DateTime(2026, 11, 5),
    ),
    Todo(id: 'c', title: '苹果派', tags: ['周末'], createdAt: now, completedAt: now),
  ];

  test(
    'keywords match title, note, labels and category with AND and case folding',
    () {
      expect(
        const TaskQuery(
          view: TaskView.all,
          completed: null,
          search: '#周末 苹果',
        ).apply(tasks, now).map((task) => task.id),
        ['a', 'c'],
      );
      expect(
        const TaskQuery(
          view: TaskView.all,
          search: ' FRUIT  生活 ',
        ).apply(tasks, now).single.id,
        'a',
      );
      expect(
        const TaskQuery(view: TaskView.all, search: '苹果 不存在').apply(tasks, now),
        isEmpty,
      );
    },
  );

  test(
    'date range includes endpoints and composes with exact label and priority',
    () {
      expect(
        TaskQuery(
          view: TaskView.all,
          completed: null,
          dateFrom: now,
          dateTo: DateTime(2026, 11, 5, 23, 59),
        ).apply(tasks, now).map((task) => task.id),
        ['a', 'b'],
      );
      expect(
        TaskQuery(
          view: TaskView.all,
          completed: null,
          dateFrom: now,
          dateTo: now,
          tag: '周末',
          priority: TaskPriority.high,
          category: TaskCategory.personal,
        ).apply(tasks, now).single.id,
        'a',
      );
      expect(
        const TaskQuery(view: TaskView.all, tag: '周').apply(tasks, now),
        isEmpty,
      );
    },
  );

  test(
    'undated and completed filters preserve other conditions and reset cleanly',
    () {
      expect(
        const TaskQuery(
          view: TaskView.all,
          completed: null,
          undatedOnly: true,
          tag: '周末',
        ).apply(tasks, now).single.id,
        'c',
      );
      expect(
        const TaskQuery(
          view: TaskView.all,
          completed: false,
          undatedOnly: true,
        ).apply(tasks, now),
        isEmpty,
      );
      final filters = TaskFilters(
        dateFrom: now,
        dateTo: now,
        tag: '周末',
      ).withStatus(true);
      expect(filters.dateFrom, now);
      expect(filters.tag, '周末');
      expect(filters.activeCount, 3);
      expect(const TaskFilters().activeCount, 0);
      expect(TaskFilters.availableTags(tasks), ['周末', '工作']);
    },
  );
}
