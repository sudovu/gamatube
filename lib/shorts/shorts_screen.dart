import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/video_platform_service.dart';
import '../models/video.dart';
import '../playback/video_player_screen.dart';
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
      final videos = await service.searchVideos('#shorts trending');
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
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _shorts.length,
        itemBuilder: (context, index) {
          final video = _shorts[index];
          return _buildShortPage(context, video);
        },
      ),
    );
  }

  Widget _buildShortPage(BuildContext context, Video video) {
    final isLiked = _likedShorts.contains(video.id);
    final isSubscribed = _subscribedChannels.contains(video.channelTitle);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background thumbnail with subtle zoom
        Image.network(
          video.thumbnailUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: const Color(0xFF181818),
            child: const Center(
              child: Icon(Icons.play_circle_outline_rounded, color: Colors.white54, size: 64),
            ),
          ),
        ),

        // Dark gradient overlay for readability
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black45,
                Colors.black87,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.4, 0.75, 1.0],
            ),
          ),
        ),

        // Center tap to play full video in player
        Center(
          child: IconButton(
            iconSize: 72,
            icon: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoPlayerScreen(video: video),
                ),
              );
            },
          ),
        ),

        // Top bar with "Shorts" header
        Positioned(
          top: 40,
          left: 16,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'SHORTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
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
                icon: isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                label: isLiked ? 'Liked' : '420K',
                iconColor: isLiked ? AppColors.primary : Colors.white,
                onTap: () {
                  setState(() {
                    if (isLiked) {
                      _likedShorts.remove(video.id);
                    } else {
                      _likedShorts.add(video.id);
                    }
                  });
                },
              ),
              const SizedBox(height: 18),

              // Dislike
              _buildActionButton(
                icon: Icons.thumb_down_outlined,
                label: 'Dislike',
                onTap: () {},
              ),
              const SizedBox(height: 18),

              // Comments
              _buildActionButton(
                icon: Icons.comment_rounded,
                label: '2.4K',
                onTap: () => _showShortComments(context, video),
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

              // Full Player Jump
              _buildActionButton(
                icon: Icons.fullscreen_rounded,
                label: 'Watch',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(video: video),
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
          right: 80,
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
                    backgroundImage: video.channelAvatarUrl != null
                        ? NetworkImage(video.channelAvatarUrl!)
                        : null,
                    child: video.channelAvatarUrl == null
                        ? Text(
                            video.channelTitle.isNotEmpty ? video.channelTitle[0] : 'C',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '@${video.channelTitle.replaceAll(' ', '')}',
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
                    onTap: () {
                      setState(() {
                        if (isSubscribed) {
                          _subscribedChannels.remove(video.channelTitle);
                        } else {
                          _subscribedChannels.add(video.channelTitle);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSubscribed ? Colors.white24 : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isSubscribed ? 'Subscribed' : 'Subscribe',
                        style: TextStyle(
                          color: isSubscribed ? Colors.white : Colors.black,
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
                video.title,
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
                      'Original Audio • ${video.channelTitle}',
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

  void _showShortComments(BuildContext context, Video video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 450,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
