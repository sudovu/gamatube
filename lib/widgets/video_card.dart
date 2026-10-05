import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video.dart';
import '../providers/library_provider.dart';
import '../theme/app_colors.dart';

class VideoCard extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;
  final bool isCompact;

  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactCard(context);
    }
    return _buildStandardCard(context);
  }

  Widget _buildStandardCard(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      width: double.infinity,
                      height: double.infinity,
                      child: Image.network(
                        video.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(
                          child: Icon(
                            Icons.play_circle_outline_rounded,
                            size: 48,
                            color: theme.colorScheme.onSurface.withAlpha(80),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (video.formattedDuration.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(200),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video.formattedDuration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (video.isLive)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Info Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withAlpha(30),
                  backgroundImage: video.channelAvatarUrl != null
                      ? NetworkImage(video.channelAvatarUrl!)
                      : null,
                  child: video.channelAvatarUrl == null
                      ? Text(
                          video.channelTitle.isNotEmpty ? video.channelTitle[0] : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${video.channelTitle} • ${video.formattedViews} • ${video.formattedTimeAgo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(160),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActionMenu(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        width: double.infinity,
                        height: double.infinity,
                        child: Image.network(
                          video.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.play_arrow_rounded, size: 28),
                          ),
                        ),
                      ),
                    ),
                    if (video.formattedDuration.isNotEmpty)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(200),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            video.formattedDuration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.channelTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(160),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${video.formattedViews} • ${video.formattedTimeAgo}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withAlpha(130),
                    ),
                  ),
                ],
              ),
            ),
            _buildActionMenu(context),
          ],
        ),
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
      ),
      padding: EdgeInsets.zero,
      onSelected: (action) async {
        final library = context.read<LibraryProvider>();
        if (action == 'watch_later') {
          await library.addToWatchLater(video);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Added to Watch Later')),
            );
          }
        } else if (action == 'playlist') {
          _showAddToPlaylistDialog(context);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'watch_later',
          child: Row(
            children: [
              Icon(Icons.watch_later_outlined, size: 18),
              SizedBox(width: 10),
              Text('Save to Watch Later'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'playlist',
          child: Row(
            children: [
              Icon(Icons.playlist_add_rounded, size: 18),
              SizedBox(width: 10),
              Text('Add to playlist'),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddToPlaylistDialog(BuildContext context) {
    final library = context.read<LibraryProvider>();
    showDialog(
      context: context,
      builder: (ctx) {
        final playlists = library.playlists;
        return AlertDialog(
          title: const Text('Add to Playlist'),
          content: playlists.isEmpty
              ? const Text('No playlists created yet. Create one in Library.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (c, idx) {
                      final p = playlists[idx];
                      return ListTile(
                        leading: const Icon(Icons.playlist_play_rounded),
                        title: Text(p.title),
                        subtitle: Text('${p.videoCount} videos'),
                        onTap: () async {
                          await library.addVideoToPlaylist(p.id, video);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Added to ${p.title}')),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
