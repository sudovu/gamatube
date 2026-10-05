import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';
import '../models/user_profile.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  UserProfile? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider({required this._authService}) {
    _init();
  }

  UserProfile? get user => _currentUser;
  bool get isAuthenticated => _currentUser != null && _currentUser!.isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> _init() async {
    _currentUser = await _authService.getCurrentUser();
    notifyListeners();
  }

  Future<bool> signIn() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await _authService.signIn();
      _currentUser = profile;
      _isLoading = false;
      notifyListeners();
      return profile != null;
    } catch (e) {
      _errorMessage = 'Failed to sign in. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    await _authService.signOut();
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }
}
