import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../api/video_platform_service.dart';
import '../models/comment.dart';
import '../models/video.dart';
import '../providers/library_provider.dart';
import '../providers/playback_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_colors.dart';
import '../widgets/video_card.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Video video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late YoutubePlayerController _controller;
  bool _isDescriptionExpanded = false;
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _isSubscribed = false;
  bool _isLoadingComments = true;
  List<Comment> _comments = [];
  List<Video> _relatedVideos = [];
  String? _aiSummary;
  bool _isGeneratingSummary = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _loadMetadata();
  }

  void _initPlayer() {
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
        enableCaption: true,
      ),
    );

    _controller.loadVideoById(videoId: widget.video.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final playback = context.read<PlaybackProvider>();
      playback.loadVideo(widget.video);
    });
  }

  Future<void> _loadMetadata() async {
    final service = context.read<VideoPlatformService>();
    try {
      final comments = await service.getComments(widget.video.id);
      final related = await service.getRelatedVideos(widget.video.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _relatedVideos = related;
          _isLoadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        AspectRatio(
          aspectRatio: 16 / 9,
          child: YoutubePlayer(
            controller: _controller,
            aspectRatio: 16 / 9,
          ),
        ),
      ],
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
                onTap: () {
                  setState(() => _isSubscribed = !_isSubscribed);
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
                        onTap: () {
                          setState(() {
                            _isLiked = !_isLiked;
                            if (_isLiked) _isDisliked = false;
                          });
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
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
                            if (_isDisliked) _isLiked = false;
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
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Video link copied: https://youtu.be/${widget.video.id}')),
                    );
                  },
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

                // Download Pill (Clean legal notice)
                _buildActionPill(
                  isDark: isDark,
                  icon: Icons.download_outlined,
                  label: 'Download',
                  onTap: () => _showDownloadNotice(context),
                ),
                const SizedBox(width: 8),

                // Save to Watch Later Pill
                _buildActionPill(
                  isDark: isDark,
                  icon: Icons.playlist_add_rounded,
                  label: 'Save',
                  onTap: () async {
                    await library.addToWatchLater(widget.video);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Saved to Watch Later')),
                      );
                    }
                  },
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF181818) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
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
                          ? const Center(child: Text('No comments available.'))
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
                                      backgroundImage: NetworkImage(c.authorAvatarUrl),
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
                                                c.formattedTimeAgo,
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
              ],
            );
          },
        );
      },
    );
  }

  void _showDownloadNotice(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Offline Playback'),
          ],
        ),
        content: const Text(
          'Offline downloads are officially restricted by YouTube Terms of Service for third-party client integrations. GAMATUBE strictly adheres to official API policies.\n\nYou can save videos to Watch Later for instant high-speed streaming anytime.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understand')),
        ],
      ),
    );
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
}
