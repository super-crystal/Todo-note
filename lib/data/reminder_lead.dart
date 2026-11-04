abstract final class ReminderLead {
  static const maxMinutes = 365 * 24 * 60;
  static const presets = [0, 5, 15, 30, 60, 1440];

  static int? fromParts(String days, String hours, String minutes) {
    int? parse(String value) =>
        value.trim().isEmpty ? 0 : int.tryParse(value.trim());
    final d = parse(days);
    final h = parse(hours);
    final m = parse(minutes);
    if (d == null ||
        h == null ||
        m == null ||
        d < 0 ||
        h < 0 ||
        m < 0 ||
        h > 23 ||
        m > 59) {
      return null;
    }
    final total = d * 1440 + h * 60 + m;
    return total > 0 && total <= maxMinutes ? total : null;
  }
}
