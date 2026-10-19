package com.sudovu.gamatube.gamatube

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.content.Context
import android.content.Intent
import android.os.Build
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Rational
import androidx.core.app.NotificationCompat
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL_PIP = "com.sudovu.gamatube/pip"
    private val CHANNEL_MEDIA = "com.sudovu.gamatube/media"

    private var mediaSession: MediaSessionCompat? = null
    private var notificationManager: NotificationManager? = null
    private var methodChannelMedia: MethodChannel? = null
    private var pipMethodChannel: MethodChannel? = null
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "gamatube_playback_channel"

    private var currentTitle = "GAMATUBE Video"
    private var currentAuthor = "GAMATUBE"
    private var isPlaying = true
    private var currentPositionMs = 0L
    private var currentDurationMs = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        initMediaSession()

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

        // Media Notification & Seekbar Channel
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

                        updateMediaSession(currentPositionMs, isPlaying)
                        showMediaNotification()
                        result.success(true)
                    }
                    "updatePlaybackState" -> {
                        val pos = (call.argument<Number>("positionMs"))?.toLong() ?: currentPositionMs
                        val dur = (call.argument<Number>("durationMs"))?.toLong() ?: currentDurationMs
                        val playing = call.argument<Boolean>("isPlaying") ?: isPlaying
                        currentPositionMs = pos
                        if (dur > 0) currentDurationMs = dur
                        isPlaying = playing
                        updateMediaSession(currentPositionMs, isPlaying)
                        showMediaNotification()
                        result.success(true)
                    }
                    "stopPlayback" -> {
                        hideMediaNotification()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun initMediaSession() {
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "GAMATUBE Media Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Media playback controls and seekbar for GAMATUBE"
                setShowBadge(false)
            }
            notificationManager?.createNotificationChannel(channel)
        }

        mediaSession = MediaSessionCompat(this, "GAMATUBE_MediaSession").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() {
                    isPlaying = true
                    updateMediaSession(currentPositionMs, true)
                    showMediaNotification()
                    methodChannelMedia?.invokeMethod("onPlayClicked", null)
                }

                override fun onPause() {
                    isPlaying = false
                    updateMediaSession(currentPositionMs, false)
                    showMediaNotification()
                    methodChannelMedia?.invokeMethod("onPauseClicked", null)
                }

                override fun onSeekTo(pos: Long) {
                    currentPositionMs = pos
                    updateMediaSession(pos, isPlaying)
                    showMediaNotification()
                    methodChannelMedia?.invokeMethod("onSeekTo", mapOf("positionMs" to pos))
                }

                override fun onSkipToNext() {
                    methodChannelMedia?.invokeMethod("onNextClicked", null)
                }

                override fun onSkipToPrevious() {
                    methodChannelMedia?.invokeMethod("onPreviousClicked", null)
                }

                override fun onFastForward() {
                    val newPos = currentPositionMs + 10000
                    onSeekTo(newPos)
                }

                override fun onRewind() {
                    val newPos = if (currentPositionMs > 10000) currentPositionMs - 10000 else 0
                    onSeekTo(newPos)
                }
            })
            isActive = true
        }
    }

    private fun updateMediaSession(positionMs: Long, playing: Boolean) {
        val state = if (playing) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        val actions = PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_PLAY_PAUSE or
                PlaybackStateCompat.ACTION_SEEK_TO or
                PlaybackStateCompat.ACTION_FAST_FORWARD or
                PlaybackStateCompat.ACTION_REWIND or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS

        val playbackState = PlaybackStateCompat.Builder()
            .setActions(actions)
            .setState(state, positionMs, 1.0f)
            .build()

        mediaSession?.setPlaybackState(playbackState)

        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, currentTitle)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, currentAuthor)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, currentDurationMs)
            .build()

        mediaSession?.setMetadata(metadata)
    }

    private fun showMediaNotification() {
        val session = mediaSession ?: return

        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val prevIntent = androidx.media.session.MediaButtonReceiver.buildMediaButtonPendingIntent(
            this, PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
        )
        val playPauseIntent = androidx.media.session.MediaButtonReceiver.buildMediaButtonPendingIntent(
            this, if (isPlaying) PlaybackStateCompat.ACTION_PAUSE else PlaybackStateCompat.ACTION_PLAY
        )
        val nextIntent = androidx.media.session.MediaButtonReceiver.buildMediaButtonPendingIntent(
            this, PlaybackStateCompat.ACTION_SKIP_TO_NEXT
        )

        val playPauseIcon = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        val playPauseTitle = if (isPlaying) "Pause" else "Play"

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(currentTitle)
            .setContentText(currentAuthor)
            .setContentIntent(contentIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setOngoing(isPlaying)
            .addAction(android.R.drawable.ic_media_previous, "Previous", prevIntent)
            .addAction(playPauseIcon, playPauseTitle, playPauseIntent)
            .addAction(android.R.drawable.ic_media_next, "Next", nextIntent)
            .setStyle(
                androidx.media.app.NotificationCompat.MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .build()

        notificationManager?.notify(NOTIFICATION_ID, notification)
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

    private fun hideMediaNotification() {
        notificationManager?.cancel(NOTIFICATION_ID)
    }

    override fun onDestroy() {
        hideMediaNotification()
        mediaSession?.release()
        super.onDestroy()
    }
}
