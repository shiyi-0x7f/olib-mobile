import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../services/auth_storage.dart';
import 'zlibrary_provider.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  /// True when auth init couldn't reach the current line (cf_blocked / network error).
  /// User is treated as logged in via cached credentials, but UI should suggest switching.
  final bool lineUnavailable;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.lineUnavailable = false,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? lineUnavailable,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      lineUnavailable: lineUnavailable ?? this.lineUnavailable,
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

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);

    try {
      final credentials = await _storage.getCredentials();
      final userId = credentials['userId'];
      final userKey = credentials['userKey'];

      if (userId == null || userKey == null) {
        state = AuthState();
        return;
      }

      // Build a fallback User from cached fields so we can stay logged in
      // even when the current line is unreachable.
      User cachedUser() => User(
            id: userId,
            email: credentials['email'] ?? '',
            name: credentials['name'] ?? 'User',
            remixUserkey: userKey,
          );

      try {
        // Use loginWithToken — it sets remix_userid/remix_userkey cookies on
        // Dio and hits /eapi/user/profile directly, so it works even on a
        // fresh boot when the api's internal _loggedIn flag is still false.
        final response = await _api.loginWithToken(userId, userKey);

        if (response.success && response.data != null) {
          state = AuthState(user: response.data);
        } else if (response.error == 'cf_blocked' ||
            _isTransientError(response.error)) {
          // Line is unreachable — keep credentials, suggest switching.
          state = AuthState(user: cachedUser(), lineUnavailable: true);
        } else {
          // Real auth failure (e.g. invalid token) — drop creds.
          await _storage.clearCredentials();
          state = AuthState();
        }
      } catch (e) {
        // Network exception — assume line issue, keep using cached creds.
        state = AuthState(user: cachedUser(), lineUnavailable: true);
      }
    } catch (e) {
      state = AuthState(error: e.toString());
    }
  }

  /// Heuristic: treat connection/timeout errors as transient line problems,
  /// not auth failures. We don't want to wipe credentials over a network blip.
  bool _isTransientError(String? error) {
    if (error == null) return false;
    final e = error.toLowerCase();
    return e.contains('line_error') ||
        e.contains('timeout') ||
        e.contains('socket') ||
        e.contains('connection') ||
        e.contains('network') ||
        e.contains('handshake') ||
        e.contains('unreachable') ||
        e.contains('failed host lookup') ||
        e.contains('request failed');
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.login(email, password);

      if (response.success && response.data != null) {
        final user = response.data!;

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
        state = AuthState(error: response.error ?? 'Login failed');
        return false;
      }
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<bool> loginWithToken(String userId, String userKey) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.loginWithToken(userId, userKey);

      if (response.success && response.data != null) {
        state = AuthState(user: response.data);
        return true;
      } else {
        state = AuthState(error: response.error ?? 'Token login failed');
        return false;
      }
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<ApiResponse<void>> sendVerificationCode(
    String email,
    String password,
    String name,
  ) async {
    return await _api.sendCode(email, password, name);
  }

  Future<bool> register(
    String email,
    String password,
    String name,
    String code,
  ) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.verifyCode(email, password, name, code);

      if (response.success) {
        return await login(email, password);
      } else {
        state = AuthState(error: response.error ?? 'Registration failed');
        return false;
      }
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clearCredentials();
    state = AuthState();
  }

  Future<void> refreshProfile() async {
    if (!state.isAuthenticated) return;

    try {
      final response = await _api.getProfile();
      if (response.success && response.data != null) {
        state = AuthState(user: response.data);
      }
    } catch (e) {
      // Keep existing state on error
    }
  }

  /// Re-verify the current line/credentials. Used after the user switches
  /// network line to refresh the lineUnavailable flag and pick up real profile.
  Future<void> reverify() async {
    final credentials = await _storage.getCredentials();
    final userId = credentials['userId'];
    final userKey = credentials['userKey'];
    if (userId == null || userKey == null) return;

    try {
      final response = await _api.loginWithToken(userId, userKey);
      if (response.success && response.data != null) {
        state = AuthState(user: response.data);
      } else if (response.error == 'cf_blocked' ||
          _isTransientError(response.error)) {
        // Still unreachable — keep current user but mark line unavailable.
        state = state.copyWith(lineUnavailable: true);
      }
      // Other errors: leave existing state alone; user can logout manually.
    } catch (_) {
      state = state.copyWith(lineUnavailable: true);
    }
  }

  Future<List<Map<dynamic, dynamic>>> getSavedAccounts() async {
    return await _storage.getStoredAccounts();
  }

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

  Future<void> removeAccount(String userId) async {
    await _storage.removeAccount(userId);
  }
}

/// Auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(zlibraryApiProvider);
  return AuthNotifier(api);
});
