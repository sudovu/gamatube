import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';
import '../models/user_profile.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  UserProfile? _currentUser;
  List<UserProfile> _savedAccounts = [];
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider({required AuthService authService}) : _authService = authService {
    _init();
  }

  UserProfile? get user => _currentUser;
  bool get isAuthenticated => _currentUser != null && _currentUser!.isAuthenticated && !_currentUser!.isIncognito;
  bool get isIncognito => _currentUser?.isIncognito ?? false;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<UserProfile> get savedAccounts => _savedAccounts;

  Future<void> _init() async {
    _currentUser = await _authService.getCurrentUser();
    _savedAccounts = await _authService.getSavedAccounts();
    notifyListeners();
  }

  Future<bool> signIn() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await _authService.signIn();
      _currentUser = profile;
      _savedAccounts = await _authService.getSavedAccounts();
      _isLoading = false;
      notifyListeners();
      return profile != null;
    } catch (e) {
      _errorMessage = 'Failed to sign in with Google account.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGmail(String email, {String? displayName, String? avatarUrl}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await _authService.signInWithGmail(
        email,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      _currentUser = profile;
      _savedAccounts = await _authService.getSavedAccounts();
      _isLoading = false;
      notifyListeners();
      return profile != null;
    } catch (e) {
      _errorMessage = 'Failed to add Gmail account.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> switchAccount(String accountId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.switchAccount(accountId);
      _savedAccounts = await _authService.getSavedAccounts();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleIncognito() async {
    _currentUser = await _authService.toggleIncognito();
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    await _authService.signOut();
    _currentUser = null;
    _savedAccounts = await _authService.getSavedAccounts();
    _isLoading = false;
    notifyListeners();
  }
}
