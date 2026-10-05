import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../playback/video_player_screen.dart';
import '../providers/library_provider.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/video_card.dart';

class WatchLaterScreen extends StatelessWidget {
  const WatchLaterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch Later'),
        actions: [
          if (library.watchLater.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.playlist_play_rounded),
              tooltip: 'Play all',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoPlayerScreen(video: library.watchLater.first),
                  ),
                );
              },
            ),
        ],
      ),
      body: library.watchLater.isEmpty
          ? const EmptyStateView(
              icon: Icons.watch_later_outlined,
              title: 'Watch Later is empty',
              message: 'Save videos to watch later by tapping the menu on any video card.',
            )
          : ListView.builder(
              itemCount: library.watchLater.length,
              itemBuilder: (context, index) {
                final video = library.watchLater[index];
                return Dismissible(
                  key: Key(video.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_rounded, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    library.removeFromWatchLater(video.id);
                  },
                  child: VideoCard(
                    video: video,
                    isCompact: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(video: video),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
