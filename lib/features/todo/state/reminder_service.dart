import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/todo.dart';

enum ReminderAccess { ready, notifications, exactAlarm, unavailable }

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(),
);

class ReminderService {
  static const channel = MethodChannel('cn.shiguang.todo/reminders');

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<ReminderAccess> access({bool request = false}) async {
    if (!_supported) return ReminderAccess.unavailable;
    try {
      final value = await channel.invokeMapMethod<String, bool>(
        request ? 'requestNotifications' : 'status',
      );
      if (value?['notifications'] != true) return ReminderAccess.notifications;
      if (value?['exact'] != true) return ReminderAccess.exactAlarm;
      return ReminderAccess.ready;
    } on PlatformException {
      return ReminderAccess.unavailable;
    } on MissingPluginException {
      return ReminderAccess.unavailable;
    }
  }

  Future<void> openSettings(ReminderAccess access) =>
      channel.invokeMethod<void>(
        access == ReminderAccess.exactAlarm
            ? 'exactSettings'
            : 'notificationSettings',
      );

  Future<String?> takeTask() async {
    if (!_supported) return null;
    try {
      return await channel.invokeMethod<String>('takeTask');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> sync(List<Todo> tasks) async {
    if (!_supported) return;
    await channel.invokeMethod<void>('sync', [
      for (final task in tasks)
        if (task.reminderEnabled &&
            task.hasDueTime &&
            task.dueDate != null &&
            (task.repeatDaily || !task.isCompleted))
          {
            'id': task.id,
            'title': task.title,
            'note': task.note,
            // Wall time follows the phone's time zone after a zone change.
            'localDate': task.dueDate!.toLocal().toIso8601String(),
            'leadMinutes': task.reminderLeadMinutes,
            'daily': task.repeatDaily,
            'completedDays': task.completedDays,
          },
    ]);
  }
}

final reminderStatusProvider = NotifierProvider<ReminderStatus, ReminderAccess>(
  ReminderStatus.new,
);

class ReminderStatus extends Notifier<ReminderAccess> {
  Future<void> _pending = Future.value();

  @override
  ReminderAccess build() => ReminderAccess.ready;

  // Serialize snapshots so a slower earlier write cannot restore a removed alarm.
  Future<void> reconcile(List<Todo> tasks) {
    final snapshot = List<Todo>.of(tasks);
    _pending = _pending.then((_) async {
      final service = ref.read(reminderServiceProvider);
      try {
        await service.sync(snapshot);
        state =
            snapshot.any(
              (task) =>
                  task.reminderEnabled &&
                  (task.repeatDaily || !task.isCompleted),
            )
            ? await service.access()
            : ReminderAccess.ready;
      } on PlatformException {
        state = ReminderAccess.unavailable;
      } on MissingPluginException {
        state = ReminderAccess.unavailable;
      }
    });
    return _pending;
  }
}
