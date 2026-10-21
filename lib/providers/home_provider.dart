import 'package:flutter/foundation.dart';
import '../api/video_platform_service.dart';
import '../core/errors/failures.dart';
import '../models/video.dart';

class HomeProvider extends ChangeNotifier {
  final VideoPlatformService _platformService;
  List<Video> _feedVideos = [];
  List<Video> _trendingVideos = [];
  List<Video> _shorts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  Failure? _error;
  String _selectedCategory = 'All';
  int _refreshSeed = 0;

  // Track seen video IDs to guarantee that pull-down-to-refresh and infinite scroll
  // NEVER show repeated videos.
  final Set<String> _seenVideoIds = {};

  final List<String> categories = const [
    'All',
    'Trending',
    'Music',
    'Gaming',
    'Podcasts',
    'Science & Tech',
    'News',
    'Education',
    'Documentaries',
  ];

  HomeProvider({required VideoPlatformService platformService})
      : _platformService = platformService {
    loadHomeContent();
  }

  List<Video> get feedVideos => _feedVideos;
  List<Video> get trendingVideos => _trendingVideos;
  List<Video> get shorts => _shorts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  Failure? get error => _error;
  String get selectedCategory => _selectedCategory;

  List<Video> _deduplicate(List<Video> list) {
    final seen = <String>{};
    return list.where((v) => seen.add(v.id)).toList();
  }

