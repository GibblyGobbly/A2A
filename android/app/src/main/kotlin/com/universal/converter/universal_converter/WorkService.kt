// SPDX-License-Identifier: GPL-3.0-or-later

package com.universal.converter.universal_converter

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

/**
 * Keeps the app process alive while a long job (a video encode) runs, so
 * Android does not stop it when the screen turns off. The work itself runs in
 * ffmpeg-kit; this service only holds a progress notification.
 */
class WorkService : Service() {
    companion object {
        private const val CHANNEL = "a2a_work"
        private const val NOTIFICATION_ID = 41
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_PERCENT = "percent"

        fun start(context: Context, title: String) = update(context, title, "Starting", -1)

        /** [percent] below 0 shows an indeterminate bar. */
        fun update(context: Context, title: String, text: String, percent: Int) {
            val intent = Intent(context, WorkService::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
                .putExtra(EXTRA_PERCENT, percent)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, WorkService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Working"
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: ""
        val percent = intent?.getIntExtra(EXTRA_PERCENT, -1) ?: -1
        val notification = build(title, text, percent)
        when {
            Build.VERSION.SDK_INT >= 35 ->
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING)
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ->
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            else -> startForeground(NOTIFICATION_ID, notification)
        }
        // Not restarted if the process dies: the job it guarded is gone too.
        return START_NOT_STICKY
    }

    private fun build(title: String, text: String, percent: Int): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (manager.getNotificationChannel(CHANNEL) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(CHANNEL, "Work in progress", NotificationManager.IMPORTANCE_LOW)
                        .apply { description = "Progress of long conversions" }
                )
            }
            Notification.Builder(this, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return builder
            .setSmallIcon(R.drawable.ic_stat_work)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .setProgress(100, percent.coerceIn(0, 100), percent < 0)
            .build()
    }
}
