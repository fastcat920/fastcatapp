package com.fastcat.app.services

import android.content.Context
import com.fastcat.app.FastCatApplication
import com.fastcat.app.models.VpnOptions
import com.google.gson.Gson

/** Durable VPN intent used to recover a sticky service after process death. */
object VpnRecoveryStore {
    private const val PREFERENCES_NAME = "fastcat_vpn_recovery"
    private const val KEY_DESIRED_RUNNING = "desired_running"
    private const val KEY_OPTIONS_JSON = "options_json"

    private val preferences
        get() = FastCatApplication.getAppContext().getSharedPreferences(
            PREFERENCES_NAME,
            Context.MODE_PRIVATE,
        )

    fun persistRunning(options: VpnOptions) {
        // commit() is intentional: recovery state must reach disk before the
        // process can be moved to the TV's background freezer.
        preferences.edit()
            .putBoolean(KEY_DESIRED_RUNNING, true)
            .putString(KEY_OPTIONS_JSON, Gson().toJson(options))
            .commit()
    }

    fun clearDesiredRunning() {
        preferences.edit()
            .putBoolean(KEY_DESIRED_RUNNING, false)
            .remove(KEY_OPTIONS_JSON)
            .commit()
    }

    fun isDesiredRunning(): Boolean =
        preferences.getBoolean(KEY_DESIRED_RUNNING, false)

    fun getOptionsJson(): String? =
        preferences.getString(KEY_OPTIONS_JSON, null)
}
