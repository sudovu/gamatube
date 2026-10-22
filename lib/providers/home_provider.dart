import 'dart:math';
import 'package:flutter/foundation.dart';
import '../api/video_platform_service.dart';
import '../core/errors/failures.dart';
import '../core/storage/local_store.dart';
import '../models/video.dart';
import '../repositories/history_repository.dart';
import '../repositories/search_repository.dart';

class HomeProvider extends ChangeNotifier {
  final VideoPlatformService _platformService;
  final LocalStore? _localStore;
  final HistoryRepository? _historyRepository;
  final SearchRepository? _searchRepository;

  List<Video> _feedVideos = [];
  List<Video> _trendingVideos = [];
  List<Video> _shorts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  Failure? _error;
  String _selectedCategory = 'All';
  int _refreshSeed = 0;
  bool _seenLoaded = false;

  // Track seen video IDs persistently so every app launch and pull-to-refresh
  // guarantees 100% brand-new, unseen feed recommendations strictly like YouTube.
  final Set<String> _seenVideoIds = {};
  static const String _seenStorageKey = 'gamatube_seen_video_ids_v1';

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

  static const List<List<String>> _discoveryPools = [
    ['trending music hits official', 'breakthrough technology science AI', 'viral gaming walkthrough', 'popular comedy podcast'],
    ['viral trending global today', 'future gadgets robotics engineering', 'live acoustic concert music', '4K nature wildlife documentary'],
    ['popular entertainment video essay', 'world news documentary investigative', 'superhit songs official', 'must watch highlights'],
    ['top creators trending video', 'cybersecurity coding computer science', 'classic rock jazz live', 'mind blowing science discoveries'],
    ['popular esports gaming moments', 'inspiring interview podcast lex', 'award winning animation film', 'acoustic live performance music'],
    ['astronomy space documentary', 'top viral challenges trends', 'lofi beats chill music live', 'deep dive tech analysis'],
  ];

  static final List<Video> _curatedShortsFallback = [
    Video(
      id: 'qGL05qUFQTM',
      title: 'You came back playing in the dirt again #ai #funny #shorts',
      description: '#shorts',
      thumbnailUrl: 'https://img.youtube.com/vi/qGL05qUFQTM/hqdefault.jpg',
      channelId: 'channel_qGL05qUFQTM',
      channelTitle: 'Viral Shorts',
      publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      duration: const Duration(seconds: 35),
      viewCount: 100000000,
      likeCount: 4500000,
      isLive: false,
    ),
    Video(
      id: '1GDkjZm6coU',
      title: 'Heart-touching Cute Kitten Dance 🐾 #shorts',
      description: '#shorts',
      thumbnailUrl: 'https://img.youtube.com/vi/1GDkjZm6coU/hqdefault.jpg',
      channelId: 'channel_1GDkjZm6coU',
      channelTitle: 'Cute Moments',
      publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      duration: const Duration(seconds: 40),
      viewCount: 170000000,
      likeCount: 8200000,
      isLive: false,
    ),
    Video(
      id: 'UHvbqGeE3gY',
      title: 'That one Don ladki in school 🏫 #shorts',
      description: '#shorts',
      thumbnailUrl: 'https://img.youtube.com/vi/UHvbqGeE3gY/hqdefault.jpg',
      channelId: 'channel_UHvbqGeE3gY',
      channelTitle: 'Comedy Shorts',
      publishedAt: DateTime.now().subtract(const Duration(days: 3)),
      duration: const Duration(seconds: 45),
      viewCount: 41000000,
      likeCount: 1900000,
      isLive: false,
    ),
    Video(
      id: 'ioIV4l25I00',
      title: 'Sound test satisfaction #shorts #asmr',
      description: '#shorts',
      thumbnailUrl: 'https://img.youtube.com/vi/ioIV4l25I00/hqdefault.jpg',
      channelId: 'channel_ioIV4l25I00',
      channelTitle: 'Satisfying Art',
      publishedAt: DateTime.now().subtract(const Duration(days: 4)),
      duration: const Duration(seconds: 50),
      viewCount: 55000000,
      likeCount: 2300000,
      isLive: false,
    ),
  ];

  Future<void>? _activeLoadFuture;

  HomeProvider({
    required VideoPlatformService platformService,
    LocalStore? localStore,
    HistoryRepository? historyRepository,
    SearchRepository? searchRepository,
  })  : _platformService = platformService,
        _localStore = localStore,
        _historyRepository = historyRepository,
        _searchRepository = searchRepository {
    _activeLoadFuture = _initAndLoad();
  }

