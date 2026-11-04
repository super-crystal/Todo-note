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

String dayKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

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
    this.reminderLeadMinutes = 0,
    this.repeatDaily = false,
    List<String> completedDays = const [],
    this.completedAt,
    List<String> tags = const [],
  }) : tags = TaskTags.normalize(tags),
       completedDays = List.unmodifiable(
         completedDays.toSet().toList()..sort(),
       );

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
  final int reminderLeadMinutes;
  final bool repeatDaily;
  final List<String> completedDays;
  final DateTime? completedAt;
  bool get isCompleted => isCompletedOn(DateTime.now());
  bool get isLongTerm => dueDate == null && !repeatDaily;
  DateTime get dailyStart => dayOnly(dueDate ?? createdAt);

  bool isCompletedOn(DateTime date) =>
      repeatDaily ? completedDays.contains(dayKey(date)) : completedAt != null;

  bool occursOn(DateTime date) => repeatDaily
      ? !dayOnly(date).isBefore(dailyStart)
      : dueDate != null && dayOnly(dueDate!) == dayOnly(date);

  DateTime? deadlineOn(DateTime date) {
    if (!repeatDaily) return dueDate;
    if (!occursOn(date)) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      hasDueTime ? dueDate!.hour : 0,
      hasDueTime ? dueDate!.minute : 0,
    );
  }

  bool visibleToday(DateTime now) {
    if (repeatDaily) return occursOn(now);
    return !isCompletedOn(now) ||
        (completedAt != null && dayOnly(completedAt!) == dayOnly(now));
  }

  bool isOverdue(DateTime now, {DateTime? occurrence}) =>
      !isCompletedOn(occurrence ?? now) &&
      deadlineOn(occurrence ?? now) != null &&
      (hasDueTime
          ? deadlineOn(occurrence ?? now)!.isBefore(now)
          : dayOnly(deadlineOn(occurrence ?? now)!).isBefore(dayOnly(now)));

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
    reminderLeadMinutes: reminderLeadMinutes,
    repeatDaily: repeatDaily,
    completedDays: !repeatDaily
        ? completedDays
        : isCompletedOn(now)
        ? completedDays.where((day) => day != dayKey(now)).toList()
        : [...completedDays, dayKey(now)],
    completedAt: isCompletedOn(now) ? null : now,
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
    'reminderLeadMinutes': reminderLeadMinutes,
    'repeatDaily': repeatDaily,
    'completedDays': completedDays,
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
      reminderLeadMinutes: data['reminderLeadMinutes'] as int? ?? 0,
      repeatDaily: data['repeatDaily'] as bool? ?? false,
      completedDays: data['completedDays'] == null
          ? const []
          : (data['completedDays'] as List).cast<String>(),
    );
  }
}
