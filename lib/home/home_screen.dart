import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video.dart';
import '../playback/video_player_screen.dart';
import '../shorts/shorts_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/home_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/account_sheet.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/error_state_view.dart';
import '../widgets/gamatube_logo.dart';
import '../widgets/gama_thumbnail.dart';
import '../widgets/video_card.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onSearchTap;
  final VoidCallback? onProfileTap;

  const HomeScreen({
    super.key,
    this.onSearchTap,
    this.onProfileTap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      final home = context.read<HomeProvider>();
      if (!home.isLoading && !home.isLoadingMore) {
        home.loadMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final library = context.watch<LibraryProvider>();
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: const GamatubeLogo(size: 24),
        actions: [
          // Cast Button
          IconButton(
            icon: const Icon(Icons.cast_rounded),
            tooltip: 'Cast to TV / Device',
            onPressed: () => _showCastDialog(context),
          ),
          // Notifications Bell with Badge
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                  ),
                ),
              ],
            ),
            tooltip: 'Notifications',
            onPressed: () => _showNotificationsDialog(context),
          ),
          // Search Button
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
            onPressed: widget.onSearchTap,
          ),
          // User Avatar
          Padding(
            padding: const EdgeInsets.only(right: 14, left: 4),
            child: GestureDetector(
              onTap: widget.onProfileTap ?? () => AccountSheet.show(context),
              child: auth.isIncognito
                  ? Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.visibility_off_rounded, color: Colors.white, size: 16),
                    )
                  : CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary,
                      backgroundImage: auth.user?.avatarUrl != null
                          ? NetworkImage(auth.user!.avatarUrl!)
                          : null,
                      child: auth.user?.avatarUrl == null
                          ? Text(
                              auth.user?.name.isNotEmpty == true ? auth.user!.name[0].toUpperCase() : 'G',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        displacement: 40,
        edgeOffset: 0,
        onRefresh: () async {
          await Future.wait([
            home.loadHomeContent(refresh: true),
            library.loadLibraryData(),
          ]);
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Incognito notice banner
            if (auth.isIncognito)
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_off_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "You're Incognito • Watch history is paused",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => auth.toggleIncognito(),
                        child: const Text(
                          'Turn off',
                          style: TextStyle(
                            color: Color(0xFF3EA6FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // YouTube-style Topic / Category Chips Bar
            SliverToBoxAdapter(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  scrollDirection: Axis.horizontal,
                  itemCount: home.categories.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Explore Compass icon
                      return GestureDetector(
                        onTap: () => _showExploreSheet(context, home),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF272727) : const Color(0xFFF2F2F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.explore_outlined,
                            size: 18,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      );
                    }

                    final cat = home.categories[index - 1];
                    final isSelected = home.selectedCategory == cat;

                    return GestureDetector(
                      onTap: () => home.selectCategory(cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? const Color(0xFF272727) : const Color(0xFFF2F2F2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected
                                ? (isDark ? Colors.black : Colors.white)
                                : (isDark ? const Color(0xFFF1F1F1) : const Color(0xFF0F0F0F)),
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Continue Watching section (if any history)
            if (library.history.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Continue Watching',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 195,
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
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
                  title: 'No videos found',
                  message: 'Explore topics above or search for your favorite content.',
                ),
              )
            else ...[
              // Feed with YouTube-style Shorts Shelf inserted
              SliverPadding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                sliver: _buildResponsiveVideoFeed(context, home.feedVideos, shorts: home.shorts),
              ),
              if (home.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
            ],
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
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: GamaThumbnail(
                    videoId: video.id,
                    thumbnailUrl: video.thumbnailUrl,
                    highThumbnailUrl: video.highThumbnailUrl,
                    standardThumbnailUrl: video.standardThumbnailUrl,
                    borderRadius: BorderRadius.circular(10),
                    cacheWidth: 360,
                  ),
                ),
                // Progress Bar at bottom of thumbnail
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                    child: LinearProgressIndicator(
                      value: item.completionPercentage as double,
                      backgroundColor: Colors.black.withAlpha(140),
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
                height: 1.25,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Resume at ${item.formattedPosition}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveVideoFeed(BuildContext context, List<Video> videos, {List<Video> shorts = const []}) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final isDesktop = width >= 900;
        final isTablet = width >= 600 && width < 900;

        if (!isDesktop && !isTablet) {
          // Mobile Feed with Shorts Carousel inserted after 2nd video
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // Insert Shorts Shelf at index 2 if shorts are available
                if (index == 2 && shorts.isNotEmpty) {
                  return Column(
                    children: [
                      _buildShortsShelf(context, shorts),
                      const Divider(thickness: 4, height: 28),
                      VideoCard(
                        video: videos[index],
                        onTap: () => _openPlayer(context, videos[index]),
                      ),
                    ],
                  );
                }

                final video = videos[index];
                return VideoCard(
                  video: video,
                  onTap: () => _openPlayer(context, video),
                );
              },
              childCount: videos.length,
            ),
          );
        }

        // Tablet / Desktop Grid
        int crossAxisCount = width >= 1200 ? 4 : (width >= 850 ? 3 : 2);
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.82,
            crossAxisSpacing: 16,
            mainAxisSpacing: 20,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final video = videos[index];
              return VideoCard(
                video: video,
                onTap: () => _openPlayer(context, video),
              );
            },
            childCount: videos.length,
          ),
        );
      },
    );
  }

  Widget _buildShortsShelf(BuildContext context, List<Video> shorts) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  'Shorts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 240,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: shorts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final short = shorts[index];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShortsScreen(
                          isScreenActive: true,
                          initialVideo: short,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 140,
                    child: Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 9 / 16,
                          child: GamaThumbnail(
                            videoId: short.id,
                            thumbnailUrl: short.thumbnailUrl,
                            highThumbnailUrl: short.highThumbnailUrl,
                            standardThumbnailUrl: short.standardThumbnailUrl,
                            borderRadius: BorderRadius.circular(12),
                            cacheWidth: 280,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Colors.transparent, Colors.black87],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0.55, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                short.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                short.formattedViews,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openPlayer(BuildContext context, Video video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(video: video),
      ),
    );
  }

  void _showCastDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cast_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Connect to a device'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Searching for wireless displays, Chromecasts, and smart TVs on your local Wi-Fi...'),
            SizedBox(height: 16),
            LinearProgressIndicator(color: AppColors.primary),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Icon(Icons.check_circle_outline_rounded, size: 20),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.movie_rounded, color: Colors.white, size: 18)),
                    title: const Text('Welcome to GamaTube! Enjoy ad-free clean video discovery.'),
                    subtitle: const Text('Just now'),
                  ),
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.star_rounded, color: Colors.white, size: 18)),
                    title: const Text('New trending releases are available in Tech and Science.'),
                    subtitle: const Text('2 hours ago'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExploreSheet(BuildContext context, HomeProvider home) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Explore Topics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildExploreTile(ctx, home, 'Trending', Icons.local_fire_department_rounded, const Color(0xFFFF4500)),
                    _buildExploreTile(ctx, home, 'Music', Icons.music_note_rounded, const Color(0xFFFFB300)),
                    _buildExploreTile(ctx, home, 'Gaming', Icons.sports_esports_rounded, const Color(0xFFE91E63)),
                    _buildExploreTile(ctx, home, 'Podcasts', Icons.podcasts_rounded, const Color(0xFF4CAF50)),
                    _buildExploreTile(ctx, home, 'Science & Tech', Icons.memory_rounded, const Color(0xFF2196F3)),
                    _buildExploreTile(ctx, home, 'News', Icons.newspaper_rounded, const Color(0xFF9C27B0)),
                    _buildExploreTile(ctx, home, 'Education', Icons.school_rounded, const Color(0xFF00BCD4)),
                    _buildExploreTile(ctx, home, 'Documentaries', Icons.movie_filter_rounded, const Color(0xFFFF5722)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExploreTile(BuildContext context, HomeProvider home, String title, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        home.selectCategory(title);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          border: Border.all(color: color.withAlpha(80)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
