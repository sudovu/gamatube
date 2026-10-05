import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../playback/video_player_screen.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/video_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch History'),
        actions: [
          IconButton(
            icon: Icon(
              settings.settings.historyPaused
                  ? Icons.pause_circle_filled_rounded
                  : Icons.pause_circle_outline_rounded,
            ),
            tooltip: settings.settings.historyPaused
                ? 'Resume history tracking'
                : 'Pause history tracking',
            onPressed: () {
              final newPaused = !settings.settings.historyPaused;
              settings.setHistoryPaused(newPaused);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(newPaused
                      ? 'Watch history tracking paused'
                      : 'Watch history tracking resumed'),
                ),
              );
            },
          ),
          if (library.history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear history',
              onPressed: () {
                _showClearHistoryDialog(context);
              },
            ),
        ],
      ),
      body: library.history.isEmpty
          ? const EmptyStateView(
              icon: Icons.history_rounded,
              title: 'No watch history',
              message: 'Videos you watch will show up here to easily pick up where you left off.',
            )
          : ListView.builder(
              itemCount: library.history.length,
              itemBuilder: (context, index) {
                final item = library.history[index];
                return Dismissible(
                  key: Key(item.video.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_rounded, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    library.removeFromHistory(item.video.id);
                  },
                  child: VideoCard(
                    video: item.video,
                    isCompact: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(video: item.video),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Watch History?'),
        content: const Text(
          'This will remove all video watch history from this device. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              context.read<LibraryProvider>().clearHistory();
              Navigator.pop(ctx);
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
