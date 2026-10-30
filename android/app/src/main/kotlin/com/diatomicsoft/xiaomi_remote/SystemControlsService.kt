/**
 * @author Shakib
 * @since 30/10/26
 */
package com.diatomicsoft.xiaomi_remote

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

class SystemControlsService : Service() {
    companion object {
        private const val NOTIFICATION_ID = 2101
        private const val CHANNEL_ID = "remote_controls"
        var running = false
            private set

        /** Refreshes the notification in place; only valid while the service runs. */
        fun refresh(context: Context, intent: Intent) {
            context.getSystemService(NotificationManager::class.java)
                .notify(NOTIFICATION_ID, buildNotification(context, intent))
        }

        private fun buildNotification(context: Context, intent: Intent): Notification {
            val manager = context.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 26) {
                manager.createNotificationChannel(NotificationChannel(CHANNEL_ID, "TV controls", NotificationManager.IMPORTANCE_LOW).apply {
                    setSound(null, null)
                    setShowBadge(false)
                })
            }
            val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val playing = intent.getBooleanExtra("playing", false)
            val title = intent.getStringExtra("title")?.takeIf { it.isNotBlank() } ?: "Connected"
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL_ID) else Notification.Builder(context)
            return builder
                .setSmallIcon(R.drawable.ic_stat_remote)
                .setContentTitle(intent.getStringExtra("tvName") ?: "TV")
                .setContentText(title)
                .setContentIntent(open)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .addAction(action(context, R.drawable.ic_action_volume_down, "Volume down", "volumeDown", 1))
                .addAction(action(context, if (playing) R.drawable.ic_action_pause else R.drawable.ic_action_play, if (playing) "Pause" else "Play", "playPause", 2))
                .addAction(action(context, R.drawable.ic_action_volume_up, "Volume up", "volumeUp", 3))
                .addAction(action(context, R.drawable.ic_action_mute, "Mute", "mute", 4))
                .addAction(action(context, R.drawable.ic_action_close, "Stop", "stop", 5))
                .setStyle(Notification.MediaStyle().setShowActionsInCompactView(0, 1, 2))
                .build()
        }

        private fun action(context: Context, icon: Int, label: String, name: String, requestCode: Int): Notification.Action {
            val intent = Intent(context, SystemControlsReceiver::class.java).setAction(name)
            val pending = PendingIntent.getBroadcast(context, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            return Notification.Action.Builder(android.graphics.drawable.Icon.createWithResource(context, icon), label, pending).build()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(NOTIFICATION_ID, buildNotification(this, intent))
        running = true
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }
}
