package com.fastcat.app

import android.app.ActivityManager
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import java.util.Locale

/** Advisory checks only: OEM startup grants cannot be inferred from navigation. */
object BackgroundProtection {
    private fun family(): String {
        val names = "${Build.MANUFACTURER} ${Build.BRAND}".lowercase(Locale.ROOT)
        return when {
            "honor" in names -> "honor"
            "huawei" in names -> "huawei"
            listOf("xiaomi", "redmi", "poco").any { it in names } -> "xiaomi"
            listOf("oppo", "oneplus", "realme").any { it in names } -> "oppo"
            listOf("vivo", "iqoo").any { it in names } -> "vivo"
            "samsung" in names -> "samsung"
            else -> "generic"
        }
    }

    fun status(context: Context): Map<String, Any> {
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val activity = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = if (Build.VERSION.SDK_INT >= 26) manager.getNotificationChannel(GlobalState.NOTIFICATION_CHANNEL) else null
        val channelExists = Build.VERSION.SDK_INT < 26 || channel != null
        val channelEnabled = Build.VERSION.SDK_INT < 26 || (channel != null && channel.importance != NotificationManager.IMPORTANCE_NONE)
        val appEnabled = NotificationManagerCompat.from(context).areNotificationsEnabled()
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "vendorFamily" to family(),
            "sdkInt" to Build.VERSION.SDK_INT,
            "androidVersion" to Build.VERSION.RELEASE,
            "batteryExempt" to (Build.VERSION.SDK_INT < 23 || power.isIgnoringBatteryOptimizations(context.packageName)),
            "backgroundRestricted" to (Build.VERSION.SDK_INT >= 28 && activity.isBackgroundRestricted),
            "appNotificationsEnabled" to appEnabled,
            "notificationChannelExists" to channelExists,
            "connectionChannelEnabled" to channelEnabled,
            "notificationsEnabled" to (appEnabled && channelEnabled),
        )
    }

    private fun component(pkg: String, cls: String) = Intent().setComponent(ComponentName(pkg, cls))

    private fun startupIntents(): List<Intent> = when (family()) {
        "honor" -> listOf(component("com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"), Intent("hihonor.intent.action.HSM_STARTUPAPP_MANAGER"), Intent("huawei.intent.action.HSM_STARTUPAPP_MANAGER"))
        "huawei" -> listOf(Intent("huawei.intent.action.HSM_STARTUPAPP_MANAGER"), component("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"))
        "xiaomi" -> listOf(component("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"))
        "oppo" -> listOf(
            component("com.oplus.safecenter", "com.oplus.safecenter.startupapp.StartupAppListActivity"),
            component("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            component("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
        )
        "vivo" -> listOf(component("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"), component("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"))
        else -> emptyList()
    }

    // Legacy callers keep the Boolean API; the page uses the detailed result.
    fun open(context: Context, target: String): Boolean = openDetailed(context, target)["opened"] == true

    fun openDetailed(context: Context, target: String): Map<String, Any> {
        val details = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
        val candidates = mutableListOf<Pair<String, Intent>>()
        when (target) {
            "battery" -> {
                if (family() == "xiaomi") candidates += "vendor" to component("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity")
                    .putExtra("package_name", context.packageName)
                    .putExtra("package_label", context.applicationInfo.loadLabel(context.packageManager).toString())
                if (Build.VERSION.SDK_INT >= 23) candidates += "battery_list" to Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            }
            "notifications" -> if (Build.VERSION.SDK_INT >= 26) {
                // A disabled app-wide switch must be enabled before its channel.
                if (NotificationManagerCompat.from(context).areNotificationsEnabled() &&
                    (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                        .getNotificationChannel(GlobalState.NOTIFICATION_CHANNEL) != null) {
                    candidates += "channel" to Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                        .putExtra(Settings.EXTRA_CHANNEL_ID, GlobalState.NOTIFICATION_CHANNEL)
                }
                candidates += "app_notifications" to Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            }
            "startup" -> candidates += startupIntents().map { "vendor" to it }
            else -> return mapOf("opened" to false, "route" to "unavailable")
        }
        candidates += "app_details" to details
        for ((route, intent) in candidates) {
            try {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return mapOf("opened" to true, "route" to route)
            } catch (_: android.content.ActivityNotFoundException) {
                // Undocumented OEM settings vary by firmware; try the next route.
            } catch (_: SecurityException) {
                // Exposed activities can still be restricted to system apps.
            }
        }
        return mapOf("opened" to false, "route" to "unavailable")
    }
}
