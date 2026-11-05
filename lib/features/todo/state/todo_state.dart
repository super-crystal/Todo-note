import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../../../data/todo.dart';
import '../../../data/todo_repository.dart';
import 'reminder_service.dart';

final repositoryProvider = FutureProvider<TodoRepository>((ref) async {
  final directory = await getApplicationSupportDirectory();
  final box = await Hive.openBox<dynamic>('tasks_v1', path: directory.path);
  ref.onDispose(() => box.close());
  return TodoRepository(box);
});

final tasksProvider = AsyncNotifierProvider<TasksController, List<Todo>>(
  TasksController.new,
);

class ReminderInPastException implements Exception {
  const ReminderInPastException();
}

class TasksController extends AsyncNotifier<List<Todo>> {
  int _sequence = 0;

  @override
  Future<List<Todo>> build() async {
    final repository = await ref.watch(repositoryProvider.future);
    final tasks = repository.readAll();
    await ref.read(reminderStatusProvider.notifier).reconcile(tasks);
    return tasks;
  }

  Future<void> save({
    Todo? existing,
    required String title,
    required String note,
    required TaskCategory category,
    required TaskPriority priority,
    DateTime? dueDate,
    List<String>? tags,
    bool? hasDueTime,
    bool? reminderEnabled,
    int? reminderLeadMinutes,
    bool? repeatDaily,
  }) async {
    final now = DateTime.now();
    final timed = hasDueTime ?? existing?.hasDueTime ?? false;
    final remind = reminderEnabled ?? existing?.reminderEnabled ?? false;
    final lead = reminderLeadMinutes ?? existing?.reminderLeadMinutes ?? 0;
    final daily = repeatDaily ?? existing?.repeatDaily ?? false;
    final unchangedReminder =
        existing?.reminderEnabled == true &&
        existing?.dueDate == dueDate &&
        existing?.reminderLeadMinutes == lead &&
        existing?.repeatDaily == daily;
    if (dueDate != null &&
        timed &&
        remind &&
        !daily &&
        !unchangedReminder &&
        !dueDate.subtract(Duration(minutes: lead)).isAfter(now) &&
        existing?.isCompleted != true) {
      throw const ReminderInPastException();
    }
    final task = Todo(
      id: existing?.id ?? '${now.microsecondsSinceEpoch}-${_sequence++}',
      title: title,
      note: note.trim(),
      tags: tags ?? existing?.tags ?? const [],
      category: category,
      priority: priority,
      createdAt: existing?.createdAt ?? now,
      dueDate: dueDate == null ? null : (timed ? dueDate : dayOnly(dueDate)),
      hasDueTime: dueDate != null && timed,
      reminderEnabled: dueDate != null && timed && remind,
      reminderLeadMinutes: lead,
      repeatDaily: daily,
      completedDays: daily && existing?.repeatDaily == true
          ? existing!.completedDays
          : const [],
      completedAt: existing?.repeatDaily == daily
          ? existing?.completedAt
          : null,
    );
    await restore(task);
  }

  Future<void> restore(Todo task) async {
    final repository = await ref.read(repositoryProvider.future);
    await repository.save(task);
    state = AsyncData(repository.readAll());
    await ref
        .read(reminderStatusProvider.notifier)
        .reconcile(state.requireValue);
  }

  Future<void> toggle(Todo task, {DateTime? date}) =>
      restore(task.toggle(date ?? DateTime.now()));

  Future<void> delete(Todo task) async {
    final repository = await ref.read(repositoryProvider.future);
    await repository.delete(task.id);
    state = AsyncData(repository.readAll());
    await ref
        .read(reminderStatusProvider.notifier)
        .reconcile(state.requireValue);
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
    final scheduled = tasks.where((task) => task.visibleToday(now)).toList();
    return DailyProgress._(
      scheduled.length,
      scheduled.where((task) => task.isCompletedOn(now)).length,
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
    final referenceDate = view == TaskView.planned ? dateFrom ?? now : now;
    final words = search
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((word) => word.replaceFirst(RegExp(r'^#+'), ''))
        .where((word) => word.isNotEmpty)
        .toList();
    final result = tasks.where((task) {
      if (completed != null && task.isCompletedOn(referenceDate) != completed) {
        return false;
      }
      if (category != null && category != task.category) return false;
      if (priority != null && priority != task.priority) return false;
      if (tag != null &&
          !task.tags.any(
            (value) => value.toLowerCase() == tag!.toLowerCase(),
          )) {
        return false;
      }
      final due = task.repeatDaily
          ? (dateFrom != null && dayOnly(dateFrom!).isAfter(task.dailyStart)
                ? dayOnly(dateFrom!)
                : task.dailyStart)
          : task.dueDate == null
          ? null
          : dayOnly(task.dueDate!);
      if (undatedOnly) {
        if (due != null) return false;
      } else if (!(view == TaskView.planned && task.isLongTerm)) {
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
        TaskView.today => task.visibleToday(now),
        TaskView.planned => true,
        TaskView.all => true,
      };
    }).toList();
    result.sort((a, b) {
      int compareDate() {
        final aDate = a.deadlineOn(referenceDate);
        final bDate = b.deadlineOn(referenceDate);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
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
