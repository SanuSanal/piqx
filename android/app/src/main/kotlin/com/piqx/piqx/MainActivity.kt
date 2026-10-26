package com.piqx.piqx

import android.app.PictureInPictureParams
import android.app.UiModeManager
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import androidx.core.content.FileProvider
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi
import java.io.File

class MainActivity : FlutterActivity() {
    private var pipChannel: MethodChannel? = null

    // Set while the stream screen plays a video, so leaving the app shrinks it into a
    // picture-in-picture window.
    private var videoPlaying = false
    private var videoAspect = Rational(16, 9)

    // Set from entering picture-in-picture until the app is back in full; still set when
    // the activity stops, it means the user closed the window.
    private var pipShown = false

    private val supportsPip
        get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

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
        // Adds a script that runs as every page and frame of one of the app's WebViews starts,
        // other sites' frames included, before the page's own scripts. False when this
        // device's WebView can't.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "piqx/webview").setMethodCallHandler { call, result ->
            if (call.method != "addDocumentStartScript") return@setMethodCallHandler result.notImplemented()
            val id = call.argument<Number>("webView")?.toLong()
            val script = call.argument<String>("script")
            val webView = id?.let { WebViewFlutterAndroidExternalApi.getWebView(flutterEngine, it) }
            if (webView == null || script == null || !WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
                return@setMethodCallHandler result.success(false)
            }
            WebViewCompat.addDocumentStartJavaScript(webView, script, setOf("*"))
            result.success(true)
        }
        // Told by the stream screen whether a video is playing and its size; on Android 12+
        // the window then opens by itself on Home, and older versions use onUserLeaveHint.
        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "piqx/pip").apply {
            setMethodCallHandler { call, result ->
                if (call.method != "setVideo") return@setMethodCallHandler result.notImplemented()
                videoPlaying = call.argument<Boolean>("playing") ?: false
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                // Android refuses ratios wider or taller than 2.39:1.
                videoAspect = if (width > 0 && height > 0) {
                    Rational(width, height).coerceIn(Rational(100, 239), Rational(239, 100))
                } else {
                    Rational(16, 9)
                }
                if (supportsPip) setPictureInPictureParams(pipParams())
                result.success(supportsPip)
            }
        }
    }

    private fun pipParams(): PictureInPictureParams =
        PictureInPictureParams.Builder()
            .setAspectRatio(videoAspect)
            .apply { if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) setAutoEnterEnabled(videoPlaying) }
            .build()

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (videoPlaying && supportsPip && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            enterPictureInPictureMode(pipParams())
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (isInPictureInPictureMode) pipShown = true
        pipChannel?.invokeMethod("changed", isInPictureInPictureMode)
    }

    override fun onResume() {
        super.onResume()
        pipShown = false
    }

    override fun onStop() {
        super.onStop()
        if (!pipShown) return
        pipShown = false
        pipChannel?.invokeMethod("dismissed", null)
    }
}
