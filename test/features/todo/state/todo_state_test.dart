import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shiguang_todo/data/todo.dart';
import 'package:shiguang_todo/data/todo_repository.dart';
import 'package:shiguang_todo/features/todo/state/todo_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 4, 23, 59);
  Todo task(
    String id, {
    DateTime? due,
    bool completed = false,
    TaskPriority priority = TaskPriority.low,
    TaskCategory category = TaskCategory.inbox,
  }) => Todo(
    id: id,
    title: id,
    note: '读书笔记',
    createdAt: DateTime(2026, 11, 1),
    dueDate: due,
    completedAt: completed ? now : null,
    priority: priority,
    category: category,
  );

  test('today includes future deadlines, overdue and long-term tasks', () {
    final tasks = [
      task('overdue', due: DateTime(2026, 11, 3)),
      task('today', due: DateTime(2026, 11, 4)),
      task('tomorrow', due: DateTime(2026, 11, 5)),
      task('undated'),
      task('done', due: DateTime(2026, 11, 4), completed: true),
    ];
    expect(const TaskQuery().apply(tasks, now).map((t) => t.id), [
      'overdue',
      'today',
      'tomorrow',
      'undated',
    ]);
    expect(
      const TaskQuery().apply(tasks, DateTime(2026, 11, 5)).map((t) => t.id),
      ['overdue', 'today', 'tomorrow', 'undated'],
    );
    expect(const TaskQuery(view: TaskView.planned).apply(tasks, now).length, 4);
  });

  test('search, category, completion and priority order compose', () {
    final tasks = [
      task('normal', category: TaskCategory.study),
      task('urgent', category: TaskCategory.study, priority: TaskPriority.high),
      task('other'),
      task('done', category: TaskCategory.study, completed: true),
    ];
    const query = TaskQuery(
      view: TaskView.all,
      category: TaskCategory.study,
      search: '  笔记 ',
      sort: TaskSort.priority,
    );
    expect(query.apply(tasks, now).map((t) => t.id), ['urgent', 'normal']);
    expect(
      const TaskQuery(
        view: TaskView.all,
        completed: true,
      ).apply(tasks, now).single.id,
      'done',
    );
    expect(
      const TaskQuery(view: TaskView.all, search: 'missing').apply(tasks, now),
      isEmpty,
    );
  });

  test(
    'daily progress follows visible future, overdue and long-term tasks',
    () {
      final scheduled = task('today', due: DateTime(2026, 11, 4));
      final finished = task(
        'finished',
        due: DateTime(2026, 11, 4),
        completed: true,
      );
      final overdue = task('overdue', due: DateTime(2026, 11, 3));
      final progress = DailyProgress.fromTasks([
        scheduled,
        finished,
        overdue,
        task('undated'),
      ], now);
      expect(progress.total, 4);
      expect(progress.completed, 1);
      expect(progress.pending, 3);
      expect(progress.fraction, .25);
      expect(DailyProgress.fromTasks([], now).fraction, 0);
      expect(overdue.isOverdue(now), isTrue);
      expect(overdue.toggle(now).isOverdue(now), isFalse);
      expect(scheduled.isOverdue(now), isFalse);
    },
  );

  test(
    'controller saves, edits, toggles and restores through repository',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'shiguang_state_',
      );
      final box = await Hive.openBox<dynamic>(
        'controller',
        path: directory.path,
      );
      final repository = TodoRepository(box);
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWith((ref) async => repository)],
      );
      try {
        await container.read(tasksProvider.future);
        final controller = container.read(tasksProvider.notifier);
        await controller.save(
          title: '阅读',
          tags: ['读书'],
          note: '',
          category: TaskCategory.study,
          priority: TaskPriority.low,
          dueDate: now,
        );
        final original = container.read(tasksProvider).requireValue.single;
        expect(original.dueDate, dayOnly(now));
        expect(original.tags, ['读书']);
        await controller.toggle(original);
        final completed = container.read(tasksProvider).requireValue.single;
        await controller.save(
          existing: completed,
          title: '阅读第二章',
          note: '重点',
          category: TaskCategory.study,
          priority: TaskPriority.high,
        );
        final edited = container.read(tasksProvider).requireValue.single;
        expect(edited.isCompleted, isTrue);
        expect(edited.dueDate, isNull);
        expect(edited.tags, ['读书']);
        await controller.delete(edited);
        expect(container.read(tasksProvider).requireValue, isEmpty);
        await controller.restore(edited);
        expect(
          container.read(tasksProvider).requireValue.single.title,
          '阅读第二章',
        );
      } finally {
        container.dispose();
        await box.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
