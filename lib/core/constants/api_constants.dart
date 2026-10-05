class ApiConstants {
  static const String youtubeBaseUrl = 'https://www.googleapis.com/youtube/v3';
  static const String googleAuthEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const String googleTokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const String googleRevokeEndpoint = 'https://oauth2.googleapis.com/revoke';

  // Permitted official YouTube scopes
  static const List<String> defaultScopes = [
    'https://www.googleapis.com/auth/youtube.readonly',
    'openid',
    'profile',
    'email',
  ];

  static const List<String> fullScopes = [
    'https://www.googleapis.com/auth/youtube.readonly',
    'https://www.googleapis.com/auth/youtube',
    'openid',
    'profile',
    'email',
  ];

  // Request timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
