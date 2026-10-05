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
                              _buildCommentsSection(theme),
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
                      _buildRelatedVideosList(theme),
                      _buildCommentsSection(theme),
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
        // Resume prompt banner if previous playback detected
        if (playback.savedResumePosition != null)
          Container(
            color: AppColors.primaryDark,
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
        // IFrame compliant player
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.video.title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.video.formattedViews} • ${widget.video.formattedTimeAgo}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(160),
            ),
          ),
          const SizedBox(height: 14),

          // Channel and action bar
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withAlpha(40),
                backgroundImage: widget.video.channelAvatarUrl != null
                    ? NetworkImage(widget.video.channelAvatarUrl!)
                    : null,
                child: widget.video.channelAvatarUrl == null
                    ? Text(
                        widget.video.channelTitle.isNotEmpty ? widget.video.channelTitle[0] : 'C',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
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
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      'Official Channel',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withAlpha(140),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () {
                  setState(() => _isSubscribed = !_isSubscribed);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _isSubscribed
                      ? theme.colorScheme.surfaceContainerHighest
                      : AppColors.primary,
                  foregroundColor: _isSubscribed
                      ? theme.colorScheme.onSurface
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(_isSubscribed ? 'Subscribed' : 'Subscribe'),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Actions row (Like, Watch Later, Save, AI Summary)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _isLiked = !_isLiked);
                  },
                  icon: Icon(
                    _isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                    size: 16,
                    color: _isLiked ? AppColors.primary : null,
                  ),
                  label: Text(_isLiked ? 'Liked' : 'Like'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await library.addToWatchLater(widget.video);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to Watch Later')),
                      );
                    }
                  },
                  icon: const Icon(Icons.watch_later_outlined, size: 16),
                  label: const Text('Watch Later'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _handleAISummary(),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.secondary),
                  label: const Text('AI Summary'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Collapsible description
          InkWell(
            onTap: () {
              setState(() => _isDescriptionExpanded = !_isDescriptionExpanded);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.description.isNotEmpty
                        ? widget.video.description
                        : 'No description provided.',
                    maxLines: _isDescriptionExpanded ? 100 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isDescriptionExpanded ? 'Show less' : 'Show more',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Generating local summary...', style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    if (_aiSummary == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.secondary),
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

  Widget _buildCommentsSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Comments',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(
                '(${_comments.length})',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withAlpha(140),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingComments)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_comments.isEmpty)
            const Text('Comments are disabled or empty for this video.', style: TextStyle(fontSize: 13))
          else
            ..._comments.map((comment) => _buildCommentTile(comment, theme)),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Comment comment, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(comment.authorAvatarUrl),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: comment.authorAvatarUrl.isEmpty
                ? Text(comment.authorName.isNotEmpty ? comment.authorName[0] : 'U')
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
                      comment.authorName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.formattedTimeAgo,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withAlpha(140),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.text, style: const TextStyle(fontSize: 13, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedVideosList(ThemeData theme) {
    if (_relatedVideos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Related Videos',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
