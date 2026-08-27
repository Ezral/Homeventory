package com.homeventory.homeventory

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.os.Build
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.abs
import kotlin.math.min

/**
 * Samsung One UI–compatible reminder notifications.
 *
 * Uses NotificationCompat + DecoratedCustomViewStyle so the system keeps the
 * native header (app identity, timestamp, expand chevron). Custom RemoteViews
 * own only the content: scheduled time, item/room photo, title, details,
 * recurrence, plus real Snooze / Mark done actions.
 */
object ReminderNotifications {
    const val CHANNEL_ID = "homeventory_reminders"
    const val ACTION_FIRE = "com.homeventory.homeventory.REMINDER_FIRE"
    const val ACTION_SNOOZE = "com.homeventory.homeventory.REMINDER_SNOOZE"
    const val ACTION_SNOOZE_FIRE = "com.homeventory.homeventory.REMINDER_SNOOZE_FIRE"
    const val ACTION_COMPLETE = "com.homeventory.homeventory.REMINDER_COMPLETE"
    const val ACTION_OPEN = "com.homeventory.homeventory.REMINDER_OPEN"
    const val EXTRA_ID = "id"
    const val EXTRA_ACTION = "reminder_action"
    const val EXTRA_REMINDER_ID = "reminder_id"
    const val EXTRA_ROUTE = "route"
    const val METHOD_ON_ACTION = "onReminderAction"

    /** Established snooze duration when the product has not defined another. */
    const val SNOOZE_DURATION_MS = 15 * 60 * 1000L

    private const val PREFS = "reminder_notifications"
    private const val KEY_ALERTS = "alerts"
    private const val KEY_PENDING_ACTION = "pending_action"
    private const val COLOR_NAVY = 0xFF12304A.toInt()
    private const val COLOR_CORAL = 0xFFFF6B4A.toInt()
    private const val DEBUG_PREVIEW_ID = 0x7E107001
    private const val SALT_CONTENT = 0x11
    private const val SALT_SNOOZE = 0x22
    private const val SALT_COMPLETE = 0x33
    private const val SALT_SNOOZE_ALARM = 0x44

    @Volatile private var actionChannel: MethodChannel? = null

