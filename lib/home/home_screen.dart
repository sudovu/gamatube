import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video.dart';
import '../playback/video_player_screen.dart';
import '../providers/home_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/error_state_view.dart';
import '../widgets/gamatube_logo.dart';
import '../widgets/video_card.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onSearchTap;

  const HomeScreen({super.key, this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final library = context.watch<LibraryProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const GamatubeLogo(),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search videos',
            onPressed: onSearchTap,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => home.loadHomeContent(refresh: true),
        child: CustomScrollView(
          slivers: [
            // Category filter chips
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  scrollDirection: Axis.horizontal,
                  itemCount: home.categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = home.categories[index];
                    final isSelected = home.selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (_) => home.selectCategory(cat),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Continue Watching section (if any history with uncompleted progress)
            if (library.history.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_fill_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Continue Watching',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 190,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: library.history.take(6).length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = library.history[index];
                      return _buildContinueWatchingItem(context, item);
                    },
                  ),
                ),
              ),
            ],

            // Feed Content
            if (home.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (home.error != null)
              SliverFillRemaining(
                child: ErrorStateView(
                  failure: home.error,
                  onRetry: () => home.loadHomeContent(refresh: true),
                ),
              )
            else if (home.feedVideos.isEmpty)
              const SliverFillRemaining(
                child: EmptyStateView(
                  icon: Icons.video_library_outlined,
                  title: 'No videos available',
                  message: 'Explore categories or search for content.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                sliver: _buildResponsiveVideoGrid(context, home.feedVideos),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueWatchingItem(BuildContext context, dynamic item) {
    final theme = Theme.of(context);
    final video = item.video as Video;

    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(video: video),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      video.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.play_arrow_rounded),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    child: LinearProgressIndicator(
                      value: item.completionPercentage as double,
                      backgroundColor: Colors.black.withAlpha(120),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Resume at ${item.formattedPosition}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveVideoGrid(BuildContext context, List<Video> videos) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        int crossAxisCount = 1;
        if (width >= 1200) {
          crossAxisCount = 4;
        } else if (width >= 850) {
          crossAxisCount = 3;
        } else if (width >= 600) {
          crossAxisCount = 2;
        }

        if (crossAxisCount == 1) {
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final video = videos[index];
                return VideoCard(
                  video: video,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoPlayerScreen(video: video),
                      ),
                    );
                  },
                );
              },
              childCount: videos.length,
            ),
          );
        }

        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.88,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final video = videos[index];
              return VideoCard(
                video: video,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(video: video),
                    ),
                  );
                },
              );
            },
            childCount: videos.length,
          ),
        );
      },
    );
  }
}
