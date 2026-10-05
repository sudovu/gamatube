import 'package:flutter/foundation.dart';
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

  List<WatchHistoryItem> _history = [];
  List<Video> _watchLater = [];
  List<Playlist> _playlists = [];
  bool _isLoading = false;

  LibraryProvider({
    required this._historyRepository,
    required this._watchLaterRepository,
    required this._playlistRepository,
  }) {
    loadLibraryData();
  }

  List<WatchHistoryItem> get history => _history;
  List<Video> get watchLater => _watchLater;
  List<Playlist> get playlists => _playlists;
  bool get isLoading => _isLoading;

  Future<void> loadLibraryData() async {
    _isLoading = true;
    notifyListeners();

    _history = await _historyRepository.getHistory();
    _watchLater = await _watchLaterRepository.getWatchLaterVideos();
    _playlists = await _playlistRepository.getPlaylists();

    _isLoading = false;
    notifyListeners();
  }

  // Watch History actions
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
}
