import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shiguang_todo/core/strings.dart';
import 'package:shiguang_todo/data/todo.dart';
import 'package:shiguang_todo/data/todo_repository.dart';
import 'package:shiguang_todo/features/todo/state/todo_state.dart';
import 'package:shiguang_todo/features/todo/state/reminder_service.dart';
import 'package:shiguang_todo/main.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      ReminderService.channel,
      (call) async =>
          call.method == 'status' || call.method == 'requestNotifications'
          ? {'notifications': true, 'exact': true}
          : null,
    ),
  );
  tearDown(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      ReminderService.channel,
      null,
    ),
  );
  testWidgets('empty title is rejected, saved task follows completion flow', (
    tester,
  ) async {
    final repository = _MemoryRepository();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) async => repository),
          ],
          child: const ShiguangApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.newTask));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(S.save));
      await tester.tap(find.text(S.save));
      await tester.pumpAndSettle();
      expect(find.text(S.titleRequired), findsOneWidget);
      final title = find.byType(TextFormField).first;
      await tester.ensureVisible(title);
      await tester.enterText(title, '读完第一章');
      await tester.ensureVisible(find.text(S.save));
      await tester.tap(find.text(S.save));
      await tester.pumpAndSettle();
      expect(repository.readAll().single.title, '读完第一章');
      expect(find.text('读完第一章'), findsOneWidget);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(repository.readAll().single.isCompleted, isTrue);
      await tester.ensureVisible(find.text(S.completed));
      await tester.tap(find.text(S.completed));
      await tester.pumpAndSettle();
      expect(find.text('读完第一章'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });
  testWidgets(
    'future tasks show today and editor switches long-term and daily',
    (tester) async {
      final now = DateTime.now();
      final repository = _MemoryRepository([
        Todo(
          id: 'future',
          title: '未来的任务',
          createdAt: now,
          dueDate: DateTime(now.year, now.month, now.day + 7),
        ),
      ]);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              repositoryProvider.overrideWith((ref) async => repository),
            ],
            child: const ShiguangApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('未来的任务'));
        await tester.tap(find.text('未来的任务'));
        await tester.pumpAndSettle();
        final longTerm = find.byKey(const ValueKey('task-long-term'));
        await tester.ensureVisible(longTerm);
        await tester.tap(longTerm);
        await tester.tap(find.text(S.save));
        await tester.pumpAndSettle();
        expect(repository.readAll().single.isLongTerm, isTrue);
        await tester.ensureVisible(find.text('未来的任务'));
        await tester.tap(find.text('未来的任务'));
        await tester.pumpAndSettle();
        final daily = find.byKey(const ValueKey('task-daily'));
        await tester.ensureVisible(daily);
        await tester.tap(daily);
        await tester.tap(find.text(S.save));
        await tester.pumpAndSettle();
        expect(repository.readAll().single.repeatDaily, isTrue);
        expect(repository.readAll().single.dueDate, dayOnly(now));
        await tester.ensureVisible(find.byType(Checkbox));
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        expect(repository.readAll().single.completedDays, [dayKey(now)]);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
  );

  testWidgets('calendar dots and selected day switch the task details', (
    tester,
  ) async {
    final today = dayOnly(DateTime.now());
    final other = DateTime(today.year, today.month, today.day == 1 ? 2 : 1);
    final repository = _MemoryRepository([
      Todo(id: 'today', title: '今天的计划', createdAt: today, dueDate: today),
      Todo(id: 'other', title: '选中日期的计划', createdAt: today, dueDate: other),
    ]);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) async => repository),
          ],
          child: const ShiguangApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('calendar-dot-${other.toIso8601String()}')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(ValueKey(other)));
      await tester.tap(find.byKey(ValueKey(other)));
      await tester.pumpAndSettle();
      expect(find.text('选中日期的计划'), findsOneWidget);
      expect(find.text('今天的计划'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('all search combines labels and undated filter and can reset', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final today = dayOnly(DateTime.now());
    final repository = _MemoryRepository([
      Todo(
        id: 'a',
        title: '买苹果',
        tags: ['周末'],
        createdAt: today,
        dueDate: today,
      ),
      Todo(id: 'b', title: '准备报告', tags: ['工作'], createdAt: today),
      Todo(
        id: 'c',
        title: '苹果派',
        tags: ['周末'],
        createdAt: today,
        completedAt: today,
      ),
    ]);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) async => repository),
          ],
          child: const ShiguangApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(2));
      await tester.pumpAndSettle();
      expect(find.text(S.filters), findsNothing);
      final pending = find.byKey(const ValueKey('status-pending'));
      await tester.tap(pending);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.widget<ChoiceChip>(pending).selected, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('苹果派'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('status-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('all-task-search')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SearchAnchor), findsWidgets);
      await tester.pumpAndSettle();
      Finder resultText(String text) => find.descendant(
        of: find.byKey(const ValueKey('search-results')),
        matching: find.text(text),
      );
      await tester.enterText(find.byType(TextField).last, '#周末 苹果');
      await tester.pumpAndSettle();
      expect(resultText('买苹果'), findsOneWidget);
      expect(resultText('苹果派'), findsOneWidget);
      expect(resultText('准备报告'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('search-filters')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(S.onlyUndated));
      await tester.tap(find.text(S.onlyUndated));
      await tester.tap(find.text(S.applyFilters));
      await tester.pumpAndSettle();
      expect(resultText('买苹果'), findsNothing);
      expect(resultText('苹果派'), findsOneWidget);
      expect(find.bySemanticsLabel(S.filters), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byKey(const ValueKey('search-filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.resetFilters));
      await tester.pumpAndSettle();
      expect(resultText('买苹果'), findsOneWidget);
      await tester.tap(find.byTooltip(S.clearSearch));
      await tester.pumpAndSettle();
      expect(resultText('准备报告'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });
}

class _UnusedBox extends Fake implements Box<dynamic> {}

class _MemoryRepository extends TodoRepository {
  _MemoryRepository([Iterable<Todo> initial = const []]) : super(_UnusedBox()) {
    _tasks.addEntries(initial.map((task) => MapEntry(task.id, task)));
  }
  final _tasks = <String, Todo>{};

  @override
  List<Todo> readAll() => List.unmodifiable(_tasks.values);

  @override
  Future<void> save(Todo task) async {
    _tasks[task.id] = task;
  }

  @override
  Future<void> delete(String id) async {
    _tasks.remove(id);
  }
}
