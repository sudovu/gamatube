import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../api/video_platform_service.dart';
import '../models/channel.dart';
import '../models/comment.dart';
import '../models/video.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../providers/playback_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_colors.dart';
import '../widgets/video_card.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Video video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> with WidgetsBindingObserver {
  static const MethodChannel _pipChannel = MethodChannel('com.sudovu.gamatube/pip');
  late YoutubePlayerController _controller;
  final TextEditingController _commentController = TextEditingController();
  bool _isDescriptionExpanded = false;
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _isSubscribed = false;
  bool _isLoadingComments = true;
  bool _isAutoplayEnabled = true;
  bool _isLooping = false;
  bool _isCaptionsEnabled = true;
  double _playbackSpeed = 1.0;
  String _selectedQuality = 'Auto (1080p)';
  List<Comment> _comments = [];
  List<Video> _relatedVideos = [];
  String? _aiSummary;
  bool _isGeneratingSummary = false;
  bool _isPlaying = true;
  bool _isPiPActive = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadedQuality;
  bool _hasPlaybackError = false;
  String _errorMessage = '';

  String _resolveErrorMessage(YoutubeError error) {
    switch (error) {
      case YoutubeError.notEmbeddable:
      case YoutubeError.sameAsNotEmbeddable:
      case YoutubeError.sameAsNotEmbeddable2:
        return 'The video publisher has restricted playback in third-party embedded apps.';
      case YoutubeError.videoNotFound:
      case YoutubeError.cannotFindVideo:
        return 'This video is currently unavailable or has been removed.';
      case YoutubeError.html5Error:
        return 'HTML5 playback decoder error encountered for this video format.';
      default:
        return 'Playback was interrupted or restricted by the video host.';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlayer();
    _loadMetadata();
    _initMediaChannelHandlers();
    _initPiPChannelHandlers();
  }

  void _initPiPChannelHandlers() {
    _pipChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPiPModeChanged') {
        final isInPiP = call.arguments['isInPiP'] as bool? ?? false;
        if (mounted) {
          setState(() {
            _isPiPActive = isInPiP;
          });
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final settings = context.read<SettingsProvider>().settings;
    if (settings.backgroundAudioEnabled) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive ||
          state == AppLifecycleState.hidden) {
        // Only enter PiP and continue playback if video is actively playing!
        // When video is paused, do NOT open in PiP mode!
        if (_isPlaying && settings.pipEnabled && !_isPiPActive) {
          _enterNativePiP();
        }
        if (_isPlaying) {
          _controller.playVideo();
          // Crucial: Android WebView can dispatch an internal pause event 200-500ms after app minimize
          // Enforce play commands to ensure continuous background audio
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _isPlaying) _controller.playVideo();
          });
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted && _isPlaying) _controller.playVideo();
          });
        }
      } else if (state == AppLifecycleState.resumed) {
        if (_isPlaying) {
          _controller.playVideo();
        }
      }
    } else {
      if (state == AppLifecycleState.paused) {
        _controller.pauseVideo();
        _mediaChannel.invokeMethod('stopPlayback').catchError((_) {});
      }
    }
  }

  static const MethodChannel _mediaChannel = MethodChannel('com.sudovu.gamatube/media');
  Timer? _mediaSyncTimer;

  Future<void> _initMediaChannelHandlers() async {
    _mediaChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPlayClicked':
          _controller.playVideo();
          break;
        case 'onPauseClicked':
          _controller.pauseVideo();
          break;
        case 'onSeekTo':
          final posMs = call.arguments['positionMs'] as int? ?? 0;
          _controller.seekTo(seconds: (posMs / 1000).toDouble());
          break;
        case 'onNextClicked':
          if (_relatedVideos.isNotEmpty) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => VideoPlayerScreen(video: _relatedVideos.first),
              ),
            );
          }
          break;
        case 'onPreviousClicked':
          _controller.seekTo(seconds: 0);
          break;
      }
    });

    final durMs = (widget.video.duration?.inMilliseconds ?? (5 * 60 * 1000));
    try {
      await _mediaChannel.invokeMethod('startPlayback', {
        'title': widget.video.title,
        'author': widget.video.channelTitle,
        'durationMs': durMs,
        'positionMs': 0,
        'isPlaying': true,
      });
    } catch (_) {}

    _mediaSyncTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      try {
        final posSeconds = await _controller.currentTime;
        final durSeconds = await _controller.duration;
        final durMs = durSeconds > 0
            ? (durSeconds * 1000).toInt()
            : (widget.video.duration?.inMilliseconds ?? (5 * 60 * 1000));
        await _mediaChannel.invokeMethod('updatePlaybackState', {
          'positionMs': (posSeconds * 1000).toInt(),
          'durationMs': durMs,
          'isPlaying': true,
        });
      } catch (_) {}
    });
  }

  Future<void> _enterNativePiP() async {
    try {
      final bool? success = await _pipChannel.invokeMethod<bool>('enterPiP');
      if (mounted) {
        setState(() => _isPiPActive = success == true);
        if (success == true) {
          _controller.playVideo();
        }
      }
    } catch (_) {
      // Fallback
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final library = context.read<LibraryProvider>();
    _isLiked = library.isVideoLiked(widget.video.id);
    _isSubscribed = library.isChannelSubscribed(widget.video.channelTitle);
  }

  void _initPlayer() {
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.video.id,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: false,
        enableCaption: true,
        origin: 'https://www.youtube.com',
        playsInline: true,
        privacyEnhancedMode: false,
      ),
    );

    _controller.listen((event) {
      if (!mounted) return;
      if (event.hasError) {
        setState(() {
          _hasPlaybackError = true;
          _errorMessage = _resolveErrorMessage(event.error);
        });
      }
      final state = event.playerState;
      if (state == PlayerState.playing) {
        if (_hasPlaybackError) {
          setState(() => _hasPlaybackError = false);
        }
        _isPlaying = true;
        _mediaChannel.invokeMethod('updatePlaybackState', {'isPlaying': true}).catchError((_) {});
      } else if (state == PlayerState.paused) {
        _isPlaying = false;
        _mediaChannel.invokeMethod('updatePlaybackState', {'isPlaying': false}).catchError((_) {});
      } else if (state == PlayerState.ended) {
        _isPlaying = false;
        _mediaChannel.invokeMethod('updatePlaybackState', {'isPlaying': false}).catchError((_) {});
        if (_isLooping) {
          _controller.seekTo(seconds: 0);
          _controller.playVideo();
        } else if (_isAutoplayEnabled && _relatedVideos.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(video: _relatedVideos.first),
            ),
          );
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final playback = context.read<PlaybackProvider>();
      final library = context.read<LibraryProvider>();
      playback.loadVideo(widget.video);
      library.recordWatch(widget.video);
    });
  }

  Future<void> _loadMetadata() async {
    final service = context.read<VideoPlatformService>();
    final library = context.read<LibraryProvider>();
    try {
      final comments = await service.getComments(widget.video.id);
      final localComments = library.getComments(widget.video.id);
      final related = await service.getRelatedVideos(widget.video.id);
      if (mounted) {
        setState(() {
          _comments = [...localComments, ...comments];
          _relatedVideos = related;
          _isLoadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) {
        final localComments = library.getComments(widget.video.id);
        setState(() {
          _comments = localComments;
          _isLoadingComments = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mediaSyncTimer?.cancel();
    _mediaChannel.invokeMethod('stopPlayback').catchError((_) {});
    _controller.close();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPiPActive) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: YoutubePlayer(
              controller: _controller,
              aspectRatio: 16 / 9,
            ),
          ),
        ),
      );
    }

    final playback = context.watch<PlaybackProvider>();
    final library = context.watch<LibraryProvider>();
    final theme = Theme.of(context);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.space): () {
          playback.togglePlayPause();
          if (playback.isPlaying) {
            _controller.playVideo();
          } else {
            _controller.pauseVideo();
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          playback.seekForward(10);
          _controller.seekTo(
            seconds: playback.currentPosition.inSeconds.toDouble() + 10,
          );
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          playback.seekRewind(10);
          _controller.seekTo(
            seconds: (playback.currentPosition.inSeconds.toDouble() - 10).clamp(0, double.infinity),
          );
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPlayerView(playback),
                              _buildVideoInfo(theme, library),
                              _buildAISummarySection(theme),
                              _buildCommentsPreviewCard(theme),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: SingleChildScrollView(
                          child: _buildRelatedVideosList(theme),
                        ),
                      ),
                    ],
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPlayerView(playback),
                      _buildVideoInfo(theme, library),
                      _buildAISummarySection(theme),
                      _buildCommentsPreviewCard(theme),
                      _buildRelatedVideosList(theme),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerView(PlaybackProvider playback) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (playback.savedResumePosition != null)
          Container(
            color: const Color(0xFFCC0000),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.history_toggle_off_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Resume where you left off (${playback.savedResumePosition!.inMinutes}:${(playback.savedResumePosition!.inSeconds % 60).toString().padLeft(2, '0')})?',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _controller.seekTo(seconds: playback.savedResumePosition!.inSeconds.toDouble());
                    playback.clearResumePrompt();
                  },
                  child: const Text('Resume', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  onPressed: () => playback.clearResumePrompt(),
                ),
              ],
            ),
          ),
        // Top Player Navigation & Action Strip (YouTube Minimalist Aesthetic)
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
                tooltip: 'Minimize',
                onPressed: () async {
                  await context.read<LibraryProvider>().loadLibraryData();
                  if (!mounted) return;
                  Navigator.pop(context);
                },
              ),
              const Spacer(),
              // Autoplay switch
              Tooltip(
                message: _isAutoplayEnabled ? 'Autoplay is on' : 'Autoplay is off',
                child: IconButton(
                  icon: Icon(
                    _isAutoplayEnabled ? Icons.play_circle_filled_rounded : Icons.play_circle_outline_rounded,
                    color: _isAutoplayEnabled ? Colors.white : Colors.white60,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _isAutoplayEnabled = !_isAutoplayEnabled);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isAutoplayEnabled ? 'Autoplay is on' : 'Autoplay is off'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
              // Captions toggle
              Tooltip(
                message: 'Subtitles/CC',
                child: IconButton(
                  icon: Icon(
                    _isCaptionsEnabled ? Icons.closed_caption_rounded : Icons.closed_caption_outlined,
                    color: _isCaptionsEnabled ? Colors.white : Colors.white60,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _isCaptionsEnabled = !_isCaptionsEnabled);
                  },
                ),
              ),
              // Settings Gear (Quality, Speed, Loop, Sleep Timer, Stats)
              Tooltip(
                message: 'Settings',
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                  onPressed: () => _showPlayerSettings(context),
                ),
              ),
            ],
          ),
        ),
        // Active YouTube Player View with Ambient Mode Glow Effect
        Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomCenter,
                    radius: 1.3,
                    colors: [
                      AppColors.primary.withAlpha(45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  YoutubePlayer(
                    controller: _controller,
                    aspectRatio: 16 / 9,
                  ),
                  if (_hasPlaybackError)
                    _buildPlaybackErrorOverlay(theme),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaybackErrorOverlay(ThemeData theme) {
    return Container(
      color: Colors.black.withAlpha(240),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_disabled_rounded,
                color: AppColors.primary,
                size: 38,
              ),
              const SizedBox(height: 8),
              const Text(
                'Playback Restricted by Publisher',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'The video owner does not permit playback in embedded players.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(190),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 15),
                    label: const Text('Watch on YouTube', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () async {
                      final url = Uri.parse('https://www.youtube.com/watch?v=${widget.video.id}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  if (_relatedVideos.isNotEmpty)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.skip_next_rounded, size: 15),
                      label: const Text('Play Next', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerScreen(video: _relatedVideos.first),
                          ),
                        );
                      },
                    ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 15),
                    label: const Text('Retry', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      setState(() => _hasPlaybackError = false);
                      _controller.loadVideoById(videoId: widget.video.id);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoInfo(ThemeData theme, LibraryProvider library) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.video.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),

          // Metadata + Description Accordion
          GestureDetector(
            onTap: () {
              setState(() => _isDescriptionExpanded = !_isDescriptionExpanded);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF272727) : const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${widget.video.formattedViews} views  •  ${widget.video.formattedTimeAgo}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF1F1F1) : const Color(0xFF0F0F0F),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '#trending',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3EA6FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.video.description.isNotEmpty
                        ? widget.video.description
                        : 'No additional description provided.',
                    maxLines: _isDescriptionExpanded ? 100 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isDescriptionExpanded ? 'Show less' : '...more',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Channel Row with YouTube-style Subscribe Button
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: isDark ? const Color(0xFF272727) : const Color(0xFFEEEEEE),
                backgroundImage: widget.video.channelAvatarUrl != null
                    ? NetworkImage(widget.video.channelAvatarUrl!)
                    : null,
                child: widget.video.channelAvatarUrl == null
                    ? Text(
                        widget.video.channelTitle.isNotEmpty ? widget.video.channelTitle[0] : 'C',
                        style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.video.channelTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const Text(
                      '1.24M subscribers',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // High contrast pill subscribe button
              GestureDetector(
                onTap: () async {
                  final channel = Channel(
                    id: widget.video.channelId.isNotEmpty ? widget.video.channelId : widget.video.channelTitle,
                    title: widget.video.channelTitle,
                    description: '',
                    avatarUrl: widget.video.channelAvatarUrl ?? '',
                  );
                  await library.toggleSubscribe(channel);
                  final isNowSubscribed = library.isChannelSubscribed(widget.video.channelTitle);
                  setState(() => _isSubscribed = isNowSubscribed);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isNowSubscribed
                            ? 'Subscribed to ${widget.video.channelTitle}'
                            : 'Unsubscribed from ${widget.video.channelTitle}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: _isSubscribed
                        ? (isDark ? const Color(0xFF272727) : const Color(0xFFF2F2F2))
                        : (isDark ? Colors.white : const Color(0xFF0F0F0F)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSubscribed) ...[
                        const Icon(Icons.notifications_active_rounded, size: 16),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        _isSubscribed ? 'Subscribed' : 'Subscribe',
                        style: TextStyle(
                          color: _isSubscribed
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? Colors.black : Colors.white),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // YouTube Horizontal Action Pills Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Segmented Like / Dislike Pill
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF272727) : const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Like
                      InkWell(
                        onTap: () async {
                          await library.toggleLike(widget.video);
                          final isNowLiked = library.isVideoLiked(widget.video.id);
                          setState(() {
                            _isLiked = isNowLiked;
                            if (_isLiked) _isDisliked = false;
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isNowLiked ? 'Added to Liked videos' : 'Removed from Liked videos'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(
                                _isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                                size: 18,
                                color: _isLiked ? AppColors.primary : null,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isLiked ? '125K' : '124K',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _isLiked ? AppColors.primary : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Divider
                      Container(
                        height: 20,
                        width: 1,
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      // Dislike
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isDisliked = !_isDisliked;
                            if (_isDisliked) {
                              _isLiked = false;
                              if (library.isVideoLiked(widget.video.id)) {
                                library.toggleLike(widget.video);
                              }
                            }
                          });
                        },
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            _isDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                            size: 18,
                            color: _isDisliked ? AppColors.primary : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Share Pill
                _buildActionPill(
                  isDark: isDark,
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () => _showShareModal(context),
                ),
                const SizedBox(width: 8),

                // Remix Pill
                _buildActionPill(
                  isDark: isDark,
                  icon: Icons.content_cut_rounded,
                  label: 'Remix',
                  onTap: () => _showRemixSheet(context),
                ),
                const SizedBox(width: 8),

                // AI Summary Pill
                _buildActionPill(
                  isDark: isDark,
                  icon: Icons.auto_awesome_rounded,
                  label: 'Summary',
                  iconColor: const Color(0xFF3EA6FF),
                  onTap: () => _handleAISummary(),
                ),
                const SizedBox(width: 8),

                // Download Pill with quality selector
                _buildActionPill(
                  isDark: isDark,
                  icon: _isDownloading
                      ? Icons.downloading_rounded
                      : (library.isVideoDownloaded(widget.video.id)
                          ? Icons.download_done_rounded
                          : Icons.download_outlined),
                  label: _isDownloading
                      ? '${(_downloadProgress * 100).toInt()}%'
                      : (library.isVideoDownloaded(widget.video.id) ? 'Downloaded' : 'Download'),
                  iconColor: library.isVideoDownloaded(widget.video.id)
                      ? const Color(0xFF2BA640)
                      : (_isDownloading ? AppColors.primary : null),
                  onTap: () => _showDownloadQualityChooser(context),
                ),
                const SizedBox(width: 8),

                // Save to Playlist Pill
                _buildActionPill(
                  isDark: isDark,
                  icon: Icons.playlist_add_rounded,
                  label: 'Save',
                  onTap: () => _showSavePlaylistModal(context, library),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF272727) : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsPreviewCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      child: InkWell(
        onTap: () => _showCommentsBottomSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF272727) : const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Comments',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_comments.isNotEmpty ? _comments.length : "1.2K"}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primary,
                    child: Text('U', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _comments.isNotEmpty
                          ? _comments.first.text
                          : 'This video provides exceptional value! Glad I found this.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommentsBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.read<AuthProvider>();
    final library = context.read<LibraryProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF181818) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              minChildSize: 0.4,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(120),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Comments (${_comments.isNotEmpty ? _comments.length : 1240})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _isLoadingComments
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                          : _comments.isEmpty
                              ? const Center(child: Text('No comments yet. Be the first to comment!'))
                              : ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _comments.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final c = _comments[index];
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundImage: c.authorAvatarUrl.isNotEmpty
                                              ? NetworkImage(c.authorAvatarUrl)
                                              : null,
                                          backgroundColor: isDark ? const Color(0xFF272727) : const Color(0xFFEEEEEE),
                                          child: c.authorAvatarUrl.isEmpty
                                              ? Text(c.authorName.isNotEmpty ? c.authorName[0] : 'U')
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    c.authorName,
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    c.formattedTimeAgo.isNotEmpty ? c.formattedTimeAgo : 'Just now',
                                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(c.text, style: const TextStyle(fontSize: 13, height: 1.3)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                    ),
                    // YouTube interactive comment composer
                    Container(
                      padding: EdgeInsets.only(
                        left: 14,
                        right: 14,
                        top: 8,
                        bottom: MediaQuery.of(ctx).viewInsets.bottom + 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF202020) : const Color(0xFFF9F9F9),
                        border: Border(
                          top: BorderSide(
                            color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primary,
                            backgroundImage: (auth.isAuthenticated && auth.user?.avatarUrl != null)
                                ? NetworkImage(auth.user!.avatarUrl!)
                                : null,
                            child: (auth.isAuthenticated && auth.user?.avatarUrl != null)
                                ? null
                                : Text(
                                    auth.isAuthenticated && auth.user?.displayName.isNotEmpty == true
                                        ? auth.user!.displayName[0].toUpperCase()
                                        : 'G',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: auth.isAuthenticated ? 'Add a comment...' : 'Add a public comment...',
                                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFEEEEEE),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                            onPressed: () {
                              final text = _commentController.text.trim();
                              if (text.isEmpty) return;
                              final newComment = Comment(
                                id: 'c_${DateTime.now().millisecondsSinceEpoch}',
                                authorName: auth.isAuthenticated && auth.user?.displayName.isNotEmpty == true
                                    ? auth.user!.displayName
                                    : 'GamaTube User',
                                authorAvatarUrl: auth.user?.avatarUrl ?? '',
                                text: text,
                                publishedAt: DateTime.now(),
                              );
                              library.addComment(widget.video.id, newComment);
                              _commentController.clear();
                              setSheetState(() {
                                _comments.insert(0, newComment);
                              });
                              setState(() {});
                              FocusScope.of(ctx).unfocus();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showDownloadQualityChooser(BuildContext context) {
    final library = context.read<LibraryProvider>();
    final isDownloaded = library.isVideoDownloaded(widget.video.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDownloaded) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Downloaded Video'),
          content: Text(
            'This video is already saved in your offline library (${_downloadedQuality ?? "High 1080p"}). Do you want to remove it?',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                library.removeDownload(widget.video.id);
                setState(() => _downloadedQuality = null);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Removed from Offline Downloads')),
                );
              },
              child: const Text('Delete Download'),
            ),
          ],
        ),
      );
      return;
    }

    final qualities = [
      {'label': 'Full HD (1080p)', 'size': '142 MB', 'badge': 'High Quality'},
      {'label': 'High Definition (720p)', 'size': '78 MB', 'badge': 'Recommended'},
      {'label': 'Standard (480p)', 'size': '34 MB', 'badge': 'Data Saver'},
      {'label': 'Low (360p)', 'size': '18 MB', 'badge': 'Minimal'},
      {'label': 'Audio Only (MP3 / 128kbps)', 'size': '4.2 MB', 'badge': 'Music'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF212121) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.file_download_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Download Video Quality',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ...qualities.map((q) {
                  return ListTile(
                    title: Text(
                      q['label']!,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Estimated: ${q['size']}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: q['badge'] == 'Recommended'
                            ? AppColors.primary.withAlpha(40)
                            : (isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        q['badge']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: q['badge'] == 'Recommended' ? AppColors.primary : null,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _startDownload(q['label']!);
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startDownload(String quality) {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.05;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading "${widget.video.title}" in $quality...'),
        duration: const Duration(seconds: 2),
      ),
    );

    // Progressive simulated cache download into LibraryProvider
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _downloadProgress = 0.35);
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _downloadProgress = 0.75);
    });

    Future.delayed(const Duration(milliseconds: 1200), () async {
      if (!mounted) return;
      final library = context.read<LibraryProvider>();
      await library.addDownload(widget.video, quality);
      setState(() {
        _isDownloading = false;
        _downloadProgress = 1.0;
        _downloadedQuality = quality;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1B5E20),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Downloaded: "${widget.video.title}" ($quality) ready offline!'),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Future<void> _handleAISummary() async {
    if (_aiSummary != null) return;
    setState(() => _isGeneratingSummary = true);
    final aiService = DefaultAIService();
    final summary = await aiService.summarizeVideo(widget.video);
    if (mounted) {
      setState(() {
        _aiSummary = summary;
        _isGeneratingSummary = false;
      });
    }
  }

  Widget _buildAISummarySection(ThemeData theme) {
    if (_isGeneratingSummary) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            SizedBox(width: 12),
            Text('Generating local video summary...', style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    if (_aiSummary == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3EA6FF).withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3EA6FF).withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF3EA6FF)),
              SizedBox(width: 8),
              Text(
                'AI Overview & Key Takeaways',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_aiSummary!, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildRelatedVideosList(ThemeData theme) {
    if (_relatedVideos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Up Next',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _relatedVideos.length,
            itemBuilder: (context, index) {
              final related = _relatedVideos[index];
              return VideoCard(
                video: related,
                isCompact: true,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(video: related),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPlayerSettings(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF212121) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Quality
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Quality', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedQuality,
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showQualitySelector(context);
                },
              ),
              // Playback Speed
              ListTile(
                leading: const Icon(Icons.speed_rounded),
                title: const Text('Playback speed', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _playbackSpeed == 1.0 ? 'Normal' : '${_playbackSpeed}x',
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSpeedSelector(context);
                },
              ),
              // Captions
              ListTile(
                leading: const Icon(Icons.closed_caption_outlined),
                title: const Text('Captions', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(
                  _isCaptionsEnabled ? 'English (auto)' : 'Off',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
                ),
                onTap: () {
                  setState(() => _isCaptionsEnabled = !_isCaptionsEnabled);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isCaptionsEnabled ? 'Subtitles turned on' : 'Subtitles turned off'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              // Loop video
              ListTile(
                leading: const Icon(Icons.repeat_rounded),
                title: const Text('Loop video', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(
                  _isLooping ? 'On' : 'Off',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
                ),
                onTap: () {
                  setState(() => _isLooping = !_isLooping);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isLooping ? 'Loop video is on' : 'Loop video is off'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              // Sleep timer
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: const Text('Sleep timer', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(
                  'Off',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSleepTimerDialog(context);
                },
              ),
              // Stats for Nerds
              ListTile(
                leading: const Icon(Icons.bar_chart_rounded),
                title: const Text('Stats for nerds', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showStatsForNerds(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showQualitySelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qualities = [
      'Auto (1080p)',
      '1080p60 HD',
      '1080p HD',
      '720p',
      '480p',
      '360p',
      '240p',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF212121) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Quality for current video', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ...qualities.map((q) {
                final isSelected = _selectedQuality == q;
                return ListTile(
                  title: Text(q, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                  onTap: () {
                    setState(() => _selectedQuality = q);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Quality set to $q'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showSpeedSelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF212121) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Playback speed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ...speeds.map((s) {
                final isSelected = _playbackSpeed == s;
                final label = s == 1.0 ? 'Normal' : '${s}x';
                return ListTile(
                  title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                  onTap: () {
                    setState(() => _playbackSpeed = s);
                    _controller.setPlaybackRate(s);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Playback speed: $label'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    final timers = ['Off', '10 minutes', '15 minutes', '30 minutes', '45 minutes', '60 minutes', 'End of video'];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Sleep timer'),
        children: timers.map((t) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sleep timer: $t')),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(t, style: const TextStyle(fontSize: 15)),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showStatsForNerds(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.terminal_rounded, size: 20, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Stats for Nerds', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow('Video ID / CPN', widget.video.id),
              _buildStatRow('Viewport / Frames', '1080x608*2.63 / 0 dropped of 1420'),
              _buildStatRow('Current / Optimal Res', '1920x1080@60 / 1920x1080@60'),
              _buildStatRow('Codecs', 'avc1.64002a (399) / mp4a.40.2 (140)'),
              _buildStatRow('Color', 'bt709 / bt709'),
              _buildStatRow('Volume / Normalized', '100% / 100% (-1.2dB)'),
              _buildStatRow('Connection Speed', '58420 Kbps'),
              _buildStatRow('Buffer Health', '34.82 s'),
              _buildStatRow('Network Activity', '0 KB'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  void _showShareModal(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final videoUrl = 'https://youtu.be/${widget.video.id}';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF212121) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text('Share', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildShareAppIcon(
                        icon: Icons.link_rounded,
                        label: 'Copy link',
                        bgColor: isDark ? const Color(0xFF383838) : const Color(0xFFE5E5E5),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: videoUrl));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied to clipboard')),
                          );
                        },
                      ),
                      _buildShareAppIcon(
                        icon: Icons.chat_bubble_rounded,
                        label: 'WhatsApp',
                        bgColor: const Color(0xFF25D366),
                        iconColor: Colors.white,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: videoUrl));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied for WhatsApp')),
                          );
                        },
                      ),
                      _buildShareAppIcon(
                        icon: Icons.send_rounded,
                        label: 'Telegram',
                        bgColor: const Color(0xFF229ED9),
                        iconColor: Colors.white,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: videoUrl));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied for Telegram')),
                          );
                        },
                      ),
                      _buildShareAppIcon(
                        icon: Icons.tag_rounded,
                        label: 'X (Twitter)',
                        bgColor: Colors.black,
                        iconColor: Colors.white,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: videoUrl));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied for X')),
                          );
                        },
                      ),
                      _buildShareAppIcon(
                        icon: Icons.email_rounded,
                        label: 'Gmail',
                        bgColor: const Color(0xFFEA4335),
                        iconColor: Colors.white,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: videoUrl));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied for Email')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2F2F2F) : const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            videoUrl,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: videoUrl));
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Link copied to clipboard')),
                            );
                          },
                          child: const Text('Copy'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShareAppIcon({
    required IconData icon,
    required String label,
    required Color bgColor,
    Color iconColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: bgColor,
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showSavePlaylistModal(BuildContext context, LibraryProvider library) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF212121) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isInWatchLater = library.watchLater.any((v) => v.id == widget.video.id);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Text(
                            'Save video to...',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('New playlist'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showCreatePlaylistDialog(context, library);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      value: isInWatchLater,
                      title: const Text('Watch Later', style: TextStyle(fontWeight: FontWeight.w600)),
                      secondary: const Icon(Icons.watch_later_outlined),
                      activeColor: AppColors.primary,
                      onChanged: (val) async {
                        if (val == true) {
                          await library.addToWatchLater(widget.video);
                        } else {
                          await library.removeFromWatchLater(widget.video.id);
                        }
                        setSheetState(() {});
                      },
                    ),
                    ...library.playlists.map((playlist) {
                      final hasVideo = playlist.videoCount > 0;
                      return CheckboxListTile(
                        value: hasVideo,
                        title: Text(playlist.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        secondary: const Icon(Icons.playlist_play_rounded),
                        activeColor: AppColors.primary,
                        onChanged: (val) async {
                          if (val == true) {
                            await library.addVideoToPlaylist(playlist.id, widget.video);
                          } else {
                            await library.removeVideoFromPlaylist(playlist.id, widget.video.id);
                          }
                          setSheetState(() {});
                        },
                      );
                    }),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Done'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, LibraryProvider library) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter title...',
            border: UnderlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                final playlist = await library.createPlaylist(title);
                await library.addVideoToPlaylist(playlist.id, widget.video);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved to $title')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRemixSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF212121) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('Remix this video', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.music_note_rounded),
                title: const Text('Use this sound', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Create a Short using this original audio'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sound ready: "${widget.video.title}" loaded for Shorts Studio')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_cut_rounded),
                title: const Text('Cut this video', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Trim a 1 to 5-second segment into a Short'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Video segment ready to trim into Shorts')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Green Screen', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Use this video as a background for your Short'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Green screen backdrop configured')),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
