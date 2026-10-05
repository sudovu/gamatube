import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Search videos, channels, topics...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withAlpha(120),
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _controller.clear();
                        search.onQueryChanged('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (text) => search.onQueryChanged(text),
            onSubmitted: (text) => search.executeSearch(text),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter sort bar if there is an active search
          if (search.searchResults.isNotEmpty)
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const Text('Sort by: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  DropdownButton<String>(
                    value: search.sortOrder,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
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
                ],
              ),
            ),
          Expanded(child: _buildBody(context, search)),
        ],
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

    if (search.searchResults.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off_rounded,
        title: 'No results found',
        message: 'Try searching for different keywords or check your spelling.',
      );
    }

    return ListView.builder(
      itemCount: search.searchResults.length,
      itemBuilder: (context, index) {
        final video = search.searchResults[index];
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
}
