import '../core/constants/app_constants.dart';
import '../core/logging/app_logger.dart';
import '../core/storage/local_store.dart';
import '../models/video.dart';

abstract class WatchLaterRepository {
  Future<List<Video>> getWatchLaterVideos();
  Future<void> addToWatchLater(Video video);
  Future<void> removeFromWatchLater(String videoId);
  Future<bool> isInWatchLater(String videoId);
  Future<void> clearWatchLater();
}

class WatchLaterRepositoryImpl implements WatchLaterRepository {
  final LocalStore _localStore;

  WatchLaterRepositoryImpl({required this._localStore});

  @override
  Future<List<Video>> getWatchLaterVideos() async {
    final list = await _localStore.getJsonList(AppConstants.keyWatchLater);
    if (list == null) return [];
    return list.map((j) => Video.fromJson(j)).toList();
  }

  @override
  Future<void> addToWatchLater(Video video) async {
    final list = await getWatchLaterVideos();
    if (list.any((v) => v.id == video.id)) return;
    list.insert(0, video);
    await _localStore.setJsonList(
      AppConstants.keyWatchLater,
      list.map((v) => v.toJson()).toList(),
    );
    AppLogger.debug('Added to Watch Later: ${video.title}');
  }

  @override
  Future<void> removeFromWatchLater(String videoId) async {
    final list = await getWatchLaterVideos();
    list.removeWhere((v) => v.id == videoId);
    await _localStore.setJsonList(
      AppConstants.keyWatchLater,
      list.map((v) => v.toJson()).toList(),
    );
  }

  @override
  Future<bool> isInWatchLater(String videoId) async {
    final list = await getWatchLaterVideos();
    return list.any((v) => v.id == videoId);
  }

  @override
  Future<void> clearWatchLater() async {
    await _localStore.remove(AppConstants.keyWatchLater);
  }
}
