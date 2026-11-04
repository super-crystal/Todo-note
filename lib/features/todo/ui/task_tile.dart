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
    this.occurrenceDate,
  });

  final Todo task;
  final DateTime now;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final DateTime? occurrenceDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final date = occurrenceDate ?? now;
    final completed = task.isCompletedOn(date);
    final deadline = task.deadlineOn(date);
    final overdue = task.isOverdue(now, occurrence: date);
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
                value: completed,
                onChanged: (_) => onToggle(),
                shape: const CircleBorder(),
                side: BorderSide(color: priorityColor, width: 1.6),
                semanticLabel: completed ? S.pending : S.completed,
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
                          decoration: completed
                              ? TextDecoration.lineThrough
                              : null,
                          color: completed
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
                          if (task.repeatDaily)
                            _Meta(
                              icon: Icons.repeat,
                              label: S.daily,
                              color: colors.primary,
                            ),
                          if (task.isLongTerm)
                            _Meta(
                              icon: Icons.all_inclusive,
                              label: S.longTerm,
                              color: colors.primary,
                            ),
                          if (deadline != null &&
                              (!task.repeatDaily || task.hasDueTime))
                            _Meta(
                              icon: Icons.event_outlined,
                              label:
                                  '${overdue ? '${S.overdue} · ' : ''}'
                                  '${task.repeatDaily ? S.time(deadline) : S.deadline(deadline, task.hasDueTime)}',
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
                          if (task.reminderEnabled && !completed)
                            _Meta(
                              icon: Icons.notifications_active_outlined,
                              label: S.reminderLead(task.reminderLeadMinutes),
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
