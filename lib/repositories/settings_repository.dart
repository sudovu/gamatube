import '../core/constants/app_constants.dart';
import '../core/storage/local_store.dart';
import '../models/app_settings.dart';

abstract class SettingsRepository {
  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);
  Future<bool> isFirstRunCompleted();
  Future<void> setFirstRunCompleted();
}

class SettingsRepositoryImpl implements SettingsRepository {
  final LocalStore _localStore;

  SettingsRepositoryImpl({required this._localStore});

  @override
  Future<AppSettings> getSettings() async {
    final json = await _localStore.getJson(AppConstants.keySettings);
    if (json == null) return const AppSettings();
    return AppSettings.fromJson(json);
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _localStore.setJson(AppConstants.keySettings, settings.toJson());
  }

  @override
  Future<bool> isFirstRunCompleted() async {
    final val = await _localStore.getString(AppConstants.keyFirstRun);
    return val == 'true';
  }

  @override
  Future<void> setFirstRunCompleted() async {
    await _localStore.setString(AppConstants.keyFirstRun, 'true');
  }
}
