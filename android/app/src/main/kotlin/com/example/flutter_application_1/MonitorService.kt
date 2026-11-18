package com.example.flutter_application_1

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Foreground service that keeps the app process (and its Dart code: alarm
 * checks, ESP32 connection, alarm sound) running while the screen is off or
 * another app is open. It does no work itself; it only shows the ongoing
 * "Monitoring" notification Android requires and holds a CPU wake lock.
 *
 * Started and stopped from Dart through the "argus/monitor" channel in
 * MainActivity (when a session starts / on logout).
 */
class MonitorService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        if (wakeLock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "argus:monitoring",
            ).apply {
                setReferenceCounted(false)
                acquire()
            }
        }

        // If Android kills the app anyway, do not restart the service on its
        // own: without the app there is nothing to monitor.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }

    // The person swiped the app away from the recent apps list: stop.
    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    private fun buildNotification(): Notification {
        val manager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Monitoring",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shown while ARGUS is monitoring"
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        // Tapping the notification opens the app.
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("ARGUS is monitoring")
            .setContentText("Alarms stay active while the app is in the background.")
            .setSmallIcon(applicationInfo.icon)
            .setContentIntent(openApp)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "argus_monitoring"
        private const val NOTIFICATION_ID = 4201
    }
}
