import 'package:flutter_test/flutter_test.dart';
import 'package:gamatube/api/youtube_v3_service.dart';
import 'package:gamatube/providers/home_provider.dart';
import 'package:gamatube/providers/search_provider.dart';
import 'package:gamatube/repositories/search_repository.dart';

class FakeSearchRepository implements SearchRepository {
  final List<String> _history = [];

  @override
  Future<List<String>> getRecentSearches() async => List.unmodifiable(_history);

  @override
  Future<void> addSearchQuery(String query) async {
    _history.remove(query);
    _history.insert(0, query);
  }

  @override
  Future<void> removeSearchQuery(String query) async {
    _history.remove(query);
  }

  @override
  Future<void> clearRecentSearches() async {
    _history.clear();
  }
}

void main() {
  group('Category and Feed Feature Tests', () {
    late YouTubeV3Service service;
    late HomeProvider home;

    setUp(() {
      service = YouTubeV3Service();
      home = HomeProvider(platformService: service);
    });

    test('Initial feed and trending videos load properly', () async {
      await home.loadHomeContent();
      expect(home.feedVideos.isNotEmpty, true);
      expect(home.trendingVideos.isNotEmpty, true);
      expect(home.selectedCategory, 'All');
    });

    test('Selecting Trending category loads trending content', () async {
      home.selectCategory('Trending');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(home.selectedCategory, 'Trending');
      expect(home.feedVideos.isNotEmpty, true);
    });

    test('Selecting Music category returns music videos', () async {
      home.selectCategory('Music');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(home.selectedCategory, 'Music');
      expect(home.feedVideos.isNotEmpty, true);
      expect(
        home.feedVideos.any((v) => v.description.contains('#music') || v.title.toLowerCase().contains('music') || v.channelTitle.toLowerCase().contains('music')),
        true,
      );
    });

    test('Selecting Gaming category returns gaming videos', () async {
      home.selectCategory('Gaming');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(home.selectedCategory, 'Gaming');
      expect(home.feedVideos.isNotEmpty, true);
      expect(
        home.feedVideos.any((v) => v.title.contains('Minecraft') || v.title.contains('GTA') || v.title.contains('VALORANT')),
        true,
      );
    });

    test('Selecting Podcasts category returns podcast videos', () async {
      home.selectCategory('Podcasts');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(home.selectedCategory, 'Podcasts');
      expect(home.feedVideos.isNotEmpty, true);
      expect(
        home.feedVideos.any((v) => v.title.contains('Fridman') || v.title.contains('Huberman') || v.title.contains('Rogan')),
        true,
      );
    });

    test('Selecting Science & Tech category returns tech videos', () async {
      home.selectCategory('Science & Tech');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(home.selectedCategory, 'Science & Tech');
      expect(home.feedVideos.isNotEmpty, true);
      expect(
        home.feedVideos.any((v) => v.title.contains('Vision Pro') || v.title.contains('Flutter') || v.title.contains('Computer Science')),
        true,
      );
    });

    test('Selecting News category returns news and documentary videos', () async {
      home.selectCategory('News');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(home.selectedCategory, 'News');
      expect(home.feedVideos.isNotEmpty, true);
      expect(
        home.feedVideos.any((v) => v.title.contains('BBC') || v.title.contains('Vox') || v.title.contains('Bloomberg')),
        true,
      );
    });

    test('Selecting Education category returns educational videos', () async {
      home.selectCategory('Education');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(home.selectedCategory, 'Education');
      expect(home.feedVideos.isNotEmpty, true);
      expect(
        home.feedVideos.any((v) => v.title.contains('Math') || v.channelTitle.contains('3Blue1Brown') || v.channelTitle.contains('Veritasium')),
        true,
      );
    });

    test('Selecting Documentaries category returns documentary videos', () async {
      home.selectCategory('Documentaries');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(home.selectedCategory, 'Documentaries');
      expect(home.feedVideos.isNotEmpty, true);
      expect(
        home.feedVideos.any((v) => v.title.contains('DW') || v.title.contains('Transit') || v.title.contains('Microchips')),
        true,
      );
    });

    test('Switching back to All reloads full feed', () async {
      home.selectCategory('Gaming');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(home.selectedCategory, 'Gaming');

      home.selectCategory('All');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(home.selectedCategory, 'All');
      expect(home.feedVideos.isNotEmpty, true);
    });
  });

  group('YouTube URL & Search Feature Tests', () {
    late YouTubeV3Service service;

    setUp(() {
      service = YouTubeV3Service();
    });

    test('Direct youtu.be URL is extracted and returned as video result', () async {
      final results = await service.searchVideos('https://youtu.be/dQw4w9WgXcQ');
      expect(results.length, 1);
      expect(results.first.id, 'dQw4w9WgXcQ');
    });

    test('Direct youtube.com/watch?v= URL is extracted and returned as video result', () async {
      final results = await service.searchVideos('https://www.youtube.com/watch?v=kJQP7kiw5Fk');
      expect(results.length, 1);
      expect(results.first.id, 'kJQP7kiw5Fk');
    });

    test('Direct 11-char video ID is extracted and returned', () async {
      final results = await service.searchVideos('fJ9rUzIMcZQ');
      expect(results.length, 1);
      expect(results.first.id, 'fJ9rUzIMcZQ');
    });

    test('Search keyword "flutter" returns Flutter video', () async {
      final results = await service.searchVideos('flutter');
      expect(results.isNotEmpty, true);
      expect(results.any((v) => v.title.contains('Flutter')), true);
    });

    test('Search keyword "shorts" returns vertical shorts', () async {
      final results = await service.searchVideos('shorts trending');
      expect(results.isNotEmpty, true);
      expect(results.any((v) => v.description.contains('#shorts')), true);
    });
  });

  group('SearchProvider Integration Tests', () {
    late YouTubeV3Service service;
    late FakeSearchRepository repo;
    late SearchProvider searchProvider;

    setUp(() {
      service = YouTubeV3Service();
      repo = FakeSearchRepository();
      searchProvider = SearchProvider(platformService: service, searchRepository: repo);
    });

    test('executeSearch populates search results and saves recent search', () async {
      await searchProvider.executeSearch('Minecraft');
      expect(searchProvider.searchResults.isNotEmpty, true);
      expect(searchProvider.recentSearches.contains('Minecraft'), true);
      expect(searchProvider.currentQuery, 'Minecraft');
    });

    test('Sorting order change preserves query and updates state', () async {
      searchProvider.setSortOrder('date');
      expect(searchProvider.sortOrder, 'date');
    });

    test('Recent searches can be removed and cleared', () async {
      await searchProvider.executeSearch('Topic A');
      await searchProvider.executeSearch('Topic B');
      expect(searchProvider.recentSearches.length, 2);

      await searchProvider.removeRecentSearch('Topic A');
      expect(searchProvider.recentSearches.contains('Topic A'), false);
      expect(searchProvider.recentSearches.contains('Topic B'), true);

      await searchProvider.clearRecentSearches();
      expect(searchProvider.recentSearches.isEmpty, true);
    });
  });
}