  Future<void> loadHomeContent({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_selectedCategory != 'All') {
        if (_selectedCategory == 'Trending') {
          await _loadTrendingCategory(refresh: refresh);
        } else {
          await _searchCategoryVideos(_selectedCategory, refresh: refresh);
        }
        _isLoading = false;
        notifyListeners();
        return;
      }

      final feed = await _platformService.getHomeFeed();
      final trending = await _platformService.getTrending();
      _trendingVideos = trending;

      if (refresh) {
        _refreshSeed++;
        // Rotating discovery queries for genuine multi-topic fresh results on every pull down
        final discoveryTopics = [
          'trending music tech gaming',
          'popular video highlights',
          'science technology breakthroughs',
          'top podcasts interviews',
          'gaming walkthrough trailer',
          'hit songs official',
          'educational deep dive',
          'world news analysis',
        ];
        final topic = discoveryTopics[_refreshSeed % discoveryTopics.length];
        final searched = await _platformService.searchVideos(topic);

        // Combine all candidates and deduplicate
        final candidates = _deduplicate([...searched, ...feed, ...trending]);

        // Extract verified shorts only
        final shortsCandidates = candidates.where((v) {
          final isShortDuration = v.duration != null && v.duration!.inSeconds <= 60;
          final hasShortTag = v.description.toLowerCase().contains('#shorts') ||
              v.title.toLowerCase().contains('#shorts');
          if (v.duration != null && v.duration!.inSeconds > 70) return false;
          return isShortDuration || hasShortTag;
        }).toList();
        if (shortsCandidates.isNotEmpty) {
          _shorts = shortsCandidates.take(8).toList();
        }

        // Prioritize videos that haven't been shown yet this session
        final unseen = candidates.where((v) => 
          !_seenVideoIds.contains(v.id) && !_feedVideos.any((e) => e.id == v.id)
        ).toList();

        if (unseen.length >= 8) {
          _feedVideos = unseen.take(15).toList();
          _seenVideoIds.addAll(_feedVideos.map((v) => v.id));
        } else {
          // If the pool is mostly seen, retain only currently visible IDs in the exclusion set
          // so newly loaded videos NEVER match what was just on screen!
          final currentScreenIds = _feedVideos.map((v) => v.id).toSet();
          _seenVideoIds.clear();
          _seenVideoIds.addAll(currentScreenIds);

          final fresh = candidates.where((v) => !currentScreenIds.contains(v.id)).toList();
          if (fresh.isNotEmpty) {
            _feedVideos = fresh.take(15).toList();
          } else {
            // Shift candidate order to guarantee varied layout
            final shift = (_refreshSeed * 7) % candidates.length;
            _feedVideos = [...candidates.sublist(shift), ...candidates.sublist(0, shift)].take(15).toList();
          }
          _seenVideoIds.addAll(_feedVideos.map((v) => v.id));
        }
      } else {
        // Initial load: take first batch and track
        final initial = _deduplicate([...feed, ...trending]);
        _feedVideos = initial.take(15).toList();
        _seenVideoIds.addAll(_feedVideos.map((v) => v.id));

        // Extract verified shorts only
        final shortsCandidates = initial.where((v) {
          final isShortDuration = v.duration != null && v.duration!.inSeconds <= 60;
          final hasShortTag = v.description.toLowerCase().contains('#shorts') ||
              v.title.toLowerCase().contains('#shorts');
          if (v.duration != null && v.duration!.inSeconds > 70) return false;
          return isShortDuration || hasShortTag;
        }).toList();
        if (shortsCandidates.isNotEmpty) {
          _shorts = shortsCandidates.take(8).toList();
        } else {
          try {
            final searchedShorts = await _platformService.searchVideos('shorts');
            _shorts = searchedShorts.where((v) {
              final isShortDuration = v.duration != null && v.duration!.inSeconds <= 60;
              final hasShortTag = v.description.toLowerCase().contains('#shorts') ||
                  v.title.toLowerCase().contains('#shorts');
              if (v.duration != null && v.duration!.inSeconds > 70) return false;
              return isShortDuration || hasShortTag;
            }).take(8).toList();
          } catch (_) {}
        }
      }

      _isLoading = false;
      notifyListeners();
    } on Failure catch (f) {
      _error = f;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = const ApiUnavailableFailure();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFeed() => loadHomeContent(refresh: true);

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      List<Video> more = [];
      if (_selectedCategory == 'All') {
        final queries = [
          'popular video highlights',
          'documentaries science nature',
          'coding tech future engineering',
          'world news global',
          'popular podcasts huberman lex',
          'gaming gameplay trailer',
          'music official hits coldplay',
        ];
        final query = queries[_refreshSeed % queries.length];
        _refreshSeed++;
        more = await _platformService.searchVideos(query);
      } else if (_selectedCategory == 'Trending') {
        more = await _platformService.getTrending();
      } else {
        final subQueries = [
          '$_selectedCategory best trending',
          '$_selectedCategory highlights viral',
          '$_selectedCategory official',
        ];
        final q = subQueries[_refreshSeed % subQueries.length];
        _refreshSeed++;
        more = await _platformService.searchVideos(q);
      }

      // Filter out items already visible in _feedVideos AND items in _seenVideoIds
      final newItems = more.where((v) => 
        !_feedVideos.any((e) => e.id == v.id) && !_seenVideoIds.contains(v.id)
      ).toList();

      if (newItems.isNotEmpty) {
        _feedVideos.addAll(newItems);
        _seenVideoIds.addAll(newItems.map((v) => v.id));
      } else {
        // Fallback: append any distinct items not yet currently visible
        final distinct = more.where((v) => !_feedVideos.any((e) => e.id == v.id)).toList();
        if (distinct.isNotEmpty) {
          _feedVideos.addAll(distinct.take(6));
          _seenVideoIds.addAll(distinct.map((v) => v.id));
        }
      }
      _isLoadingMore = false;
      notifyListeners();
    } catch (_) {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void selectCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    notifyListeners();
    if (category == 'All') {
      loadHomeContent();
    } else if (category == 'Trending') {
      _loadTrendingCategory();
    } else {
      _searchCategoryVideos(category);
    }
  }

  Future<void> _loadTrendingCategory({bool refresh = false}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final trending = await _platformService.getTrending();
      final deduplicated = _deduplicate(trending);

      if (refresh) {
        // Exclude currently visible items to prevent immediate repetition
        final currentIds = _feedVideos.map((v) => v.id).toSet();
        final fresh = deduplicated.where((v) => !currentIds.contains(v.id)).toList();
        _feedVideos = fresh.isNotEmpty ? fresh : deduplicated;
      } else {
        _feedVideos = deduplicated;
      }

      _seenVideoIds.addAll(_feedVideos.map((v) => v.id));
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _searchCategoryVideos(String category, {bool refresh = false}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await _platformService.searchVideos(category);
      final deduplicated = _deduplicate(results);

      if (refresh) {
        final currentIds = _feedVideos.map((v) => v.id).toSet();
        final fresh = deduplicated.where((v) => !currentIds.contains(v.id)).toList();
        _feedVideos = fresh.isNotEmpty ? fresh : deduplicated;
      } else {
        _feedVideos = deduplicated;
      }

      _seenVideoIds.addAll(_feedVideos.map((v) => v.id));
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }
}
