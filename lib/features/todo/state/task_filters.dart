import '../../../data/task_tags.dart';
import '../../../data/todo.dart';

class TaskFilters {
  const TaskFilters({
    this.category,
    this.priority,
    this.tag,
    this.dateFrom,
    this.dateTo,
    this.undatedOnly = false,
    this.completed,
  });

  final TaskCategory? category;
  final TaskPriority? priority;
  final String? tag;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final bool undatedOnly;
  final bool? completed;

  TaskFilters withStatus(bool? value) => TaskFilters(
    category: category,
    priority: priority,
    tag: tag,
    dateFrom: dateFrom,
    dateTo: dateTo,
    undatedOnly: undatedOnly,
    completed: value,
  );

  TaskFilters withCategory(TaskCategory? value) => TaskFilters(
    category: value,
    priority: priority,
    tag: tag,
    dateFrom: dateFrom,
    dateTo: dateTo,
    undatedOnly: undatedOnly,
    completed: completed,
  );

  int get activeCount => [
    category != null,
    priority != null,
    tag != null,
    dateFrom != null || dateTo != null || undatedOnly,
    completed != null,
  ].where((active) => active).length;

  static List<String> availableTags(List<Todo> tasks) {
    final tags = TaskTags.normalize(tasks.expand((task) => task.tags)).toList();
    tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return List.unmodifiable(tags);
  }
}
