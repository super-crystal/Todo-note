import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/strings.dart';
import '../../../data/todo.dart';
import '../../../data/task_tags.dart';

class TaskTagsField extends StatelessWidget {
  const TaskTagsField({
    super.key,
    required this.controller,
    required this.enabled,
  });
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: const ValueKey('task-tags'),
    controller: controller,
    enabled: enabled,
    maxLength: TaskTags.maxInputLength,
    decoration: const InputDecoration(
      labelText: S.tags,
      hintText: S.tagsExample,
      helperText: S.tagsHelp,
      helperMaxLines: 2,
    ),
    validator: (value) =>
        switch (TaskTags.validate(TaskTags.parse(value ?? ''))) {
          TagInputError.tooMany => S.tagsTooMany,
          TagInputError.tooLong => S.tagTooLong,
          null => null,
        },
  );
}

class TaskTextFields extends StatelessWidget {
  const TaskTextFields({
    super.key,
    required this.title,
    required this.note,
    required this.enabled,
    required this.autofocus,
  });

  final TextEditingController title;
  final TextEditingController note;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextFormField(
        controller: title,
        autofocus: autofocus,
        enabled: enabled,
        maxLength: 120,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: S.taskTitle,
          hintText: S.titleHint,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return S.titleRequired;
          return value.trim().length > 120 ? S.titleTooLong : null;
        },
      ),
      const SizedBox(height: AppSpace.sm),
      TextFormField(
        controller: note,
        enabled: enabled,
        maxLength: 2000,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: S.note,
          hintText: S.noteHint,
        ),
        validator: (value) =>
            (value?.length ?? 0) > 2000 ? S.noteTooLong : null,
      ),
    ],
  );
}

class TaskDateField extends StatelessWidget {
  const TaskDateField({super.key, this.date, this.onPick, this.onClear});
  final DateTime? date;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.event_outlined),
          label: Text(date == null ? S.noDate : S.fullDate(date!)),
        ),
      ),
      if (date != null)
        IconButton(
          tooltip: S.clearDate,
          onPressed: onClear,
          icon: const Icon(Icons.close),
        ),
    ],
  );
}

class TaskOptionFields extends StatelessWidget {
  const TaskOptionFields({
    super.key,
    required this.category,
    required this.priority,
    this.onCategory,
    this.onPriority,
  });

  final TaskCategory category;
  final TaskPriority priority;
  final ValueChanged<TaskCategory>? onCategory;
  final ValueChanged<TaskPriority>? onPriority;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _OptionGroup<TaskCategory>(
        label: S.category,
        items: TaskCategory.values,
        selected: category,
        itemLabel: (value) => value.label,
        onChanged: onCategory,
      ),
      const SizedBox(height: AppSpace.lg),
      _OptionGroup<TaskPriority>(
        label: S.priority,
        items: TaskPriority.values,
        selected: priority,
        itemLabel: (value) => value.label,
        icon: Icons.flag_outlined,
        onChanged: onPriority,
      ),
    ],
  );
}

class _OptionGroup<T> extends StatelessWidget {
  const _OptionGroup({
    required this.label,
    required this.items,
    required this.selected,
    required this.itemLabel,
    this.icon,
    this.onChanged,
  });

  final String label;
  final List<T> items;
  final T selected;
  final String Function(T) itemLabel;
  final IconData? icon;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppSpace.sm),
      Wrap(
        spacing: AppSpace.sm,
        children: items
            .map(
              (item) => ChoiceChip(
                avatar: icon == null
                    ? null
                    : Icon(icon, size: AppSize.chipIcon),
                label: Text(itemLabel(item)),
                selected: item == selected,
                onSelected: onChanged == null ? null : (_) => onChanged!(item),
              ),
            )
            .toList(),
      ),
    ],
  );
}
