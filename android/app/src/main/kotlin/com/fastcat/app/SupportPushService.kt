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
        // FCM notification payload is displayed by the OS in background.
        // Foreground chat already owns sound and unread UI; do not duplicate it.
    }
    companion object {
        fun createChannel(context: android.content.Context) {
            if (Build.VERSION.SDK_INT >= 26) {
                val manager = context.getSystemService(NotificationManager::class.java)
                manager.createNotificationChannel(NotificationChannel("fastcat_support", "Support replies", NotificationManager.IMPORTANCE_DEFAULT))
            }
        }
    }
}
