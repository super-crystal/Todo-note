import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shiguang_todo/data/todo.dart';
import 'package:shiguang_todo/data/todo_repository.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late TodoRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('shiguang_test_');
    box = await Hive.openBox<dynamic>('tasks', path: directory.path);
    repository = TodoRepository(box);
  });

  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  Todo task({String title = '  阅读  ', List<String> tags = const ['读书']}) =>
      Todo(
        id: 'test-1',
        title: title,
        note: '第一章',
        tags: tags,
        category: TaskCategory.study,
        priority: TaskPriority.high,
        createdAt: DateTime(2026, 11, 4),
        dueDate: DateTime(2026, 11, 5),
      );

  test('create, reopen, edit and delete preserve task fields', () async {
    await repository.save(task());
    await box.close();
    box = await Hive.openBox<dynamic>('tasks', path: directory.path);
    repository = TodoRepository(box);
    final stored = repository.readAll().single;
    expect(stored.title, '阅读');
    expect(stored.note, '第一章');
    expect(stored.tags, ['读书']);
    expect(stored.category, TaskCategory.study);
    expect(stored.priority, TaskPriority.high);
    expect(stored.dueDate, DateTime(2026, 11, 5));
    await repository.save(task(title: '复习'));
    expect(repository.readAll().single.title, '复习');
    await repository.delete(stored.id);
    expect(repository.readAll(), isEmpty);
    await repository.save(stored);
    expect(repository.readAll().single.id, stored.id);
  });

  test(
    'completion persists and can be undone without losing due date',
    () async {
      final completed = task().toggle(DateTime(2026, 11, 4, 9));
      await repository.save(completed);
      final stored = repository.readAll().single;
      expect(stored.isCompleted, isTrue);
      expect(stored.completedAt, DateTime(2026, 11, 4, 9));
      await repository.save(stored.toggle(DateTime(2026, 11, 4, 10)));
      expect(repository.readAll().single.isCompleted, isFalse);
      expect(repository.readAll().single.dueDate, task().dueDate);
      expect(repository.readAll().single.tags, task().tags);
    },
  );

  test(
    'invalid input and unknown schema do not silently destroy data',
    () async {
      await repository.save(task());
      await expectLater(
        repository.save(task(title: '  ')),
        throwsArgumentError,
      );
      expect(repository.readAll().single.title, '阅读');
      await expectLater(
        repository.save(task(tags: ['abcdefghijklmnopq'])),
        throwsArgumentError,
      );
      expect(
        () => Todo.fromMap({...task().toMap(), 'schemaVersion': 2}),
        throwsFormatException,
      );
    },
  );
}
