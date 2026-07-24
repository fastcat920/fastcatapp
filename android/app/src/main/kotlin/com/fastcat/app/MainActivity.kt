package com.fastcat.app

import android.annotation.SuppressLint
import android.os.Build
import android.os.Bundle
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import com.fastcat.app.plugins.AppPlugin
import com.fastcat.app.plugins.ServicePlugin
import com.fastcat.app.plugins.TilePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var customerServiceBackCallback: OnBackInvokedCallback? = null
    private var customerServiceBackPending = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerCustomerServiceBackCallback()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AppPlugin())
        flutterEngine.plugins.add(ServicePlugin)
        flutterEngine.plugins.add(TilePlugin())
        GlobalState.flutterEngine = flutterEngine
        GlobalState.syncStatus()
    }

    override fun onBackPressed() {
        handleCustomerServiceBack()
    }

    @SuppressLint("NewApi")
    private fun registerCustomerServiceBackCallback() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (customerServiceBackCallback != null) return
        val callback = OnBackInvokedCallback {
            handleCustomerServiceBack()
        }
        onBackInvokedDispatcher.registerOnBackInvokedCallback(
            OnBackInvokedDispatcher.PRIORITY_OVERLAY,
            callback
        )
        customerServiceBackCallback = callback
    }

    @SuppressLint("NewApi")
    private fun unregisterCustomerServiceBackCallback() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val callback = customerServiceBackCallback ?: return
        onBackInvokedDispatcher.unregisterOnBackInvokedCallback(callback)
        customerServiceBackCallback = null
    }

    private fun handleCustomerServiceBack() {
        val engine = flutterEngine ?: GlobalState.flutterEngine
        if (engine == null || customerServiceBackPending) {
            dispatchDefaultBack()
            return
        }

        customerServiceBackPending = true
        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            "fastcat/customer_service_back"
        ).invokeMethod("hideIfVisible", null, object : MethodChannel.Result {
            override fun success(result: Any?) {
                customerServiceBackPending = false
                if (result == true) return
                dispatchDefaultBack()
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                customerServiceBackPending = false
                dispatchDefaultBack()
            }

            override fun notImplemented() {
                customerServiceBackPending = false
                dispatchDefaultBack()
            }
        })
    }

    private fun dispatchDefaultBack() {
        runOnUiThread {
            unregisterCustomerServiceBackCallback()
            super@MainActivity.onBackPressed()
            registerCustomerServiceBackCallback()
        }
    }

    override fun onDestroy() {
        unregisterCustomerServiceBackCallback()
        GlobalState.flutterEngine = null
        super.onDestroy()
    }
}
