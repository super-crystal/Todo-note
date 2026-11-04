import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/strings.dart';
import '../../../data/todo.dart';
import '../state/task_filters.dart';
import 'task_controls.dart';

Future<TaskFilters?> showTaskFilters(
  BuildContext context, {
  required TaskFilters filters,
  required List<String> tags,
}) => showModalBottomSheet<TaskFilters>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => TaskFilterSheet(initial: filters, tags: tags),
);

class TaskFilterSheet extends StatefulWidget {
  const TaskFilterSheet({super.key, required this.initial, required this.tags});
  final TaskFilters initial;
  final List<String> tags;

  @override
  State<TaskFilterSheet> createState() => _TaskFilterSheetState();
}

class _TaskFilterSheetState extends State<TaskFilterSheet> {
  TaskCategory? _category;
  TaskPriority? _priority;
  String? _tag;
  bool? _completed;
  DateTimeRange? _range;
  bool _undated = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _category = initial.category;
    _priority = initial.priority;
    _tag = initial.tag;
    _completed = initial.completed;
    _undated = initial.undatedOnly;
    if (initial.dateFrom != null && initial.dateTo != null) {
      _range = DateTimeRange(start: initial.dateFrom!, end: initial.dateTo!);
    }
  }

  Future<void> _pickRange() async {
    final current = _range?.start ?? DateTime.now();
    final end = _range?.end ?? current;
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(current.year < 2000 ? current.year : 2000),
      lastDate: DateTime(end.year > 2100 ? end.year : 2100, 12, 31),
      helpText: S.dateRange,
    );
    if (range != null && mounted) {
      setState(() {
        _range = range;
        _undated = false;
      });
    }
  }

  void _apply() => Navigator.pop(
    context,
    TaskFilters(
      category: _category,
      priority: _priority,
      tag: _tag,
      completed: _completed,
      undatedOnly: _undated,
      dateFrom: _range?.start,
      dateTo: _range?.end,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(S.filters, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpace.xl),
                  _selectionFields(),
                  const SizedBox(height: AppSpace.lg),
                  Text(S.status, style: theme.textTheme.titleSmall),
                  TaskStatusChips(
                    selected: _completed,
                    onChanged: (value) => setState(() => _completed = value),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _dateFields(),
                  const SizedBox(height: AppSpace.lg),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, const TaskFilters()),
                  child: const Text(S.resetFilters),
                ),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpace.lg),
                      child: Text(S.applyFilters),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectionFields() => Column(
    children: [
      DropdownButtonFormField<TaskCategory>(
        key: const ValueKey('filter-category'),
        initialValue: _category,
        isExpanded: true,
        decoration: const InputDecoration(labelText: S.category),
        hint: const Text(S.anyCategory),
        items: [
          const DropdownMenuItem(child: Text(S.anyCategory)),
          ...TaskCategory.values.map(
            (value) => DropdownMenuItem(value: value, child: Text(value.label)),
          ),
        ],
        onChanged: (value) => setState(() => _category = value),
      ),
      const SizedBox(height: AppSpace.lg),
      DropdownButtonFormField<TaskPriority>(
        key: const ValueKey('filter-priority'),
        initialValue: _priority,
        isExpanded: true,
        decoration: const InputDecoration(labelText: S.priority),
        hint: const Text(S.anyPriority),
        items: [
          const DropdownMenuItem(child: Text(S.anyPriority)),
          ...TaskPriority.values.map(
            (value) => DropdownMenuItem(value: value, child: Text(value.label)),
          ),
        ],
        onChanged: (value) => setState(() => _priority = value),
      ),
      const SizedBox(height: AppSpace.lg),
      DropdownButtonFormField<String>(
        key: const ValueKey('filter-tag'),
        initialValue: _tag,
        isExpanded: true,
        decoration: const InputDecoration(labelText: S.tags),
        hint: const Text(S.anyTag),
        items: [
          const DropdownMenuItem(child: Text(S.anyTag)),
          ...{...widget.tags, ?_tag}.map(
            (value) =>
                DropdownMenuItem(value: value, child: Text(S.tagLabel(value))),
          ),
        ],
        onChanged: (value) => setState(() => _tag = value),
      ),
    ],
  );

  Widget _dateFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: _pickRange,
        icon: const Icon(Icons.date_range),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
          child: Text(
            _range == null ? S.dateRange : S.range(_range!.start, _range!.end),
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: FilterChip(
          label: const Text(S.onlyUndated),
          selected: _undated,
          onSelected: (value) => setState(() {
            _undated = value;
            if (value) _range = null;
          }),
        ),
      ),
      if (_range != null || _undated)
        TextButton(
          onPressed: () => setState(() {
            _range = null;
            _undated = false;
          }),
          child: const Text(S.clearRange),
        ),
    ],
  );
}

class TaskFilterSummary extends StatelessWidget {
  const TaskFilterSummary({super.key, required this.filters});
  final TaskFilters filters;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpace.sm,
    runSpacing: AppSpace.xs,
    children: [
      if (filters.category != null) Chip(label: Text(filters.category!.label)),
      if (filters.priority != null) Chip(label: Text(filters.priority!.label)),
      if (filters.tag != null) Chip(label: Text(S.tagLabel(filters.tag!))),
      if (filters.undatedOnly) const Chip(label: Text(S.onlyUndated)),
      if (filters.dateFrom != null && filters.dateTo != null)
        Chip(label: Text(S.range(filters.dateFrom!, filters.dateTo!))),
    ],
  );
}
