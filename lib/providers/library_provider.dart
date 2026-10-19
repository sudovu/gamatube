import 'package:flutter/foundation.dart';
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
}
