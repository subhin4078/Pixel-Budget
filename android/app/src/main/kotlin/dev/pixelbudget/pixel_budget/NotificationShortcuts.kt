package dev.pixelbudget.pixel_budget

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.widget.RemoteViews

object NotificationShortcuts {
    private const val CHANNEL_ID = "quick_entry"
    private const val NOTIFICATION_ID = 1001
    private const val PREFERENCES = "notification_shortcuts"
    private const val ENABLED = "enabled"
    private const val ACTION_PREFIX = "dev.pixelbudget.app.quick."

    private fun manager(context: Context) =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun enabled(context: Context) =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).getBoolean(ENABLED, false)

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager(context).createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    context.getString(R.string.notification_shortcuts_channel),
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = context.getString(R.string.notification_shortcuts_description)
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                },
            )
        }
    }

    private fun allowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return false
        val notifications = manager(context)
        return notifications.areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                notifications.getNotificationChannel(CHANNEL_ID)?.importance !=
                NotificationManager.IMPORTANCE_NONE)
    }

    fun status(context: Context): Map<String, Boolean> {
        createChannel(context)
        return mapOf("enabled" to enabled(context), "allowed" to allowed(context))
    }

    fun setEnabled(context: Context, value: Boolean): Map<String, Boolean> {
        createChannel(context)
        if (!value || allowed(context)) {
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                .edit().putBoolean(ENABLED, value).apply()
        }
        refresh(context)
        return status(context)
    }

    @Suppress("DEPRECATION")
    @SuppressLint("MissingPermission")
    fun refresh(context: Context) {
        if (!enabled(context)) {
            manager(context).cancel(NOTIFICATION_ID)
            return
        }
        createChannel(context)
        if (!allowed(context)) {
            manager(context).cancel(NOTIFICATION_ID)
            return
        }
        val home = pendingIntent(context, "home", 0)
        val layout = RemoteViews(context.packageName, R.layout.notification_shortcuts).apply {
            setOnClickPendingIntent(R.id.shortcut_home, home)
            setOnClickPendingIntent(R.id.shortcut_income, pendingIntent(context, "income", 1))
            setOnClickPendingIntent(R.id.shortcut_expense, pendingIntent(context, "expense", 2))
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context).setPriority(Notification.PRIORITY_LOW)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_notification_budget)
            .setContentTitle("像素記帳")
            .setContentText(context.getString(R.string.notification_shortcuts_description))
            .setContentIntent(home)
            .setStyle(Notification.DecoratedCustomViewStyle())
            .setCustomContentView(layout)
            .setCustomBigContentView(layout)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setSound(null)
            .setVibrate(longArrayOf(0))
            .build()
        manager(context).notify(NOTIFICATION_ID, notification)
    }

    private fun pendingIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = ACTION_PREFIX + action
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun actionFrom(intent: Intent?): String? = when (intent?.action) {
        ACTION_PREFIX + "home" -> "home"
        ACTION_PREFIX + "income" -> "income"
        ACTION_PREFIX + "expense" -> "expense"
        else -> null
    }
}

class NotificationShortcutsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) NotificationShortcuts.refresh(context)
    }
}
