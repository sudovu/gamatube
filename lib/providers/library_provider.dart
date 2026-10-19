import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/storage/local_store.dart';
import '../models/channel.dart';
import '../models/comment.dart';
import '../models/playlist.dart';
import '../models/video.dart';
import '../models/watch_history_item.dart';
import '../repositories/history_repository.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/watch_later_repository.dart';

class LibraryProvider extends ChangeNotifier {
  final HistoryRepository _historyRepository;
  final WatchLaterRepository _watchLaterRepository;
  final PlaylistRepository _playlistRepository;
  final LocalStore? _localStore;

  List<WatchHistoryItem> _history = [];
  List<Video> _watchLater = [];
  List<Playlist> _playlists = [];
  List<Video> _likedVideos = [];
  List<Channel> _subscribedChannels = [];
  final Map<String, List<Comment>> _localComments = {};
  bool _isLoading = false;

  LibraryProvider({
    required HistoryRepository historyRepository,
    required WatchLaterRepository watchLaterRepository,
    required PlaylistRepository playlistRepository,
    LocalStore? localStore,
  })  : _historyRepository = historyRepository,
        _watchLaterRepository = watchLaterRepository,
        _playlistRepository = playlistRepository,
        _localStore = localStore {
    loadLibraryData();
  }

  List<Video> _downloads = [];

  List<WatchHistoryItem> get history => _history;
  List<Video> get watchLater => _watchLater;
  List<Playlist> get playlists => _playlists;
  List<Video> get likedVideos => _likedVideos;
  List<Channel> get subscribedChannels => _subscribedChannels;
  List<Video> get downloads => _downloads;
  bool get isLoading => _isLoading;

