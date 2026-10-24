package com.acrostella.acrostella_analytics

import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

class UpdateChannel(private val activity: FlutterActivity, messenger: BinaryMessenger) : AutoCloseable {
    private val channel = MethodChannel(messenger, "acrostella/updates")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var closed = false

    init { channel.setMethodCallHandler(::handle) }

    @Suppress("DEPRECATION")
    private fun flags(): Int = if (Build.VERSION.SDK_INT >= 28) {
        PackageManager.GET_SIGNING_CERTIFICATES
    } else PackageManager.GET_SIGNATURES

    @Suppress("DEPRECATION")
    private fun current(): PackageInfo = activity.packageManager.getPackageInfo(activity.packageName, flags())

    @Suppress("DEPRECATION")
    private fun identity(info: PackageInfo): ApkIdentity {
        val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners
            else info.signatures
        val signers = signatures?.map { signature ->
            MessageDigest.getInstance("SHA-256").digest(signature.toByteArray())
                .joinToString("") { "%02x".format(it.toInt() and 0xff) }
        }?.toSet() ?: emptySet()
        val version = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
        return ApkIdentity(info.packageName, version, signers)
    }

    private fun canInstall() = Build.VERSION.SDK_INT < 26 || activity.packageManager.canRequestPackageInstalls()

    @Suppress("DEPRECATION")
    private fun verifiedFile(call: MethodCall): File {
        val path = requireNotNull(call.argument<String>("path"))
        val file = File(path).canonicalFile
        val root = File(activity.cacheDir, "app_updates").canonicalFile
        require(file.parentFile == root && file.name.matches(Regex("acrostella-[0-9]+\\.apk"))) { "Invalid path" }
        val bytes = requireNotNull(call.argument<Number>("bytes")).toLong()
        require(bytes in 1..(350L * 1024 * 1024) && file.isFile && file.length() == bytes) { "Invalid length" }
        val expectedHash = requireNotNull(call.argument<String>("sha256"))
        file.inputStream().use { ApkUpdatePolicy.validateHash(ApkUpdatePolicy.digest(it), expectedHash) }
        val archive = requireNotNull(activity.packageManager.getPackageArchiveInfo(file.path, flags()))
        require(requireNotNull(archive.applicationInfo).minSdkVersion <= Build.VERSION.SDK_INT) { "Unsupported Android version" }
        val version = requireNotNull(call.argument<Number>("code")).toLong()
        ApkUpdatePolicy.validate(identity(current()), identity(archive), version)
        return file
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "installed" -> {
                    val info = current()
                    result.success(mapOf("code" to identity(info).version, "name" to (info.versionName ?: ""),
                        "sdk" to Build.VERSION.SDK_INT, "canInstall" to canInstall()))
                }
                "permission" -> {
                    if (Build.VERSION.SDK_INT >= 26 && !canInstall()) {
                        activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:${activity.packageName}")))
                    }
                    result.success(null)
                }
                "verify", "install" -> worker.execute {
                    try {
                        val file = verifiedFile(call)
                        main.post {
                            if (closed) return@post
                            try {
                                if (call.method == "install") {
                                    require(canInstall()) { "Install permission required" }
                                    val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
                                    val intent = Intent(Intent.ACTION_VIEW).apply {
                                        setDataAndType(uri, "application/vnd.android.package-archive")
                                        clipData = ClipData.newRawUri("AcroStella update", uri)
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    }
                                    activity.startActivity(intent)
                                }
                                result.success(null)
                            } catch (_: Exception) {
                                result.error("install_unavailable", "No se pudo abrir el instalador.", null)
                            }
                        }
                    } catch (_: Exception) {
                        main.post {
                            if (!closed) result.error("invalid_update", "El APK no coincide con esta aplicación.", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            result.error("update_unavailable", "No se pudo completar la operación.", null)
        }
    }

    override fun close() {
        closed = true
        channel.setMethodCallHandler(null)
        worker.shutdownNow()
    }
}
