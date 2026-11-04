import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/strings.dart';
import '../../../data/todo.dart';
import '../state/todo_state.dart';

class TaskCategoryChips extends StatelessWidget {
  const TaskCategoryChips({super.key, this.selected, required this.onChanged});
  final TaskCategory? selected;
  final ValueChanged<TaskCategory?> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        ChoiceChip(
          label: const Text(S.all),
          selected: selected == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final category in TaskCategory.values) ...[
          const SizedBox(width: AppSpace.sm),
          ChoiceChip(
            label: Text(category.label),
            selected: selected == category,
            onSelected: (_) => onChanged(category),
          ),
        ],
      ],
    ),
  );
}

class TaskStatusChips extends StatelessWidget {
  const TaskStatusChips({
    super.key,
    this.selected,
    required this.onChanged,
    this.allowAll = true,
  });
  final bool? selected;
  final ValueChanged<bool?> onChanged;
  final bool allowAll;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpace.xs,
    children: [
      if (allowAll) _button(context, null, S.allStatuses, 'status-all'),
      _button(context, false, S.pending, 'status-pending'),
      _button(context, true, S.completed, 'status-completed'),
    ],
  );

  Widget _button(BuildContext context, bool? value, String label, String key) {
    final active = selected == value;
    return ChoiceChip(
      key: ValueKey(key),
      selected: active,
      showCheckmark: false,
      onSelected: (_) => onChanged(value),
      label: Text(label),
    );
  }
}

class TaskListControls extends StatelessWidget {
  const TaskListControls({
    super.key,
    required this.count,
    required this.completed,
    required this.sort,
    required this.onStatus,
    required this.onSort,
    this.allowAll = true,
  });
  final int count;
  final bool? completed;
  final TaskSort sort;
  final ValueChanged<bool?> onStatus;
  final ValueChanged<TaskSort> onSort;
  final bool allowAll;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TaskStatusChips(
          selected: completed,
          onChanged: onStatus,
          allowAll: allowAll,
        ),
      ),
      Text(S.taskCount(count), style: Theme.of(context).textTheme.labelSmall),
      PopupMenuButton<TaskSort>(
        tooltip: S.sort,
        initialValue: sort,
        icon: const Icon(Icons.sort),
        onSelected: onSort,
        itemBuilder: (_) => const [
          PopupMenuItem(value: TaskSort.dueDate, child: Text(S.dateSort)),
          PopupMenuItem(value: TaskSort.priority, child: Text(S.prioritySort)),
          PopupMenuItem(value: TaskSort.newest, child: Text(S.createdSort)),
        ],
      ),
    ],
  );
}
