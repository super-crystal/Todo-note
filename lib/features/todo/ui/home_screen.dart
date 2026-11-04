import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/strings.dart';
import '../../../data/todo.dart';
import '../state/todo_state.dart';
import 'task_editor.dart';
import 'task_tile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  TaskView _view = TaskView.today;
  TaskCategory? _category;
  TaskSort _sort = TaskSort.dueDate;
  bool _completed = false;
  final _search = TextEditingController();
  final _busyIds = <String>{};
  late final Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
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
      floatingActionButton: tasks.hasValue
          ? FloatingActionButton.extended(
              onPressed: () =>
                  openTaskEditor(context, today: _view == TaskView.today),
              icon: const Icon(Icons.add),
              label: const Text(S.newTask),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _view.index,
        onDestinationSelected: (index) => setState(() {
          _view = TaskView.values[index];
          _category = null;
          _completed = false;
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

  Widget _content(List<Todo> tasks) {
    final theme = Theme.of(context);
    final filtered = TaskQuery(
      view: _view,
      category: _category,
      completed: _completed,
      search: _search.text,
      sort: _sort,
    ).apply(tasks, _now);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.lg,
            AppSpace.xl,
            0,
          ),
          sliver: SliverList.list(
            children: [
              Text(
                S.headerDate(_now),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                switch (_view) {
                  TaskView.today => S.focus,
                  TaskView.planned => S.planned,
                  TaskView.all => S.all,
                },
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              if (_view == TaskView.today) ...[
                _FocusCard(tasks: tasks, now: _now),
                const SizedBox(height: AppSpace.xl),
              ],
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text(S.all),
                        selected: _category == null,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                      for (final category in TaskCategory.values) ...[
                        const SizedBox(width: AppSpace.sm),
                        ChoiceChip(
                          label: Text(category.label),
                          selected: _category == category,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppSpace.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _completed = false),
                            child: Text(
                              S.pending,
                              style: TextStyle(
                                color: _completed
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.primary,
                                fontWeight: _completed ? null : FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _completed = true),
                            child: Text(
                              S.completed,
                              style: TextStyle(
                                color: _completed
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: _completed ? FontWeight.bold : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      S.taskCount(filtered.length),
                      style: theme.textTheme.labelSmall,
                    ),
                    PopupMenuButton<TaskSort>(
                      tooltip: S.sort,
                      initialValue: _sort,
                      icon: const Icon(Icons.sort),
                      onSelected: (sort) => setState(() => _sort = sort),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: TaskSort.dueDate,
                          child: Text(S.dateSort),
                        ),
                        PopupMenuItem(
                          value: TaskSort.priority,
                          child: Text(S.prioritySort),
                        ),
                        PopupMenuItem(
                          value: TaskSort.newest,
                          child: Text(S.createdSort),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
              ],
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
    );
  }

  Widget _empty(bool noTasks) {
    final filtered = _category != null || _search.text.trim().isNotEmpty;
    final (title, body) = filtered
        ? (S.noResults, S.noResultsBody)
        : _completed
        ? (S.completedEmpty, S.completedEmptyBody)
        : noTasks
        ? (S.emptyTitle, S.emptyBody)
        : switch (_view) {
            TaskView.today => (S.todayEmpty, S.todayEmptyBody),
            TaskView.planned => (S.plannedEmpty, S.plannedEmptyBody),
            TaskView.all => (S.emptyTitle, S.emptyBody),
          };
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
