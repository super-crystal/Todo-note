package cn.shiguang.shiguang_todo;

import java.text.SimpleDateFormat;
import java.util.Locale;
import java.util.Set;
import java.util.TimeZone;

public final class ReminderTimingTest {
    private static long at(String value, TimeZone zone) throws Exception {
        SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.ROOT);
        format.setTimeZone(zone);
        return format.parse(value).getTime();
    }

    private static void equal(long actual, long expected) {
        if (actual != expected) throw new AssertionError(actual + " != " + expected);
    }

    public static void main(String[] args) throws Exception {
        TimeZone shanghai = TimeZone.getTimeZone("Asia/Shanghai");
        long deadline = at("2027-01-01 00:30", shanghai);
        equal(ReminderTiming.triggerAt(deadline, 1440), at("2026-12-31 00:30", shanghai));
        equal(ReminderTiming.triggerAt(deadline, 1590), at("2026-12-30 22:00", shanghai));

        long anchor = at("2026-11-04 08:00", shanghai);
        equal(ReminderTiming.nextDaily(anchor, at("2026-11-04 07:00", shanghai), 0,
            Set.of("2026-11-04", "2026-11-05"), "2026-11-06", shanghai),
            at("2026-11-07 08:00", shanghai));
        equal(ReminderTiming.nextDaily(anchor, at("2026-11-04 09:00", shanghai), 0,
            Set.of(), "", shanghai), at("2026-11-05 08:00", shanghai));
        equal(ReminderTiming.nextDaily(at("2026-11-10 08:00", shanghai),
            at("2026-11-04 07:00", shanghai), 1440, Set.of(), "", shanghai),
            at("2026-11-10 08:00", shanghai));

        TimeZone newYork = TimeZone.getTimeZone("America/New_York");
        long beforeDst = at("2026-03-07 09:00", newYork);
        long next = ReminderTiming.nextDaily(beforeDst, at("2026-03-07 09:01", newYork),
            0, Set.of(), "", newYork);
        equal(next, at("2026-03-08 09:00", newYork));
        equal(next - beforeDst, 23 * 60 * 60_000L);
        System.out.println("3 native timing checks passed: advance offsets, daily completion/start, daylight saving.");
    }
}
