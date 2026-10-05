import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../core/logging/app_logger.dart';
import '../core/storage/local_store.dart';
import '../models/playlist.dart';
import '../models/video.dart';

abstract class PlaylistRepository {
  Future<List<Playlist>> getPlaylists();
  Future<Playlist?> getPlaylist(String id);
  Future<Playlist> createPlaylist(String title, {String description = ''});
  Future<void> updatePlaylist(Playlist playlist);
  Future<void> deletePlaylist(String id);
  Future<void> addVideoToPlaylist(String playlistId, Video video);
  Future<void> removeVideoFromPlaylist(String playlistId, String videoId);
}

class PlaylistRepositoryImpl implements PlaylistRepository {
  final LocalStore _localStore;
  final Uuid _uuid = const Uuid();

  PlaylistRepositoryImpl({required this._localStore});

  @override
  Future<List<Playlist>> getPlaylists() async {
    final list = await _localStore.getJsonList(AppConstants.keyPlaylists);
    if (list == null) return [];
    return list.map((j) => Playlist.fromJson(j)).toList();
  }

  @override
  Future<Playlist?> getPlaylist(String id) async {
    final list = await getPlaylists();
    try {
      return list.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Playlist> createPlaylist(String title, {String description = ''}) async {
    final list = await getPlaylists();
    final playlist = Playlist(
      id: _uuid.v4(),
      title: title,
      description: description,
      createdAt: DateTime.now(),
      isLocal: true,
      items: [],
    );
    list.insert(0, playlist);
    await _save(list);
    AppLogger.info('Created playlist: $title');
    return playlist;
  }

  @override
  Future<void> updatePlaylist(Playlist playlist) async {
    final list = await getPlaylists();
    final index = list.indexWhere((p) => p.id == playlist.id);
    if (index != -1) {
      list[index] = playlist;
      await _save(list);
    }
  }

  @override
  Future<void> deletePlaylist(String id) async {
    final list = await getPlaylists();
    list.removeWhere((p) => p.id == id);
    await _save(list);
  }

  @override
  Future<void> addVideoToPlaylist(String playlistId, Video video) async {
    final playlist = await getPlaylist(playlistId);
    if (playlist == null) return;
    if (playlist.items.any((v) => v.id == video.id)) return;

    final updatedItems = List<Video>.from(playlist.items)..add(video);
    final updated = playlist.copyWith(
      items: updatedItems,
      videoCount: updatedItems.length,
      thumbnailUrl: playlist.thumbnailUrl ?? video.thumbnailUrl,
    );
    await updatePlaylist(updated);
  }

  @override
  Future<void> removeVideoFromPlaylist(String playlistId, String videoId) async {
    final playlist = await getPlaylist(playlistId);
    if (playlist == null) return;

    final updatedItems = List<Video>.from(playlist.items)
      ..removeWhere((v) => v.id == videoId);
    final updated = playlist.copyWith(
      items: updatedItems,
      videoCount: updatedItems.length,
    );
    await updatePlaylist(updated);
  }

  Future<void> _save(List<Playlist> playlists) async {
    await _localStore.setJsonList(
      AppConstants.keyPlaylists,
      playlists.map((p) => p.toJson()).toList(),
    );
  }
}
