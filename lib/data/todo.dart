import 'package:flutter/foundation.dart';

import 'task_tags.dart';

enum TaskCategory {
  personal('生活'),
  work('工作'),
  study('学习'),
  inbox('收集箱');

  const TaskCategory(this.label);
  final String label;
}

enum TaskPriority {
  low('普通'),
  medium('重要'),
  high('紧急');

  const TaskPriority(this.label);
  final String label;
}

DateTime dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

@immutable
class Todo {
  Todo({
    required this.id,
    required this.title,
    required this.createdAt,
    this.note = '',
    this.category = TaskCategory.inbox,
    this.priority = TaskPriority.low,
    this.dueDate,
    this.hasDueTime = false,
    this.reminderEnabled = false,
    this.completedAt,
    List<String> tags = const [],
  }) : tags = TaskTags.normalize(tags);

  final String id;
  final String title;
  final String note;
  final List<String> tags;
  final TaskCategory category;
  final TaskPriority priority;
  final DateTime createdAt;
  final DateTime? dueDate;
  final bool hasDueTime;
  final bool reminderEnabled;
  final DateTime? completedAt;
  bool get isCompleted => completedAt != null;

  bool isOverdue(DateTime now) =>
      !isCompleted &&
      dueDate != null &&
      (hasDueTime
          ? dueDate!.isBefore(now)
          : dayOnly(dueDate!).isBefore(dayOnly(now)));

  Todo toggle(DateTime now) => Todo(
    id: id,
    title: title,
    note: note,
    tags: tags,
    category: category,
    priority: priority,
    createdAt: createdAt,
    dueDate: dueDate,
    hasDueTime: hasDueTime,
    reminderEnabled: reminderEnabled,
    completedAt: isCompleted ? null : now,
  );

  Map<String, Object?> toMap() => {
    'schemaVersion': 1,
    'id': id,
    'title': title,
    'note': note,
    'tags': tags,
    'category': category.name,
    'priority': priority.name,
    'createdAt': createdAt.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'hasDueTime': hasDueTime,
    'reminderEnabled': reminderEnabled,
    'completedAt': completedAt?.toIso8601String(),
  };

  factory Todo.fromMap(Map<dynamic, dynamic> data) {
    // Refuse unknown formats so a downgrade cannot overwrite newer data.
    if (data['schemaVersion'] != 1) {
      throw const FormatException('Unsupported task schema');
    }
    return Todo(
      id: data['id'] as String,
      title: data['title'] as String,
      note: data['note'] as String,
      // Labels are additive in schema 1; existing installations have no field.
      tags: data['tags'] == null
          ? const []
          : (data['tags'] as List).cast<String>(),
      category: TaskCategory.values.byName(data['category'] as String),
      priority: TaskPriority.values.byName(data['priority'] as String),
      createdAt: DateTime.parse(data['createdAt'] as String),
      dueDate: data['dueDate'] == null
          ? null
          : DateTime.parse(data['dueDate'] as String),
      completedAt: data['completedAt'] == null
          ? null
          : DateTime.parse(data['completedAt'] as String),
      hasDueTime: data['hasDueTime'] as bool? ?? false,
      reminderEnabled: data['reminderEnabled'] as bool? ?? false,
    );
  }
}