    fun attachChannel(channel: MethodChannel?) {
        actionChannel = channel
    }

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
            "previewSample" -> {
                if (!isDebuggable(context)) {
                    result.error("debug_only", "Preview is debug-only", null)
                    return
                }
                previewSample(context)
                result.success(null)
            }
            "peekPendingAction" -> result.success(peekPendingAction(context))
            "consumePendingAction" -> {
                clearPendingAction(context)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun onLaunchIntent(context: Context, intent: Intent?) {
        if (intent == null) return
        val action = intent.getStringExtra(EXTRA_ACTION) ?: return
        val reminderId = intent.getStringExtra(EXTRA_REMINDER_ID) ?: return
        val id = intent.getIntExtra(EXTRA_ID, -1)
        if (action == "complete" && id >= 0) {
            NotificationManagerCompat.from(context).cancel(id)
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(pending(context, id, ACTION_SNOOZE_FIRE, SALT_SNOOZE_ALARM))
        }
        stashPendingAction(
            context,
            mapOf(
                "type" to action,
                "reminderId" to reminderId,
                "route" to (intent.getStringExtra(EXTRA_ROUTE) ?: ""),
            ),
        )
        try {
            actionChannel?.invokeMethod(METHOD_ON_ACTION, null)
        } catch (_: Exception) {
            // Flutter handler may not be attached yet; Dart peeks on startup.
        }
    }

    fun sync(context: Context, alerts: List<Alert>) {
        val previous = load(context)
        val newIds = alerts.map { it.id }.toSet()
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (old in previous) {
            if (old.id !in newIds) {
                am.cancel(firePending(context, old.id))
                am.cancel(pending(context, old.id, ACTION_SNOOZE_FIRE, SALT_SNOOZE_ALARM))
                NotificationManagerCompat.from(context).cancel(old.id)
            } else {
                am.cancel(firePending(context, old.id))
                am.cancel(pending(context, old.id, ACTION_SNOOZE_FIRE, SALT_SNOOZE_ALARM))
            }
        }
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
                upsert(context, alert.copy(showNow = false, scheduleAtMillis = null))
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

    fun onSnoozeFire(context: Context, id: Int) {
        val alert =
            load(context).firstOrNull { it.id == id }
                ?: if (id == DEBUG_PREVIEW_ID) sampleAlert() else return
        upsert(context, alert.copy(snoozeAtMillis = null))
        show(context, alert.copy(snoozeAtMillis = null))
    }

    fun snooze(context: Context, id: Int) {
        NotificationManagerCompat.from(context).cancel(id)
        val alert =
            load(context).firstOrNull { it.id == id }
                ?: if (id == DEBUG_PREVIEW_ID) sampleAlert() else return
        val at = System.currentTimeMillis() + SNOOZE_DURATION_MS
        upsert(context, alert.copy(snoozeAtMillis = at, showNow = false))
        armSnooze(context, alert, at)
    }

    fun markDone(context: Context, id: Int) {
        val alert =
            load(context).firstOrNull { it.id == id }
                ?: if (id == DEBUG_PREVIEW_ID) sampleAlert() else return
        NotificationManagerCompat.from(context).cancel(id)
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pending(context, id, ACTION_SNOOZE_FIRE, SALT_SNOOZE_ALARM))
        stashPendingAction(
            context,
            mapOf(
                "type" to "complete",
                "reminderId" to alert.reminderId,
                "route" to (alert.route ?: ""),
            ),
        )
        startMainActivity(context, "complete", alert)
        try {
            actionChannel?.invokeMethod(METHOD_ON_ACTION, null)
        } catch (_: Exception) {
        }
    }

    fun restoreAfterBoot(context: Context) {
        for (alert in load(context)) {
            if (alert.scheduleAtMillis != null) {
                arm(context, alert)
            }
            val snoozeAt = alert.snoozeAtMillis
            if (snoozeAt != null && snoozeAt > System.currentTimeMillis()) {
                armSnooze(context, alert, snoozeAt)
            }
        }
    }

    fun show(context: Context, alert: Alert) {
        ensureChannel(context)
        val density = context.resources.displayMetrics.density
        val photos = loadPhotos(context, alert.imagePath, density)
        val collapsed = RemoteViews(context.packageName, R.layout.notification_reminder)
        val expanded = RemoteViews(context.packageName, R.layout.notification_reminder_big)
        bindCollapsed(context, collapsed, alert, photos.thumb)
        bindExpanded(context, expanded, alert, photos.hero)

        val contentIntent =
            PendingIntent.getActivity(
                context,
                requestCode(alert.id, SALT_CONTENT),
                mainActivityIntent(context, "open", alert),
                pendingFlags(),
            )

        val builder =
            NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_notify)
                .setContentTitle(alert.title)
                .setContentText(alert.details.ifBlank { alert.body })
                .setColor(COLOR_NAVY)
                .setCustomContentView(collapsed)
                .setCustomBigContentView(expanded)
                .setCustomHeadsUpContentView(collapsed)
                .setStyle(NotificationCompat.DecoratedCustomViewStyle())
                .setContentIntent(contentIntent)
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)

        if (alert.canSnooze) {
            builder.addAction(
                NotificationCompat.Action.Builder(
                    R.drawable.ic_notif_snooze,
                    context.getString(R.string.notif_action_snooze),
                    PendingIntent.getBroadcast(
                        context,
                        requestCode(alert.id, SALT_SNOOZE),
                        Intent(context, ReminderActionReceiver::class.java).apply {
                            action = ACTION_SNOOZE
                            putExtra(EXTRA_ID, alert.id)
                        },
                        pendingFlags(),
                    ),
                ).build(),
            )
        }
        if (alert.canMarkDone) {
            // Activity PendingIntent — Android 12+ blocks starting an activity
            // from a notification BroadcastReceiver (notification trampoline).
            builder.addAction(
                NotificationCompat.Action.Builder(
                    R.drawable.ic_notif_done,
                    context.getString(R.string.notif_action_mark_done),
                    PendingIntent.getActivity(
                        context,
                        requestCode(alert.id, SALT_COMPLETE),
                        mainActivityIntent(context, "complete", alert),
                        pendingFlags(),
                    ),
                ).build(),
            )
        }

