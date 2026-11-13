import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witrack/data/auth/auth_repository.dart';
import 'package:witrack/data/providers.dart';

class AuthState {
  const AuthState({
    this.user,
    this.isLoading = true,
    this.error,
    this.stage = AuthFlowStage.idle,
  });

  final AuthUser? user;
  final bool isLoading;
  final String? error;
  final AuthFlowStage stage;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool? isLoading,
    String? error,
    AuthFlowStage? stage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      stage: stage ?? this.stage,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(restore);
    return const AuthState();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> restore() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.restoreSession();
      state = AuthState(user: user, isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInLocalDev() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.signInLocalDev();
      state = AuthState(user: user, isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInLocalAdmin() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.signInLocalAdmin();
      state = AuthState(user: user, isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState(isLoading: false);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
