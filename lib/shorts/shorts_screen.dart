import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../api/video_platform_service.dart';
import '../models/video.dart';
import '../playback/video_player_screen.dart';
import '../search/search_screen.dart';
import '../theme/app_colors.dart';

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key});

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  final PageController _pageController = PageController();
  List<Video> _shorts = [];
  bool _isLoading = true;
  int _currentPage = 0;
  final Set<String> _likedShorts = {};
  final Set<String> _subscribedChannels = {};

  @override
  void initState() {
    super.initState();
    _loadShorts();
  }

  Future<void> _loadShorts() async {
    final service = context.read<VideoPlatformService>();
    try {
      final videos = await service.searchVideos('shorts trending');
      if (mounted) {
        setState(() {
          _shorts = videos;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        final fallback = await service.getHomeFeed();
        setState(() {
          _shorts = fallback;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_shorts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flash_on_rounded, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'No Shorts Available',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadShorts();
                },
                child: const Text('Refresh', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadShorts,
        child: PageView.builder(
          controller: _pageController,
          physics: const AlwaysScrollableScrollPhysics(),
          scrollDirection: Axis.vertical,
          itemCount: _shorts.length,
          onPageChanged: (index) {
            setState(() => _currentPage = index);
          },
          itemBuilder: (context, index) {
            final video = _shorts[index];
            final isLiked = _likedShorts.contains(video.id);
            final isSubscribed = _subscribedChannels.contains(video.channelTitle);

            return _ShortItemView(
              key: ValueKey(video.id),
              video: video,
              isActive: _currentPage == index,
              isLiked: isLiked,
              isSubscribed: isSubscribed,
              onToggleLike: () {
                setState(() {
                  if (isLiked) {
                    _likedShorts.remove(video.id);
                  } else {
                    _likedShorts.add(video.id);
                  }
                });
              },
              onToggleSubscribe: () {
                setState(() {
                  if (isSubscribed) {
                    _subscribedChannels.remove(video.channelTitle);
                  } else {
                    _subscribedChannels.add(video.channelTitle);
                  }
                });
              },
              onShowComments: () => _showShortComments(context, video),
              onOpenSearch: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showShortComments(BuildContext context, Video video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24),
                Expanded(
                  child: ListView(
                    children: [
                      _buildCommentRow(
                        avatar: 'A',
                        user: 'Alex Rivera',
                        time: '2 hours ago',
                        text: 'The editing and pacing on this short is top tier! 🔥',
                        likes: '1.2K',
                      ),
                      _buildCommentRow(
                        avatar: 'M',
                        user: 'Maya Chen',
                        time: '5 hours ago',
                        text: 'So satisfying to watch. Subscribed right away!',
                        likes: '540',
                      ),
                      _buildCommentRow(
                        avatar: 'D',
                        user: 'Dev Prodigy',
                        time: '1 day ago',
                        text: 'Clean visuals, no fluff, straight to the point.',
                        likes: '289',
                      ),
                    ],
                  ),
                ),
                // Add comment input
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF272727),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const TextField(
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      suffixIcon: Icon(Icons.send_rounded, color: AppColors.primary, size: 20),
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

  Widget _buildCommentRow({
    required String avatar,
    required String user,
    required String time,
    required String text,
    required String likes,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withAlpha(40),
            child: Text(avatar, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.thumb_up_outlined, size: 14, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text(likes, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(width: 16),
                    const Icon(Icons.thumb_down_outlined, size: 14, color: Colors.white54),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortItemView extends StatefulWidget {
  final Video video;
  final bool isActive;
  final bool isLiked;
  final bool isSubscribed;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleSubscribe;
  final VoidCallback onShowComments;
  final VoidCallback onOpenSearch;

  const _ShortItemView({
    super.key,
    required this.video,
    required this.isActive,
    required this.isLiked,
    required this.isSubscribed,
    required this.onToggleLike,
    required this.onToggleSubscribe,
    required this.onShowComments,
    required this.onOpenSearch,
  });

  @override
  State<_ShortItemView> createState() => _ShortItemViewState();
}

class _ShortItemViewState extends State<_ShortItemView> {
  late YoutubePlayerController _controller;
  bool _isPlaying = true;
  bool _showPlayIndicator = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.video.id,
      autoPlay: widget.isActive,
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        strictRelatedVideos: true,
        loop: true,
        enableCaption: false,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _ShortItemView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.playVideo();
      _isPlaying = true;
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.pauseVideo();
      _isPlaying = false;
    }
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _controller.pauseVideo();
      _isPlaying = false;
    } else {
      _controller.playVideo();
      _isPlaying = true;
    }
    setState(() => _showPlayIndicator = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showPlayIndicator = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Live Youtube Player centered in 9:16 vertical view
        Center(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: YoutubePlayer(
              controller: _controller,
              aspectRatio: 9 / 16,
            ),
          ),
        ),

        // Non-blocking gesture detector for tap to play/pause & double tap to like
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _togglePlayPause,
            onDoubleTap: widget.onToggleLike,
          ),
        ),

        // Gradient overlay for bottom info readability
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 240,
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),

        // Center Animated Play / Pause Indicator
        if (_showPlayIndicator)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(160),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),

        // Top bar with "Shorts" header and search button
        Positioned(
          top: 48,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SHORTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
                    onPressed: widget.onOpenSearch,
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 24),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Short options: Quality, Captions, Report')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Right-side floating action column
        Positioned(
          right: 12,
          bottom: 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Like
              _buildActionButton(
                icon: widget.isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                label: widget.isLiked ? 'Liked' : '420K',
                iconColor: widget.isLiked ? AppColors.primary : Colors.white,
                onTap: widget.onToggleLike,
              ),
              const SizedBox(height: 18),

              // Dislike
              _buildActionButton(
                icon: Icons.thumb_down_outlined,
                label: 'Dislike',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Marked as not interested')),
                  );
                },
              ),
              const SizedBox(height: 18),

              // Comments
              _buildActionButton(
                icon: Icons.comment_rounded,
                label: '2.4K',
                onTap: widget.onShowComments,
              ),
              const SizedBox(height: 18),

              // Share
              _buildActionButton(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Video link copied to clipboard')),
                  );
                },
              ),
              const SizedBox(height: 18),

              // Watch full in 16:9 player
              _buildActionButton(
                icon: Icons.fullscreen_rounded,
                label: 'Watch',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(video: widget.video),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Bottom left info (Channel, Subscribe, Caption, Audio)
        Positioned(
          left: 16,
          right: 86,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Channel row
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    backgroundImage: widget.video.channelAvatarUrl != null
                        ? NetworkImage(widget.video.channelAvatarUrl!)
                        : null,
                    child: widget.video.channelAvatarUrl == null
                        ? Text(
                            widget.video.channelTitle.isNotEmpty ? widget.video.channelTitle[0] : 'C',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '@${widget.video.channelTitle.replaceAll(' ', '')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Subscribe Pill
                  GestureDetector(
                    onTap: widget.onToggleSubscribe,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.isSubscribed ? Colors.white24 : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.isSubscribed ? 'Subscribed' : 'Subscribe',
                        style: TextStyle(
                          color: widget.isSubscribed ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title / Caption
              Text(
                widget.video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),

              // Sound track tag
              Row(
                children: [
                  const Icon(Icons.music_note_rounded, size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Original Audio • ${widget.video.channelTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
