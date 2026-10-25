package com.piqx.piqx

import android.app.UiModeManager
import android.content.Intent
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Opens a downloaded update APK in the system package installer, and reports the
        // device's ABIs (best first) so the updater downloads the matching APK.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "piqx/installer").setMethodCallHandler { call, result ->
            if (call.method == "supportedAbis") return@setMethodCallHandler result.success(Build.SUPPORTED_ABIS.toList())
            if (call.method != "installApk") return@setMethodCallHandler result.notImplemented()
            val path = call.argument<String>("path")
                ?: return@setMethodCallHandler result.error("bad_args", "Missing APK path", null)
            try {
                val uri = FileProvider.getUriForFile(this, "$packageName.updates", File(path))
                val intent = Intent(Intent.ACTION_VIEW)
                    .setDataAndType(uri, "application/vnd.android.package-archive")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                result.success(null)
            } catch (e: Exception) {
                result.error("install_failed", e.message, null)
            }
        }
        // Makes the app's light/dark choice the app's night mode on Android 12+, so the
        // system launch screen (and the -night resources) follow it on the next start.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "piqx/theme").setMethodCallHandler { call, result ->
            if (call.method != "setNightMode") return@setMethodCallHandler result.notImplemented()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val dark = call.argument<Boolean>("dark") ?: true
                getSystemService(UiModeManager::class.java).setApplicationNightMode(
                    if (dark) UiModeManager.MODE_NIGHT_YES else UiModeManager.MODE_NIGHT_NO
                )
            }
            result.success(null)
        }
    }
}
