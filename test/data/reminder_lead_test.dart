import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_todo/data/reminder_lead.dart';

void main() {
  test(
    'custom days, hours and minutes enforce total and component boundaries',
    () {
      expect(ReminderLead.fromParts('1', '2', '30'), 1590);
      expect(ReminderLead.fromParts('', '', '1'), 1);
      expect(ReminderLead.fromParts('365', '', ''), ReminderLead.maxMinutes);
      for (final values in [
        ['0', '0', '0'],
        ['-1', '0', '0'],
        ['1', '24', '0'],
        ['0', '0', '60'],
        ['365', '0', '1'],
        ['abc', '0', '0'],
      ]) {
        expect(ReminderLead.fromParts(values[0], values[1], values[2]), isNull);
      }
    },
  );
}
