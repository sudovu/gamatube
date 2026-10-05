import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api/video_platform_service.dart';
import '../core/errors/failures.dart';
import '../models/video.dart';
import '../repositories/search_repository.dart';

class SearchProvider extends ChangeNotifier {
  final VideoPlatformService _platformService;
  final SearchRepository _searchRepository;

  List<String> _recentSearches = [];
  List<Video> _searchResults = [];
  bool _isLoading = false;
  Failure? _error;
  String _currentQuery = '';
  String _sortOrder = 'relevance';
  Timer? _debounceTimer;

  SearchProvider({
    required this._platformService,
    required this._searchRepository,
  }) {
    loadRecentSearches();
  }

  List<String> get recentSearches => _recentSearches;
  List<Video> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  Failure? get error => _error;
  String get currentQuery => _currentQuery;
  String get sortOrder => _sortOrder;

  Future<void> loadRecentSearches() async {
    _recentSearches = await _searchRepository.getRecentSearches();
    notifyListeners();
  }

  void onQueryChanged(String query) {
    _currentQuery = query;
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      _searchResults = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    // 400ms debounce to prevent unnecessary API hits
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      executeSearch(query);
    });
  }

  Future<void> executeSearch(String query, {bool saveHistory = true}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _currentQuery = trimmed;
    _isLoading = true;
    _error = null;
    notifyListeners();

    if (saveHistory) {
      await _searchRepository.addSearchQuery(trimmed);
      await loadRecentSearches();
    }

    try {
      final results = await _platformService.searchVideos(
        trimmed,
        order: _sortOrder,
      );
      _searchResults = results;
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

  void setSortOrder(String order) {
    if (_sortOrder == order) return;
    _sortOrder = order;
    if (_currentQuery.isNotEmpty) {
      executeSearch(_currentQuery, saveHistory: false);
    }
  }

  Future<void> removeRecentSearch(String query) async {
    await _searchRepository.removeSearchQuery(query);
    await loadRecentSearches();
  }

  Future<void> clearRecentSearches() async {
    await _searchRepository.clearRecentSearches();
    _recentSearches = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
