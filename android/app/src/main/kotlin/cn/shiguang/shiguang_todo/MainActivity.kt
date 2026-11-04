package cn.shiguang.shiguang_todo

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private var reminderChannel: MethodChannel? = null
    private var pendingTaskId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingTaskId = intent.getStringExtra("taskId")
        reminderChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.shiguang.todo/reminders")
        reminderChannel!!.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "sync" -> {
                        @Suppress("UNCHECKED_CAST")
                        val tasks = call.arguments as List<Map<String, Any?>>
                        TaskReminders.sync(this, tasks)
                        result.success(null)
                    }
                    "status" -> result.success(TaskReminders.status(this))
                    "requestNotifications" -> {
                        TaskReminders.ensureChannel(this)
                        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            if (permissionResult != null) result.error("busy", "Permission request in progress", null)
                            else {
                                permissionResult = result
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 120)
                            }
                        } else result.success(TaskReminders.status(this))
                    }
                    "exactSettings" -> {
                        if (Build.VERSION.SDK_INT >= 31) startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    "notificationSettings" -> {
                        val settings = if (Build.VERSION.SDK_INT >= 26) {
                            if (getSystemService(android.app.NotificationManager::class.java).areNotificationsEnabled())
                                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName).putExtra(Settings.EXTRA_CHANNEL_ID, "task_due_v1")
                            else Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        } else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                        startActivity(settings)
                        result.success(null)
                    }
                    "takeTask" -> {
                        result.success(pendingTaskId)
                        pendingTaskId = null
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("reminders", error.message, null)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingTaskId = intent.getStringExtra("taskId")
        reminderChannel?.invokeMethod("taskOpened", null)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 120) {
            permissionResult?.success(TaskReminders.status(this))
            permissionResult = null
        }
    }
}
