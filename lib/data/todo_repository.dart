import 'package:hive/hive.dart';

import 'todo.dart';
import 'task_tags.dart';

class TodoRepository {
  TodoRepository(this._box);
  final Box<dynamic> _box;

  List<Todo> readAll() =>
      List.unmodifiable(_box.values.map((value) => Todo.fromMap(value as Map)));

  Future<void> save(Todo task) async {
    final title = task.title.trim();
    if (title.isEmpty ||
        title.length > 120 ||
        task.note.length > 2000 ||
        TaskTags.validate(task.tags) != null) {
      throw ArgumentError('Invalid task content');
    }
    await _box.put(task.id, {...task.toMap(), 'title': title});
  }

  Future<void> delete(String id) => _box.delete(id);
}
