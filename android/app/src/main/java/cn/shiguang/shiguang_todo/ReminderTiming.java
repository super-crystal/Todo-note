package cn.shiguang.shiguang_todo;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Locale;
import java.util.Set;
import java.util.TimeZone;

/** Calendar arithmetic kept independent of Android services for clock-boundary checks. */
final class ReminderTiming {
    private ReminderTiming() {}

    static long triggerAt(long deadline, int leadMinutes) {
        return deadline - leadMinutes * 60_000L;
    }

    static long nextDaily(long anchorTime, long now, int leadMinutes,
            Set<String> completedDays, String lastDeliveredDay, TimeZone zone) {
        Calendar anchor = Calendar.getInstance(zone);
        anchor.setTimeInMillis(anchorTime);
        Calendar next = Calendar.getInstance(zone);
        next.setTimeInMillis(now + leadMinutes * 60_000L);
        next.set(Calendar.HOUR_OF_DAY, anchor.get(Calendar.HOUR_OF_DAY));
        next.set(Calendar.MINUTE, anchor.get(Calendar.MINUTE));
        next.set(Calendar.SECOND, 0);
        next.set(Calendar.MILLISECOND, 0);
        if (next.before(anchor)) next.setTimeInMillis(anchorTime);

        SimpleDateFormat day = new SimpleDateFormat("yyyy-MM-dd", Locale.ROOT);
        day.setTimeZone(zone);
        while (triggerAt(next.getTimeInMillis(), leadMinutes) <= now
                || completedDays.contains(day.format(next.getTime()))
                || lastDeliveredDay.equals(day.format(next.getTime()))) {
            // A calendar day keeps wall time through daylight-saving changes.
            next.add(Calendar.DAY_OF_MONTH, 1);
        }
        return next.getTimeInMillis();
    }
}
