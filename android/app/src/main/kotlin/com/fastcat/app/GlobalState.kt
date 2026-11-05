package com.fastcat.app

import android.util.Base64
import android.util.Log
import androidx.lifecycle.MutableLiveData
import com.fastcat.app.plugins.AppPlugin
import com.fastcat.app.plugins.TilePlugin
import com.fastcat.app.plugins.VpnPlugin
import com.fastcat.app.services.VpnRecoveryStore
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

enum class RunState {
    START,
    PENDING,
    STOP
}


object GlobalState {
    val runLock = ReentrantLock()

    const val NOTIFICATION_CHANNEL = "FastCat"

    const val NOTIFICATION_ID = 1

    val runState: MutableLiveData<RunState> = MutableLiveData<RunState>(RunState.STOP)
    var flutterEngine: FlutterEngine? = null
    private var serviceEngine: FlutterEngine? = null
    @Volatile
    private var recoveryRestartInProgress = false

    fun getCurrentAppPlugin(): AppPlugin? {
        val currentEngine = if (flutterEngine != null) flutterEngine else serviceEngine
        return currentEngine?.plugins?.get(AppPlugin::class.java) as AppPlugin?
    }

    fun syncStatus() {
        CoroutineScope(Dispatchers.Default).launch {
            val plugin = getCurrentVPNPlugin()
            plugin?.getStatus()
            val connectionState = plugin?.getConnectionState() ?: "disconnected"
            withContext(Dispatchers.Main){
                runState.value = when {
                    connectionState == "connected" ||
                            connectionState == "degraded" -> RunState.START
                    connectionState == "recovering" ->
                        runState.value ?: RunState.PENDING
                    else -> RunState.STOP
                }
            }
        }
    }

    suspend fun getText(text: String): String {
        return getCurrentAppPlugin()?.getText(text) ?: ""
    }

    fun getCurrentTilePlugin(): TilePlugin? {
        val currentEngine = if (flutterEngine != null) flutterEngine else serviceEngine
        return currentEngine?.plugins?.get(TilePlugin::class.java) as TilePlugin?
    }

    fun getCurrentVPNPlugin(): VpnPlugin? {
        return serviceEngine?.plugins?.get(VpnPlugin::class.java) as VpnPlugin?
    }

    fun handleToggle() {
        val starting = handleStart()
        if (!starting) {
            handleStop()
        }
    }

    fun handleStart(): Boolean {
        if (runState.value == RunState.STOP) {
            runState.value = RunState.PENDING
            runLock.lock()
            val tilePlugin = getCurrentTilePlugin()
            if (tilePlugin != null) {
                tilePlugin.handleStart()
            } else {
                initServiceEngine()
            }
            return true
        }
        return false
    }

    fun handleStop() {
        if (runState.value == RunState.START) {
            runState.value = RunState.PENDING
            runLock.lock()
            getCurrentTilePlugin()?.handleStop()
        }
    }

    fun handleTryDestroy() {
        if (flutterEngine == null) {
            destroyServiceEngine()
        }
    }

    fun destroyServiceEngine() {
        runLock.withLock {
            serviceEngine?.destroy()
            serviceEngine = null
        }
    }

    fun initServiceEngine(
        forceQuickStart: Boolean = false,
        recoveryOptionsJson: String? = null,
    ) {
        if (serviceEngine != null) return
        destroyServiceEngine()
        runLock.withLock {
            serviceEngine = FlutterEngine(FastCatApplication.getAppContext())
            serviceEngine?.plugins?.add(VpnPlugin)
            serviceEngine?.plugins?.add(AppPlugin())
            serviceEngine?.plugins?.add(TilePlugin())
            val vpnService = DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "_service"
            )
            val quickStart = forceQuickStart || flutterEngine == null
            val entrypointArgs: List<String>? = if (quickStart) {
                val args = mutableListOf("quick")
                recoveryOptionsJson?.takeIf { it.isNotBlank() }?.let { json ->
                    args.add(
                        "vpn-options=" + Base64.encodeToString(
                            json.toByteArray(Charsets.UTF_8),
                            Base64.NO_WRAP,
                        ),
                    )
                }
                args
            } else {
                null
            }
            serviceEngine?.dartExecutor?.executeDartEntrypoint(
                vpnService,
                entrypointArgs,
            )
            Log.i(
                "FastCatGlobalState",
                "service engine started quick=$quickStart recoveryOptions=${recoveryOptionsJson != null}",
            )
        }
    }

    fun restartServiceEngineForRecovery(reason: String) {
        if (recoveryRestartInProgress || !VpnRecoveryStore.isDesiredRunning()) return
        recoveryRestartInProgress = true
        CoroutineScope(Dispatchers.Main).launch {
            try {
                Log.w("FastCatGlobalState", "restarting VPN service engine: $reason")
                getCurrentVPNPlugin()?.prepareForRecovery()
                runLock.withLock {
                    serviceEngine?.destroy()
                    serviceEngine = null
                    runState.value = RunState.PENDING
                }
                initServiceEngine(
                    forceQuickStart = true,
                    recoveryOptionsJson = VpnRecoveryStore.getOptionsJson(),
                )
            } finally {
                recoveryRestartInProgress = false
            }
        }
    }
}
