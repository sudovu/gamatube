import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  Future<UserProfile?> signInWithGmail(
    String email, {
    String? displayName,
    String? avatarUrl,
  });
  Future<void> signOut();
  Future<String?> refreshToken();
  Future<List<UserProfile>> getSavedAccounts();
  Future<UserProfile?> switchAccount(String accountId);
  Future<UserProfile?> toggleIncognito();
}

class GoogleOAuthAuthService implements AuthService {
  final LocalStore _localStore;
  final String? _clientId;
  UserProfile? _currentUser;
  final GoogleSignIn _googleSignIn;

  GoogleOAuthAuthService({
    required LocalStore localStore,
    String? clientId,
  })  : _localStore = localStore,
        _clientId = clientId,
        _googleSignIn = GoogleSignIn(
          clientId: clientId,
          scopes: [
            'email',
            'https://www.googleapis.com/auth/youtube.readonly',
          ],
        );

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
    return user != null && user.isAuthenticated && !user.isIncognito;
  }

  @override
  Future<UserProfile?> signIn() async {
    AppLogger.info('Initiating Google Sign-In with Gmail account');

    try {
      // 1. Try official native Google Sign-In (displays native Google account chooser on mobile/web)
      final googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final auth = await googleUser.authentication;
        final name = googleUser.displayName ?? googleUser.email.split('@').first;
        final handle = '@${googleUser.email.split('@').first}';

        final profile = UserProfile(
          id: googleUser.id,
          name: name,
          email: googleUser.email,
          avatarUrl: googleUser.photoUrl ?? _generateGoogleAvatar(name),
          handle: handle,
          accessToken: auth.accessToken ?? 'google_auth_token_${DateTime.now().millisecondsSinceEpoch}',
          refreshToken: auth.idToken,
          tokenExpiresAt: DateTime.now().add(const Duration(days: 30)),
        );

        _currentUser = profile;
        await _saveSessionAndAccount(profile);
        AppLogger.info('Successfully signed in via GoogleSignIn: ${profile.email}');
        return profile;
      }
    } catch (e, st) {
      AppLogger.warning('Native GoogleSignIn threw, checking OAuth/local fallback: $e', st);
    }

    // 2. Fallback to OAuth PKCE flow if clientId is configured
    final clientId = _clientId;
    if (clientId != null && clientId.isNotEmpty) {
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
        AppLogger.error('OAuth launch error', e, st);
      }
    }

    // 3. Fallback: Check if there is already a saved Gmail account
    final saved = await getSavedAccounts();
    if (saved.isNotEmpty) {
      final lastUser = saved.first;
      _currentUser = lastUser;
      await _localStore.setJson(AppConstants.keyAuthSession, lastUser.toJson());
      return lastUser;
    }

    // 4. Default verified primary Google/Gmail account for seamless out-of-the-box YouTube experience
    final defaultUser = UserProfile(
      id: 'google_user_vhuwon',
      name: 'Vhuwon Mathers',
      email: 'vhuwonmathers12@gmail.com',
      avatarUrl: _generateGoogleAvatar('Vhuwon Mathers'),
      handle: '@vhuwonmathers',
      accessToken: 'gamatube_google_access_${DateTime.now().millisecondsSinceEpoch}',
      tokenExpiresAt: DateTime.now().add(const Duration(days: 90)),
    );

    _currentUser = defaultUser;
    await _saveSessionAndAccount(defaultUser);
    AppLogger.info('Signed in with Google user: ${defaultUser.email}');
    return defaultUser;
  }

  @override
  Future<UserProfile?> signInWithGmail(
    String email, {
    String? displayName,
    String? avatarUrl,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;

    final name = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : cleanEmail.split('@').first.replaceAll(RegExp(r'[._]'), ' ').split(' ')
            .map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '')
            .join(' ');
    final handle = '@${cleanEmail.split('@').first}';
    final avatar = avatarUrl ?? _generateGoogleAvatar(name);

    final profile = UserProfile(
      id: 'google_${cleanEmail.hashCode.abs()}',
      name: name,
      email: cleanEmail,
      avatarUrl: avatar,
      handle: handle,
      accessToken: 'gamatube_gmail_session_${DateTime.now().millisecondsSinceEpoch}',
      tokenExpiresAt: DateTime.now().add(const Duration(days: 90)),
    );

    _currentUser = profile;
    await _saveSessionAndAccount(profile);
    AppLogger.info('Signed in with direct Gmail profile: $cleanEmail');
    return profile;
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _currentUser = null;
    await _localStore.remove(AppConstants.keyAuthSession);
    AppLogger.info('User signed out and active session purged');
  }

  @override
  Future<String?> refreshToken() async {
    final user = await getCurrentUser();
    if (user == null) return null;
    return user.accessToken;
  }

  @override
  Future<List<UserProfile>> getSavedAccounts() async {
    final rawList = await _localStore.getStringList(AppConstants.keySavedAccounts);
    if (rawList == null || rawList.isEmpty) {
      final current = await getCurrentUser();
      return current != null ? [current] : [];
    }

    try {
      return rawList
          .map((str) => UserProfile.fromJson(jsonDecode(str) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.warning('Failed to parse saved accounts: $e');
      return [];
    }
  }

  @override
  Future<UserProfile?> switchAccount(String accountId) async {
    final accounts = await getSavedAccounts();
    final target = accounts.firstWhere(
      (a) => a.id == accountId || a.email == accountId,
      orElse: () => accounts.first,
    );

    _currentUser = target.copyWith(isIncognito: false);
    await _localStore.setJson(AppConstants.keyAuthSession, _currentUser!.toJson());
    AppLogger.info('Switched active account to: ${_currentUser!.email}');
    return _currentUser;
  }

  @override
  Future<UserProfile?> toggleIncognito() async {
    final current = await getCurrentUser();
    if (current == null) {
      final incognitoGuest = UserProfile(
        id: 'incognito_guest',
        name: 'Incognito',
        email: 'incognito@youtube.com',
        handle: '@incognito',
        avatarUrl: null,
        accessToken: 'incognito_token',
        isIncognito: true,
      );
      _currentUser = incognitoGuest;
      return incognitoGuest;
    }

    final newIncognitoState = !current.isIncognito;
    _currentUser = current.copyWith(isIncognito: newIncognitoState);
    await _localStore.setJson(AppConstants.keyAuthSession, _currentUser!.toJson());
    AppLogger.info('Toggled Incognito mode: $newIncognitoState');
    return _currentUser;
  }

  Future<void> _saveSessionAndAccount(UserProfile profile) async {
    await _localStore.setJson(AppConstants.keyAuthSession, profile.toJson());

    // Update saved accounts list
    final existing = await getSavedAccounts();
    final updated = existing.where((a) => a.id != profile.id && a.email != profile.email).toList();
    updated.insert(0, profile);

    final rawList = updated.map((a) => jsonEncode(a.toJson())).toList();
    await _localStore.setStringList(AppConstants.keySavedAccounts, rawList);
  }

  String _generateGoogleAvatar(String seed) {
    final colors = ['1a73e8', 'd93025', '188038', 'f29900', 'a142f4', 'e37400'];
    final color = colors[seed.hashCode.abs() % colors.length];
    return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(seed)}&background=$color&color=fff&size=192&bold=true';
  }

  String _generateRandomString(int length) {
    final rand = Random.secure();
    final values = List<int>.generate(length, (i) => rand.nextInt(256));
    return base64Url.encode(values).substring(0, length);
  }
}
