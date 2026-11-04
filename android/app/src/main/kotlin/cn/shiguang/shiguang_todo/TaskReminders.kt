package cn.shiguang.shiguang_todo

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale

internal object TaskReminders {
    private const val STORE = "task_reminders_v1"
    private const val ENTRIES = "entries"
    private const val CHANNEL = "task_due_v1"
    private const val FIRE = "cn.shiguang.todo.TASK_DUE"

    private fun preferences(context: Context) = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
    private fun entries(context: Context) = JSONObject(preferences(context).getString(ENTRIES, "{}")!!)
    private fun persist(context: Context, entries: JSONObject) {
        check(preferences(context).edit().putString(ENTRIES, entries.toString()).commit())
    }
    private fun manager(context: Context) = context.getSystemService(NotificationManager::class.java)

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) manager(context).createNotificationChannel(
            NotificationChannel(CHANNEL, "任务到期提醒", NotificationManager.IMPORTANCE_HIGH)
                .apply { description = "任务截止时间到达时提醒" }
        )
    }

    fun status(context: Context): Map<String, Boolean> {
        ensureChannel(context)
        val notifications = manager(context)
        val channelEnabled = Build.VERSION.SDK_INT < 26 || notifications.getNotificationChannel(CHANNEL).importance != NotificationManager.IMPORTANCE_NONE
        val alarms = context.getSystemService(AlarmManager::class.java)
        return mapOf(
            "notifications" to (notifications.areNotificationsEnabled() && channelEnabled),
            "exact" to (Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms())
        )
    }

    private fun alarmIntent(context: Context, id: String) = PendingIntent.getBroadcast(
        context, 0,
        Intent(context, ReminderReceiver::class.java).setAction(FIRE)
            .setData(Uri.Builder().scheme("shiguang").authority("reminder").appendPath(id).build()),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    private fun cancel(context: Context, id: String) {
        context.getSystemService(AlarmManager::class.java).cancel(alarmIntent(context, id))
        manager(context).cancel(id, 0)
    }

    private fun dueTime(entry: JSONObject): Long = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.ROOT)
        .apply { isLenient = false }.parse(entry.getString("localDate").take(23))!!.time

    private fun schedule(context: Context, id: String, entry: JSONObject) {
        val due = dueTime(entry)
        if (entry.optBoolean("delivered")) return
        if (due <= System.currentTimeMillis()) {
            fire(context, id)
            return
        }
        val alarms = context.getSystemService(AlarmManager::class.java)
        val intent = alarmIntent(context, id)
        try {
            if (Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()) {
                alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, intent)
            } else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, intent)
        } catch (_: SecurityException) {
            // Permission may change between the check and the system call.
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, intent)
        }
    }

    @Synchronized
    fun sync(context: Context, tasks: List<Map<String, Any?>>) {
        ensureChannel(context)
        val old = entries(context)
        val next = JSONObject()
        for (task in tasks) {
            val id = task["id"] as String
            val entry = JSONObject(task)
            dueTime(entry)
            val previous = old.optJSONObject(id)
            if (previous?.optString("localDate") == entry.getString("localDate")) {
                entry.put("delivered", previous.optBoolean("delivered"))
            }
            next.put(id, entry)
        }
        // Persist desired state before changing system alarms so boot/launch can reconcile.
        persist(context, next)
        for (id in old.keys()) {
            if (!next.has(id) || old.getJSONObject(id).optString("localDate") != next.getJSONObject(id).optString("localDate")) cancel(context, id)
        }
        for (id in next.keys()) schedule(context, id, next.getJSONObject(id))
    }

    @Synchronized
    fun restore(context: Context) {
        ensureChannel(context)
        val saved = entries(context)
        for (id in saved.keys()) schedule(context, id, saved.getJSONObject(id))
    }

    @Synchronized
    fun fire(context: Context, id: String) {
        val saved = entries(context)
        val entry = saved.optJSONObject(id) ?: return
        if (entry.optBoolean("delivered")) return
        if (dueTime(entry) > System.currentTimeMillis()) {
            schedule(context, id, entry)
            return
        }
        if (status(context)["notifications"] != true) return
        val open = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java)
                .setData(Uri.Builder().scheme("shiguang").authority("task").appendPath(id).build())
                .putExtra("taskId", id)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        val note = entry.optString("note").ifBlank { "这项任务到期了" }
        val notification = builder.setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(entry.getString("title")).setContentText(note)
            .setStyle(Notification.BigTextStyle().bigText(note))
            .setCategory(Notification.CATEGORY_REMINDER).setContentIntent(open)
            .setAutoCancel(true).setShowWhen(true).setWhen(dueTime(entry))
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .apply {
                if (Build.VERSION.SDK_INT < 26) {
                    setPriority(Notification.PRIORITY_HIGH)
                    setDefaults(Notification.DEFAULT_ALL)
                }
            }.build()
        try {
            manager(context).notify(id, 0, notification)
            entry.put("delivered", true)
            persist(context, saved)
        } catch (_: SecurityException) {
            // A permission change must not crash a background receiver.
        }
    }

    fun handle(context: Context, intent: Intent) {
        if (intent.action == FIRE) intent.data?.lastPathSegment?.let { fire(context, it) }
        else restore(context)
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        TaskReminders.handle(context, intent)
    }
}
