import 'package:flutter/material.dart';

import '../../../core/strings.dart';
import '../state/reminder_service.dart';

class ReminderAccessHint extends StatelessWidget {
  const ReminderAccessHint({
    super.key,
    required this.access,
    required this.onFix,
  });
  final ReminderAccess access;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.notifications_off_outlined),
    title: Text(switch (access) {
      ReminderAccess.notifications => S.notificationAccess,
      ReminderAccess.exactAlarm => S.exactAccess,
      _ => S.reminderError,
    }, style: Theme.of(context).textTheme.bodySmall),
    trailing: TextButton(
      onPressed: onFix,
      child: Text(access == ReminderAccess.unavailable ? S.retry : S.settings),
    ),
  );
}
