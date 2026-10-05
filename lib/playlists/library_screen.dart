import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../history/history_screen.dart';
import '../playback/video_player_screen.dart';
import '../playlists/watch_later_screen.dart';
import '../providers/library_provider.dart';
import '../theme/app_colors.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Section 1: History
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'History',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    );
                  },
                  child: const Text('See all'),
                ),
              ],
            ),
          ),
          if (library.history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('No watch history yet. Videos you watch will appear here.',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
            )
          else
            SizedBox(
              height: 175,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: library.history.take(6).length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = library.history[index];
                  return SizedBox(
                    width: 200,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerScreen(video: item.video),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                item.video.thumbnailUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          const Divider(height: 32),

          // Section 2: Watch Later Quick Access
          ListTile(
            leading: const Icon(Icons.watch_later_outlined, color: AppColors.primary),
            title: const Text('Watch Later', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${library.watchLater.length} videos'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WatchLaterScreen()),
              );
            },
          ),

          const Divider(height: 32),

          // Section 3: Playlists
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.playlist_play_rounded, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Playlists',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _showCreatePlaylistDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New playlist'),
                ),
              ],
            ),
          ),
          if (library.playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('No custom playlists yet. Tap "New playlist" to create one.',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
            )
          else
            ...library.playlists.map((playlist) => ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.playlist_play_rounded, color: AppColors.primary),
                  ),
                  title: Text(playlist.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${playlist.videoCount} videos • Local playlist'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    onPressed: () => library.deletePlaylist(playlist.id),
                  ),
                  onTap: () {
                    if (playlist.items.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(video: playlist.items.first),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('This playlist has no videos yet.')),
                      );
                    }
                  },
                )),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'Enter playlist title...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<LibraryProvider>().createPlaylist(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
