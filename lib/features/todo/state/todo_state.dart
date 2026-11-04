import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../../../data/todo.dart';
import '../../../data/todo_repository.dart';

final repositoryProvider = FutureProvider<TodoRepository>((ref) async {
  final directory = await getApplicationSupportDirectory();
  final box = await Hive.openBox<dynamic>('tasks_v1', path: directory.path);
  ref.onDispose(() => box.close());
  return TodoRepository(box);
});

final tasksProvider = AsyncNotifierProvider<TasksController, List<Todo>>(
  TasksController.new,
);

class TasksController extends AsyncNotifier<List<Todo>> {
  int _sequence = 0;

  @override
  Future<List<Todo>> build() async {
    final repository = await ref.watch(repositoryProvider.future);
    return repository.readAll();
  }

  Future<void> save({
    Todo? existing,
    required String title,
    required String note,
    required TaskCategory category,
    required TaskPriority priority,
    DateTime? dueDate,
    List<String>? tags,
  }) async {
    final now = DateTime.now();
    final task = Todo(
      id: existing?.id ?? '${now.microsecondsSinceEpoch}-${_sequence++}',
      title: title,
      note: note.trim(),
      tags: tags ?? existing?.tags ?? const [],
      category: category,
      priority: priority,
      createdAt: existing?.createdAt ?? now,
      dueDate: dueDate == null ? null : dayOnly(dueDate),
      completedAt: existing?.completedAt,
    );
    await restore(task);
  }

  Future<void> restore(Todo task) async {
    final repository = await ref.read(repositoryProvider.future);
    await repository.save(task);
    state = AsyncData(repository.readAll());
  }

  Future<void> toggle(Todo task) => restore(task.toggle(DateTime.now()));

  Future<void> delete(Todo task) async {
    final repository = await ref.read(repositoryProvider.future);
    await repository.delete(task.id);
    state = AsyncData(repository.readAll());
  }
}

enum TaskView { today, planned, all }

enum TaskSort { dueDate, priority, newest }

class DailyProgress {
  const DailyProgress._(this.total, this.completed);
  final int total;
  final int completed;
  int get pending => total - completed;
  double get fraction => total == 0 ? 0 : completed / total;

  factory DailyProgress.fromTasks(List<Todo> tasks, DateTime now) {
    final today = dayOnly(now);
    final scheduled = tasks
        .where(
          (task) => task.dueDate != null && dayOnly(task.dueDate!) == today,
        )
        .toList();
    return DailyProgress._(
      scheduled.length,
      scheduled.where((task) => task.isCompleted).length,
    );
  }
}

class TaskQuery {
  const TaskQuery({
    this.view = TaskView.today,
    this.category,
    this.completed = false,
    this.search = '',
    this.sort = TaskSort.dueDate,
    this.priority,
    this.tag,
    this.dateFrom,
    this.dateTo,
    this.undatedOnly = false,
  });

  final TaskView view;
  final TaskCategory? category;
  final bool? completed;
  final String search;
  final TaskSort sort;
  final TaskPriority? priority;
  final String? tag;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final bool undatedOnly;

  List<Todo> apply(List<Todo> tasks, DateTime now) {
    final today = dayOnly(now);
    final words = search
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((word) => word.replaceFirst(RegExp(r'^#+'), ''))
        .where((word) => word.isNotEmpty)
        .toList();
    final result = tasks.where((task) {
      if (completed != null && task.isCompleted != completed) return false;
      if (category != null && category != task.category) return false;
      if (priority != null && priority != task.priority) return false;
      if (tag != null &&
          !task.tags.any(
            (value) => value.toLowerCase() == tag!.toLowerCase(),
          )) {
        return false;
      }
      final due = task.dueDate == null ? null : dayOnly(task.dueDate!);
      if (undatedOnly) {
        if (due != null) return false;
      } else {
        if (dateFrom != null &&
            (due == null || due.isBefore(dayOnly(dateFrom!)))) {
          return false;
        }
        if (dateTo != null && (due == null || due.isAfter(dayOnly(dateTo!)))) {
          return false;
        }
      }
      final content =
          '${task.title}\n${task.note}\n${task.category.label}\n${task.tags.join(' ')}'
              .toLowerCase();
      if (!words.every(content.contains)) return false;
      return switch (view) {
        TaskView.today =>
          task.dueDate != null && !dayOnly(task.dueDate!).isAfter(today),
        TaskView.planned => task.dueDate != null,
        TaskView.all => true,
      };
    }).toList();
    result.sort((a, b) {
      int compareDate() {
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      }

      final primary = switch (sort) {
        TaskSort.dueDate => compareDate(),
        TaskSort.priority => b.priority.index.compareTo(a.priority.index),
        TaskSort.newest => b.createdAt.compareTo(a.createdAt),
      };
      if (primary != 0) return primary;
      final priority = b.priority.index.compareTo(a.priority.index);
      return priority != 0 ? priority : b.createdAt.compareTo(a.createdAt);
    });
    return List.unmodifiable(result);
  }
}
