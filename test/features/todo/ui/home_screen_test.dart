import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shiguang_todo/core/strings.dart';
import 'package:shiguang_todo/data/todo.dart';
import 'package:shiguang_todo/data/todo_repository.dart';
import 'package:shiguang_todo/features/todo/state/todo_state.dart';
import 'package:shiguang_todo/main.dart';

void main() {
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
}

class _UnusedBox extends Fake implements Box<dynamic> {}

class _MemoryRepository extends TodoRepository {
  _MemoryRepository() : super(_UnusedBox());
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
