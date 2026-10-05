class AppConstants {
  static const String appName = 'GAMATUBE';
  static const String appTagline = 'Your Personal Clean Video Experience';
  static const String appVersion = '1.1.0';
  static const String buildNumber = '2';

  static const String privacyPolicyUrl = 'https://github.com/sudovu/gamatube/blob/main/PRIVACY.md';
  static const String termsUrl = 'https://github.com/sudovu/gamatube/blob/main/README.md';
  static const String sourceRepoUrl = 'https://github.com/sudovu/gamatube';

  // Storage keys
  static const String keySettings = 'gamatube_settings_v1';
  static const String keySearchHistory = 'gamatube_search_history_v1';
  static const String keyWatchHistory = 'gamatube_watch_history_v1';
  static const String keyWatchLater = 'gamatube_watch_later_v1';
  static const String keyPlaylists = 'gamatube_playlists_v1';
  static const String keyAuthSession = 'gamatube_auth_session_v1';
  static const String keySubscriptions = 'gamatube_subscriptions_v1';
  static const String keyFirstRun = 'gamatube_first_run_completed';

  // Cache configuration defaults
  static const int defaultCacheSizeMb = 250;
  static const List<int> cacheSizeOptionsMb = [100, 250, 500, 1024];
  static const Duration defaultCacheTtl = Duration(hours: 2);
}