        try {
            NotificationManagerCompat.from(context).notify(alert.id, builder.build())
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS not granted yet.
        }
    }

    private fun previewSample(context: Context) {
        val alert = sampleAlert()
        upsert(context, alert)
        show(context, alert)
    }

    private fun sampleAlert(): Alert {
        val now = System.currentTimeMillis()
        return Alert(
            id = DEBUG_PREVIEW_ID,
            reminderId = "debug-preview-ac-filter",
            title = "Clean the bedroom AC filter",
            body = "Wash the filter and let it dry before putting it back.",
            details = "Bedroom · Air conditioner",
            targetLabel = "Air conditioner",
            itemOrRoomName = "Air conditioner",
            itemOrRoomId = "debug-ac",
            imagePath = null,
            imageContentDescription = "Bedroom air conditioner",
            recurrence = "Recurring every 3 months",
            route = "/",
            repeat = "CUSTOM_DAYS",
            intervalDays = 90,
            showNow = true,
            scheduleAtMillis = now,
            displayAtMillis = now,
            canSnooze = true,
            canMarkDone = true,
            snoozeAtMillis = null,
        )
    }

    private fun bindCollapsed(
        context: Context,
        views: RemoteViews,
        alert: Alert,
        bitmap: Bitmap?,
    ) {
        val whenText = formatScheduledWhen(context, displayMillis(alert))
        views.setTextViewText(R.id.notif_when, whenText)
        views.setTextColor(R.id.notif_when, scheduledWhenColor(context))
        views.setTextViewText(R.id.notif_title, alert.title)
        views.setTextViewText(R.id.notif_details, alert.details.ifBlank { alert.body })
        bindImage(views, bitmap, photoDescription(context, alert))
    }

    private fun bindExpanded(
        context: Context,
        views: RemoteViews,
        alert: Alert,
        bitmap: Bitmap?,
    ) {
        val whenText = formatScheduledWhen(context, displayMillis(alert))
        views.setTextViewText(R.id.notif_when, whenText)
        views.setTextColor(R.id.notif_when, scheduledWhenColor(context))
        views.setTextViewText(R.id.notif_title, alert.title)
        views.setTextViewText(R.id.notif_details, alert.details.ifBlank { alert.body })
        val recurrence = alert.recurrence?.trim().orEmpty()
        if (recurrence.isNotEmpty()) {
            views.setViewVisibility(R.id.notif_recurrence, View.VISIBLE)
            views.setTextViewText(R.id.notif_recurrence, recurrence)
            views.setTextColor(R.id.notif_recurrence, scheduledWhenColor(context))
        } else {
            views.setViewVisibility(R.id.notif_recurrence, View.GONE)
        }
        bindImage(views, bitmap, photoDescription(context, alert))
    }

    private fun bindImage(views: RemoteViews, bitmap: Bitmap?, description: String) {
        views.setContentDescription(R.id.notif_image, description)
        if (bitmap != null) {
            views.setImageViewBitmap(R.id.notif_image, bitmap)
        } else {
            views.setImageViewResource(R.id.notif_image, R.drawable.notification_photo_placeholder)
        }
    }

    private fun photoDescription(context: Context, alert: Alert): String {
        return alert.imageContentDescription?.trim()?.takeIf { it.isNotEmpty() }
            ?: alert.itemOrRoomName?.trim()?.takeIf { it.isNotEmpty() }
            ?: context.getString(R.string.notif_photo_fallback)
    }

    private fun displayMillis(alert: Alert): Long {
        return alert.displayAtMillis ?: alert.scheduleAtMillis ?: System.currentTimeMillis()
    }

    private fun scheduledWhenColor(context: Context): Int {
        val night =
            context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
                Configuration.UI_MODE_NIGHT_YES
        // Navy on light shade, coral on dark — both brand accents with readable contrast.
        return if (night) COLOR_CORAL else COLOR_NAVY
    }

    private fun formatScheduledWhen(context: Context, millis: Long): String {
        val locale = Locale.getDefault()
        val tz = TimeZone.getDefault()
        val date = Date(millis)
        val datePattern = DateFormat.getBestDateTimePattern(locale, "EEE, d MMM")
        val dateFormat = SimpleDateFormat(datePattern, locale).apply { timeZone = tz }
        val timeSkeleton = if (DateFormat.is24HourFormat(context)) "HH:mm" else "h:mm a"
        val timePattern = DateFormat.getBestDateTimePattern(locale, timeSkeleton)
        val timeFormat = SimpleDateFormat(timePattern, locale).apply { timeZone = tz }
        return "${dateFormat.format(date)} • ${timeFormat.format(date)}"
    }

    private fun arm(context: Context, alert: Alert) {
        val at = alert.scheduleAtMillis ?: return
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = firePending(context, alert.id)
        when (alert.repeat) {
            "DAILY" -> am.setRepeating(AlarmManager.RTC_WAKEUP, at, AlarmManager.INTERVAL_DAY, pi)
            "WEEKLY" ->
                am.setRepeating(
                    AlarmManager.RTC_WAKEUP,
                    at,
                    AlarmManager.INTERVAL_DAY * 7,
                    pi,
                )
            else -> setInexactWakeup(am, at, pi)
        }
    }

    private fun armSnooze(context: Context, alert: Alert, at: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        setInexactWakeup(
            am,
            at,
            pending(context, alert.id, ACTION_SNOOZE_FIRE, SALT_SNOOZE_ALARM),
        )
    }

    private fun setInexactWakeup(am: AlarmManager, at: Long, pi: PendingIntent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        } else {
            @Suppress("DEPRECATION")
            am.set(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }

    private fun cancel(context: Context, id: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(firePending(context, id))
        am.cancel(pending(context, id, ACTION_SNOOZE_FIRE, SALT_SNOOZE_ALARM))
        NotificationManagerCompat.from(context).cancel(id)
        save(context, load(context).filterNot { it.id == id })
    }

    private fun firePending(context: Context, id: Int): PendingIntent {
        val intent =
            Intent(context, ReminderAlarmReceiver::class.java).apply {
                action = ACTION_FIRE
                putExtra(EXTRA_ID, id)
            }
        return PendingIntent.getBroadcast(context, id, intent, pendingFlags())
    }

    private fun pending(context: Context, id: Int, action: String, salt: Int): PendingIntent {
        val intent =
            Intent(context, ReminderAlarmReceiver::class.java).apply {
                this.action = action
                putExtra(EXTRA_ID, id)
            }
        return PendingIntent.getBroadcast(context, requestCode(id, salt), intent, pendingFlags())
    }

    private fun requestCode(id: Int, salt: Int): Int = (id xor (salt shl 16)) and 0x7fffffff

    private fun pendingFlags(): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return flags
    }

    private fun mainActivityIntent(context: Context, action: String, alert: Alert): Intent {
        return Intent(context, MainActivity::class.java).apply {
            this.action = ACTION_OPEN
            flags =
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_ACTION, action)
            putExtra(EXTRA_REMINDER_ID, alert.reminderId)
            putExtra(EXTRA_ROUTE, alert.route ?: "")
            putExtra(EXTRA_ID, alert.id)
        }
    }

    private fun startMainActivity(context: Context, action: String, alert: Alert) {
        context.startActivity(mainActivityIntent(context, action, alert))
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java)
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.notif_channel_name),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = context.getString(R.string.notif_channel_description)
            }
        nm.createNotificationChannel(channel)
    }

    private data class Photos(val thumb: Bitmap?, val hero: Bitmap?)

    private fun loadPhotos(context: Context, path: String?, density: Float): Photos {
        val src = path?.let { decodeSampled(it, maxPx = 720) }
        if (src == null) {
            return Photos(
                thumb = placeholderBitmap(context, (48 * density).toInt().coerceAtLeast(48), 1f),
                hero = placeholderBitmap(context, (320 * density).toInt().coerceAtLeast(320), 16f / 9f),
            )
        }
        val thumbSize = (48 * density).toInt().coerceAtLeast(48)
        val heroWidth = (320 * density).toInt().coerceAtMost(720).coerceAtLeast(320)
        val heroHeight = (heroWidth * 9f / 16f).toInt().coerceAtLeast(1)
        val thumb =
            roundCorners(
                scaleTo(centerCrop(src, 1f), thumbSize, thumbSize),
                radiusPx = 8f * density,
            )
        val hero =
            roundCorners(
                scaleTo(centerCrop(src, 16f / 9f), heroWidth, heroHeight),
                radiusPx = 12f * density,
            )
        if (!src.isRecycled && src != thumb && src != hero) {
            src.recycle()
        }
        return Photos(thumb, hero)
    }

    private fun decodeSampled(path: String, maxPx: Int): Bitmap? {
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
            var sample = 1
            while (bounds.outWidth / sample > maxPx || bounds.outHeight / sample > maxPx) {
                sample *= 2
            }
            BitmapFactory.decodeFile(
                path,
                BitmapFactory.Options().apply { inSampleSize = sample },
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun centerCrop(src: Bitmap, aspect: Float): Bitmap {
        val srcAspect = src.width.toFloat() / src.height.toFloat()
        if (abs(srcAspect - aspect) < 0.02f) return src
        return if (srcAspect > aspect) {
            val newW = (src.height * aspect).toInt().coerceAtLeast(1)
            val x = ((src.width - newW) / 2).coerceAtLeast(0)
            Bitmap.createBitmap(src, x, 0, newW.coerceAtMost(src.width - x), src.height)
        } else {
            val newH = (src.width / aspect).toInt().coerceAtLeast(1)
            val y = ((src.height - newH) / 2).coerceAtLeast(0)
            Bitmap.createBitmap(src, 0, y, src.width, newH.coerceAtMost(src.height - y))
        }
    }

    private fun scaleTo(src: Bitmap, width: Int, height: Int): Bitmap {
        if (src.width == width && src.height == height) return src
        return Bitmap.createScaledBitmap(src, width.coerceAtLeast(1), height.coerceAtLeast(1), true)
    }

    private fun roundCorners(src: Bitmap, radiusPx: Float): Bitmap {
        val out = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val rect = RectF(0f, 0f, src.width.toFloat(), src.height.toFloat())
        canvas.drawRoundRect(rect, radiusPx, radiusPx, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(src, 0f, 0f, paint)
        if (out != src && src.isRecycled.not() && src.width != out.width) {
            // cropped intermediates can be recycled by callers
        }
        return out
    }

    private fun placeholderBitmap(context: Context, widthPx: Int, aspect: Float): Bitmap {
        val w = widthPx.coerceAtLeast(48)
        val h = (w / aspect).toInt().coerceAtLeast(48)
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = COLOR_NAVY
        val radius = 12f * context.resources.displayMetrics.density
        canvas.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), radius, radius, paint)
        val icon = ContextCompat.getDrawable(context, R.drawable.ic_stat_notify)
        if (icon != null) {
            val size = min(w, h) / 3
            val left = (w - size) / 2
            val top = (h - size) / 2
            icon.setBounds(left, top, left + size, top + size)
            icon.setTint(0xFFFFFFFF.toInt())
            icon.draw(canvas)
        }
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
            reminderId = map["reminderId"] as? String ?: "",
            title = title,
            body = map["body"] as? String ?: "",
            details = map["details"] as? String ?: "",
            targetLabel = map["targetLabel"] as? String,
            itemOrRoomName = map["itemOrRoomName"] as? String,
            itemOrRoomId = map["itemOrRoomId"] as? String,
            imagePath = map["imagePath"] as? String,
            imageContentDescription = map["imageContentDescription"] as? String,
            recurrence = map["recurrence"] as? String,
            route = map["route"] as? String,
            repeat = map["repeat"] as? String ?: "ONCE",
            intervalDays = (map["intervalDays"] as? Number)?.toInt() ?: 1,
            showNow = map["showNow"] as? Boolean ?: false,
            scheduleAtMillis = (map["scheduleAtMillis"] as? Number)?.toLong(),
            displayAtMillis = (map["displayAtMillis"] as? Number)?.toLong(),
            canSnooze = map["canSnooze"] as? Boolean ?: true,
            canMarkDone = map["canMarkDone"] as? Boolean ?: true,
            snoozeAtMillis = (map["snoozeAtMillis"] as? Number)?.toLong(),
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

    private fun stashPendingAction(context: Context, action: Map<String, String>) {
        val json =
            JSONObject().apply {
                put("type", action["type"] ?: "")
                put("reminderId", action["reminderId"] ?: "")
                put("route", action["route"] ?: "")
            }
        context
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PENDING_ACTION, json.toString())
            .apply()
    }

    private fun peekPendingAction(context: Context): Map<String, String>? {
        val raw =
            context
                .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_PENDING_ACTION, null) ?: return null
        return try {
            val obj = JSONObject(raw)
            val type = obj.optString("type")
            if (type.isEmpty()) return null
            mapOf(
                "type" to type,
                "reminderId" to obj.optString("reminderId"),
                "route" to obj.optString("route"),
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun clearPendingAction(context: Context) {
        context
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_PENDING_ACTION)
            .apply()
    }

    private fun isDebuggable(context: Context): Boolean {
        return context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
    }

    data class Alert(
        val id: Int,
        val reminderId: String,
        val title: String,
        val body: String,
        val details: String,
        val targetLabel: String?,
        val itemOrRoomName: String?,
        val itemOrRoomId: String?,
        val imagePath: String?,
        val imageContentDescription: String?,
        val recurrence: String?,
        val route: String?,
        val repeat: String,
        val intervalDays: Int,
        val showNow: Boolean,
        val scheduleAtMillis: Long?,
        val displayAtMillis: Long?,
        val canSnooze: Boolean,
        val canMarkDone: Boolean,
        val snoozeAtMillis: Long?,
    ) {
        fun toJson(): JSONObject =
            JSONObject().apply {
                put("id", id)
                put("reminderId", reminderId)
                put("title", title)
                put("body", body)
                put("details", details)
                put("targetLabel", targetLabel ?: JSONObject.NULL)
                put("itemOrRoomName", itemOrRoomName ?: JSONObject.NULL)
                put("itemOrRoomId", itemOrRoomId ?: JSONObject.NULL)
                put("imagePath", imagePath ?: JSONObject.NULL)
                put("imageContentDescription", imageContentDescription ?: JSONObject.NULL)
                put("recurrence", recurrence ?: JSONObject.NULL)
                put("route", route ?: JSONObject.NULL)
                put("repeat", repeat)
                put("intervalDays", intervalDays)
                put("showNow", false)
                put("scheduleAtMillis", scheduleAtMillis ?: JSONObject.NULL)
                put("displayAtMillis", displayAtMillis ?: JSONObject.NULL)
                put("canSnooze", canSnooze)
                put("canMarkDone", canMarkDone)
                put("snoozeAtMillis", snoozeAtMillis ?: JSONObject.NULL)
            }

        companion object {
            fun fromJson(obj: JSONObject): Alert? {
                if (!obj.has("id") || !obj.has("title")) return null
                return Alert(
                    id = obj.getInt("id"),
                    reminderId = obj.optString("reminderId"),
                    title = obj.getString("title"),
                    body = obj.optString("body"),
                    details = obj.optString("details"),
                    targetLabel = optionalString(obj, "targetLabel"),
                    itemOrRoomName = optionalString(obj, "itemOrRoomName"),
                    itemOrRoomId = optionalString(obj, "itemOrRoomId"),
                    imagePath = optionalString(obj, "imagePath"),
                    imageContentDescription = optionalString(obj, "imageContentDescription"),
                    recurrence = optionalString(obj, "recurrence"),
                    route = optionalString(obj, "route"),
                    repeat = obj.optString("repeat", "ONCE"),
                    intervalDays = obj.optInt("intervalDays", 1),
                    showNow = false,
                    scheduleAtMillis =
                        if (obj.isNull("scheduleAtMillis")) null else obj.optLong("scheduleAtMillis"),
                    displayAtMillis =
                        if (obj.isNull("displayAtMillis")) null else obj.optLong("displayAtMillis"),
                    canSnooze = obj.optBoolean("canSnooze", true),
                    canMarkDone = obj.optBoolean("canMarkDone", true),
                    snoozeAtMillis =
                        if (obj.isNull("snoozeAtMillis")) null else obj.optLong("snoozeAtMillis"),
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
        val id = intent.getIntExtra(ReminderNotifications.EXTRA_ID, -1)
        if (id < 0) return
        when (intent.action) {
            ReminderNotifications.ACTION_FIRE -> ReminderNotifications.onAlarm(context, id)
            ReminderNotifications.ACTION_SNOOZE_FIRE ->
                ReminderNotifications.onSnoozeFire(context, id)
        }
    }
}

class ReminderActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(ReminderNotifications.EXTRA_ID, -1)
        if (id < 0) return
        when (intent.action) {
            ReminderNotifications.ACTION_SNOOZE -> ReminderNotifications.snooze(context, id)
            ReminderNotifications.ACTION_COMPLETE -> ReminderNotifications.markDone(context, id)
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
