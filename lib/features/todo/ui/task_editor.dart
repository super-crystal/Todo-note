import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/strings.dart';
import '../../../data/todo.dart';
import '../../../data/task_tags.dart';
import '../state/todo_state.dart';
import '../state/reminder_service.dart';
import 'reminder_access_hint.dart';
import 'task_editor_fields.dart';

Future<void> openTaskEditor(
  BuildContext context, {
  Todo? task,
  bool today = false,
  DateTime? initialDate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        TaskEditor(task: task, defaultToday: today, initialDate: initialDate),
  );
}

class TaskEditor extends ConsumerStatefulWidget {
  const TaskEditor({
    super.key,
    this.task,
    this.defaultToday = false,
    this.initialDate,
  });
  final Todo? task;
  final bool defaultToday;
  final DateTime? initialDate;

  @override
  ConsumerState<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<TaskEditor>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _note;
  late final TextEditingController _tags;
  late TaskCategory _category;
  late TaskPriority _priority;
  DateTime? _dueDate;
  bool _hasDueTime = false;
  bool _reminderEnabled = false;
  ReminderAccess _access = ReminderAccess.ready;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _title = TextEditingController(text: widget.task?.title);
    _note = TextEditingController(text: widget.task?.note);
    _tags = TextEditingController(text: widget.task?.tags.join('，'));
    _category = widget.task?.category ?? TaskCategory.inbox;
    _priority = widget.task?.priority ?? TaskPriority.low;
    _hasDueTime = widget.task?.hasDueTime ?? false;
    _reminderEnabled = widget.task?.reminderEnabled ?? false;
    _dueDate = widget.task != null
        ? widget.task!.dueDate
        : widget.initialDate ??
              (widget.defaultToday ? dayOnly(DateTime.now()) : null);
    if (_reminderEnabled) _refreshAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _title.dispose();
    _note.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = _dueDate ?? now;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year < 2000 ? current.year : 2000),
      lastDate: DateTime(current.year > 2100 ? current.year : 2100, 12, 31),
      helpText: S.dueDate,
    );
    if (selected != null && mounted) {
      setState(
        () => _dueDate = DateTime(
          selected.year,
          selected.month,
          selected.day,
          _hasDueTime ? current.hour : 0,
          _hasDueTime ? current.minute : 0,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _reminderEnabled) {
      _refreshAccess();
    }
  }

  Future<void> _refreshAccess() async {
    final access = await ref.read(reminderServiceProvider).access();
    if (mounted) setState(() => _access = access);
  }

  Future<void> _fixAccess() async {
    try {
      if (_access == ReminderAccess.unavailable) {
        await _refreshAccess();
      } else {
        await ref.read(reminderServiceProvider).openSettings(_access);
      }
    } catch (_) {
      if (mounted) setState(() => _access = ReminderAccess.unavailable);
    }
  }

  Future<void> _setReminder(bool value) async {
    setState(() => _reminderEnabled = value);
    if (value) {
      final access = await ref
          .read(reminderServiceProvider)
          .access(request: true);
      if (mounted) setState(() => _access = access);
    }
  }

  Future<void> _pickTime() async {
    if (_dueDate == null) return;
    final current = _dueDate!;
    final selected = await showTimePicker(
      context: context,
      initialTime: _hasDueTime
          ? TimeOfDay.fromDateTime(current)
          : TimeOfDay.now(),
      helpText: S.dueTime,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _dueDate = DateTime(
        current.year,
        current.month,
        current.day,
        selected.hour,
        selected.minute,
      );
      _hasDueTime = true;
    });
    await _setReminder(true);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(tasksProvider.notifier)
          .save(
            existing: widget.task,
            title: _title.text,
            note: _note.text,
            tags: TaskTags.parse(_tags.text),
            category: _category,
            priority: _priority,
            dueDate: _dueDate,
            hasDueTime: _hasDueTime,
            reminderEnabled: _reminderEnabled,
          );
      if (mounted) Navigator.pop(context);
    } on ReminderInPastException {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = S.reminderPast;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = S.writeError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.task == null ? S.newTask : S.editTask,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpace.xl),
                        TaskTextFields(
                          title: _title,
                          note: _note,
                          autofocus: widget.task == null,
                          enabled: !_saving,
                        ),
                        const SizedBox(height: AppSpace.sm),
                        TaskTagsField(controller: _tags, enabled: !_saving),
                        const SizedBox(height: AppSpace.sm),
                        TaskDateField(
                          date: _dueDate,
                          onPick: _saving ? null : _pickDate,
                          onClear: _saving
                              ? null
                              : () => setState(() {
                                  _dueDate = null;
                                  _hasDueTime = false;
                                  _reminderEnabled = false;
                                }),
                        ),
                        if (_dueDate != null)
                          TaskTimeField(
                            date: _dueDate!,
                            hasTime: _hasDueTime,
                            onPick: _saving ? null : _pickTime,
                            onClear: _saving
                                ? null
                                : () => setState(() {
                                    _dueDate = dayOnly(_dueDate!);
                                    _hasDueTime = false;
                                    _reminderEnabled = false;
                                  }),
                          ),
                        SwitchListTile(
                          key: const ValueKey('task-reminder'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text(S.remindAtDue),
                          subtitle: !_hasDueTime
                              ? const Text(S.reminderNeedsTime)
                              : null,
                          value: _reminderEnabled,
                          onChanged: _saving || !_hasDueTime
                              ? null
                              : _setReminder,
                        ),
                        if (_reminderEnabled && _access != ReminderAccess.ready)
                          ReminderAccessHint(
                            access: _access,
                            onFix: _fixAccess,
                          ),
                        const SizedBox(height: AppSpace.lg),
                        TaskOptionFields(
                          category: _category,
                          priority: _priority,
                          onCategory: _saving
                              ? null
                              : (value) => setState(() => _category = value),
                          onPriority: _saving
                              ? null
                              : (value) => setState(() => _priority = value),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpace.lg),
                            child: Text(
                              _error!,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        const SizedBox(height: AppSpace.lg),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl,
                  AppSpace.sm,
                  AppSpace.xl,
                  AppSpace.xl,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: AppSize.chipIcon,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Padding(
                      padding: EdgeInsets.all(AppSpace.lg),
                      child: Text(S.save),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
