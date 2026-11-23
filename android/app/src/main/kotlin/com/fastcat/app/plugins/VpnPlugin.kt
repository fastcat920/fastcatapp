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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ParcelFileDescriptor
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
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock as withCoroutineLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.URL
import java.net.Proxy
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import kotlin.concurrent.withLock

enum class VpnConnectionHealth {
    CONNECTED,
    DEGRADED,
    RECOVERING,
    DISCONNECTED,
}

private data class DataPlaneProbeResult(
    val reachable: Boolean,
    val durationMillis: Long,
)

data object VpnPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var flutterMethodChannel: MethodChannel
    private var fastCatService: BaseServiceInterface? = null
    private var options: VpnOptions? = null
    private var isBind: Boolean = false
    private lateinit var scope: CoroutineScope
    private var lastStartForegroundParams: StartForegroundParams? = null
    private var timerJob: Job? = null
    private var heartbeatJob: Job? = null
    private var startupJob: Job? = null
    private val lifecycleMutex = Mutex()
    private val session = AtomicLong()
    private var consecutiveHeartbeatFailures = 0
    private var lastHealthyHeartbeatAt = 0L
    private var lastTrafficTotal: Long? = null
    private var lastTrafficProgressAt = 0L
    private var lastDataPlaneProbeAt = 0L
    private var consecutiveDataPlaneFailures = 0
    private var dataPlaneRecoveryStage = 0
    private val heartbeatMutex = Mutex()
    @Volatile
    private var connectionHealth = VpnConnectionHealth.DISCONNECTED
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
            connectionHealth = if (VpnRecoveryStore.isDesiredRunning()) {
                VpnConnectionHealth.RECOVERING
            } else {
                VpnConnectionHealth.DISCONNECTED
            }
            GlobalState.runState.postValue(
                if (VpnRecoveryStore.isDesiredRunning()) RunState.PENDING else RunState.STOP,
            )
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
        session.incrementAndGet()
        startupJob?.cancel()
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

    fun attachMain() {
        // The UI engine can be recreated while this engine and TUN survive.
        flutterMethodChannel.invokeMethod("attachMain", null)
    }

    val networks: MutableSet<Network> = ConcurrentHashMap.newKeySet()

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
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) physicalPathChanged()
        }
    }

    private var bestPhysicalNetwork: Network? = null
    private val bestPathCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            val old = bestPhysicalNetwork
            bestPhysicalNetwork = network
            if (old != null && old != network) physicalPathChanged()
        }

        override fun onLost(network: Network) {
            if (bestPhysicalNetwork == network) {
                bestPhysicalNetwork = null
                physicalPathChanged()
            }
        }
    }

    private fun physicalPathChanged() {
        scope.launch(Dispatchers.Main) {
            if (GlobalState.runState.value == RunState.START) {
                flutterMethodChannel.invokeMethod("physicalPathChanged", null)
            }
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
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            connectivity?.registerBestMatchingNetworkCallback(request, bestPathCallback, Handler(Looper.getMainLooper()))
        }
    }

    private fun unRegisterNetworkCallback() {
        connectivity?.unregisterNetworkCallback(callback)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            connectivity?.unregisterNetworkCallback(bestPathCallback)
            bestPhysicalNetwork = null
        }
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
        consecutiveDataPlaneFailures = 0
        dataPlaneRecoveryStage = 0
        val now = SystemClock.elapsedRealtime()
        lastHealthyHeartbeatAt = now
        lastTrafficProgressAt = now
        lastDataPlaneProbeAt = 0L
        lastTrafficTotal = null
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
        heartbeatMutex.withCoroutineLock {
            performHeartbeatLocked()
        }
    }

    private suspend fun performHeartbeatLocked() {
        if (GlobalState.runState.value != RunState.START) return
        val vpnService = fastCatService as? FastCatVpnService
        val tunHealthy = if (options?.enable == false) {
            fastCatService != null
        } else {
            vpnService?.isTunActive() == true
        }
        val tunState = withContext(Dispatchers.IO) {
            runCatching { Gson().fromJson(Core.getTunStatus(), Map::class.java)["state"] as? String }
                .getOrNull()
        }
        if (tunState == "failed") {
            connectionHealth = VpnConnectionHealth.RECOVERING
            Log.e(TAG, "vpn_health event=forwarder outcome=failed")
            if (VpnRecoveryStore.isDesiredRunning() && rebuildTun()) {
                connectionHealth = VpnConnectionHealth.CONNECTED
                consecutiveHeartbeatFailures = 0
            } else if (VpnRecoveryStore.isDesiredRunning()) {
                restartCoreForDataPlaneFailure("TCP forwarder recovery exhausted")
            }
            return
        }
        if (tunState == "recovering") {
            connectionHealth = VpnConnectionHealth.RECOVERING
            return
        }
        if (tunState != "ready") {
            handleControlPlaneFailure(tunHealthy, false)
            return
        }
        val response = requestDartResult(
            method = "heartbeat",
            timeoutMillis = HEARTBEAT_RPC_TIMEOUT_MS,
        ) as? Map<*, *>
        val coreHealthy = response?.get("healthy") == true
        val trafficTotal = (response?.get("trafficTotal") as? Number)?.toLong()

        if (!tunHealthy || !coreHealthy) {
            handleControlPlaneFailure(tunHealthy, coreHealthy)
            return
        }

        val now = SystemClock.elapsedRealtime()
        consecutiveHeartbeatFailures = 0
        lastHealthyHeartbeatAt = now
        vpnService?.refreshWifiLock()

        val trafficProgressed = trafficTotal != null &&
                (lastTrafficTotal == null || trafficTotal != lastTrafficTotal)
        lastTrafficTotal = trafficTotal
        if (trafficProgressed) {
            markDataPlaneHealthy(now, "traffic")
        }

        if (options?.enable == false) {
            markDataPlaneHealthy(now, "service")
            return
        }

        val idleThreshold = if (vpnService?.isTelevisionDevice() == true) {
            TV_IDLE_PROBE_AFTER_MS
        } else {
            MOBILE_IDLE_PROBE_AFTER_MS
        }
        if (now - lastDataPlaneProbeAt < 120_000L &&
            (now - lastTrafficProgressAt < idleThreshold ||
                now - lastDataPlaneProbeAt < DATA_PLANE_PROBE_MIN_INTERVAL_MS)
        ) {
            return
        }

        lastDataPlaneProbeAt = now
        if (networks.isEmpty()) {
            connectionHealth = VpnConnectionHealth.DEGRADED
            Log.w(
                TAG,
                "vpn_health event=probe outcome=skipped reason=no_underlying_network " +
                        lockState(vpnService),
            )
            return
        }

        val probe = probeDataPlane()
        if (probe.reachable) {
            markDataPlaneHealthy(SystemClock.elapsedRealtime(), "probe")
            Log.i(
                TAG,
                "vpn_health event=probe outcome=success duration_ms=${probe.durationMillis} " +
                        lockState(vpnService),
            )
            return
        }

        consecutiveDataPlaneFailures += 1
        connectionHealth = VpnConnectionHealth.DEGRADED
        Log.w(
            TAG,
            "vpn_health event=probe outcome=failure duration_ms=${probe.durationMillis} " +
                    "count=$consecutiveDataPlaneFailures stage=$dataPlaneRecoveryStage " +
                    lockState(vpnService),
        )
        recoverDataPlane(vpnService)
    }

    private suspend fun handleControlPlaneFailure(
        tunHealthy: Boolean,
        coreHealthy: Boolean,
    ) {
        connectionHealth = VpnConnectionHealth.DEGRADED
        consecutiveHeartbeatFailures += 1
        Log.w(
            TAG,
            "vpn_health event=control_heartbeat outcome=failure " +
                    "count=$consecutiveHeartbeatFailures tun=$tunHealthy core=$coreHealthy",
        )
        if (consecutiveHeartbeatFailures < HEARTBEAT_FAILURE_LIMIT) return

        connectionHealth = VpnConnectionHealth.RECOVERING
        requestDartResult(
            method = "prepareRecovery",
            timeoutMillis = CORE_SHUTDOWN_TIMEOUT_MS,
        )
        GlobalState.restartServiceEngineForRecovery(
            "heartbeat failures=$consecutiveHeartbeatFailures tun=$tunHealthy core=$coreHealthy",
        )
    }

    private fun markDataPlaneHealthy(now: Long, source: String) {
        val wasUnhealthy = connectionHealth != VpnConnectionHealth.CONNECTED
        connectionHealth = VpnConnectionHealth.CONNECTED
        consecutiveDataPlaneFailures = 0
        dataPlaneRecoveryStage = 0
        lastTrafficProgressAt = now
        if (wasUnhealthy) {
            Log.i(TAG, "vpn_health event=data_plane outcome=recovered source=$source")
        }
    }

    private suspend fun recoverDataPlane(vpnService: FastCatVpnService?) {
        when (dataPlaneRecoveryStage) {
            0 -> {
                dataPlaneRecoveryStage = 1
                val recovered = requestDartResult(
                    method = "recoverDataPlane",
                    timeoutMillis = SOFT_RECOVERY_TIMEOUT_MS,
                ) == true
                vpnService?.refreshWifiLock()
                Log.w(
                    TAG,
                    "vpn_health event=recovery level=soft outcome=${if (recovered) "applied" else "failed"}",
                )
            }

            1 -> {
                connectionHealth = VpnConnectionHealth.RECOVERING
                val rebuilt = rebuildTun()
                if (rebuilt) {
                    dataPlaneRecoveryStage = 2
                    consecutiveDataPlaneFailures = 0
                    lastDataPlaneProbeAt = SystemClock.elapsedRealtime()
                    Log.w(TAG, "vpn_health event=recovery level=tun outcome=rebuilt")
                } else {
                    restartCoreForDataPlaneFailure("TUN rebuild failed")
                }
            }

            else -> restartCoreForDataPlaneFailure("probe failed after TUN rebuild")
        }
    }

    private suspend fun rebuildTun(): Boolean {
        val service = fastCatService as? FastCatVpnService ?: return false
        val nextOptions = options ?: return false
        val generation = session.get()
        if (!nextOptions.enable || !VpnRecoveryStore.isDesiredRunning()) return false
        return lifecycleMutex.withCoroutineLock {
            if (session.get() != generation) return@withCoroutineLock false
            try {
                withContext(Dispatchers.Main) { GlobalState.runState.value = RunState.PENDING }
                withContext(Dispatchers.IO) { Core.stopTun() }
                withContext(Dispatchers.Main) { service.markTunStopped() }
                establishCore(service, nextOptions, generation)
                withContext(Dispatchers.Main) {
                    check(session.get() == generation && VpnRecoveryStore.isDesiredRunning())
                    GlobalState.runState.value = RunState.START
                    lastHealthyHeartbeatAt = SystemClock.elapsedRealtime()
                }
                true
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                Log.e(TAG, "vpn_health event=recovery level=tun outcome=failure error=${error.javaClass.simpleName}")
                false
            }
        }
    }

    private suspend fun restartCoreForDataPlaneFailure(reason: String) {
        connectionHealth = VpnConnectionHealth.RECOVERING
        Log.e(TAG, "vpn_health event=recovery level=core outcome=started")
        requestDartResult(
            method = "prepareRecovery",
            timeoutMillis = CORE_SHUTDOWN_TIMEOUT_MS,
        )
        GlobalState.restartServiceEngineForRecovery(reason)
    }

    private suspend fun probeDataPlane(): DataPlaneProbeResult =
        withContext(Dispatchers.IO) {
            val startedAt = SystemClock.elapsedRealtime()
            var reachable = false
            for (probeUrl in DATA_PLANE_PROBE_URLS) {
                val connection = runCatching {
                    URL(probeUrl).openConnection(Proxy.NO_PROXY) as HttpURLConnection
                }.getOrNull() ?: continue
                try {
                    connection.requestMethod = "GET"
                    connection.connectTimeout = DATA_PLANE_PROBE_TIMEOUT_MS.toInt()
                    connection.readTimeout = DATA_PLANE_PROBE_TIMEOUT_MS.toInt()
                    connection.instanceFollowRedirects = false
                    connection.useCaches = false
                    connection.setRequestProperty("Cache-Control", "no-cache")
                    val responseCode = connection.responseCode
                    if (responseCode in 200..399) {
                        reachable = true
                        break
                    }
                } catch (_: Exception) {
                    // Try the next fixed connectivity endpoint.
                } finally {
                    connection.disconnect()
                }
            }
            DataPlaneProbeResult(
                reachable = reachable,
                durationMillis = SystemClock.elapsedRealtime() - startedAt,
            )
        }

    private fun lockState(vpnService: FastCatVpnService?): String =
        "tv=${vpnService?.isTelevisionDevice() == true} " +
                "wifi=${vpnService?.isUsingWifiConnection() == true} " +
                "wake_lock=${vpnService?.isWakeLockHeld() == true} " +
                "wifi_lock=${vpnService?.isWifiLockHeld() == true}"

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
        if (GlobalState.runState.value == RunState.START) {
            val forwarderFailed = withContext(Dispatchers.IO) {
                runCatching { Gson().fromJson(Core.getTunStatus(), Map::class.java)["state"] == "failed" }
                    .getOrDefault(true)
            }
            if (forwarderFailed || SystemClock.elapsedRealtime() - lastHealthyHeartbeatAt > HEARTBEAT_STALE_AFTER_MS) {
                performHeartbeat()
            }
        }
        if (!isActuallyRunning()) return false
        return requestDartResult(
            method = "status",
            timeoutMillis = HEARTBEAT_RPC_TIMEOUT_MS,
        ) as? Boolean ?: false
    }

    private fun handleStartService() {
        if (fastCatService == null) { bindService(); return }
        if (startupJob?.isActive == true || GlobalState.runState.value == RunState.START) return
        val service = fastCatService ?: return
        val nextOptions = options ?: return
        val generation = session.incrementAndGet()
        VpnRecoveryStore.persistRunning(nextOptions)
        connectionHealth = VpnConnectionHealth.RECOVERING
        GlobalState.runState.value = RunState.PENDING
        startupJob = scope.launch(Dispatchers.Main) {
            lifecycleMutex.withCoroutineLock {
                try {
                    ensureActive()
                    check(session.get() == generation && VpnRecoveryStore.isDesiredRunning())
                    withContext(Dispatchers.IO) { Core.stopTun() }
                    establishCore(service, nextOptions, generation)
                    ensureActive()
                    check(session.get() == generation && VpnRecoveryStore.isDesiredRunning())
                    GlobalState.runState.value = RunState.START
                    connectionHealth = VpnConnectionHealth.CONNECTED
                    lastHealthyHeartbeatAt = SystemClock.elapsedRealtime()
                    startForegroundJob()
                    startHeartbeatJob()
                    Log.i(TAG, "vpn_lifecycle event=start outcome=ready")
                } catch (error: CancellationException) {
                    withContext(NonCancellable + Dispatchers.IO) { Core.stopTun() }
                    throw error
                } catch (error: Exception) {
                    withContext(NonCancellable + Dispatchers.IO) { Core.stopTun() }
                    if (session.get() == generation) {
                        VpnRecoveryStore.clearDesiredRunning()
                        GlobalState.runState.value = RunState.STOP
                        connectionHealth = VpnConnectionHealth.DISCONNECTED
                        (service as? FastCatVpnService)?.markTunStopped()
                        service.stop()
                        Log.e(TAG, "vpn_lifecycle event=start outcome=failed error=${error.javaClass.simpleName}")
                    }
                }
            }
        }
    }

    private suspend fun establishCore(
        service: BaseServiceInterface,
        nextOptions: VpnOptions,
        generation: Long,
    ) {
        val awaiter = if (nextOptions.enable) {
            VpnNetworkReady(checkNotNull(connectivity), nextOptions.ipv4Address.substringBefore('/'))
        } else null
        var fd: Int? = null
        var handedToCore = false
        try {
            awaiter?.register()
            withContext(Dispatchers.Main) { fd = service.start(nextOptions) }
            awaiter?.await()
            check(session.get() == generation && VpnRecoveryStore.isDesiredRunning())
            kotlinx.coroutines.currentCoroutineContext().ensureActive()
            // Go owns fd from entry, including failed initialization. It lends a
            // duplicate to the driver, so cancellation never closes a recycled fd.
            withContext(Dispatchers.IO) {
                kotlinx.coroutines.currentCoroutineContext().ensureActive()
                handedToCore = true
                check(Core.startTun(fd ?: 0, this@VpnPlugin::protect, this@VpnPlugin::resolverProcess))
            }
            Log.i(TAG, "vpn_lifecycle event=network_ready outcome=success")
        } finally {
            awaiter?.close()
            if (!handedToCore && fd != null && fd != 0) {
                ParcelFileDescriptor.adoptFd(fd!!).close()
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
        val generation = session.incrementAndGet()
        startupJob?.cancel()
        VpnRecoveryStore.clearDesiredRunning()
        connectionHealth = VpnConnectionHealth.DISCONNECTED
        GlobalState.runState.value = RunState.STOP
        stopForegroundJob()
        stopHeartbeatJob()
        scope.launch {
            lifecycleMutex.withCoroutineLock {
                if (session.get() != generation) return@withCoroutineLock
                withContext(Dispatchers.IO) { Core.stopTun() }
                withContext(Dispatchers.Main) {
                    if (session.get() != generation) return@withContext
                    (fastCatService as? FastCatVpnService)?.markTunStopped()
                    fastCatService?.stop()
                    GlobalState.handleTryDestroy()
                }
            }
        }
    }

    fun isActuallyRunning(): Boolean {
        val heartbeatFresh = SystemClock.elapsedRealtime() - lastHealthyHeartbeatAt <=
                HEARTBEAT_STALE_AFTER_MS
        val tunHealthy = (fastCatService as? FastCatVpnService)?.isTunActive()
            ?: (options?.enable == false)
        return GlobalState.runState.value == RunState.START &&
                heartbeatFresh && tunHealthy &&
                connectionHealth != VpnConnectionHealth.DISCONNECTED
    }

    fun getConnectionState(): String = connectionHealth.name.lowercase()

    fun prepareForRecovery() {
        connectionHealth = VpnConnectionHealth.RECOVERING
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
    private const val SOFT_RECOVERY_TIMEOUT_MS = 5_000L
    private const val HEARTBEAT_FAILURE_LIMIT = 3
    private const val HEARTBEAT_STALE_AFTER_MS = 60_000L
    private const val TV_IDLE_PROBE_AFTER_MS = 60_000L
    private const val MOBILE_IDLE_PROBE_AFTER_MS = 120_000L
    private const val DATA_PLANE_PROBE_MIN_INTERVAL_MS = 15_000L
    private const val DATA_PLANE_PROBE_TIMEOUT_MS = 3_000L
    private val DATA_PLANE_PROBE_URLS = listOf(
        "https://connect.rom.miui.com/generate_204",
        "https://wifi.vivo.com.cn/generate_204",
        "https://connectivitycheck.platform.hicloud.com/generate_204",
    )
}
