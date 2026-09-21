package com.fastcat.app.services

import android.annotation.SuppressLint
import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.ProxyInfo
import android.net.VpnService
import android.net.wifi.WifiManager
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.Parcel
import android.os.PowerManager
import android.os.RemoteException
import android.util.Log
import androidx.core.content.getSystemService
import androidx.core.app.NotificationCompat
import com.fastcat.app.R
import com.fastcat.app.GlobalState
import com.fastcat.app.RunState
import com.fastcat.app.core.Core
import com.fastcat.app.extensions.getIpv4RouteAddress
import com.fastcat.app.extensions.getIpv6RouteAddress
import com.fastcat.app.extensions.toCIDR
import com.fastcat.app.models.AccessControlMode
import com.fastcat.app.models.VpnOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch


class FastCatVpnService : VpnService(), BaseServiceInterface {
    @Volatile
    private var tunActive = false

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onCreate() {
        super.onCreate()
        // startForegroundService must promote the service immediately. The
        // Flutter engine will replace this placeholder with live traffic text.
        startFastCatPlaceholderForeground()
        Log.i(TAG, "VPN service created pid=${android.os.Process.myPid()}")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val systemAlwaysOn = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && isAlwaysOn
        val shouldRecover = VpnRecoveryStore.isDesiredRunning() || systemAlwaysOn
        Log.i(
            TAG,
            "VPN service start intent=${intent?.action} sticky=${intent == null} recover=$shouldRecover",
        )
        if (intent == null && shouldRecover) {
            // START_STICKY may recreate only the Android service while the
            // previous Flutter engine is still alive but bound to a dead TUN.
            GlobalState.restartServiceEngineForRecovery("sticky VPN service restart")
        } else {
            GlobalState.initServiceEngine(
                forceQuickStart = shouldRecover,
                recoveryOptionsJson = VpnRecoveryStore.getOptionsJson(),
            )
        }
        return START_STICKY
    }

    override fun start(options: VpnOptions): Int {
        val fd = with(Builder()) {
            if (options.ipv4Address.isNotEmpty()) {
                val cidr = options.ipv4Address.toCIDR()
                addAddress(cidr.address, cidr.prefixLength)
                Log.d(
                    "addAddress",
                    "address: ${cidr.address} prefixLength:${cidr.prefixLength}"
                )
                val routeAddress = options.getIpv4RouteAddress()
                if (routeAddress.isNotEmpty()) {
                    try {
                        routeAddress.forEach { i ->
                            Log.d(
                                "addRoute4",
                                "address: ${i.address} prefixLength:${i.prefixLength}"
                            )
                            addRoute(i.address, i.prefixLength)
                        }
                    } catch (_: Exception) {
                        addRoute("0.0.0.0", 0)
                    }
                } else {
                    addRoute("0.0.0.0", 0)
                }
            } else {
                addRoute("0.0.0.0", 0)
            }
            try {
                if (options.ipv6Address.isNotEmpty()) {
                    val cidr = options.ipv6Address.toCIDR()
                    Log.d(
                        "addAddress6",
                        "address: ${cidr.address} prefixLength:${cidr.prefixLength}"
                    )
                    addAddress(cidr.address, cidr.prefixLength)
                    val routeAddress = options.getIpv6RouteAddress()
                    if (routeAddress.isNotEmpty()) {
                        try {
                            routeAddress.forEach { i ->
                                Log.d(
                                    "addRoute6",
                                    "address: ${i.address} prefixLength:${i.prefixLength}"
                                )
                                addRoute(i.address, i.prefixLength)
                            }
                        } catch (_: Exception) {
                            addRoute("::", 0)
                        }
                    } else {
                        addRoute("::", 0)
                    }
                }
            }catch (_:Exception){
                Log.d(
                    "addAddress6",
                    "IPv6 is not supported."
                )
            }
            addDnsServer(options.dnsServerAddress)
            setMtu(9000)
            options.accessControl.let { accessControl ->
                if (accessControl.enable) {
                    when (accessControl.mode) {
                        AccessControlMode.acceptSelected -> {
                            // Keep the client itself inside the VPN so its
                            // WebView follows the same proxy path as other apps.
                            (accessControl.acceptList + packageName)
                                .distinct()
                                .forEach { addAllowedApplication(it) }
                        }
                        AccessControlMode.rejectSelected -> {
                            // The client must remain in the VPN; only explicitly
                            // rejected applications bypass it.
                            (accessControl.rejectList - packageName)
                                .distinct()
                                .forEach { addDisallowedApplication(it) }
                        }
                    }
                }
            }
            setSession(getString(R.string.app_name))
            setBlocking(false)
            if (Build.VERSION.SDK_INT >= 29) {
                setMetered(false)
            }
            if (options.allowBypass) {
                allowBypass()
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && options.systemProxy) {
                setHttpProxy(
                    ProxyInfo.buildDirectProxy(
                        "127.0.0.1",
                        options.port,
                        options.bypassDomain
                    )
                )
            }
            establish()?.detachFd()
                ?: throw NullPointerException("Establish VPN rejected by system")
        }
        tunActive = true
        acquireRuntimeLocks()
        Log.i(TAG, "TUN established fd=$fd wakeLock=${wakeLock?.isHeld == true}")
        return fd
    }

