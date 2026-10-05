import '../core/constants/app_constants.dart';
import '../core/logging/app_logger.dart';
import '../core/storage/local_store.dart';
import '../models/video.dart';
import '../models/watch_history_item.dart';

abstract class HistoryRepository {
  Future<List<WatchHistoryItem>> getHistory();
  Future<void> addToHistory(Video video, Duration position, Duration duration);
  Future<void> removeFromHistory(String videoId);
  Future<void> clearHistory();
  Future<WatchHistoryItem?> getHistoryItem(String videoId);
}

class HistoryRepositoryImpl implements HistoryRepository {
  final LocalStore _localStore;

  HistoryRepositoryImpl({required this._localStore});

  @override
  Future<List<WatchHistoryItem>> getHistory() async {
    final list = await _localStore.getJsonList(AppConstants.keyWatchHistory);
    if (list == null) return [];
    return list.map((j) => WatchHistoryItem.fromJson(j)).toList();
  }

  @override
  Future<void> addToHistory(Video video, Duration position, Duration duration) async {
    final current = await getHistory();
    // Remove if already exists to push to front
    current.removeWhere((item) => item.video.id == video.id);

    final durMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : 1;
    final posMs = position.inMilliseconds;
    final pct = (posMs / durMs).clamp(0.0, 1.0);

    final newItem = WatchHistoryItem(
      video: video,
      watchedAt: DateTime.now(),
      position: position,
      duration: duration,
      completionPercentage: pct,
    );

    current.insert(0, newItem);

    // Limit history to 500 items to prevent unbounded storage
    if (current.length > 500) {
      current.removeRange(500, current.length);
    }

    await _localStore.setJsonList(
      AppConstants.keyWatchHistory,
      current.map((i) => i.toJson()).toList(),
    );
    AppLogger.debug('Recorded history for ${video.title} at $position');
  }

  @override
  Future<void> removeFromHistory(String videoId) async {
    final current = await getHistory();
    current.removeWhere((item) => item.video.id == videoId);
    await _localStore.setJsonList(
      AppConstants.keyWatchHistory,
      current.map((i) => i.toJson()).toList(),
    );
  }

  @override
  Future<void> clearHistory() async {
    await _localStore.remove(AppConstants.keyWatchHistory);
    AppLogger.info('Cleared watch history');
  }

  @override
  Future<WatchHistoryItem?> getHistoryItem(String videoId) async {
    final list = await getHistory();
    try {
      return list.firstWhere((i) => i.video.id == videoId);
    } catch (_) {
      return null;
    }
  }
}
