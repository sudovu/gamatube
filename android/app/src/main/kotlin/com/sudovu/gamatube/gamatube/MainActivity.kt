package com.sudovu.gamatube.gamatube

import android.app.PictureInPictureParams
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.res.Configuration
import android.os.Build
import android.os.IBinder
import android.util.Rational
import android.view.ViewGroup
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL_PIP = "com.sudovu.gamatube/pip"
    private val CHANNEL_MEDIA = "com.sudovu.gamatube/media"

    private var methodChannelMedia: MethodChannel? = null
    private var pipMethodChannel: MethodChannel? = null

    private var mediaService: MediaPlaybackService? = null
    private var isServiceBound = false

    private var currentTitle = "GAMATUBE Video"
    private var currentAuthor = "GAMATUBE"
    private var isPlaying = true
    private var currentPositionMs = 0L
    private var currentDurationMs = 0L

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val binder = service as? MediaPlaybackService.LocalBinder
            mediaService = binder?.getService()
            isServiceBound = true
            mediaService?.eventListener = { event, data ->
                runOnUiThread {
                    methodChannelMedia?.invokeMethod(event, data)
                }
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            mediaService = null
            isServiceBound = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Bind to background media playback service
        val intent = Intent(this, MediaPlaybackService::class.java)
        bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)

        // PiP Channel
        pipMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_PIP).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterPiP" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            try {
                                val aspectRatio = Rational(16, 9)
                                val builder = PictureInPictureParams.Builder()
                                    .setAspectRatio(aspectRatio)
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    builder.setAutoEnterEnabled(true)
                                }
                                val entered = enterPictureInPictureMode(builder.build())
                                result.success(entered)
                            } catch (e: Exception) {
                                result.error("PIP_ERROR", e.localizedMessage, null)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    "isPiPSupported" -> {
                        val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE)
                        result.success(supported)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Media Notification & Background Playback Channel
        methodChannelMedia = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_MEDIA).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "startPlayback" -> {
                        currentTitle = call.argument<String>("title") ?: "GAMATUBE Video"
                        currentAuthor = call.argument<String>("author") ?: "GAMATUBE"
                        currentDurationMs = (call.argument<Number>("durationMs"))?.toLong() ?: 0L
                        currentPositionMs = (call.argument<Number>("positionMs"))?.toLong() ?: 0L
                        isPlaying = call.argument<Boolean>("isPlaying") ?: true

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            try {
                                setPictureInPictureParams(
                                    PictureInPictureParams.Builder()
                                        .setAspectRatio(Rational(16, 9))
                                        .setAutoEnterEnabled(true)
                                        .build()
                                )
                            } catch (_: Exception) {}
                        }

                        startForegroundMediaService()
                        result.success(true)
                    }
                    "updatePlaybackState" -> {
                        val pos = (call.argument<Number>("positionMs"))?.toLong() ?: currentPositionMs
                        val dur = (call.argument<Number>("durationMs"))?.toLong() ?: currentDurationMs
                        val playing = call.argument<Boolean>("isPlaying") ?: isPlaying
                        currentPositionMs = pos
                        if (dur > 0L) currentDurationMs = dur
                        isPlaying = playing

                        mediaService?.updatePosition(currentPositionMs, currentDurationMs, isPlaying)
                        result.success(true)
                    }
                    "stopPlayback" -> {
                        isPlaying = false
                        mediaService?.stopForegroundAndService()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun startForegroundMediaService() {
        val intent = Intent(this, MediaPlaybackService::class.java).apply {
            action = MediaPlaybackService.ACTION_START
            putExtra("title", currentTitle)
            putExtra("author", currentAuthor)
            putExtra("durationMs", currentDurationMs)
            putExtra("positionMs", currentPositionMs)
            putExtra("isPlaying", isPlaying)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }

        mediaService?.eventListener = { event, data ->
            runOnUiThread {
                methodChannelMedia?.invokeMethod(event, data)
            }
        }
    }

    override fun onPause() {
        super.onPause()
        if (isPlaying) {
            resumeWebViewPlayback()
        }
    }

    override fun onStop() {
        super.onStop()
        if (isPlaying) {
            resumeWebViewPlayback()
        }
    }

    private fun resumeWebViewPlayback() {
        try {
            val root = window?.decorView as? ViewGroup
            root?.let { findAndResumeWebViews(it) }
        } catch (_: Exception) {}
    }

    private fun findAndResumeWebViews(viewGroup: ViewGroup) {
        for (i in 0 until viewGroup.childCount) {
            val child = viewGroup.getChildAt(i)
            if (child is WebView) {
                child.onResume()
                child.resumeTimers()
            } else if (child is ViewGroup) {
                findAndResumeWebViews(child)
            }
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isPlaying && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val aspectRatio = Rational(16, 9)
                val builder = PictureInPictureParams.Builder()
                    .setAspectRatio(aspectRatio)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    builder.setAutoEnterEnabled(true)
                }
                enterPictureInPictureMode(builder.build())
            } catch (_: Exception) {}
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipMethodChannel?.invokeMethod("onPiPModeChanged", mapOf("isInPiP" to isInPictureInPictureMode))
    }

    override fun onDestroy() {
        if (isServiceBound) {
            unbindService(serviceConnection)
            isServiceBound = false
        }
        super.onDestroy()
    }
}
