package com.fastcat.app.plugins

import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Process
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.withTimeoutOrNull
import java.net.Inet4Address

/** Register before establish(), then await the system's own VPN network snapshot. */
internal class VpnNetworkReady(
    private val manager: ConnectivityManager,
    private val address: String,
) : AutoCloseable {
    private val ready = CompletableDeferred<Unit>()
    private var registered = false
    private var existingNetworks = emptySet<Network>()
    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = check(network)
        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) = check(network)
        override fun onLinkPropertiesChanged(network: Network, properties: LinkProperties) = check(network, properties)
    }

    fun register() {
        existingNetworks = manager.allNetworks.toSet()
        val request = NetworkRequest.Builder()
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .addTransportType(NetworkCapabilities.TRANSPORT_VPN)
            .build()
        manager.registerNetworkCallback(request, callback)
        registered = true
    }

    private fun check(network: Network, supplied: LinkProperties? = null) {
        if (network in existingNetworks) return
        val capabilities = manager.getNetworkCapabilities(network) ?: return
        if (!capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && capabilities.ownerUid >= 0 && capabilities.ownerUid != Process.myUid()) return
        val properties = supplied ?: manager.getLinkProperties(network) ?: return
        if (properties.interfaceName.isNullOrBlank()) return
        if (properties.linkAddresses.none { it.address.hostAddress == address }) return
        if (properties.routes.none { it.destination.address is Inet4Address }) return
        ready.complete(Unit)
    }

    suspend fun await() = awaitVpnNetworkReady(ready)

    override fun close() {
        if (registered) {
            registered = false
            runCatching { manager.unregisterNetworkCallback(callback) }
        }
    }
}

// A registration timeout is a startup failure, not user cancellation. Keep an
// external coroutine cancellation distinct so stop still cancels immediately.
internal suspend fun awaitVpnNetworkReady(signal: Deferred<Unit>, timeoutMillis: Long = 8_000L) {
    check(withTimeoutOrNull(timeoutMillis) { signal.await(); true } == true) {
        "VPN network registration timed out"
    }
}