  List<Video> get feedVideos => _feedVideos;
  List<Video> get trendingVideos => _trendingVideos;
  List<Video> get shorts => _shorts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  Failure? get error => _error;
  String get selectedCategory => _selectedCategory;

  Future<void> _initAndLoad() async {
    await _loadSeenVideos();
    await _loadHomeContentInternal(refresh: false);
  }

  Future<void> _loadSeenVideos() async {
    if (_seenLoaded) return;
    try {
      final stored = await _localStore?.getStringList(_seenStorageKey);
      if (stored != null && stored.isNotEmpty) {
        _seenVideoIds.addAll(stored);
      }
    } catch (_) {}
    _seenLoaded = true;
  }

  Future<void> _saveSeenVideos() async {
    try {
      // Keep up to 500 recent seen IDs to ensure long-term novelty without bloat
      final toStore = _seenVideoIds.length > 500
          ? _seenVideoIds.skip(_seenVideoIds.length - 500).toList()
          : _seenVideoIds.toList();
      await _localStore?.setStringList(_seenStorageKey, toStore);
    } catch (_) {}
  }

  List<Video> _deduplicate(List<Video> list) {
    final seen = <String>{};
    return list.where((v) => seen.add(v.id)).toList();
  }

  /// Extracts personalized recommendation seed queries based on recent watch & search history
  Future<List<String>> _getPersonalizedQueries() async {
    final queries = <String>[];

    // 1. From Search History
    final searchRepo = _searchRepository;
    if (searchRepo != null) {
      try {
        final recent = await searchRepo.getRecentSearches();
        for (final q in recent.take(3)) {
          final trimmed = q.trim();
          if (trimmed.isNotEmpty) {
            queries.add('$trimmed recommendations');
            queries.add('$trimmed trending');
          }
        }
      } catch (_) {}
    }

    // 2. From Watch History (Channel and title keywords)
    final historyRepo = _historyRepository;
    if (historyRepo != null) {
      try {
        final history = await historyRepo.getHistory();
        for (final item in history.take(3)) {
          final ch = item.video.channelTitle;
          if (ch.isNotEmpty && ch != 'Creator') {
            queries.add('$ch official');
          }
        }
      } catch (_) {}
    }

    return queries;
  }

  Future<void> loadHomeContent({bool refresh = false}) async {
    if (_activeLoadFuture != null && !refresh) {
      await _activeLoadFuture;
      return;
    }

    final future = _loadHomeContentInternal(refresh: refresh);
    _activeLoadFuture = future;
    try {
      await future;
    } finally {
      if (_activeLoadFuture == future) {
        _activeLoadFuture = null;
      }
    }
  }

