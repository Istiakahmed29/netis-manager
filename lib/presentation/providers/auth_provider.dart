import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_error.dart';
import '../../core/utils/result.dart';
import '../providers/providers.dart';

// ---------------------------------------------------------------------------
// Auth state
// ---------------------------------------------------------------------------

enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.routerIp,
    this.error,
  });

  final AuthStatus status;
  final String? routerIp;
  final AppError? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    String? routerIp,
    AppError? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      routerIp: routerIp ?? this.routerIp,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) {
    _tryAutoLogin();
  }

  final Ref _ref;

  RouterRepository get _repo => _ref.read(routerRepositoryProvider);
  CredentialStorage get _creds => _ref.read(credentialStorageProvider);

  /// On startup: check for saved credentials and auto-login.
  Future<void> _tryAutoLogin() async {
    state = state.copyWith(status: AuthStatus.loading);

    final saved = await _creds.loadCredentials();
    if (saved == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    final result = await _repo.login(
      routerIp: saved.routerIp,
      username: saved.username,
      password: saved.password,
    );

    result.fold(
      onSuccess: (_) => state = state.copyWith(
        status: AuthStatus.authenticated,
        routerIp: saved.routerIp,
      ),
      onFailure: (e) => state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e,
      ),
    );
  }

  /// Manual login — discovers router if IP not provided.
  Future<void> login({
    String? routerIp,
    required String username,
    required String password,
    bool saveCredentials = true,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);

    // If no IP given, try to discover
    String? ip = routerIp;
    if (ip == null || ip.isEmpty) {
      ip = await _repo.discoverRouter();
      if (ip == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: const RouterNotFoundError(),
        );
        return;
      }
    }

    final result = await _repo.login(
      routerIp: ip,
      username: username,
      password: password,
    );

    await result.fold(
      onSuccess: (_) async {
        if (saveCredentials) {
          await _creds.saveCredentials(
            routerIp: ip!,
            username: username,
            password: password,
          );
        }
        state = state.copyWith(
          status: AuthStatus.authenticated,
          routerIp: ip,
        );
      },
      onFailure: (e) async {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: e,
        );
      },
    );
  }

  Future<void> logout() async {
    await _repo.logout();
    await _creds.clearCredentials();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
