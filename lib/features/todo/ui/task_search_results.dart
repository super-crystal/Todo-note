import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/strings.dart';
import '../../../data/todo.dart';
import '../state/task_filters.dart';
import '../state/todo_state.dart';
import 'task_controls.dart';
import 'task_filter_sheet.dart';
import 'task_tile.dart';

class TaskSearchResults extends ConsumerStatefulWidget {
  const TaskSearchResults({
    super.key,
    required this.controller,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final SearchController controller;
  final ValueChanged<Todo> onEdit;
  final ValueChanged<Todo> onToggle;
  final ValueChanged<Todo> onDelete;

  @override
  ConsumerState<TaskSearchResults> createState() => _TaskSearchResultsState();
}

class _TaskSearchResultsState extends ConsumerState<TaskSearchResults> {
  TaskFilters _filters = const TaskFilters();
  TaskSort _sort = TaskSort.dueDate;
  final _resultsFocus = FocusNode(skipTraversal: true);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _resultsFocus.dispose();
    super.dispose();
  }

  Future<void> _openFilters(List<Todo> tasks) async {
    _resultsFocus.requestFocus();
    final selected = await showTaskFilters(
      context,
      filters: _filters,
      tags: TaskFilters.availableTags(tasks),
    );
    if (mounted) {
      _resultsFocus.requestFocus();
      if (selected != null) setState(() => _filters = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider).value ?? const <Todo>[];
    final now = DateTime.now();
    final results = TaskQuery(
      view: TaskView.all,
      search: widget.controller.text,
      category: _filters.category,
      priority: _filters.priority,
      tag: _filters.tag,
      completed: _filters.completed,
      dateFrom: _filters.dateFrom,
      dateTo: _filters.dateTo,
      undatedOnly: _filters.undatedOnly,
      sort: _sort,
    ).apply(tasks, now);
    return Scaffold(
      body: Focus(
        focusNode: _resultsFocus,
        includeSemantics: false,
        child: CustomScrollView(
          key: const ValueKey('search-results'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            S.searchResults,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Semantics(
                          label: S.filters,
                          button: true,
                          onTap: () => _openFilters(tasks),
                          child: ExcludeSemantics(
                            child: TextButton.icon(
                              key: const ValueKey('search-filters'),
                              onPressed: () => _openFilters(tasks),
                              icon: Badge(
                                isLabelVisible: _filters.activeCount > 0,
                                label: Text('${_filters.activeCount}'),
                                child: const Icon(Icons.tune),
                              ),
                              label: const Text(S.filters),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_filters.activeCount > 0)
                      TaskFilterSummary(filters: _filters),
                    TaskListControls(
                      count: results.length,
                      completed: _filters.completed,
                      sort: _sort,
                      onStatus: (value) =>
                          setState(() => _filters = _filters.withStatus(value)),
                      onSort: (value) => setState(() => _sort = value),
                    ),
                    const SizedBox(height: AppSpace.sm),
                  ],
                ),
              ),
            ),
            if (results.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.all(AppSpace.xl),
                sliver: SliverToBoxAdapter(child: Text(S.noResults)),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                sliver: SliverList.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpace.md),
                  itemBuilder: (context, index) {
                    final task = results[index];
                    return TaskTile(
                      key: ValueKey(task.id),
                      task: task,
                      now: now,
                      onEdit: () => widget.onEdit(task),
                      onToggle: () => widget.onToggle(task),
                      onDelete: () => widget.onDelete(task),
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xl)),
          ],
        ),
      ),
    );
  }
}
