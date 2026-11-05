import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/strings.dart';
import '../../../data/todo.dart';
import '../state/calendar_state.dart';

class TaskCalendar extends StatelessWidget {
  const TaskCalendar({
    super.key,
    required this.calendar,
    required this.now,
    required this.onSelected,
    required this.onChooseDate,
  });

  final CalendarMonth calendar;
  final DateTime now;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onChooseDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: S.previousMonth,
                  onPressed: () => onSelected(calendar.shiftMonth(-1)),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: onChooseDate,
                    child: Text(
                      S.yearMonth(calendar.month),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => onSelected(dayOnly(now)),
                  child: const Text(S.today),
                ),
                IconButton(
                  tooltip: S.nextMonth,
                  onPressed: () => onSelected(calendar.shiftMonth(1)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Row(
              children: S.weekdays
                  .map(
                    (weekday) => Expanded(
                      child: Center(
                        child: Text(
                          weekday,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpace.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                final dotWidth = math.max(
                  AppSize.calendarDot,
                  constraints.maxWidth / 7 - AppSpace.xs * 2,
                );
                const gap = AppSpace.xs / 2;
                final dotsPerRow = math.max(
                  1,
                  ((dotWidth + gap) / (AppSize.calendarDot + gap)).floor(),
                );
                final dotRows = math.max(
                  1,
                  (calendar.maxTaskCount + dotsPerRow - 1) ~/ dotsPerRow,
                );
                final dotHeight =
                    dotRows * AppSize.calendarDot + (dotRows - 1) * gap;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent: math.max(
                      AppSize.calendarDayHeight,
                      AppSize.calendarSelection + dotHeight + gap * 2,
                    ),
                  ),
                  itemCount: calendar.cellCount,
                  itemBuilder: (context, index) {
                    final date = calendar.dateAt(index);
                    if (date == null) return const SizedBox.shrink();
                    return _CalendarDay(
                      key: ValueKey(date),
                      date: date,
                      count: calendar.countOn(date),
                      dotWidth: dotWidth,
                      dotHeight: dotHeight,
                      selected: date == calendar.selectedDate,
                      today: date == dayOnly(now),
                      onTap: () => onSelected(date),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              S.calendarHint,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    super.key,
    required this.date,
    required this.count,
    required this.selected,
    required this.today,
    required this.onTap,
    required this.dotWidth,
    required this.dotHeight,
  });

  final DateTime date;
  final int count;
  final bool selected;
  final bool today;
  final VoidCallback onTap;
  final double dotWidth;
  final double dotHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected ? colors.onPrimary : colors.onSurface;
    return Semantics(
      label: S.calendarDay(date, count, today),
      selected: selected,
      button: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpace.sm),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: AppSize.calendarSelection,
                  height: AppSize.calendarSelection,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? colors.primary : Colors.transparent,
                    border: today && !selected
                        ? Border.all(color: colors.primary)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground,
                        fontWeight: selected || today ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xs / 2),
                SizedBox(
                  key: ValueKey('calendar-dots-${date.toIso8601String()}'),
                  width: dotWidth,
                  height: dotHeight,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpace.xs / 2,
                    runSpacing: AppSpace.xs / 2,
                    children: [
                      for (var index = 0; index < count; index++)
                        SizedBox.square(
                          key: ValueKey(
                            'calendar-dot-${date.toIso8601String()}-$index',
                          ),
                          dimension: AppSize.calendarDot,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
