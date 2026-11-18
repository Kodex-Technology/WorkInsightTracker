import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:witrack/core/config/app_env.dart';
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

  Future<void> signInWithPortal() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final url = '${AppEnv.apiBaseUrl}tracker/generate-token';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, Object?> jsonMap =
            jsonDecode(response.body) as Map<String, Object?>;
        final status = jsonMap['status'] == true;
        final redirectUrl = jsonMap['redirect_url']?.toString();

        if (status && redirectUrl != null && redirectUrl.isNotEmpty) {
          final uri = Uri.parse(redirectUrl);
          final launched =
              await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!launched) {
            throw Exception('Could not open browser to redirect URL: $redirectUrl');
          }
          state = state.copyWith(isLoading: false);
        } else {
          final message =
              jsonMap['message']?.toString() ?? 'Failed to generate tracker token';
          throw Exception(message);
        }
      } else {
        throw Exception('Server error (HTTP ${response.statusCode})');
      }
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
    }
  }

  Future<void> handlePortalToken(String token) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.signInWithPortalToken(token);
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
