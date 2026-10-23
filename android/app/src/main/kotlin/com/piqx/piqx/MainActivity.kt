package com.piqx.piqx

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Opens a downloaded update APK in the system package installer.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "piqx/installer").setMethodCallHandler { call, result ->
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
    }
}
