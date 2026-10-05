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

  List<Video> get feedVideos => _feedVideos;
  List<Video> get trendingVideos => _trendingVideos;
  bool get isLoading => _isLoading;
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
      _feedVideos = feed;
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

  void selectCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    notifyListeners();
    if (category == 'All') {
      loadHomeContent(refresh: true);
    } else {
      _searchCategoryVideos(category);
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
