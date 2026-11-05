package com.fastcat.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class SupportPushService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        getSharedPreferences("support_push", MODE_PRIVATE).edit().putString("token", token).apply()
    }
    override fun onMessageReceived(message: RemoteMessage) {
        if (message.data["type"] != "support.reply") return
        // Notification payloads are handled by FCM; data-only replies use the
        // same local deduplication path as SSE.
        if (message.notification == null && !appForeground) {
            val conversation = message.data["conversationId"] ?: return
            val id = message.data["messageId"] ?: return
            showReply(this, conversation, id)
        }
    }
    companion object {
        @Volatile var appForeground = false
        @Synchronized
        fun showReply(context: android.content.Context, conversation: String, message: String) {
            if (appForeground) return
            if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) return
            val manager = context.getSystemService(NotificationManager::class.java)
            if (!manager.areNotificationsEnabled()) return
            val prefs = context.getSharedPreferences("support_reply_seen", android.content.Context.MODE_PRIVATE)
            val key = "$conversation:$message"
            val seen = prefs.getStringSet("ids", emptySet())!!.toMutableSet()
            if (!seen.add(key)) return
            createChannel(context)
            val intent = Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putExtra("type", "support.reply")
                .putExtra("conversationId", conversation)
                .putExtra("messageId", message)
                .setAction("com.fastcat.app.SUPPORT_REPLY.$conversation")
            val pending = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val builder = if (Build.VERSION.SDK_INT >= 26) {
                android.app.Notification.Builder(context, "fastcat_support")
            } else {
                android.app.Notification.Builder(context)
                    .setDefaults(android.app.Notification.DEFAULT_ALL)
            }
            val notification = builder
                .setSmallIcon(com.fastcat.app.R.drawable.ic_support_notification)
                .setContentTitle("FastCat 客服")
                .setContentText("你有新的客服回复，点击查看")
                .setContentIntent(pending).setAutoCancel(true)
                .setOnlyAlertOnce(false).build()
            manager.notify("support:$conversation", 7319, notification)
            prefs.edit().putStringSet("ids", seen.toList().takeLast(256).toSet()).apply()
        }
        fun createChannel(context: android.content.Context) {
            if (Build.VERSION.SDK_INT >= 26) {
                val manager = context.getSystemService(NotificationManager::class.java)
                manager.createNotificationChannel(NotificationChannel("fastcat_support", "Support replies", NotificationManager.IMPORTANCE_DEFAULT))
            }
        }
    }
}
