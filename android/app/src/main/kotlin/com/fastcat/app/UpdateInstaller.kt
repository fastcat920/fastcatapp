package com.fastcat.app

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

/** Private verified APKs only; installation always goes through Android UI. */
class UpdateInstaller(private val activity: Activity) {
    fun install(path: String?, expectedHash: String?, result: MethodChannel.Result) {
        Thread {
            try {
                val root = File(activity.filesDir, "updates").canonicalFile
                val file = File(path ?: "").canonicalFile
                require(file.isFile && file.parentFile == root && file.extension == "apk")
                require(expectedHash != null && Regex("[a-f0-9]{64}").matches(expectedHash))
                val digest = MessageDigest.getInstance("SHA-256")
                file.inputStream().use { stream ->
                    val buffer = ByteArray(65536)
                    while (true) { val count = stream.read(buffer); if (count < 0) break; digest.update(buffer, 0, count) }
                }
                require(digest.digest().joinToString("") { "%02x".format(it) } == expectedHash)
                val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
                val pm = activity.packageManager
                val archive = pm.getPackageArchiveInfo(file.path, flags) ?: error("Invalid APK")
                val current = pm.getPackageInfo(activity.packageName, flags)
                require(archive.packageName == activity.packageName)
                val nextCode = if (Build.VERSION.SDK_INT >= 28) archive.longVersionCode else archive.versionCode.toLong()
                val oldCode = if (Build.VERSION.SDK_INT >= 28) current.longVersionCode else current.versionCode.toLong()
                require(nextCode > oldCode)
                if (Build.VERSION.SDK_INT >= 28) {
                    val installed = current.signingInfo?.apkContentsSigners ?: error("Missing installed signature")
                    val candidate = archive.signingInfo ?: error("Missing APK signature")
                    val history = if (candidate.hasMultipleSigners()) candidate.apkContentsSigners else candidate.signingCertificateHistory
                    if (candidate.hasMultipleSigners() || current.signingInfo?.hasMultipleSigners() == true) {
                        require(installed.toSet() == candidate.apkContentsSigners.toSet())
                    } else {
                        require(installed.all { signer -> history.any { it == signer } })
                    }
                } else {
                    val installed = current.signatures ?: error("Missing installed signature")
                    val candidate = archive.signatures ?: error("Missing APK signature")
                    require(installed.isNotEmpty() && installed.map { it.toCharsString() }.toSet() == candidate.map { it.toCharsString() }.toSet())
                }
                activity.runOnUiThread {
                    try {
                        if (Build.VERSION.SDK_INT >= 26 && !pm.canRequestPackageInstalls()) {
                            activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:${activity.packageName}")))
                            result.success("permission_required")
                        } else {
                            val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.fileProvider", file)
                            val intent = Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
                                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            require(intent.resolveActivity(pm) != null) { "Installer unavailable" }
                            activity.startActivity(intent)
                            result.success("installer_opened")
                        }
                    } catch (_: Exception) { result.error("INSTALL_UNAVAILABLE", "System installer unavailable", null) }
                }
            } catch (_: Exception) {
                activity.runOnUiThread { result.error("INSTALL_VALIDATION", "Package identity, version or signature validation failed", null) }
            }
        }.start()
    }
}
