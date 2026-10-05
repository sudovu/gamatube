import 'package:flutter/foundation.dart';
import '../api/cache_manager.dart';
import '../core/device/device_profiler.dart';
import '../core/storage/local_store.dart';
import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  final CacheManager _cacheManager;
  final LocalStore _localStore;
  AppSettings _settings = const AppSettings();
  bool _isLoading = true;

  SettingsProvider({
    required this._settingsRepository,
    required this._cacheManager,
    required this._localStore,
  }) {
    loadSettings();
  }

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();
    _settings = await _settingsRepository.getSettings();
    _cacheManager.updateMaxSizeBytes(_settings.maxCacheSizeMb);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    notifyListeners();
    await _settingsRepository.saveSettings(_settings);
  }

  Future<void> setHighContrast(bool value) async {
    _settings = _settings.copyWith(highContrast: value);
    notifyListeners();
    await _settingsRepository.saveSettings(_settings);
  }

  Future<void> setReduceMotion(bool value) async {
    _settings = _settings.copyWith(reduceMotion: value);
    notifyListeners();
    await _settingsRepository.saveSettings(_settings);
  }

  Future<void> setBandwidthMode(BandwidthMode mode) async {
    _settings = _settings.copyWith(bandwidthMode: mode);
    notifyListeners();
    await _settingsRepository.saveSettings(_settings);
  }

  Future<void> setForceLowEndMode(bool value) async {
    _settings = _settings.copyWith(forceLowEndMode: value);
    notifyListeners();
    await _settingsRepository.saveSettings(_settings);
  }

  Future<void> setAutoplay(bool value) async {
    _settings = _settings.copyWith(autoplay: value);
    notifyListeners();
    await _settingsRepository.saveSettings(_settings);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _settings = _settings.copyWith(playbackSpeed: speed);
    notifyListeners();
    await _settingsRepository.saveSettings(_settings);
  }

  Future<void> setDefaultQuality(String quality) async {
    _settings = _settings.copyWith(defaultQuality: quality);
    notifyListeners();
    await _settingsRepository.saveSettings(_settings);
  }

  Future<void> setMaxCacheSizeMb(int mb) async {
    _settings = _settings.copyWith(maxCacheSizeMb: mb);
    _cacheManager.updateMaxSizeBytes(mb);
    notifyListeners();
    await _settingsRepository.saveSettings(_settings);
  }

  Future<void> setHistoryPaused(bool value) async {
    _settings = _settings.copyWith(historyPaused: value);
    notifyListeners();
    await _settingsRepository.saveSettings(_settings);
  }

  Future<void> setAnalyticsOptIn(bool value) async {
    _settings = _settings.copyWith(analyticsOptIn: value);
    notifyListeners();
    await _settingsRepository.saveSettings(_settings);
  }

  Future<void> setCrashReportingOptIn(bool value) async {
    _settings = _settings.copyWith(crashReportingOptIn: value);
    notifyListeners();
    await _settingsRepository.saveSettings(_settings);
  }

  Future<void> setCustomApiKey(String? key) async {
    _settings = _settings.copyWith(customApiKey: key);
    notifyListeners();
    await _settingsRepository.saveSettings(_settings);
  }

  Future<void> clearCache() async {
    _cacheManager.clear();
    notifyListeners();
  }

  Future<void> clearAllLocalData() async {
    _cacheManager.clear();
    await _localStore.clearAll();
    _settings = const AppSettings();
    notifyListeners();
  }
}
