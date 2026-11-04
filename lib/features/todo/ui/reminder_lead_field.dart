import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/strings.dart';
import '../../../data/reminder_lead.dart';

class ReminderLeadField extends StatelessWidget {
  const ReminderLeadField({
    super.key,
    required this.minutes,
    required this.onChanged,
  });
  final int minutes;
  final ValueChanged<int>? onChanged;

  Future<void> _custom(BuildContext context) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _CustomLeadDialog(initial: minutes),
    );
    if (value != null) onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: const InputDecoration(
      labelText: S.reminderWhen,
      prefixIcon: Icon(Icons.notifications_active_outlined),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        key: const ValueKey('reminder-lead'),
        value: minutes,
        isExpanded: true,
        items: [
          for (final value in {...ReminderLead.presets, minutes})
            DropdownMenuItem(value: value, child: Text(S.reminderLead(value))),
          const DropdownMenuItem(value: -1, child: Text(S.customLead)),
        ],
        onChanged: onChanged == null
            ? null
            : (value) async {
                if (value == -1) {
                  await _custom(context);
                } else if (value != null) {
                  onChanged!(value);
                }
              },
      ),
    ),
  );
}

class _CustomLeadDialog extends StatefulWidget {
  const _CustomLeadDialog({required this.initial});
  final int initial;
  @override
  State<_CustomLeadDialog> createState() => _CustomLeadDialogState();
}

class _CustomLeadDialogState extends State<_CustomLeadDialog> {
  late final TextEditingController _days;
  late final TextEditingController _hours;
  late final TextEditingController _minutes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _days = TextEditingController(text: '${widget.initial ~/ 1440}');
    _hours = TextEditingController(text: '${widget.initial % 1440 ~/ 60}');
    _minutes = TextEditingController(text: '${widget.initial % 60}');
  }

  @override
  void dispose() {
    _days.dispose();
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Widget _field(String label, TextEditingController controller, String key) =>
      Expanded(
        child: TextField(
          key: ValueKey(key),
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 3,
          decoration: InputDecoration(labelText: label, counterText: ''),
        ),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(S.customLead),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _field(S.days, _days, 'lead-days'),
              const SizedBox(width: AppSpace.sm),
              _field(S.hours, _hours, 'lead-hours'),
              const SizedBox(width: AppSpace.sm),
              _field(S.minutes, _minutes, 'lead-minutes'),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.md),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text(S.cancel),
      ),
      FilledButton(
        onPressed: () {
          final value = ReminderLead.fromParts(
            _days.text,
            _hours.text,
            _minutes.text,
          );
          if (value == null) {
            setState(() => _error = S.invalidLead);
          } else {
            Navigator.pop(context, value);
          }
        },
        child: const Text(S.confirm),
      ),
    ],
  );
}
