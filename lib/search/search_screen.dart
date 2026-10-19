import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video.dart';
import '../playback/video_player_screen.dart';
import '../providers/search_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/error_state_view.dart';
import '../widgets/video_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Search videos, channels, topics, or paste link...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withAlpha(120),
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _controller.clear();
                        search.onQueryChanged('');
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.mic_rounded, color: AppColors.primary, size: 20),
                    tooltip: 'Search with your voice',
                    onPressed: () => _showVoiceSearchDialog(context, search),
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (text) => search.onQueryChanged(text),
            onSubmitted: (text) {
              _focusNode.unfocus();
              search.executeSearch(text);
            },
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Filter chips bar
              if (search.searchResults.isNotEmpty)
                _buildFilterChipsBar(context, search),
              Expanded(child: _buildBody(context, search)),
            ],
          ),
          // Suggestions dropdown overlay
          if (search.showSuggestions && search.suggestions.isNotEmpty)
            _buildSuggestionsOverlay(context, search, isDark),
        ],
      ),
    );
  }

  Widget _buildFilterChipsBar(BuildContext context, SearchProvider search) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181818) : const Color(0xFFF9F9F9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF282828) : const Color(0xFFEEEEEE),
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Filter Settings Button
          ActionChip(
            avatar: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () => _showFiltersBottomSheet(context, search),
          ),
          const SizedBox(width: 8),

          // Type Chips
          _buildChip(
            label: 'All',
            isSelected: search.filterType == 'all',
            onTap: () => search.setFilterType('all'),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Videos',
            isSelected: search.filterType == 'video',
            onTap: () => search.setFilterType('video'),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Shorts',
            isSelected: search.filterType == 'shorts',
            onTap: () => search.setFilterType('shorts'),
          ),
          const SizedBox(width: 12),

          // Sort Dropdown
          Center(
            child: DropdownButton<String>(
              value: search.sortOrder,
              underline: const SizedBox.shrink(),
              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
              items: const [
                DropdownMenuItem(value: 'relevance', child: Text('Relevance')),
                DropdownMenuItem(value: 'date', child: Text('Upload Date')),
                DropdownMenuItem(value: 'viewCount', child: Text('View Count')),
                DropdownMenuItem(value: 'rating', child: Text('Rating')),
              ],
              onChanged: (val) {
                if (val != null) search.setSortOrder(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: isSelected ? Colors.white : null),
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildSuggestionsOverlay(BuildContext context, SearchProvider search, bool isDark) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 8,
        color: isDark ? const Color(0xFF212121) : Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: search.suggestions.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0),
            ),
            itemBuilder: (ctx, idx) {
              final suggestion = search.suggestions[idx];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.search_rounded, size: 18),
                title: Text(suggestion, style: const TextStyle(fontSize: 14)),
                trailing: IconButton(
                  icon: const Icon(Icons.north_west_rounded, size: 16),
                  tooltip: 'Insert into search',
                  onPressed: () {
                    _controller.text = suggestion;
                    _controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: suggestion.length),
                    );
                    search.onQueryChanged(suggestion);
                  },
                ),
                onTap: () {
                  _controller.text = suggestion;
                  _focusNode.unfocus();
                  search.executeSearch(suggestion);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SearchProvider search) {
    if (search.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (search.error != null) {
      return ErrorStateView(
        failure: search.error,
        onRetry: () => search.executeSearch(search.currentQuery),
      );
    }

    if (search.currentQuery.isEmpty && search.searchResults.isEmpty) {
      return _buildRecentSearches(context, search);
    }

    final results = search.filteredResults;

    if (results.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off_rounded,
        title: 'No results match filters',
        message: 'Try clearing filters or search for different keywords.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await search.executeSearch(search.currentQuery);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final video = results[index];
              if (isWide) {
                return _buildWideVideoCard(context, video);
              }
              return VideoCard(
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
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildWideVideoCard(BuildContext context, Video video) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(video: video),
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wide 16:9 Thumbnail
            SizedBox(
              width: 240,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        video.thumbnailUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 480,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (_, _, _) => Container(
                          color: isDark ? Colors.grey[900] : Colors.grey[300],
                          child: const Icon(Icons.play_circle_outline, size: 40),
                        ),
                      ),
                    ),
                  ),
                  if (video.duration != null)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(200),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(video.duration!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Video Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatViews(video.viewCount)} • ${_formatDate(video.publishedAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primary.withAlpha(40),
                        child: Text(
                          video.channelTitle.isNotEmpty ? video.channelTitle[0] : 'C',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          video.channelTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (video.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      video.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSearches(BuildContext context, SearchProvider search) {
    final theme = Theme.of(context);
    final history = search.recentSearches;

    if (history.isEmpty) {
      return const EmptyStateView(
        icon: Icons.history_rounded,
        title: 'Find what to watch',
        message: 'Search for music, documentaries, tech reviews, or podcasts.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Searches',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () => search.clearRecentSearches(),
              child: const Text('Clear All', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...history.map((q) => ListTile(
              leading: const Icon(Icons.history_rounded, size: 20),
              title: Text(q, style: const TextStyle(fontSize: 14)),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () => search.removeRecentSearch(q),
              ),
              onTap: () {
                _controller.text = q;
                search.executeSearch(q);
              },
            )),
      ],
    );
  }

  void _showFiltersBottomSheet(BuildContext context, SearchProvider search) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Search Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {
                            search.resetFilters();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Reset', style: TextStyle(color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const Divider(),
                    // Type
                    const Text('Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterOption('All', search.filterType == 'all', () {
                          search.setFilterType('all');
                          setModalState(() {});
                        }),
                        _buildFilterOption('Videos', search.filterType == 'video', () {
                          search.setFilterType('video');
                          setModalState(() {});
                        }),
                        _buildFilterOption('Shorts', search.filterType == 'shorts', () {
                          search.setFilterType('shorts');
                          setModalState(() {});
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Duration
                    const Text('Duration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterOption('Any', search.filterDuration == 'all', () {
                          search.setFilterDuration('all');
                          setModalState(() {});
                        }),
                        _buildFilterOption('< 4 min', search.filterDuration == 'short', () {
                          search.setFilterDuration('short');
                          setModalState(() {});
                        }),
                        _buildFilterOption('4 - 20 min', search.filterDuration == 'medium', () {
                          search.setFilterDuration('medium');
                          setModalState(() {});
                        }),
                        _buildFilterOption('> 20 min', search.filterDuration == 'long', () {
                          search.setFilterDuration('long');
                          setModalState(() {});
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Upload Date
                    const Text('Upload Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterOption('Any time', search.filterDate == 'all', () {
                          search.setFilterDate('all');
                          setModalState(() {});
                        }),
                        _buildFilterOption('Today', search.filterDate == 'today', () {
                          search.setFilterDate('today');
                          setModalState(() {});
                        }),
                        _buildFilterOption('This week', search.filterDate == 'week', () {
                          search.setFilterDate('week');
                          setModalState(() {});
                        }),
                        _buildFilterOption('This year', search.filterDate == 'year', () {
                          search.setFilterDate('year');
                          setModalState(() {});
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Apply Filters'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterOption(String label, bool isSelected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: isSelected ? Colors.white : null),
      onSelected: (_) => onTap(),
    );
  }

  void _showVoiceSearchDialog(BuildContext context, SearchProvider search) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final popularVoiceQueries = [
      'Trending Music 2026',
      'Artificial Intelligence documentaries',
      'Flutter multi-platform tutorial',
      'Lofi hip hop beats to relax',
      'Quantum computing explained',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Voice Search',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withAlpha(30),
                  ),
                  child: Center(
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      child: const Icon(Icons.mic_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Listening...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Say a video title, topic, or creator name',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Or try saying:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: popularVoiceQueries.map((query) {
                    return ActionChip(
                      avatar: const Icon(Icons.mic_none_rounded, size: 16),
                      label: Text(query, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _controller.text = query;
                        search.executeSearch(query);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatViews(int views) {
    if (views >= 1000000000) return '${(views / 1000000000).toStringAsFixed(1)}B views';
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M views';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K views';
    return '$views views';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Recently';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()} years ago';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()} months ago';
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    return '${diff.inMinutes} minutes ago';
  }
}
