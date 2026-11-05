package com.fastcat.app

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration

/** Shared device classification used by both the UI and VPN service. */
object DeviceCapabilities {
    fun isTelevision(context: Context): Boolean {
        val uiModeManager =
            context.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        return uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
                context.packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
                !context.packageManager.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)
    }
}
