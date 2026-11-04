import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/strings.dart';
import '../../../data/todo.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.now,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Todo task;
  final DateTime now;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final overdue = task.isOverdue(now);
    final priorityColor = switch (task.priority) {
      TaskPriority.high => colors.error,
      TaskPriority.medium => colors.tertiary,
      TaskPriority.low => colors.primary,
    };
    return Card(
      color: colors.surfaceContainerLowest,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpace.xl),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: task.isCompleted,
                onChanged: (_) => onToggle(),
                shape: const CircleBorder(),
                side: BorderSide(color: priorityColor, width: 1.6),
                semanticLabel: task.isCompleted ? S.pending : S.completed,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted
                              ? colors.onSurfaceVariant
                              : colors.onSurface,
                        ),
                      ),
                      if (task.note.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          task.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpace.sm),
                      Wrap(
                        spacing: AppSpace.md,
                        runSpacing: AppSpace.xs,
                        children: [
                          Text(
                            task.category.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.primary,
                            ),
                          ),
                          if (task.dueDate != null)
                            _Meta(
                              icon: Icons.event_outlined,
                              label:
                                  '${overdue ? '${S.overdue} · ' : ''}'
                                  '${S.deadline(task.dueDate!, task.hasDueTime)}',
                              color: overdue
                                  ? colors.error
                                  : colors.onSurfaceVariant,
                            ),
                          if (task.priority != TaskPriority.low)
                            _Meta(
                              icon: Icons.flag_outlined,
                              label: task.priority.label,
                              color: priorityColor,
                            ),
                          if (task.reminderEnabled && !task.isCompleted)
                            _Meta(
                              icon: Icons.notifications_active_outlined,
                              label: S.remindAtDue,
                              color: colors.onSurfaceVariant,
                            ),
                          for (final tag in task.tags)
                            Text(
                              S.tagLabel(tag),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: S.editTask,
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text(S.editTask)),
                  PopupMenuItem(value: 'delete', child: Text(S.delete)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: AppSize.metaIcon, color: color),
      const SizedBox(width: AppSpace.xs),
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    ],
  );
}
