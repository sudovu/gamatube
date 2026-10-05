import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/api_constants.dart';
import '../core/constants/app_constants.dart';
import '../core/logging/app_logger.dart';
import '../core/storage/local_store.dart';
import '../models/user_profile.dart';

abstract class AuthService {
  Future<UserProfile?> getCurrentUser();
  Future<bool> isAuthenticated();
  Future<UserProfile?> signIn();
  Future<void> signOut();
  Future<String?> refreshToken();
}

class GoogleOAuthAuthService implements AuthService {
  final LocalStore _localStore;
  final String? _clientId;
  UserProfile? _currentUser;

  GoogleOAuthAuthService({
    required this._localStore,
    this._clientId,
  });

  @override
  Future<UserProfile?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;
    final json = await _localStore.getJson(AppConstants.keyAuthSession);
    if (json != null) {
      _currentUser = UserProfile.fromJson(json);
      return _currentUser;
    }
    return null;
  }

  @override
  Future<bool> isAuthenticated() async {
    final user = await getCurrentUser();
    return user != null && user.isAuthenticated;
  }

  @override
  Future<UserProfile?> signIn() async {
    AppLogger.info('Initiating Google Sign-In with OAuth');

    // In demo/open-source mode when client credentials are not configured in .env,
    // we provide a clean, local anonymous user or mock session for testing,
    // and if client credentials ARE provided, execute standard OAuth2 PKCE flow.
    final clientId = _clientId;
    if (clientId == null || clientId.isEmpty) {
      final user = UserProfile(
        id: 'local_user_1',
        name: 'Gamatube Explorer',
        email: 'explorer@gamatube.local',
        avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100',
        accessToken: 'mock_access_token_demo',
        tokenExpiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      _currentUser = user;
      await _localStore.setJson(AppConstants.keyAuthSession, user.toJson());
      AppLogger.info('Signed in with local profile');
      return user;
    }

    try {
      final state = _generateRandomString(32);
      final codeVerifier = _generateRandomString(64);
      final codeChallenge = base64Url
          .encode(sha256.convert(ascii.encode(codeVerifier)).bytes)
          .replaceAll('=', '');

      const redirectUri = 'http://localhost:8080/callback';
      final authUri = Uri.parse(ApiConstants.googleAuthEndpoint).replace(
        queryParameters: {
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': ApiConstants.defaultScopes.join(' '),
          'state': state,
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
        },
      );

      if (await canLaunchUrl(authUri)) {
        await launchUrl(authUri, mode: LaunchMode.externalApplication);
      }

      return _currentUser;
    } catch (e, st) {
      AppLogger.error('OAuth sign in error', e, st);
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    await _localStore.remove(AppConstants.keyAuthSession);
    AppLogger.info('User signed out and session purged');
  }

  @override
  Future<String?> refreshToken() async {
    final user = await getCurrentUser();
    if (user == null || user.refreshToken == null) return null;
    return user.accessToken;
  }

  String _generateRandomString(int length) {
    final rand = Random.secure();
    final values = List<int>.generate(length, (i) => rand.nextInt(256));
    return base64Url.encode(values).substring(0, length);
  }
}
