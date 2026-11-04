import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shiguang_todo/data/todo.dart';
import 'package:shiguang_todo/data/todo_repository.dart';
import 'package:shiguang_todo/features/todo/state/reminder_service.dart';
import 'package:shiguang_todo/features/todo/state/todo_state.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  var permissions = {'notifications': true, 'exact': true};
  setUp(() {
    calls.clear();
    permissions = {'notifications': true, 'exact': true};
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      ReminderService.channel,
      (call) async {
        calls.add(call);
        return call.method == 'status' || call.method == 'requestNotifications'
            ? permissions
            : null;
      },
    );
  });
  tearDown(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      ReminderService.channel,
      null,
    ),
  );

  test('old records stay date-only and timed deadlines retain precision', () {
    final due = DateTime(2026, 11, 4, 14, 30);
    final old =
        Todo(
            id: 'old',
            title: 'old',
            createdAt: due,
            dueDate: dayOnly(due),
          ).toMap()
          ..remove('hasDueTime')
          ..remove('reminderEnabled');
    final legacy = Todo.fromMap(old);
    expect(legacy.hasDueTime, isFalse);
    expect(legacy.reminderEnabled, isFalse);
    expect(legacy.isOverdue(due), isFalse);
    final timed = Todo.fromMap({
      ...old,
      'dueDate': due.toIso8601String(),
      'hasDueTime': true,
      'reminderEnabled': true,
    });
    expect(timed.dueDate, due);
    expect(timed.isOverdue(due.subtract(const Duration(seconds: 1))), isFalse);
    expect(timed.isOverdue(due.add(const Duration(seconds: 1))), isTrue);
    expect(timed.toggle(due).reminderEnabled, isTrue);
    expect(
      timed.toggle(due).isOverdue(due.add(const Duration(minutes: 1))),
      isFalse,
    );
  });

  test(
    'permission states are distinct and no system request happens on status',
    () async {
      final service = ReminderService();
      expect(await service.access(), ReminderAccess.ready);
      permissions['exact'] = false;
      expect(await service.access(), ReminderAccess.exactAlarm);
      permissions['notifications'] = false;
      expect(await service.access(request: true), ReminderAccess.notifications);
      expect(calls.map((call) => call.method), [
        'status',
        'status',
        'requestNotifications',
      ]);
      await service.openSettings(ReminderAccess.exactAlarm);
      expect(calls.last.method, 'exactSettings');
    },
  );

  test(
    'save, reschedule, complete, delete and undo reconcile alarm snapshots',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'shiguang_reminders_',
      );
      final box = await Hive.openBox<dynamic>(
        'reminders',
        path: directory.path,
      );
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWith((ref) async => TodoRepository(box)),
        ],
      );
      List<dynamic> scheduled() =>
          calls.lastWhere((call) => call.method == 'sync').arguments
              as List<dynamic>;
      try {
        await container.read(tasksProvider.future);
        final controller = container.read(tasksProvider.notifier);
        final due = DateTime.now().add(const Duration(days: 1));
        await controller.save(
          title: 'Notify me',
          note: 'Details',
          category: TaskCategory.work,
          priority: TaskPriority.high,
          dueDate: due,
          hasDueTime: true,
          reminderEnabled: true,
        );
        final original = container.read(tasksProvider).requireValue.single;
        expect(original.dueDate, due);
        expect((scheduled().single as Map)['localDate'], due.toIso8601String());
        final later = due.add(const Duration(hours: 1));
        await controller.save(
          existing: original,
          title: 'Changed',
          note: '',
          category: TaskCategory.work,
          priority: TaskPriority.low,
          dueDate: later,
        );
        final edited = container.read(tasksProvider).requireValue.single;
        expect(edited.reminderEnabled, isTrue);
        expect(
          (scheduled().single as Map)['localDate'],
          later.toIso8601String(),
        );
        await controller.toggle(edited);
        expect(scheduled(), isEmpty);
        await controller.toggle(
          container.read(tasksProvider).requireValue.single,
        );
        expect(scheduled(), hasLength(1));
        await controller.delete(edited);
        expect(scheduled(), isEmpty);
        await controller.restore(edited);
        expect(scheduled(), hasLength(1));
        await expectLater(
          controller.save(
            existing: edited,
            title: 'Past',
            note: '',
            category: TaskCategory.work,
            priority: TaskPriority.low,
            dueDate: DateTime.now().subtract(const Duration(minutes: 1)),
            hasDueTime: true,
            reminderEnabled: true,
          ),
          throwsA(isA<ReminderInPastException>()),
        );
        expect(
          container.read(tasksProvider).requireValue.single.dueDate,
          later,
        );
        await controller.save(
          existing: edited,
          title: 'Date only',
          note: '',
          category: TaskCategory.work,
          priority: TaskPriority.low,
          dueDate: later,
          hasDueTime: false,
        );
        expect(scheduled(), isEmpty);
        expect(
          container.read(tasksProvider).requireValue.single.reminderEnabled,
          isFalse,
        );
      } finally {
        container.dispose();
        await box.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
