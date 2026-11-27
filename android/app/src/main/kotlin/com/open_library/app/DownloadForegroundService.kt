package com.open_library.app

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
 * 下载期间的前台服务：只负责在通知栏挂一条进度通知、让系统不冻结进程，
 * 实际下载仍在 Dart 侧进行。切后台后 Flutter 引擎继续运行，下载不中断。
 */
class DownloadForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification(
            this,
            intent?.getStringExtra(EXTRA_TITLE) ?: "",
            intent?.getStringExtra(EXTRA_TEXT) ?: "",
            intent?.getIntExtra(EXTRA_PROGRESS, -1) ?: -1,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        // 进程被杀后 Dart 下载状态已丢失，不需要系统重建服务
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // 用户从最近任务划掉应用时 Flutter 引擎随 Activity 销毁，下载随之终止
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        running = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL_ID = "olib_downloads"
        private const val NOTIFICATION_ID = 0x0D10AD
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_PROGRESS = "progress"

        @Volatile
        private var running = false

        /** 首次调用启动前台服务，之后只刷新通知内容。progress < 0 表示进度未知。 */
        fun update(context: Context, title: String, text: String, progress: Int, channelName: String) {
            ensureChannel(context, channelName)
            if (!running) {
                val intent = Intent(context, DownloadForegroundService::class.java)
                    .putExtra(EXTRA_TITLE, title)
                    .putExtra(EXTRA_TEXT, text)
                    .putExtra(EXTRA_PROGRESS, progress)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                running = true
                return
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, buildNotification(context, title, text, progress))
        }

        fun stop(context: Context) {
            if (!running) return
            running = false
            context.stopService(Intent(context, DownloadForegroundService::class.java))
        }

        private fun ensureChannel(context: Context, name: String) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            // 低重要性：不响铃不弹横幅，只在通知栏常驻
            val channel = NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_LOW)
            channel.setShowBadge(false)
            manager.createNotificationChannel(channel)
        }

        private fun buildNotification(context: Context, title: String, text: String, progress: Int): Notification {
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                launch.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
                builder.setContentIntent(
                    PendingIntent.getActivity(
                        context,
                        0,
                        launch,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            }
            return builder
                .setSmallIcon(android.R.drawable.stat_sys_download)
                .setContentTitle(title)
                .setContentText(text)
                .setProgress(100, progress.coerceIn(0, 100), progress < 0)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .build()
        }
    }
}
