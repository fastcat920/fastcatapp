package com.fastcat.app.plugins

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import androidx.core.content.getSystemService
import androidx.core.content.ContextCompat
import com.fastcat.app.FastCatApplication
import com.fastcat.app.GlobalState
import com.fastcat.app.RunState
import com.fastcat.app.core.Core
import com.fastcat.app.extensions.resolveDns
import com.fastcat.app.models.StartForegroundParams
import com.fastcat.app.models.VpnOptions
import com.fastcat.app.services.BaseServiceInterface
import com.fastcat.app.services.FastCatService
import com.fastcat.app.services.FastCatVpnService
import com.fastcat.app.services.VpnRecoveryStore
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.net.InetSocketAddress
import kotlin.concurrent.withLock

data object VpnPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var flutterMethodChannel: MethodChannel
    private var fastCatService: BaseServiceInterface? = null
    private var options: VpnOptions? = null
    private var isBind: Boolean = false
    private lateinit var scope: CoroutineScope
    private var lastStartForegroundParams: StartForegroundParams? = null
    private var timerJob: Job? = null
    private var heartbeatJob: Job? = null
    private var consecutiveHeartbeatFailures = 0
    private var lastHealthyHeartbeatAt = 0L
    private var lastTrafficTotal: Long? = null
    private val uidPageNameMap = mutableMapOf<Int, String>()

    private val connectivity by lazy {
        FastCatApplication.getAppContext().getSystemService<ConnectivityManager>()
    }

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(className: ComponentName, service: IBinder) {
            isBind = true
            fastCatService = when (service) {
                is FastCatVpnService.LocalBinder -> service.getService()
                is FastCatService.LocalBinder -> service.getService()
                else -> throw Exception("invalid binder")
            }
            handleStartService()
        }

        override fun onServiceDisconnected(arg: ComponentName) {
            isBind = false
            fastCatService = null
            // The VPN disappeared underneath the Flutter UI (usually a ROM
            // reclaim or service crash). Never leave the UI showing a stale
            // connected state.
            GlobalState.runState.postValue(RunState.STOP)
            GlobalState.restartServiceEngineForRecovery("VPN service binder disconnected")
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        scope.launch {
            registerNetworkCallback()
        }
        flutterMethodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "vpn")
        flutterMethodChannel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        stopForegroundJob()
        stopHeartbeatJob()
        runCatching { unRegisterNetworkCallback() }
        unbindServiceSafely()
        scope.cancel()
        flutterMethodChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val data = call.argument<String>("data")
                result.success(handleStart(Gson().fromJson(data, VpnOptions::class.java)))
            }

            "stop" -> {
                handleStop()
                result.success(true)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    fun handleStart(options: VpnOptions): Boolean {
        onUpdateNetwork();
        if (options.enable != this.options?.enable) {
            this.fastCatService = null
        }
        this.options = options
        when (options.enable) {
            true -> handleStartVpn()
            false -> handleStartService()
        }
        return true
    }

    private fun handleStartVpn() {
        GlobalState.getCurrentAppPlugin()?.requestVpnPermission {
            handleStartService()
        }
    }

    fun requestGc() {
        flutterMethodChannel.invokeMethod("gc", null)
    }

    val networks = mutableSetOf<Network>()

    fun onUpdateNetwork() {
        (fastCatService as? FastCatVpnService)?.refreshWifiLock()
        val dns = networks.flatMap { network ->
            connectivity?.resolveDns(network) ?: emptyList()
        }.toSet().joinToString(",")
        scope.launch {
            withContext(Dispatchers.Main) {
                flutterMethodChannel.invokeMethod("dnsChanged", dns)
            }
        }
    }

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            networks.add(network)
            onUpdateNetwork()
        }

        override fun onLost(network: Network) {
            networks.remove(network)
            onUpdateNetwork()
        }
    }

    private val request = NetworkRequest.Builder().apply {
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
    }.build()

    private fun registerNetworkCallback() {
        networks.clear()
        connectivity?.registerNetworkCallback(request, callback)
    }

    private fun unRegisterNetworkCallback() {
        connectivity?.unregisterNetworkCallback(callback)
        networks.clear()
        onUpdateNetwork()
    }

    private suspend fun startForeground() {
        if (GlobalState.runState.value != RunState.START) return
        val data = requestDartResult(
            method = "getStartForegroundParams",
            timeoutMillis = NOTIFICATION_RPC_TIMEOUT_MS,
        ) as? String ?: return
        if (data.isBlank()) return
        val startForegroundParams = runCatching {
            Gson().fromJson(data, StartForegroundParams::class.java)
        }.getOrNull() ?: return
        val shouldUpdate = GlobalState.runLock.withLock {
            if (GlobalState.runState.value != RunState.START) return@withLock false
            if (lastStartForegroundParams != startForegroundParams) {
                lastStartForegroundParams = startForegroundParams
                true
            } else {
                false
            }
        }
        if (shouldUpdate) {
            fastCatService?.startForeground(
                startForegroundParams.title,
                startForegroundParams.content,
            )
        }
    }

    private fun startForegroundJob() {
        stopForegroundJob()
        timerJob = CoroutineScope(Dispatchers.Main).launch {
            while (isActive) {
                startForeground()
                delay(1000)
            }
        }
    }

    private fun stopForegroundJob() {
        timerJob?.cancel()
        timerJob = null
    }

    private fun startHeartbeatJob() {
        stopHeartbeatJob()
        consecutiveHeartbeatFailures = 0
        lastHealthyHeartbeatAt = SystemClock.elapsedRealtime()
        heartbeatJob = scope.launch {
            while (isActive) {
                delay(HEARTBEAT_INTERVAL_MS)
                performHeartbeat()
            }
        }
    }

    private fun stopHeartbeatJob() {
        heartbeatJob?.cancel()
        heartbeatJob = null
    }

    private suspend fun performHeartbeat() {
        if (GlobalState.runState.value != RunState.START) return
        val vpnService = fastCatService as? FastCatVpnService
        val tunHealthy = if (options?.enable == false) {
            fastCatService != null
        } else {
            vpnService?.isTunActive() == true
        }
        val response = requestDartResult(
            method = "heartbeat",
            timeoutMillis = HEARTBEAT_RPC_TIMEOUT_MS,
        ) as? Map<*, *>
        val coreHealthy = response?.get("healthy") == true
        val trafficTotal = (response?.get("trafficTotal") as? Number)?.toLong()

        if (tunHealthy && coreHealthy) {
            consecutiveHeartbeatFailures = 0
            lastHealthyHeartbeatAt = SystemClock.elapsedRealtime()
            if (trafficTotal != null && trafficTotal != lastTrafficTotal) {
                Log.d(TAG, "VPN heartbeat healthy trafficTotal=$trafficTotal")
            }
            lastTrafficTotal = trafficTotal
            vpnService?.refreshWifiLock()
            return
        }

        consecutiveHeartbeatFailures += 1
        Log.w(
            TAG,
            "VPN heartbeat failed count=$consecutiveHeartbeatFailures tun=$tunHealthy core=$coreHealthy",
        )
        if (consecutiveHeartbeatFailures < HEARTBEAT_FAILURE_LIMIT) return

        requestDartResult(
            method = "prepareRecovery",
            timeoutMillis = CORE_SHUTDOWN_TIMEOUT_MS,
        )
        GlobalState.restartServiceEngineForRecovery(
            "heartbeat failures=$consecutiveHeartbeatFailures tun=$tunHealthy core=$coreHealthy",
        )
    }

    private suspend fun requestDartResult(
        method: String,
        arguments: Any? = null,
        timeoutMillis: Long,
    ): Any? {
        val result = CompletableDeferred<Any?>()
        withContext(Dispatchers.Main) {
            flutterMethodChannel.invokeMethod(
                method,
                arguments,
                object : MethodChannel.Result {
                    override fun success(value: Any?) {
                        result.complete(value)
                    }

                    override fun error(code: String, message: String?, details: Any?) {
                        result.complete(null)
                    }

                    override fun notImplemented() {
                        result.complete(null)
                    }
                },
            )
        }
        return withTimeoutOrNull(timeoutMillis) { result.await() }
    }


    suspend fun getStatus(): Boolean? {
        if (!isActuallyRunning()) return false
        return requestDartResult(
            method = "status",
            timeoutMillis = HEARTBEAT_RPC_TIMEOUT_MS,
        ) as? Boolean ?: false
    }

    private fun handleStartService() {
        if (fastCatService == null) {
            bindService()
            return
        }
        GlobalState.runLock.withLock {
            if (GlobalState.runState.value == RunState.START) return
            val nextOptions = options ?: return
            VpnRecoveryStore.persistRunning(nextOptions)
            try {
                val fd = fastCatService?.start(nextOptions)
                Core.startTun(
                    fd = fd ?: 0,
                    protect = this::protect,
                    resolverProcess = this::resolverProcess,
                )
                GlobalState.runState.value = RunState.START
                lastHealthyHeartbeatAt = SystemClock.elapsedRealtime()
                startForegroundJob()
                startHeartbeatJob()
            } catch (error: Throwable) {
                VpnRecoveryStore.clearDesiredRunning()
                GlobalState.runState.value = RunState.STOP
                throw error
            }
        }
    }

    private fun protect(fd: Int): Boolean {
        return (fastCatService as? FastCatVpnService)?.protect(fd) == true
    }

    private fun resolverProcess(
        protocol: Int,
        source: InetSocketAddress,
        target: InetSocketAddress,
        uid: Int,
    ): String {
        val nextUid = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            connectivity?.getConnectionOwnerUid(protocol, source, target) ?: -1
        } else {
            uid
        }
        if (nextUid == -1) {
            return ""
        }
        if (!uidPageNameMap.containsKey(nextUid)) {
            uidPageNameMap[nextUid] =
                FastCatApplication.getAppContext().packageManager?.getPackagesForUid(nextUid)
                    ?.first() ?: ""
        }
        return uidPageNameMap[nextUid] ?: ""
    }

    fun handleStop() {
        VpnRecoveryStore.clearDesiredRunning()
        GlobalState.runLock.withLock {
            if (GlobalState.runState.value == RunState.STOP) return
            GlobalState.runState.value = RunState.STOP
            // 先停 TUN 释放 fd，让系统有机会清理 VPN 网络接口及其代理/DNS 设置
            // 再停 VPN Service，避免部分 ROM 上 HTTP 代理残留
            Core.stopTun()
            (fastCatService as? FastCatVpnService)?.markTunStopped()
            stopForegroundJob()
            stopHeartbeatJob()
            fastCatService?.stop()
            GlobalState.handleTryDestroy()
        }
    }

    fun isActuallyRunning(): Boolean {
        val heartbeatFresh = SystemClock.elapsedRealtime() - lastHealthyHeartbeatAt <=
                HEARTBEAT_STALE_AFTER_MS
        val tunHealthy = (fastCatService as? FastCatVpnService)?.isTunActive()
            ?: (options?.enable == false)
        return GlobalState.runState.value == RunState.START &&
                heartbeatFresh && tunHealthy
    }

    fun prepareForRecovery() {
        stopForegroundJob()
        stopHeartbeatJob()
        Core.stopTun()
        (fastCatService as? FastCatVpnService)?.markTunStopped()
        GlobalState.runState.value = RunState.PENDING
        unbindServiceSafely()
        fastCatService = null
        isBind = false
    }

    private fun bindService() {
        if (isBind) {
            FastCatApplication.getAppContext().unbindService(connection)
        }
        val intent = when (options?.enable == true) {
            true -> Intent(FastCatApplication.getAppContext(), FastCatVpnService::class.java)
            false -> Intent(FastCatApplication.getAppContext(), FastCatService::class.java)
        }
        // A bound-only service can be reclaimed when the TV puts the activity
        // in the background. Start it explicitly so Android can recreate it
        // while the VPN is still expected to run.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(FastCatApplication.getAppContext(), intent)
        } else {
            FastCatApplication.getAppContext().startService(intent)
        }
        FastCatApplication.getAppContext().bindService(intent, connection, Context.BIND_AUTO_CREATE)
    }

    private fun unbindServiceSafely() {
        if (!isBind) return
        runCatching {
            FastCatApplication.getAppContext().unbindService(connection)
        }
        isBind = false
    }

    private const val TAG = "FastCatVpnPlugin"
    private const val NOTIFICATION_RPC_TIMEOUT_MS = 3_000L
    private const val HEARTBEAT_INTERVAL_MS = 15_000L
    private const val HEARTBEAT_RPC_TIMEOUT_MS = 5_000L
    private const val CORE_SHUTDOWN_TIMEOUT_MS = 3_000L
    private const val HEARTBEAT_FAILURE_LIMIT = 3
    private const val HEARTBEAT_STALE_AFTER_MS = 60_000L
}
