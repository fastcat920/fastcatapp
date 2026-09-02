package com.fastcat.app.services

import android.annotation.SuppressLint
import android.content.Intent
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.Parcel
import android.os.RemoteException
import android.util.Log
import androidx.core.app.NotificationCompat
import com.fastcat.app.R
import com.fastcat.app.GlobalState
import com.fastcat.app.extensions.getIpv4RouteAddress
import com.fastcat.app.extensions.getIpv6RouteAddress
import com.fastcat.app.extensions.toCIDR
import com.fastcat.app.models.AccessControlMode
import com.fastcat.app.models.VpnOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch


class FastCatVpnService : VpnService(), BaseServiceInterface {
    override fun onCreate() {
        super.onCreate()
        GlobalState.initServiceEngine()
    }

    override fun start(options: VpnOptions): Int {
        return with(Builder()) {
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
                if (accessControl.enable &&
                    accessControl.mode == AccessControlMode.acceptSelected
                ) {
                    // The control plane must stay outside the VPN. Requests
                    // that explicitly target the local Clash proxy still work
                    // through loopback, while DIRECT OSS/gateway requests keep
                    // using the physical network.
                    accessControl.acceptList
                        .filterNot { it == packageName }
                        .distinct()
                        .forEach { addAllowedApplication(it) }
                } else {
                    val rejectedApplications = if (accessControl.enable) {
                        accessControl.rejectList
                    } else {
                        emptyList()
                    }
                    (rejectedApplications + packageName)
                        .distinct()
                        .forEach { addDisallowedApplication(it) }
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
    }

    override fun stop() {
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
        GlobalState.getCurrentVPNPlugin()?.requestGc()
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
        stop()
        super.onDestroy()
    }
}
