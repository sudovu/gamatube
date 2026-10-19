import 'package:flutter/foundation.dart';
import '../api/video_platform_service.dart';
import '../core/errors/failures.dart';
import '../models/video.dart';

class HomeProvider extends ChangeNotifier {
  final VideoPlatformService _platformService;
  List<Video> _feedVideos = [];
  List<Video> _trendingVideos = [];
  bool _isLoading = false;
  Failure? _error;
  String _selectedCategory = 'All';

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

  HomeProvider({required this._platformService}) {
    loadHomeContent();
  }

  bool _isLoadingMore = false;
  int _refreshSeed = 0;

  List<Video> get feedVideos => _feedVideos;
  List<Video> get trendingVideos => _trendingVideos;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  Failure? get error => _error;
  String get selectedCategory => _selectedCategory;

  Future<void> loadHomeContent({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final feed = await _platformService.getHomeFeed();
      final trending = await _platformService.getTrending();
      
      if (refresh) {
        _refreshSeed++;
        // Rotate or shuffle so pull-to-refresh offers new suggestions immediately
        final rotatedFeed = List<Video>.from(feed);
        if (rotatedFeed.isNotEmpty) {
          final shift = _refreshSeed % rotatedFeed.length;
          final head = rotatedFeed.sublist(shift);
          final tail = rotatedFeed.sublist(0, shift);
          _feedVideos = [...head, ...tail];
        } else {
          _feedVideos = feed;
        }
      } else {
        _feedVideos = feed;
      }
      
      _trendingVideos = trending;
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
        final queries = ['popular videos', 'documentaries', 'coding tech', 'world news', 'popular science'];
        final query = queries[_refreshSeed % queries.length];
        _refreshSeed++;
        more = await _platformService.searchVideos(query);
      } else if (_selectedCategory == 'Trending') {
        more = await _platformService.getTrending();
      } else {
        more = await _platformService.searchVideos('$_selectedCategory best trending');
      }

      final newItems = more.where((v) => !_feedVideos.any((e) => e.id == v.id)).toList();
      if (newItems.isNotEmpty) {
        _feedVideos.addAll(newItems);
      } else if (more.isNotEmpty) {
        // Fallback: append unique items or cycled items to satisfy endless scrolling
        _feedVideos.addAll(more.take(5));
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
      loadHomeContent(refresh: true);
    } else if (category == 'Trending') {
      _loadTrendingCategory();
    } else {
      _searchCategoryVideos(category);
    }
  }

  Future<void> _loadTrendingCategory() async {
    _isLoading = true;
    notifyListeners();
    try {
      final trending = await _platformService.getTrending();
      _feedVideos = trending;
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _searchCategoryVideos(String category) async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await _platformService.searchVideos(category);
      _feedVideos = results;
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }
}
