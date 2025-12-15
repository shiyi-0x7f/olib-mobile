import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_storage.dart';
import '../services/zlibrary_api.dart';
import 'zlibrary_provider.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final ZLibraryApi _api;
  final AuthStorage _storage = AuthStorage();

  AuthNotifier(this._api) : super(AuthState(isLoading: true)) {
    _init();
  }

  /// Initialize - restore session from stored credentials
  /// Now waits for API verification before setting authenticated state
  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final credentials = await _storage.getCredentials();
      final userId = credentials['userId'];
      final userKey = credentials['userKey'];

      if (userId != null && userKey != null) {
        // Verify stored credentials by calling API
        try {
          final response = await _api.getProfile();
          final success = response['success'];
          if (success == true || success == 1) {
            // API verification succeeded - use actual user data
            final userData = response['user'] as Map<String, dynamic>;
            final user = User.fromJson(userData);
            state = AuthState(user: user);
          } else {
            // API returned failure - credentials invalid, clear and require login
            await _storage.clearCredentials();
            state = AuthState();
          }
        } catch (e) {
          // Network error - fall back to stored credentials
          // Allow offline access with cached user info
          final email = credentials['email'];
          final name = credentials['name'];
          final user = User(
            id: userId,
            email: email ?? '',
            name: name ?? 'User',
            remixUserkey: userKey,
          );
          state = AuthState(user: user);
          print('Profile verification failed, using cached credentials: $e');
        }
      } else {
        // No stored credentials, need login
        state = AuthState();
      }
    } catch (e) {
      state = AuthState(error: e.toString());
    }
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.login(email, password);
      final success = response['success'];

      if (success == true || success == 1) {
        final userData = response['user'] as Map<String, dynamic>;
        final user = User.fromJson(userData);

        // Save credentials including password
        await _storage.saveCredentials(
          userId: user.id,
          userKey: user.remixUserkey,
          email: user.email,
          name: user.name,
          password: password,
        );

        state = AuthState(user: user);
        return true;
      } else {
        final errorMsg = response['error']?.toString() ?? 
                        response['message']?.toString() ?? 
                        'Login failed';
        state = AuthState(error: errorMsg);
        return false;
      }
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  /// Login with token
  Future<bool> loginWithToken(String userId, String userKey) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.loginWithToken(userId, userKey);
      final success = response['success'];

      if (success == true || success == 1) {
        final userData = response['user'] as Map<String, dynamic>;
        final user = User.fromJson(userData);

        state = AuthState(user: user);
        return true;
      } else {
        final errorMsg = response['error']?.toString() ?? 
                        response['message']?.toString() ?? 
                        'Token login failed';
        state = AuthState(error: errorMsg);
        return false;
      }
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  /// Send verification code for registration
  Future<Map<String, dynamic>> sendVerificationCode(
    String email,
    String password,
    String name,
  ) async {
    return await _api.sendCode(email, password, name);
  }

  /// Complete registration with verification code
  Future<bool> register(
    String email,
    String password,
    String name,
    String code,
  ) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.verifyCode(email, password, name, code);
      final success = response['success'];

      if (success == true || success == 1) {
        // After registration, login
        return await login(email, password);
      } else {
        final errorMsg = response['error']?.toString() ?? 
                        response['message']?.toString() ?? 
                        'Registration failed';
        state = AuthState(error: errorMsg);
        return false;
      }
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _storage.clearCredentials();
    state = AuthState();
  }

  /// Refresh user profile
  Future<void> refreshProfile() async {
    if (!state.isAuthenticated) return;

    try {
      final response = await _api.getProfile();
      final success = response['success'];
      if (success == true || success == 1) {
        final userData = response['user'] as Map<String, dynamic>;
        final user = User.fromJson(userData);
        state = AuthState(user: user);
      }
    } catch (e) {
      // Keep existing state on error
    }
  }

  /// Get all saved accounts
  Future<List<Map<dynamic, dynamic>>> getSavedAccounts() async {
    return await _storage.getStoredAccounts();
  }

  /// Switch to a saved account
  Future<bool> switchAccount(Map<String, dynamic> account) async {
    final userId = account['userId'];
    final userKey = account['userKey'];
    final email = account['email'];
    final password = account['password'];

    if (userId != null && userKey != null) {
      return await loginWithToken(userId, userKey);
    } else if (email != null && password != null) {
      return await login(email, password);
    }
    return false;
  }

  /// Remove a saved account
  Future<void> removeAccount(String userId) async {
    await _storage.removeAccount(userId);
  }
}

/// Auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(zlibraryApiProvider);
  return AuthNotifier(api);
});