  Future<void> _loadHomeContentInternal({bool refresh = false}) async {
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

      await _loadSeenVideos();

      // Dynamic rotation seed: increments on refresh and changes on cold launch
      _refreshSeed = DateTime.now().millisecondsSinceEpoch;

      // Select dynamic discovery queries
      final poolIndex = (_refreshSeed ~/ 1000) % _discoveryPools.length;
      final discoverySet = _discoveryPools[poolIndex];

      // Formulate query tasks
      final queriesToFetch = <String>[];

      // Blend personalized related topics if available
      final personalized = await _getPersonalizedQueries();
      if (personalized.isNotEmpty) {
        final randomPick = personalized[_refreshSeed % personalized.length];
        queriesToFetch.add(randomPick);
      }

      // Add 2 diverse topics from the rotating discovery pool + shorts discovery
      queriesToFetch.add(discoverySet[0]);
      queriesToFetch.add(discoverySet[1]);
      queriesToFetch.add('#shorts trending');

      // Concurrently query live sources
      final searchTasks = queriesToFetch.map((q) => _platformService.searchVideos(q));
      final results = await Future.wait([
        _platformService.getHomeFeed(),
        _platformService.getTrending(),
        ...searchTasks,
      ]);

      final trending = results[1];
      _trendingVideos = trending;

      final allCandidates = <Video>[];
      for (final list in results) {
        allCandidates.addAll(list);
      }

      final deduplicated = _deduplicate(allCandidates);

      // Separate genuine vertical shorts (<60s)
      final shortsCandidates = deduplicated.where((v) {
        final isShortDuration = v.duration != null && v.duration!.inSeconds <= 60;
        final hasShortTag = v.description.toLowerCase().contains('#shorts') ||
            v.title.toLowerCase().contains('#shorts');
        if (v.duration != null && v.duration!.inSeconds > 70) return false;
        return isShortDuration || hasShortTag;
      }).toList();

      // Separate regular feed videos (>= 60s or not a short)
      final regularCandidates = deduplicated.where((v) {
        final isShort = (v.duration != null && v.duration!.inSeconds <= 60) ||
            v.description.toLowerCase().contains('#shorts') ||
            v.title.toLowerCase().contains('#shorts');
        return !isShort;
      }).toList();

      // Exclude previously seen videos
      var unseenVideos = regularCandidates.where((v) =>
        !_seenVideoIds.contains(v.id) && !_feedVideos.any((e) => e.id == v.id)
      ).toList();

      var unseenShorts = shortsCandidates.where((v) =>
        !_seenVideoIds.contains(v.id) && !_shorts.any((e) => e.id == v.id)
      ).toList();

      // If user has seen most candidates (or offline fallback), preserve novelty
      // by retaining only currently visible IDs in exclusion set and shuffling the pool
      if (unseenVideos.length < 8) {
        final currentScreenIds = _feedVideos.map((v) => v.id).toSet();
        _seenVideoIds.clear();
        _seenVideoIds.addAll(currentScreenIds);

        unseenVideos = regularCandidates.where((v) => !currentScreenIds.contains(v.id)).toList();
        unseenVideos.shuffle(Random(_refreshSeed));
      }

      if (unseenShorts.length < 4) {
        final currentShortIds = _shorts.map((v) => v.id).toSet();
        unseenShorts = shortsCandidates.where((v) => !currentShortIds.contains(v.id)).toList();
        unseenShorts.shuffle(Random(_refreshSeed + 1));
      }

      // Assign fresh feed and shorts
      _feedVideos = unseenVideos.take(20).toList();
      if (_feedVideos.isEmpty) {
        // Fallback safety
        _feedVideos = regularCandidates.take(15).toList();
      }

      if (unseenShorts.isNotEmpty) {
        _shorts = unseenShorts.take(8).toList();
      } else if (shortsCandidates.isNotEmpty) {
        _shorts = shortsCandidates.take(8).toList();
      } else {
        _shorts = List.from(_curatedShortsFallback);
      }

      // Track newly visible videos in the persistent seen registry
      _seenVideoIds.addAll(_feedVideos.map((v) => v.id));
      _seenVideoIds.addAll(_shorts.map((v) => v.id));
      await _saveSeenVideos();

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
        final poolIndex = (_refreshSeed ~/ 1000) % _discoveryPools.length;
        final queries = _discoveryPools[poolIndex];
        final query = queries[_feedVideos.length % queries.length];
        _refreshSeed += 137;
        more = await _platformService.searchVideos(query);
      } else if (_selectedCategory == 'Trending') {
        more = await _platformService.getTrending();
      } else {
        final subQueries = [
          '$_selectedCategory trending highlights',
          '$_selectedCategory best recommended',
          '$_selectedCategory new viral',
        ];
        final q = subQueries[_feedVideos.length % subQueries.length];
        _refreshSeed += 137;
        more = await _platformService.searchVideos(q);
      }

      // Filter out items already visible in _feedVideos AND items in _seenVideoIds
      final newItems = more.where((v) =>
        !_feedVideos.any((e) => e.id == v.id) && !_seenVideoIds.contains(v.id)
      ).toList();

      if (newItems.isNotEmpty) {
        _feedVideos.addAll(newItems);
        _seenVideoIds.addAll(newItems.map((v) => v.id));
        await _saveSeenVideos();
      } else {
        final distinct = more.where((v) => !_feedVideos.any((e) => e.id == v.id)).toList();
        if (distinct.isNotEmpty) {
          _feedVideos.addAll(distinct.take(8));
          _seenVideoIds.addAll(distinct.map((v) => v.id));
          await _saveSeenVideos();
        }
      }
      _isLoadingMore = false;
      notifyListeners();
    } catch (_) {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> selectCategory(String category) async {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    notifyListeners();
    if (category == 'All') {
      await loadHomeContent();
    } else if (category == 'Trending') {
      await _loadTrendingCategory();
    } else {
      await _searchCategoryVideos(category);
    }
  }

  Future<void> _loadTrendingCategory({bool refresh = false}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final trending = await _platformService.getTrending();
      final deduplicated = _deduplicate(trending);

      if (refresh) {
        final currentIds = _feedVideos.map((v) => v.id).toSet();
        final fresh = deduplicated.where((v) => !currentIds.contains(v.id)).toList();
        _feedVideos = fresh.isNotEmpty ? fresh : deduplicated;
      } else {
        _feedVideos = deduplicated;
      }

      _seenVideoIds.addAll(_feedVideos.map((v) => v.id));
      await _saveSeenVideos();
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
      await _saveSeenVideos();
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }
}
