package com.sudovu.gamatube.gamatube

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle

class MediaPlaybackService : Service() {
    companion object {
        const val CHANNEL_ID = "gamatube_playback_channel"
        const val NOTIFICATION_ID = 1001

        const val ACTION_START = "com.sudovu.gamatube.action.START"
        const val ACTION_UPDATE = "com.sudovu.gamatube.action.UPDATE"
        const val ACTION_STOP = "com.sudovu.gamatube.action.STOP"
        const val ACTION_PLAY = "com.sudovu.gamatube.action.PLAY"
        const val ACTION_PAUSE = "com.sudovu.gamatube.action.PAUSE"
        const val ACTION_PREV = "com.sudovu.gamatube.action.PREV"
        const val ACTION_NEXT = "com.sudovu.gamatube.action.NEXT"
        const val ACTION_SEEK = "com.sudovu.gamatube.action.SEEK"

        var instance: MediaPlaybackService? = null
            private set
    }

    private var mediaSession: MediaSessionCompat? = null
    private var notificationManager: NotificationManager? = null
    private var wakeLock: PowerManager.WakeLock? = null

    private var currentTitle = "GAMATUBE Video"
    private var currentAuthor = "GAMATUBE"
    private var isPlaying = true
    private var currentPositionMs = 0L
    private var currentDurationMs = 0L

    var eventListener: ((String, Map<String, Any?>?) -> Unit)? = null

    inner class LocalBinder : Binder() {
        fun getService(): MediaPlaybackService = this@MediaPlaybackService
    }

    private val binder = LocalBinder()

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        instance = this
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        initMediaSession()
        acquireWakeLock()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "GAMATUBE Media Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Continuous background playback controls and seekbar for GAMATUBE"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "GAMATUBE:BackgroundPlaybackWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire(12 * 60 * 60 * 1000L) // 12 hours max
            }
        } catch (_: Exception) {}
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
    }

    private fun initMediaSession() {
        mediaSession = MediaSessionCompat(this, "GAMATUBE_MediaSession").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() {
                    handlePlay()
                }

                override fun onPause() {
                    handlePause()
                }

                override fun onSeekTo(pos: Long) {
                    handleSeekTo(pos)
                }

                override fun onSkipToNext() {
                    eventListener?.invoke("onNextClicked", null)
                }

                override fun onSkipToPrevious() {
                    eventListener?.invoke("onPreviousClicked", null)
                }

                override fun onFastForward() {
                    val newPos = currentPositionMs + 10000L
                    handleSeekTo(newPos)
                }

                override fun onRewind() {
                    val newPos = if (currentPositionMs > 10000L) currentPositionMs - 10000L else 0L
                    handleSeekTo(newPos)
                }
            })
            isActive = true
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                currentTitle = intent.getStringExtra("title") ?: currentTitle
                currentAuthor = intent.getStringExtra("author") ?: currentAuthor
                currentDurationMs = intent.getLongExtra("durationMs", currentDurationMs)
                currentPositionMs = intent.getLongExtra("positionMs", currentPositionMs)
                isPlaying = intent.getBooleanExtra("isPlaying", true)

                startForegroundServiceWithNotification()
            }
            ACTION_UPDATE -> {
                currentPositionMs = intent.getLongExtra("positionMs", currentPositionMs)
                val dur = intent.getLongExtra("durationMs", 0L)
                if (dur > 0L) currentDurationMs = dur
                isPlaying = intent.getBooleanExtra("isPlaying", isPlaying)

                updatePlaybackState(currentPositionMs, isPlaying)
                updateNotification()
            }
            ACTION_PLAY -> handlePlay()
            ACTION_PAUSE -> handlePause()
            ACTION_PREV -> eventListener?.invoke("onPreviousClicked", null)
            ACTION_NEXT -> eventListener?.invoke("onNextClicked", null)
            ACTION_SEEK -> {
                val pos = intent.getLongExtra("positionMs", currentPositionMs)
                handleSeekTo(pos)
            }
            ACTION_STOP -> {
                stopForegroundAndService()
            }
        }
        return START_NOT_STICKY
    }

    private fun handlePlay() {
        isPlaying = true
        updatePlaybackState(currentPositionMs, true)
        updateNotification()
        eventListener?.invoke("onPlayClicked", null)
    }

    private fun handlePause() {
        isPlaying = false
        updatePlaybackState(currentPositionMs, false)
        updateNotification()
        eventListener?.invoke("onPauseClicked", null)
    }

    private fun handleSeekTo(pos: Long) {
        currentPositionMs = pos
        updatePlaybackState(pos, isPlaying)
        updateNotification()
        eventListener?.invoke("onSeekTo", mapOf("positionMs" to pos))
    }

    fun updatePlaybackInfo(
        title: String,
        author: String,
        durationMs: Long,
        positionMs: Long,
        playing: Boolean
    ) {
        currentTitle = title
        currentAuthor = author
        currentDurationMs = durationMs
        currentPositionMs = positionMs
        isPlaying = playing

        startForegroundServiceWithNotification()
    }

    fun updatePosition(positionMs: Long, durationMs: Long, playing: Boolean) {
        currentPositionMs = positionMs
        if (durationMs > 0L) currentDurationMs = durationMs
        isPlaying = playing

        updatePlaybackState(currentPositionMs, isPlaying)
        updateNotification()
    }

    private fun startForegroundServiceWithNotification() {
        updatePlaybackState(currentPositionMs, isPlaying)
        val notification = buildNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification() {
        val notification = buildNotification()
        notificationManager?.notify(NOTIFICATION_ID, notification)
    }

    private fun updatePlaybackState(positionMs: Long, playing: Boolean) {
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

    private fun buildNotification(): Notification {
        val session = mediaSession

        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Previous
        val prevIntent = Intent(this, MediaPlaybackService::class.java).apply { action = ACTION_PREV }
        val prevPending = PendingIntent.getService(this, 1, prevIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        // Play / Pause
        val playPauseIntent = Intent(this, MediaPlaybackService::class.java).apply {
            action = if (isPlaying) ACTION_PAUSE else ACTION_PLAY
        }
        val playPausePending = PendingIntent.getService(this, 2, playPauseIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        // Next
        val nextIntent = Intent(this, MediaPlaybackService::class.java).apply { action = ACTION_NEXT }
        val nextPending = PendingIntent.getService(this, 3, nextIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val playPauseIcon = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        val playPauseText = if (isPlaying) "Pause" else "Play"

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(currentTitle)
            .setContentText(currentAuthor)
            .setContentIntent(contentPendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setOngoing(isPlaying)
            .addAction(android.R.drawable.ic_media_previous, "Previous", prevPending)
            .addAction(playPauseIcon, playPauseText, playPausePending)
            .addAction(android.R.drawable.ic_media_next, "Next", nextPending)

        if (session != null) {
            builder.setStyle(
                MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
        }

        return builder.build()
    }

    fun stopForegroundAndService() {
        releaseWakeLock()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        notificationManager?.cancel(NOTIFICATION_ID)
        stopSelf()
    }

    override fun onDestroy() {
        instance = null
        releaseWakeLock()
        mediaSession?.release()
        super.onDestroy()
    }
}
