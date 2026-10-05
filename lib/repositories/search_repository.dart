import '../core/constants/app_constants.dart';
import '../core/storage/local_store.dart';

abstract class SearchRepository {
  Future<List<String>> getRecentSearches();
  Future<void> addSearchQuery(String query);
  Future<void> removeSearchQuery(String query);
  Future<void> clearRecentSearches();
}

class SearchRepositoryImpl implements SearchRepository {
  final LocalStore _localStore;

  SearchRepositoryImpl({required this._localStore});

  @override
  Future<List<String>> getRecentSearches() async {
    final list = await _localStore.getJsonList(AppConstants.keySearchHistory);
    if (list == null) return [];
    return list.map((item) => item['query'] as String).toList();
  }

  @override
  Future<void> addSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final current = await getRecentSearches();
    current.remove(trimmed);
    current.insert(0, trimmed);

    if (current.length > 25) {
      current.removeRange(25, current.length);
    }

    await _localStore.setJsonList(
      AppConstants.keySearchHistory,
      current.map((q) => {'query': q}).toList(),
    );
  }

  @override
  Future<void> removeSearchQuery(String query) async {
    final current = await getRecentSearches();
    current.remove(query);
    await _localStore.setJsonList(
      AppConstants.keySearchHistory,
      current.map((q) => {'query': q}).toList(),
    );
  }

  @override
  Future<void> clearRecentSearches() async {
    await _localStore.remove(AppConstants.keySearchHistory);
  }
}
