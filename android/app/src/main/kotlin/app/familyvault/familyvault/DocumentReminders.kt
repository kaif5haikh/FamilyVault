package app.familyvault.familyvault

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

internal object DocumentReminders {
    private const val CHANNEL = "document_expiry"
    private const val PREFERENCES = "familyvault_document_reminders"
    private const val TIMES = "times"
    private const val LANGUAGE = "language"
    private const val ALARM = "app.familyvault.familyvault.DOCUMENT_REMINDER"
    private const val TIME = "scheduled_time"
    private const val LIMIT = 32
    private const val NOTIFICATION_ID = 764

    private fun manager(context: Context) = context.getSystemService(NotificationManager::class.java)
    private fun preferences(context: Context) = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
    private fun stored(context: Context) = preferences(context).getString(TIMES, "").orEmpty()
        .split(",").mapNotNull(String::toLongOrNull).take(LIMIT)

    fun allowed(context: Context): Boolean {
        val notifications = manager(context) ?: return false
        if (!notifications.areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < 26 ||
            notifications.getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE
    }

    fun replace(context: Context, requested: List<Long>, language: String = "en") {
        require(requested.size <= LIMIT)
        val now = System.currentTimeMillis()
        val times = requested.filter { it > now }.distinct().sorted()
        val alarms = checkNotNull(context.getSystemService(AlarmManager::class.java))
        check(preferences(context).edit()
            .putString(TIMES, times.joinToString(","))
            .putString(LANGUAGE, if (language == "hi") "hi" else "en")
            .commit())
        for (slot in 0 until LIMIT) {
            val old = PendingIntent.getBroadcast(
                context, slot, intent(context), PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (old != null) {
                alarms.cancel(old)
                old.cancel()
            }
        }
        for ((slot, time) in times.withIndex()) {
            val alarm = PendingIntent.getBroadcast(
                context, slot, intent(context).putExtra(TIME, time),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, alarm)
        }
        if (times.isEmpty()) manager(context)?.cancel(NOTIFICATION_ID)
    }

    private fun intent(context: Context) =
        Intent(context, DocumentReminderReceiver::class.java).setAction(ALARM)

    fun receive(context: Context, intent: Intent) {
        val language = preferences(context).getString(LANGUAGE, "en") ?: "en"
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            if (allowed(context)) replace(context, stored(context), language)
            return
        }
        if (intent.action != ALARM || !allowed(context)) return
        val time = intent.getLongExtra(TIME, 0)
        val times = stored(context)
        if (time <= 0 || time > System.currentTimeMillis() || time !in times) return
        check(preferences(context).edit().putString(TIMES, times.filter { it != time }.joinToString(",")).commit())

        val notifications = manager(context) ?: return
        val hindi = language == "hi"
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            notifications.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    if (hindi) "दस्तावेज़ की मियाद की याद" else "Document reminders",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
            Notification.Builder(context, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val open = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        notifications.notify(
            NOTIFICATION_ID,
            builder.setSmallIcon(android.R.drawable.ic_popup_reminder)
                .setContentTitle("FamilyVault")
                .setContentText(
                    if (hindi) "दस्तावेज़ों की मियाद देखने के लिए FamilyVault खोलें।"
                    else "Open your vault to review document dates.",
                )
                .setVisibility(Notification.VISIBILITY_PRIVATE)
                .setAutoCancel(true)
                .setContentIntent(open)
                .build(),
        )
    }
}

class DocumentReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        runCatching { DocumentReminders.receive(context, intent) }
    }
}
