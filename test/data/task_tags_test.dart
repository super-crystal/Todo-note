import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_todo/data/task_tags.dart';
import 'package:shiguang_todo/data/todo.dart';

void main() {
  test('legacy records load without labels and labels survive completion', () {
    final legacy = Todo(
      id: 'legacy',
      title: '旧任务',
      createdAt: DateTime(2026),
    ).toMap()..remove('tags');
    expect(Todo.fromMap(legacy).tags, isEmpty);
    final upgraded = Todo.fromMap({
      ...legacy,
      'tags': ['购物', '#Work', 'work'],
    });
    expect(upgraded.tags, ['购物', 'Work']);
    expect(upgraded.toggle(DateTime(2026, 11, 4)).tags, upgraded.tags);
    expect(() => upgraded.tags.add('不可变'), throwsUnsupportedError);
  });

  test('label input normalizes separators and enforces limits', () {
    expect(TaskTags.parse('  #周末，周末,Work work；购物 '), ['周末', 'Work', '购物']);
    expect(
      TaskTags.validate(TaskTags.parse('一 二 三 四 五 六')),
      TagInputError.tooMany,
    );
    expect(TaskTags.validate(['abcdefghijklmnopq']), TagInputError.tooLong);
    expect(TaskTags.validate(TaskTags.parse(' , # ')), isNull);
  });
}
