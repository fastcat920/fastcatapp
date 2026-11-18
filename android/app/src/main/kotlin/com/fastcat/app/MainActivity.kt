package com.fastcat.app

import android.annotation.SuppressLint
import android.os.Build
import android.os.Bundle
import android.content.Context
import android.app.UiModeManager
import android.content.res.Configuration
import android.view.inputmethod.InputMethodManager
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import com.fastcat.app.plugins.AppPlugin
import com.fastcat.app.plugins.ServicePlugin
import com.fastcat.app.plugins.TilePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var supportNotificationPermissionRequested = false
    private var customerServiceBackCallback: OnBackInvokedCallback? = null
    private var customerServiceBackPending = false

    override fun onCreate(savedInstanceState: Bundle?) {
        sanitizeSupportNotificationIntent(intent)
        super.onCreate(savedInstanceState)
        registerCustomerServiceBackCallback()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fastcat/tv_theme")
            .setMethodCallHandler { call, result ->
                if (call.method != "systemBrightness") {
                    result.notImplemented()
                } else if (!DeviceCapabilities.isTelevision(this)) {
                    result.success(null)
                } else {
                    val mode = (getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager)?.nightMode
                    val configured = applicationContext.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
                    result.success(when (mode) {
                        UiModeManager.MODE_NIGHT_YES -> "dark"
                        UiModeManager.MODE_NIGHT_NO -> "light"
                        else -> when (configured) {
                            Configuration.UI_MODE_NIGHT_YES -> "dark"
                            Configuration.UI_MODE_NIGHT_NO -> "light"
                            else -> null
                        }
                    })
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fastcat/update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBuild" -> result.success(BuildConfig.VERSION_CODE)
                    "install" -> UpdateInstaller(this).install(call.argument<String>("path"), call.argument<String>("sha256"), result)
                    else -> result.notImplemented()
                }
            }
        SupportPushService.createChannel(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fastcat/support_push").setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> {
                    val manager = getSystemService(android.app.NotificationManager::class.java)
                    val permission = Build.VERSION.SDK_INT < 33 || checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    val channel = if (Build.VERSION.SDK_INT >= 26) manager.getNotificationChannel("fastcat_support") else null
                    var googleServices = true
                    try { packageManager.getPackageInfo("com.google.android.gms", 0) }
                    catch (_: android.content.pm.PackageManager.NameNotFoundException) { googleServices = false }
                    result.success(mapOf("permission" to permission, "enabled" to manager.areNotificationsEnabled(), "channelEnabled" to (channel == null || channel.importance != android.app.NotificationManager.IMPORTANCE_NONE), "googleServices" to googleServices))
                }
                "badge" -> {
                    SupportPushService.updateBadge(this, (call.arguments as? Number)?.toInt() ?: 0)
                    // Android launchers own numeric badges; clear our posted
                    // notifications when authoritative unread count reaches 0.
                    if ((call.arguments as? Number)?.toInt() == 0) {
                        val manager = getSystemService(android.app.NotificationManager::class.java)
                        if (Build.VERSION.SDK_INT >= 23) {
                            manager.activeNotifications.filter { it.tag?.startsWith("support:") == true || it.tag?.startsWith("fastcat-support") == true }
                                .forEach { manager.cancel(it.tag, it.id) }
                        }
                    }
                    result.success(null)
                }
                "notification" -> {
                    val extras = intent?.extras
                    if (extras?.getString("type") == "support.reply") {
                        result.success(mapOf("type" to "support.reply", "conversationId" to extras.getString("conversationId"), "messageId" to extras.getString("messageId")))
                        intent.removeExtra("type")
                    } else result.success(null)
                }
                "showReply" -> {
                    val conversation = call.argument<String>("conversationId")
                    val message = call.argument<String>("messageId")
                    if (conversation == null || message == null) {
                        result.error("ARGUMENT", "Missing reply identity", null)
                    } else {
                        SupportPushService.showReply(this, conversation, message, call.argument<Number>("unreadCount")?.toInt())
                        result.success(null)
                    }
                }
                "token" -> {
                    if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                        if (!supportNotificationPermissionRequested) {
                            supportNotificationPermissionRequested = true
                            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 9721)
                        }
                        result.success(null)
                    } else {
                        try {
                            try {
                                packageManager.getPackageInfo("com.google.android.gms", 0)
                            } catch (_: android.content.pm.PackageManager.NameNotFoundException) {
                                result.success(null)
                                return@setMethodCallHandler
                            }
                            com.google.firebase.FirebaseApp.initializeApp(this)
                            com.google.firebase.messaging.FirebaseMessaging.getInstance().token
                                .addOnSuccessListener { result.success(it) }
                                .addOnFailureListener { result.error("FCM", "Token unavailable", null) }
                        } catch (e: Exception) { result.error("FCM_CONFIG", "Firebase configuration unavailable", null) }
                    }
                }
                else -> result.notImplemented()
            }
        }

        flutterEngine.plugins.add(AppPlugin())
        flutterEngine.plugins.add(ServicePlugin)
        flutterEngine.plugins.add(TilePlugin())
        GlobalState.flutterEngine = flutterEngine
        GlobalState.syncStatus()
    }

    override fun onResume() {
        super.onResume()
        SupportPushService.appForeground = true
    }

    override fun onPause() {
        SupportPushService.appForeground = false
        super.onPause()
    }

    // Notification metadata belongs to the support channel, not GoRouter.
    // Also handles notifications issued by older builds with fastcat://support.
    private fun sanitizeSupportNotificationIntent(intent: android.content.Intent?) {
        if (intent?.getStringExtra("type") == "support.reply") {
            intent.data = null
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        sanitizeSupportNotificationIntent(intent)
        super.onNewIntent(intent)
        setIntent(intent)
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

        dismissCustomerServiceKeyboard()
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

    private fun dismissCustomerServiceKeyboard() {
        val inputMethodManager =
            getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        val focusedView = currentFocus ?: window.decorView
        inputMethodManager?.hideSoftInputFromWindow(focusedView.windowToken, 0)
        focusedView.clearFocus()
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