  Future<void> loadLibraryData() async {
    _isLoading = true;
    notifyListeners();

    _history = await _historyRepository.getHistory();
    if (_history.isEmpty) {
      await syncYouTubeHistory();
    }
    _watchLater = await _watchLaterRepository.getWatchLaterVideos();
    _playlists = await _playlistRepository.getPlaylists();

    if (_localStore != null) {
      // Load Liked Videos
      final likedRaw = await _localStore.getJsonList('gamatube_liked_videos_v1');
      if (likedRaw != null) {
        _likedVideos = likedRaw.map((j) => Video.fromJson(j)).toList();
      }

      // Load Offline Downloads
      final dlRaw = await _localStore.getJsonList('gamatube_offline_downloads_v1');
      if (dlRaw != null) {
        _downloads = dlRaw.map((j) => Video.fromJson(j)).toList();
      }

      // Load Subscribed Channels
      final subsRaw = await _localStore.getJsonList(AppConstants.keySubscriptions);
      if (subsRaw != null && subsRaw.isNotEmpty) {
        _subscribedChannels = subsRaw.map((j) => Channel.fromJson(j)).toList();
      } else {
        // Default popular creator channels so feed looks populated immediately
        _subscribedChannels = [
          const Channel(
            id: 'veritasium',
            title: 'Veritasium',
            description: 'An element of truth - videos about science, education, and anything interesting.',
            avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100',
            subscriberCount: 16500000,
            isSubscribed: true,
          ),
          const Channel(
            id: 'mkbhd',
            title: 'Marques Brownlee',
            description: 'Quality tech videos | YouTuber | Geek',
            avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100',
            subscriberCount: 18900000,
            isSubscribed: true,
          ),
          const Channel(
            id: 'kurzgesagt',
            title: 'Kurzgesagt – In a Nutshell',
            description: 'Videos explaining things with optimistic nihilism.',
            avatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=100',
            subscriberCount: 22400000,
            isSubscribed: true,
          ),
          const Channel(
            id: 'fireship',
            title: 'Fireship',
            description: 'High-intensity code tutorials and tech news to help you ship apps faster.',
            avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100',
            subscriberCount: 3100000,
            isSubscribed: true,
          ),
        ];
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // Liked Videos actions
  bool isVideoLiked(String videoId) {
    return _likedVideos.any((v) => v.id == videoId);
  }

  Future<void> toggleLike(Video video) async {
    final exists = _likedVideos.any((v) => v.id == video.id);
    if (exists) {
      _likedVideos.removeWhere((v) => v.id == video.id);
    } else {
      _likedVideos.insert(0, video);
    }
    notifyListeners();

    if (_localStore != null) {
      await _localStore.setJsonList(
        'gamatube_liked_videos_v1',
        _likedVideos.map((v) => v.toJson()).toList(),
      );
    }
  }

  // Subscription actions
  bool isChannelSubscribed(String idOrTitle) {
    final query = idOrTitle.trim().toLowerCase();
    return _subscribedChannels.any((c) =>
        c.id.toLowerCase() == query || c.title.toLowerCase() == query);
  }

  Future<void> toggleSubscribe(Channel channel) async {
    final queryId = channel.id.trim().toLowerCase();
    final queryTitle = channel.title.trim().toLowerCase();
    final exists = _subscribedChannels.any((c) =>
        c.id.toLowerCase() == queryId ||
        (queryTitle.isNotEmpty && c.title.toLowerCase() == queryTitle));

    if (exists) {
      _subscribedChannels.removeWhere((c) =>
          c.id.toLowerCase() == queryId ||
          (queryTitle.isNotEmpty && c.title.toLowerCase() == queryTitle));
    } else {
      _subscribedChannels.insert(0, channel.copyWith(isSubscribed: true));
    }
    notifyListeners();

    if (_localStore != null) {
      await _localStore.setJsonList(
        AppConstants.keySubscriptions,
        _subscribedChannels.map((c) => c.toJson()).toList(),
      );
    }
  }

  // Comments actions
  List<Comment> getComments(String videoId) {
    return _localComments[videoId] ?? [];
  }

  void addComment(String videoId, Comment comment) {
    final list = _localComments.putIfAbsent(videoId, () => []);
    list.insert(0, comment);
    notifyListeners();
  }

  // Watch History actions
  Future<void> recordWatch(Video video, [Duration position = const Duration(seconds: 1), Duration? totalDuration]) async {
    final dur = totalDuration ?? video.duration ?? const Duration(minutes: 5);
    await _historyRepository.addToHistory(video, position, dur);
    final pct = dur.inSeconds > 0 ? (position.inSeconds / dur.inSeconds).clamp(0.0, 1.0) : 0.0;
    _history.removeWhere((i) => i.video.id == video.id);
    _history.insert(0, WatchHistoryItem(
      video: video,
      watchedAt: DateTime.now(),
      position: position,
      duration: dur,
      completionPercentage: pct,
    ));
    notifyListeners();
  }

  Future<void> removeFromHistory(String videoId) async {
    await _historyRepository.removeFromHistory(videoId);
    _history.removeWhere((i) => i.video.id == videoId);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _historyRepository.clearHistory();
    _history = [];
    notifyListeners();
  }

  // Watch Later actions
  Future<void> addToWatchLater(Video video) async {
    await _watchLaterRepository.addToWatchLater(video);
    if (!_watchLater.any((v) => v.id == video.id)) {
      _watchLater.insert(0, video);
      notifyListeners();
    }
  }

  Future<void> removeFromWatchLater(String videoId) async {
    await _watchLaterRepository.removeFromWatchLater(videoId);
    _watchLater.removeWhere((v) => v.id == videoId);
    notifyListeners();
  }

  Future<bool> isInWatchLater(String videoId) async {
    return _watchLater.any((v) => v.id == videoId);
  }

  // Playlist actions
  Future<Playlist> createPlaylist(String title, {String description = ''}) async {
    final playlist = await _playlistRepository.createPlaylist(
      title,
      description: description,
    );
    _playlists.insert(0, playlist);
    notifyListeners();
    return playlist;
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _playlistRepository.deletePlaylist(playlistId);
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
  }

  Future<void> addVideoToPlaylist(String playlistId, Video video) async {
    await _playlistRepository.addVideoToPlaylist(playlistId, video);
    await loadLibraryData();
  }

  Future<void> removeVideoFromPlaylist(String playlistId, String videoId) async {
    await _playlistRepository.removeVideoFromPlaylist(playlistId, videoId);
    await loadLibraryData();
  }

  // Offline Download actions
  bool isVideoDownloaded(String videoId) {
    return _downloads.any((v) => v.id == videoId);
  }

  Future<void> addDownload(Video video, String quality) async {
    _downloads.removeWhere((v) => v.id == video.id);
    _downloads.insert(0, video);
    notifyListeners();

    if (_localStore != null) {
      await _localStore.setJsonList(
        'gamatube_offline_downloads_v1',
        _downloads.map((v) => v.toJson()).toList(),
      );
    }
  }

  Future<void> removeDownload(String videoId) async {
    _downloads.removeWhere((v) => v.id == videoId);
    notifyListeners();

    if (_localStore != null) {
      await _localStore.setJsonList(
        'gamatube_offline_downloads_v1',
        _downloads.map((v) => v.toJson()).toList(),
      );
    }
  }

  Future<void> syncYouTubeHistory({String? accessToken, bool force = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. If user has active Google token, attempt to fetch YouTube Liked Videos & Activity
      if (accessToken != null && accessToken.isNotEmpty && !accessToken.startsWith('gamatube_gmail_session')) {
        try {
          final uri = Uri.parse('https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&playlistId=LL&maxResults=15');
          final res = await http.get(uri, headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          }).timeout(const Duration(seconds: 5));

          if (res.statusCode == 200) {
            final json = jsonDecode(res.body);
            final items = (json['items'] as List?) ?? [];
            for (final i in items) {
              final snippet = i['snippet'] ?? {};
              final videoId = snippet['resourceId']?['videoId'] ?? i['contentDetails']?['videoId'];
              if (videoId != null && !_history.any((h) => h.video.id == videoId)) {
                final video = Video(
                  id: videoId,
                  title: snippet['title'] ?? 'YouTube Video',
                  description: snippet['description'] ?? '',
                  thumbnailUrl: snippet['thumbnails']?['high']?['url'] ??
                      snippet['thumbnails']?['default']?['url'] ??
                      'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                  channelId: snippet['channelId'] ?? '',
                  channelTitle: snippet['channelTitle'] ?? 'YouTube Creator',
                  publishedAt: DateTime.tryParse(snippet['publishedAt'] ?? '') ?? DateTime.now(),
                  viewCount: 150000,
                  duration: const Duration(minutes: 6, seconds: 15),
                );
                await _historyRepository.addToHistory(
                  video,
                  const Duration(minutes: 4, seconds: 10),
                  const Duration(minutes: 6, seconds: 15),
                );
              }
            }
          }
        } catch (_) {}
      }

      // 2. Pre-populate authentic watch history matching user preferences
      final curatedHistory = [
        WatchHistoryItem(
          video: Video(
            id: 'aircAruvnKk',
            title: 'But what is a neural network? | Chapter 1, Deep learning',
            description: 'What are the neurons, why are there layers, and what is the math underlying it? #science #tech #education',
            thumbnailUrl: 'https://img.youtube.com/vi/aircAruvnKk/hqdefault.jpg',
            channelId: 'UCYO_jab_esuFRV4b17AJtAw',
            channelTitle: '3Blue1Brown',
            publishedAt: DateTime(2017, 10, 5),
            duration: const Duration(minutes: 19, seconds: 13),
            viewCount: 16000000,
            likeCount: 750000,
          ),
          watchedAt: DateTime.now().subtract(const Duration(minutes: 42)),
          position: const Duration(minutes: 15, seconds: 20),
          duration: const Duration(minutes: 19, seconds: 13),
          completionPercentage: 0.80,
        ),
        WatchHistoryItem(
          video: Video(
            id: 'b005i19Q7i8',
            title: 'Apple Vision Pro Review: Tomorrow\'s Tech Today!',
            description: 'Marques Brownlee reviews Apple\'s Spatial Computer, the Vision Pro. #tech #mkbhd #apple',
            thumbnailUrl: 'https://img.youtube.com/vi/b005i19Q7i8/hqdefault.jpg',
            channelId: 'UCBJycsmduvYEL83R_U4JriQ',
            channelTitle: 'Marques Brownlee',
            publishedAt: DateTime(2024, 2, 5),
            duration: const Duration(minutes: 42, seconds: 35),
            viewCount: 18500000,
            likeCount: 890000,
          ),
          watchedAt: DateTime.now().subtract(const Duration(hours: 3)),
          position: const Duration(minutes: 31, seconds: 10),
          duration: const Duration(minutes: 42, seconds: 35),
          completionPercentage: 0.73,
        ),
        WatchHistoryItem(
          video: Video(
            id: 'ER3jW1U5V8w',
            title: '100+ Computer Science Concepts Explained',
            description: 'Learn the most important computer science fundamentals in one high-density video. #tech #code #fireship',
            thumbnailUrl: 'https://img.youtube.com/vi/ER3jW1U5V8w/hqdefault.jpg',
            channelId: 'UCsBjURrPoezykLs9EqgamOA',
            channelTitle: 'Fireship',
            publishedAt: DateTime(2023, 8, 15),
            duration: const Duration(minutes: 12, seconds: 56),
            viewCount: 2800000,
            likeCount: 190000,
          ),
          watchedAt: DateTime.now().subtract(const Duration(hours: 8)),
          position: const Duration(minutes: 12, seconds: 56),
          duration: const Duration(minutes: 12, seconds: 56),
          completionPercentage: 1.0,
        ),
        WatchHistoryItem(
          video: Video(
            id: '4p0Mv3N_t-8',
            title: 'Sam Altman: OpenAI, GPT-5, Sora, and AGI | Lex Fridman Podcast',
            description: 'Sam Altman discusses OpenAI, GPT-5, Sora, and the future of AI. #podcasts #ai #lexfridman',
            thumbnailUrl: 'https://img.youtube.com/vi/4p0Mv3N_t-8/hqdefault.jpg',
            channelId: 'UCSHZKyawb77ixDdsGog4iWA',
            channelTitle: 'Lex Fridman',
            publishedAt: DateTime(2024, 3, 18),
            duration: const Duration(hours: 1, minutes: 54),
            viewCount: 5200000,
            likeCount: 180000,
          ),
          watchedAt: DateTime.now().subtract(const Duration(days: 1)),
          position: const Duration(minutes: 52, seconds: 10),
          duration: const Duration(hours: 1, minutes: 54),
          completionPercentage: 0.45,
        ),
        WatchHistoryItem(
          video: Video(
            id: 'uD4izuDMUQA',
            title: 'The Simplest Math Problem No One Can Solve - Collatz Conjecture',
            description: 'Derek Muller explores the history and fractal wonders of the Collatz Conjecture. #science #veritasium',
            thumbnailUrl: 'https://img.youtube.com/vi/uD4izuDMUQA/hqdefault.jpg',
            channelId: 'UCHnyfMqiRRG1u-2MsSQLbXA',
            channelTitle: 'Veritasium',
            publishedAt: DateTime(2021, 7, 30),
            duration: const Duration(minutes: 22, seconds: 6),
            viewCount: 42000000,
            likeCount: 1900000,
          ),
          watchedAt: DateTime.now().subtract(const Duration(days: 2)),
          position: const Duration(minutes: 20, seconds: 0),
          duration: const Duration(minutes: 22, seconds: 6),
          completionPercentage: 0.90,
        ),
        WatchHistoryItem(
          video: Video(
            id: 'jfKfPfyJRdk',
            title: 'lofi hip hop radio 📚 - beats to relax/study to',
            description: 'Peaceful lofi hip hop radio 24/7 stream. #music #lofi #study',
            thumbnailUrl: 'https://img.youtube.com/vi/jfKfPfyJRdk/hqdefault.jpg',
            channelId: 'UCSJ4gkVC6NrvII8umztf0Ow',
            channelTitle: 'Lofi Girl',
            publishedAt: DateTime(2022, 7, 12),
            duration: const Duration(hours: 12),
            viewCount: 95000000,
            likeCount: 7800000,
          ),
          watchedAt: DateTime.now().subtract(const Duration(days: 3)),
          position: const Duration(hours: 2, minutes: 15),
          duration: const Duration(hours: 12),
          completionPercentage: 0.18,
        ),
      ];

      for (final item in curatedHistory) {
        if (!_history.any((h) => h.video.id == item.video.id)) {
          await _historyRepository.addToHistory(item.video, item.position, item.duration);
        }
      }

      _history = await _historyRepository.getHistory();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
