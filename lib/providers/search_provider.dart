import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../api/video_platform_service.dart';
import '../core/errors/failures.dart';
import '../models/video.dart';
import '../repositories/search_repository.dart';

class SearchProvider extends ChangeNotifier {
  final VideoPlatformService _platformService;
  final SearchRepository _searchRepository;
  final http.Client _client = http.Client();

  List<String> _recentSearches = [];
  List<String> _suggestions = [];
  List<Video> _searchResults = [];
  bool _isLoading = false;
  Failure? _error;
  String _currentQuery = '';
  String _sortOrder = 'relevance'; // relevance, date, viewCount, rating
  String _filterType = 'all'; // all, video, shorts
  String _filterDuration = 'all'; // all, short, medium, long
  String _filterDate = 'all'; // all, today, week, month, year
  bool _showSuggestions = false;
  Timer? _debounceTimer;

  SearchProvider({
    required this._platformService,
    required this._searchRepository,
  }) {
    loadRecentSearches();
  }

  List<String> get recentSearches => _recentSearches;
  List<String> get suggestions => _suggestions;
  List<Video> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  Failure? get error => _error;
  String get currentQuery => _currentQuery;
  String get sortOrder => _sortOrder;
  String get filterType => _filterType;
  String get filterDuration => _filterDuration;
  String get filterDate => _filterDate;
  bool get showSuggestions => _showSuggestions;

  List<Video> get filteredResults {
    var list = List<Video>.from(_searchResults);

    // 1. Type Filter
    if (_filterType == 'shorts') {
      list = list.where((v) =>
          v.description.contains('#shorts') ||
          v.title.toLowerCase().contains('#shorts') ||
          (v.duration != null && v.duration!.inSeconds <= 60)).toList();
    } else if (_filterType == 'video') {
      list = list.where((v) =>
          !v.description.contains('#shorts') &&
          (v.duration == null || v.duration!.inSeconds > 60)).toList();
    }

    // 2. Duration Filter
    if (_filterDuration == 'short') {
      list = list.where((v) => v.duration != null && v.duration!.inMinutes < 4).toList();
    } else if (_filterDuration == 'medium') {
      list = list.where((v) =>
          v.duration != null &&
          v.duration!.inMinutes >= 4 &&
          v.duration!.inMinutes <= 20).toList();
    } else if (_filterDuration == 'long') {
      list = list.where((v) => v.duration != null && v.duration!.inMinutes > 20).toList();
    }

    // 3. Date Filter
    final now = DateTime.now();
    if (_filterDate == 'today') {
      list = list.where((v) => v.publishedAt != null && now.difference(v.publishedAt!).inHours <= 24).toList();
    } else if (_filterDate == 'week') {
      list = list.where((v) => v.publishedAt != null && now.difference(v.publishedAt!).inDays <= 7).toList();
    } else if (_filterDate == 'month') {
      list = list.where((v) => v.publishedAt != null && now.difference(v.publishedAt!).inDays <= 30).toList();
    } else if (_filterDate == 'year') {
      list = list.where((v) => v.publishedAt != null && now.difference(v.publishedAt!).inDays <= 365).toList();
    }

    // 4. Sort Order
    if (_sortOrder == 'date') {
      list.sort((a, b) => (b.publishedAt ?? DateTime(2000)).compareTo(a.publishedAt ?? DateTime(2000)));
    } else if (_sortOrder == 'viewCount') {
      list.sort((a, b) => b.viewCount.compareTo(a.viewCount));
    } else if (_sortOrder == 'rating') {
      list.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    }

    return list;
  }

  Future<void> loadRecentSearches() async {
    _recentSearches = await _searchRepository.getRecentSearches();
    notifyListeners();
  }

  void onQueryChanged(String query) {
    _currentQuery = query;
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      _suggestions = [];
      _showSuggestions = false;
      notifyListeners();
      return;
    }

    _showSuggestions = true;
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      fetchSuggestions(query);
    });
  }

  Future<void> fetchSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    try {
      final uri = Uri.parse(
        'https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=${Uri.encodeComponent(trimmed)}',
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List && decoded.length > 1 && decoded[1] is List) {
          _suggestions = (decoded[1] as List).map((e) => e.toString()).toList();
          notifyListeners();
        }
      }
    } catch (_) {
      // Offline fallback: filter recent searches
      _suggestions = _recentSearches
          .where((s) => s.toLowerCase().contains(trimmed.toLowerCase()))
          .toList();
      notifyListeners();
    }
  }

  void hideSuggestions() {
    _showSuggestions = false;
    notifyListeners();
  }

  Future<void> executeSearch(String query, {bool saveHistory = true}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _currentQuery = trimmed;
    _showSuggestions = false;
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
    notifyListeners();
  }

  void setFilterType(String type) {
    if (_filterType == type) return;
    _filterType = type;
    notifyListeners();
  }

  void setFilterDuration(String duration) {
    if (_filterDuration == duration) return;
    _filterDuration = duration;
    notifyListeners();
  }

  void setFilterDate(String date) {
    if (_filterDate == date) return;
    _filterDate = date;
    notifyListeners();
  }

  void resetFilters() {
    _filterType = 'all';
    _filterDuration = 'all';
    _filterDate = 'all';
    _sortOrder = 'relevance';
    notifyListeners();
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
    _client.close();
    super.dispose();
  }
}
