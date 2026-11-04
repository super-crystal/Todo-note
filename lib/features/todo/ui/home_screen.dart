import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/strings.dart';
import '../../../data/todo.dart';
import '../state/todo_state.dart';
import '../state/calendar_state.dart';
import '../state/task_filters.dart';
import 'task_editor.dart';
import 'task_tile.dart';
import 'task_calendar.dart';
import 'task_controls.dart';
import 'task_filter_sheet.dart';
import 'task_search_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  TaskView _view = TaskView.today;
  TaskFilters _filters = const TaskFilters(completed: false);
  TaskSort _sort = TaskSort.dueDate;
  late DateTime _selectedDay;
  final _search = TextEditingController();
  final _resultsFocus = FocusNode(skipTraversal: true);
  final _busyIds = <String>{};
  late final Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDay = dayOnly(_now);
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => _refreshDate());
  }

  void _refreshDate() {
    if (mounted) setState(() => _now = DateTime.now());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.cancel();
    _search.dispose();
    _resultsFocus.dispose();
    super.dispose();
  }

  Future<void> _action(Todo task, Future<void> Function() action) async {
    if (!_busyIds.add(task.id)) return;
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text(S.writeError)));
      }
    } finally {
      _busyIds.remove(task.id);
    }
  }

  Future<void> _delete(Todo task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.delete),
        content: const Text(S.deletePrompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _action(task, () async {
      await ref.read(tasksProvider.notifier).delete(task);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: const Text(S.deleted),
          action: SnackBarAction(
            label: S.undo,
            onPressed: () => _action(
              task,
              () => ref.read(tasksProvider.notifier).restore(task),
            ),
          ),
        ),
      );
    });
  }

  void _about() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.spa_outlined),
        title: const Text(S.about),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.aboutBody),
            SizedBox(height: AppSpace.xl),
            Text(S.version),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(S.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.spa_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpace.sm),
            const Text(S.appName),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _about,
            tooltip: S.about,
            icon: const Icon(Icons.info_outline),
          ),
          const SizedBox(width: AppSpace.sm),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpace.pageWidth),
            child: tasks.when(
              data: _content,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _LoadError(
                onRetry: () {
                  ref.invalidate(repositoryProvider);
                  ref.invalidate(tasksProvider);
                },
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: tasks.hasValue && _view != TaskView.planned
          ? FloatingActionButton.extended(
              onPressed: _openNewTask,
              icon: const Icon(Icons.add),
              label: const Text(S.newTask),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _view.index,
        onDestinationSelected: (index) => setState(() {
          _view = TaskView.values[index];
          _filters = TaskFilters(
            completed: _view == TaskView.today ? false : null,
          );
          _search.clear();
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny),
            label: S.today,
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: S.planned,
          ),
          NavigationDestination(
            icon: Icon(Icons.layers_outlined),
            selectedIcon: Icon(Icons.layers),
            label: S.all,
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters(List<Todo> tasks) async {
    _resultsFocus.requestFocus();
    final selected = await showTaskFilters(
      context,
      filters: _filters,
      tags: TaskFilters.availableTags(tasks),
    );
    if (selected != null && mounted) {
      _resultsFocus.requestFocus();
      setState(() => _filters = selected);
    }
  }

  void _openNewTask() => openTaskEditor(
    context,
    today: _view == TaskView.today,
    initialDate: _view == TaskView.planned ? _selectedDay : null,
  );

  Future<void> _chooseCalendarDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(_selectedDay.year < 2000 ? _selectedDay.year : 2000),
      lastDate: DateTime(
        _selectedDay.year > 2100 ? _selectedDay.year : 2100,
        12,
        31,
      ),
      helpText: S.chooseDate,
    );
    if (selected != null && mounted) {
      setState(() => _selectedDay = dayOnly(selected));
    }
  }

  Widget _content(List<Todo> tasks) {
    final filtered = TaskQuery(
      view: _view,
      category: _filters.category,
      completed: _filters.completed,
      search: _search.text,
      sort: _sort,
      priority: _filters.priority,
      tag: _filters.tag,
      dateFrom: _view == TaskView.planned ? _selectedDay : _filters.dateFrom,
      dateTo: _view == TaskView.planned ? _selectedDay : _filters.dateTo,
      undatedOnly: _filters.undatedOnly,
    ).apply(tasks, _now);
    return Focus(
      focusNode: _resultsFocus,
      includeSemantics: false,
      child: CustomScrollView(
        key: ValueKey(_view),
        slivers: [
          if (_view == TaskView.all)
            SliverPersistentHeader(
              pinned: true,
              delegate: TaskSearchHeader(
                controller: _search,
                filterCount: _filters.activeCount,
                onChanged: () => setState(() {}),
                onFilters: () => _openFilters(tasks),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.lg,
              AppSpace.xl,
              0,
            ),
            sliver: SliverList.list(
              children: [
                if (_view == TaskView.today) ..._todayHeader(tasks),
                if (_view == TaskView.planned) ..._calendarHeader(tasks),
                if (_view == TaskView.all && _filters.activeCount > 0) ...[
                  TaskFilterSummary(filters: _filters),
                  const SizedBox(height: AppSpace.sm),
                ],
                if (_view != TaskView.today || tasks.isNotEmpty)
                  TaskListControls(
                    count: filtered.length,
                    completed: _filters.completed,
                    allowAll: _view != TaskView.today,
                    sort: _sort,
                    onStatus: (value) =>
                        setState(() => _filters = _filters.withStatus(value)),
                    onSort: (value) => setState(() => _sort = value),
                  ),
                const SizedBox(height: AppSpace.sm),
              ],
            ),
          ),
          if (filtered.isEmpty)
            SliverToBoxAdapter(child: _empty(tasks.isEmpty))
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
                itemBuilder: (context, index) {
                  final task = filtered[index];
                  return TaskTile(
                    key: ValueKey(task.id),
                    task: task,
                    now: _now,
                    onToggle: () => _action(
                      task,
                      () => ref.read(tasksProvider.notifier).toggle(task),
                    ),
                    onEdit: () => openTaskEditor(context, task: task),
                    onDelete: () => _delete(task),
                  );
                },
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpace.fabClearance),
          ),
        ],
      ),
    );
  }

  List<Widget> _todayHeader(List<Todo> tasks) {
    final theme = Theme.of(context);
    return [
      Text(
        S.headerDate(_now),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: AppSpace.sm),
      Text(
        S.focus,
        style: theme.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: AppSpace.xl),
      _FocusCard(tasks: tasks, now: _now),
      const SizedBox(height: AppSpace.xl),
      if (tasks.isNotEmpty) ...[
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: S.search,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: S.clearSearch,
                    onPressed: () => setState(_search.clear),
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        TaskCategoryChips(
          selected: _filters.category,
          onChanged: (value) =>
              setState(() => _filters = _filters.withCategory(value)),
        ),
        const SizedBox(height: AppSpace.lg),
      ],
    ];
  }

  List<Widget> _calendarHeader(List<Todo> tasks) => [
    TaskCalendar(
      calendar: CalendarMonth(_selectedDay, tasks),
      now: _now,
      onSelected: (date) => setState(() => _selectedDay = date),
      onChooseDate: _chooseCalendarDate,
    ),
    const SizedBox(height: AppSpace.lg),
    Row(
      children: [
        Expanded(
          child: Text(
            '${S.fullDate(_selectedDay)} · ${S.weekday(_selectedDay)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton.filledTonal(
          tooltip: S.newTask,
          onPressed: _openNewTask,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    const SizedBox(height: AppSpace.sm),
  ];

  Widget _empty(bool noTasks) {
    if (_view == TaskView.planned) {
      return const _EmptyState(title: S.dayEmptyTitle, body: S.dayEmptyBody);
    }
    final narrowed =
        _search.text.trim().isNotEmpty ||
        _filters.category != null ||
        (_view == TaskView.all && _filters.activeCount > 0);
    final (title, body) = narrowed
        ? (S.noResults, S.noResultsBody)
        : _filters.completed == true
        ? (S.completedEmpty, S.completedEmptyBody)
        : noTasks
        ? (S.emptyTitle, S.emptyBody)
        : _view == TaskView.today
        ? (S.todayEmpty, S.todayEmptyBody)
        : (S.emptyTitle, S.emptyBody);
    return _EmptyState(title: title, body: body);
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.tasks, required this.now});
  final List<Todo> tasks;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = DailyProgress.fromTasks(tasks, now);
    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(AppSpace.xl),
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: colors.onPrimary),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: colors.onPrimary,
                  size: AppSize.smallIcon,
                ),
                const SizedBox(width: AppSpace.sm),
                const Expanded(child: Text(S.focusHint)),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            Text(
              progress.total == 0
                  ? S.focusEmpty
                  : progress.pending == 0
                  ? S.focusDone
                  : S.remaining(progress.pending),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            LinearProgressIndicator(
              value: progress.fraction,
              color: colors.onPrimary,
              backgroundColor: colors.onPrimary.withValues(alpha: .2),
              minHeight: AppSize.progressHeight,
              borderRadius: BorderRadius.circular(AppSpace.sm),
            ),
            const SizedBox(height: AppSpace.md),
            Text(S.progress(progress.completed, progress.total)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpace.xxl),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.xl),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.checklist_rounded,
              size: AppSize.emptyIcon,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const _EmptyState(title: S.loadError, body: S.loadErrorBody),
      FilledButton(onPressed: onRetry, child: const Text(S.retry)),
    ],
  );
}
