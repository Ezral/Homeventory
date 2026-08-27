package com.homeventory.homeventory

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.min

/**
 * Custom reminder notifications: photo on the left third, title/body on the
 * right. Alarms are persisted so they survive reboot without Flutter.
 */
object ReminderNotifications {
    const val CHANNEL_ID = "homeventory_reminders"
    const val ACTION_FIRE = "com.homeventory.homeventory.REMINDER_FIRE"
    private const val PREFS = "reminder_notifications"
    private const val KEY_ALERTS = "alerts"
    private const val EXTRA_ID = "id"
    private const val COLOR_MOSS = 0xFF1F5C4A.toInt()

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sync" -> {
                val raw = call.arguments as? List<*> ?: emptyList<Any>()
                val alerts = raw.mapNotNull { parseAlert(it) }
                sync(context, alerts)
                result.success(null)
            }
            "cancel" -> {
                val id = (call.arguments as? Number)?.toInt()
                if (id != null) cancel(context, id)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun sync(context: Context, alerts: List<Alert>) {
        cancelAll(context)
        save(context, alerts)
        for (alert in alerts) {
            if (alert.showNow) {
                show(context, alert)
            }
            if (alert.scheduleAtMillis != null) {
                arm(context, alert)
            }
        }
    }

    fun onAlarm(context: Context, id: Int) {
        val alert = load(context).firstOrNull { it.id == id } ?: return
        show(context, alert)
        when (alert.repeat) {
            "ONCE" -> {
                save(context, load(context).filterNot { it.id == id })
            }
            "MONTHLY" -> {
                val next = nextMonthly(alert.scheduleAtMillis ?: System.currentTimeMillis())
                upsert(context, alert.copy(showNow = false, scheduleAtMillis = next))
                arm(context, alert.copy(showNow = false, scheduleAtMillis = next))
            }
            "CUSTOM_DAYS" -> {
                val days = alert.intervalDays.coerceAtLeast(1)
                val from = alert.scheduleAtMillis ?: System.currentTimeMillis()
                val next = from + days * 24L * 60L * 60L * 1000L
                upsert(context, alert.copy(showNow = false, scheduleAtMillis = next))
                arm(context, alert.copy(showNow = false, scheduleAtMillis = next))
            }
            else -> {
                // DAILY / WEEKLY use setRepeating; nothing to re-arm.
            }
        }
    }

    fun restoreAfterBoot(context: Context) {
        for (alert in load(context)) {
            if (alert.scheduleAtMillis != null) {
                arm(context, alert)
            }
        }
    }

    fun show(context: Context, alert: Alert) {
        ensureChannel(context)
        val bitmap = alert.imagePath?.let { decodePhoto(it) }
        val collapsed = RemoteViews(context.packageName, R.layout.notification_reminder)
        val expanded = RemoteViews(context.packageName, R.layout.notification_reminder_big)
        bindCollapsed(collapsed, alert, bitmap)
        bindExpanded(expanded, alert, bitmap)

        val launch =
            PendingIntent.getActivity(
                context,
                alert.id,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                pendingFlags(),
            )

        val notification =
            NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_notify)
                .setContentTitle(alert.title)
                .setContentText(alert.body)
                .setColor(COLOR_MOSS)
                .setCustomContentView(collapsed)
                .setCustomBigContentView(expanded)
                .setStyle(NotificationCompat.DecoratedCustomViewStyle())
                .setContentIntent(launch)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .build()

        try {
            NotificationManagerCompat.from(context).notify(alert.id, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS not granted yet.
        }
    }

    private fun bindCollapsed(views: RemoteViews, alert: Alert, bitmap: Bitmap?) {
        views.setTextViewText(R.id.notif_title, alert.title)
        views.setTextViewText(R.id.notif_body, alert.body)
        if (bitmap != null) {
            views.setViewVisibility(R.id.notif_image, View.VISIBLE)
            views.setImageViewBitmap(R.id.notif_image, bitmap)
        } else {
            views.setViewVisibility(R.id.notif_image, View.GONE)
        }
    }

    private fun bindExpanded(views: RemoteViews, alert: Alert, bitmap: Bitmap?) {
        views.setTextViewText(R.id.notif_title, alert.title)
        views.setTextViewText(R.id.notif_body, alert.body)
        val target = alert.targetLabel?.trim().orEmpty()
        if (target.isNotEmpty() && !target.equals(alert.title, ignoreCase = true)) {
            views.setViewVisibility(R.id.notif_target, View.VISIBLE)
            views.setTextViewText(R.id.notif_target, target)
        } else {
            views.setViewVisibility(R.id.notif_target, View.GONE)
        }
        if (bitmap != null) {
            views.setViewVisibility(R.id.notif_image, View.VISIBLE)
            views.setImageViewBitmap(R.id.notif_image, bitmap)
        } else {
            views.setViewVisibility(R.id.notif_image, View.GONE)
        }
    }

    private fun arm(context: Context, alert: Alert) {
        val at = alert.scheduleAtMillis ?: return
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pending(context, alert.id)
        when (alert.repeat) {
            "DAILY" -> am.setRepeating(AlarmManager.RTC_WAKEUP, at, AlarmManager.INTERVAL_DAY, pi)
            "WEEKLY" ->
                am.setRepeating(
                    AlarmManager.RTC_WAKEUP,
                    at,
                    AlarmManager.INTERVAL_DAY * 7,
                    pi,
                )
            else ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                } else {
                    @Suppress("DEPRECATION")
                    am.set(AlarmManager.RTC_WAKEUP, at, pi)
                }
        }
    }

    private fun cancel(context: Context, id: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pending(context, id))
        NotificationManagerCompat.from(context).cancel(id)
        save(context, load(context).filterNot { it.id == id })
    }

    private fun cancelAll(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (alert in load(context)) {
            am.cancel(pending(context, alert.id))
            NotificationManagerCompat.from(context).cancel(alert.id)
        }
        save(context, emptyList())
    }

    private fun pending(context: Context, id: Int): PendingIntent {
        val intent =
            Intent(context, ReminderAlarmReceiver::class.java).apply {
                action = ACTION_FIRE
                putExtra(EXTRA_ID, id)
            }
        return PendingIntent.getBroadcast(context, id, intent, pendingFlags())
    }

    private fun pendingFlags(): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return flags
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java)
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                "Reminders",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Cleanup alarms and refill reminders"
            }
        nm.createNotificationChannel(channel)
    }

    private fun decodePhoto(path: String): Bitmap? {
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
            var sample = 1
            val maxPx = 512
            while (bounds.outWidth / sample > maxPx || bounds.outHeight / sample > maxPx) {
                sample *= 2
            }
            val raw =
                BitmapFactory.decodeFile(
                    path,
                    BitmapFactory.Options().apply { inSampleSize = sample },
                ) ?: return null
            roundCorners(raw, radiusPx = 16f)
        } catch (_: Exception) {
            null
        }
    }

    private fun roundCorners(src: Bitmap, radiusPx: Float): Bitmap {
        val out = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val rect = RectF(0f, 0f, src.width.toFloat(), src.height.toFloat())
        canvas.drawRoundRect(rect, radiusPx, radiusPx, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(src, 0f, 0f, paint)
        if (out != src) src.recycle()
        return out
    }

    private fun nextMonthly(fromMillis: Long): Long {
        val cal = java.util.Calendar.getInstance()
        cal.timeInMillis = fromMillis
        val day = cal.get(java.util.Calendar.DAY_OF_MONTH)
        cal.add(java.util.Calendar.MONTH, 1)
        val max = cal.getActualMaximum(java.util.Calendar.DAY_OF_MONTH)
        cal.set(java.util.Calendar.DAY_OF_MONTH, min(day, max))
        var next = cal.timeInMillis
        val now = System.currentTimeMillis()
        while (next <= now) {
            cal.add(java.util.Calendar.MONTH, 1)
            next = cal.timeInMillis
        }
        return next
    }

    private fun parseAlert(raw: Any?): Alert? {
        val map = raw as? Map<*, *> ?: return null
        val id = (map["id"] as? Number)?.toInt() ?: return null
        val title = map["title"] as? String ?: return null
        return Alert(
            id = id,
            title = title,
            body = map["body"] as? String ?: "",
            targetLabel = map["targetLabel"] as? String,
            imagePath = map["imagePath"] as? String,
            repeat = map["repeat"] as? String ?: "ONCE",
            intervalDays = (map["intervalDays"] as? Number)?.toInt() ?: 1,
            showNow = map["showNow"] as? Boolean ?: false,
            scheduleAtMillis = (map["scheduleAtMillis"] as? Number)?.toLong(),
        )
    }

    private fun save(context: Context, alerts: List<Alert>) {
        val array = JSONArray()
        for (alert in alerts) {
            array.put(alert.toJson())
        }
        context
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ALERTS, array.toString())
            .apply()
    }

    private fun load(context: Context): List<Alert> {
        val raw =
            context
                .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_ALERTS, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            buildList {
                for (i in 0 until array.length()) {
                    Alert.fromJson(array.getJSONObject(i))?.let { add(it) }
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun upsert(context: Context, alert: Alert) {
        val rest = load(context).filterNot { it.id == alert.id }
        save(context, rest + alert)
    }

    data class Alert(
        val id: Int,
        val title: String,
        val body: String,
        val targetLabel: String?,
        val imagePath: String?,
        val repeat: String,
        val intervalDays: Int,
        val showNow: Boolean,
        val scheduleAtMillis: Long?,
    ) {
        fun toJson(): JSONObject =
            JSONObject().apply {
                put("id", id)
                put("title", title)
                put("body", body)
                put("targetLabel", targetLabel ?: JSONObject.NULL)
                put("imagePath", imagePath ?: JSONObject.NULL)
                put("repeat", repeat)
                put("intervalDays", intervalDays)
                put("showNow", false)
                put("scheduleAtMillis", scheduleAtMillis ?: JSONObject.NULL)
            }

                companion object {
            fun fromJson(obj: JSONObject): Alert? {
                if (!obj.has("id") || !obj.has("title")) return null
                return Alert(
                    id = obj.getInt("id"),
                    title = obj.getString("title"),
                    body = obj.optString("body"),
                    targetLabel = optionalString(obj, "targetLabel"),
                    imagePath = optionalString(obj, "imagePath"),
                    repeat = obj.optString("repeat", "ONCE"),
                    intervalDays = obj.optInt("intervalDays", 1),
                    showNow = false,
                    scheduleAtMillis =
                        if (obj.isNull("scheduleAtMillis")) {
                            null
                        } else {
                            obj.optLong("scheduleAtMillis")
                        },
                )
            }

            private fun optionalString(obj: JSONObject, key: String): String? {
                if (!obj.has(key) || obj.isNull(key)) return null
                val value = obj.optString(key)
                return value.takeIf { it.isNotEmpty() && it != "null" }
            }
        }
    }
}

class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ReminderNotifications.ACTION_FIRE) return
        val id = intent.getIntExtra("id", -1)
        if (id >= 0) {
            ReminderNotifications.onAlarm(context, id)
        }
    }
}

class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            -> ReminderNotifications.restoreAfterBoot(context)
        }
    }
}