    override fun stop() {
        markTunStopped()
        releaseRuntimeLocks()
        stopSelf()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
    }

    private var cachedBuilder: NotificationCompat.Builder? = null

    private suspend fun notificationBuilder(): NotificationCompat.Builder {
        if (cachedBuilder == null) {
            cachedBuilder = createFastCatNotificationBuilder().await()
        }
        return cachedBuilder!!
    }

    @SuppressLint("ForegroundServiceType")
    override suspend fun startForeground(title: String, content: String) {
        startForeground(
            notificationBuilder()
                .setContentTitle(title)
                .setContentText(content).build()
        )
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        Log.w(TAG, "onTrimMemory level=$level tunActive=$tunActive")
        GlobalState.getCurrentVPNPlugin()?.requestGc()
    }

    fun isTunActive(): Boolean = tunActive

    fun markTunStopped() {
        tunActive = false
    }

    @Synchronized
    fun refreshWifiLock() {
        if (!tunActive || !isTelevision() || !isUsingWifi()) {
            releaseWifiLock()
            return
        }
        if (wifiLock?.isHeld == true) return

        @Suppress("DEPRECATION")
        val nextLock = getSystemService<WifiManager>()?.createWifiLock(
            WifiManager.WIFI_MODE_FULL_HIGH_PERF,
            "$packageName:vpn-wifi",
        ) ?: return
        nextLock.setReferenceCounted(false)
        nextLock.acquire()
        wifiLock = nextLock
        Log.i(TAG, "TV Wi-Fi lock acquired")
    }

    @Synchronized
    private fun acquireRuntimeLocks() {
        if (wakeLock?.isHeld != true) {
            val powerManager = getSystemService<PowerManager>()
            wakeLock = powerManager?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "$packageName:vpn-core",
            )?.apply {
                setReferenceCounted(false)
                acquire()
            }
            Log.i(TAG, "VPN partial wake lock acquired")
        }
        refreshWifiLock()
    }

    @Synchronized
    private fun releaseRuntimeLocks() {
        releaseWifiLock()
        wakeLock?.let { lock ->
            if (lock.isHeld) lock.release()
        }
        wakeLock = null
        Log.i(TAG, "VPN runtime locks released")
    }

    private fun releaseWifiLock() {
        wifiLock?.let { lock ->
            if (lock.isHeld) lock.release()
        }
        if (wifiLock != null) Log.i(TAG, "TV Wi-Fi lock released")
        wifiLock = null
    }

    private fun isUsingWifi(): Boolean {
        val connectivity = getSystemService<ConnectivityManager>() ?: return false
        return connectivity.allNetworks.any { network ->
            val capabilities = connectivity.getNetworkCapabilities(network)
            capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true &&
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN).not() &&
                    capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        }
    }

    private fun isTelevision(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        return uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
                packageManager.hasSystemFeature("android.software.leanback")
    }

    private val binder = LocalBinder()

    inner class LocalBinder : Binder() {
        fun getService(): FastCatVpnService = this@FastCatVpnService

        override fun onTransact(code: Int, data: Parcel, reply: Parcel?, flags: Int): Boolean {
            try {
                val isSuccess = super.onTransact(code, data, reply, flags)
                if (!isSuccess) {
                    CoroutineScope(Dispatchers.Main).launch {
                        GlobalState.getCurrentTilePlugin()?.handleStop()
                    }
                }
                return isSuccess
            } catch (e: RemoteException) {
                throw e
            }
        }
    }

    override fun onBind(intent: Intent): IBinder {
        return binder
    }

    override fun onUnbind(intent: Intent?): Boolean {
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        Log.w(TAG, "VPN service destroyed desired=${VpnRecoveryStore.isDesiredRunning()}")
        markTunStopped()
        releaseRuntimeLocks()
        Core.stopTun()
        super.onDestroy()
    }

    override fun onRevoke() {
        Log.w(TAG, "VPN permission revoked")
        VpnRecoveryStore.clearDesiredRunning()
        GlobalState.runState.postValue(RunState.STOP)
        markTunStopped()
        releaseRuntimeLocks()
        Core.stopTun()
        super.onRevoke()
    }

    companion object {
        private const val TAG = "FastCatVpnService"
    }
}
