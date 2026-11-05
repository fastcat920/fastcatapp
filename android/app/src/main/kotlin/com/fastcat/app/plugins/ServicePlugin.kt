package com.fastcat.app.plugins

import com.fastcat.app.GlobalState
import com.fastcat.app.models.VpnOptions
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.fastcat.app.RunState


data object ServicePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var flutterMethodChannel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        flutterMethodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "service")
        flutterMethodChannel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        flutterMethodChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) = when (call.method) {
        "startVpn" -> {
            val data = call.argument<String>("data")
            val options = Gson().fromJson(data, VpnOptions::class.java)
            GlobalState.getCurrentVPNPlugin()?.handleStart(options)
            result.success(true)
        }

        "stopVpn" -> {
            GlobalState.getCurrentVPNPlugin()?.handleStop()
            result.success(true)
        }

        "init" -> {
            GlobalState.getCurrentAppPlugin()
                ?.requestNotificationsPermission()
            GlobalState.initServiceEngine()
            result.success(true)
        }

        "requestNotificationsPermission" -> {
            GlobalState.getCurrentAppPlugin()
                ?.requestNotificationsPermission()
            result.success(true)
        }

        "status" -> {
            result.success(
                GlobalState.runState.value == RunState.START &&
                        GlobalState.getCurrentVPNPlugin()?.isActuallyRunning() == true
            )
        }

        "connectionState" -> {
            result.success(
                GlobalState.getCurrentVPNPlugin()?.getConnectionState() ?: "disconnected"
            )
        }

        "destroy" -> {
            handleDestroy()
            result.success(true)
        }

        else -> {
            result.notImplemented()
        }
    }


    private fun handleDestroy() {
        GlobalState.destroyServiceEngine()
    }
}
