import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:witrack/core/config/app_env.dart';
import 'package:witrack/core/platform/deep_link_service.dart';
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
      state = AuthState(isLoading: false, error: _cleanErrorMessage(e));
    }
  }

  Future<void> signInLocalDev() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.signInLocalDev();
      state = AuthState(user: user, isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: _cleanErrorMessage(e));
    }
  }

  Future<void> signInLocalAdmin() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.signInLocalAdmin();
      state = AuthState(user: user, isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: _cleanErrorMessage(e));
    }
  }

  Future<void> signInWithPortal() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await http.post(
        AppEnv.apiUri('tracker/generate-token'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw Exception('The portal returned an invalid response.');
        }
        final jsonMap = decoded;
        final status = jsonMap['status'] == true;
        final redirectUrl = jsonMap['redirect_url']?.toString();

        if (status && redirectUrl != null && redirectUrl.isNotEmpty) {
          final uri = Uri.tryParse(redirectUrl);
          if (uri == null) {
            debugPrint('Portal returned an unparsable login URL.');
            throw Exception(
              'The portal returned an invalid login URL. Check the server portal URL configuration.',
            );
          }
          debugPrint(
            'Portal redirect URL from server: ${_redactUrl(uri)}',
          );
          if ((uri.scheme != 'https' && uri.scheme != 'http') ||
              uri.host.isEmpty) {
            throw Exception(
              'The portal returned an invalid login URL '
              '(${_redactUrl(uri)}). Check the server WEB_URL configuration.',
            );
          }
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!launched) {
            throw Exception(_browserUnavailableMessage);
          }
          state = state.copyWith(isLoading: false);
        } else {
          final message =
              jsonMap['message']?.toString() ??
              'Failed to generate tracker token';
          throw Exception(message);
        }
      } else {
        throw Exception('Server error (HTTP ${response.statusCode})');
      }
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'Could not launch the portal login URL '
        '(code: ${error.code}): ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      state = AuthState(
        isLoading: false,
        error: _browserUnavailableMessage,
      );
    } catch (e) {
      state = AuthState(isLoading: false, error: _cleanErrorMessage(e));
    }
  }

  static const String _browserUnavailableMessage =
      'Windows could not open the portal login page. Set a default browser in '
      'Windows Settings > Apps > Default apps, then try again.';

  static String _redactUrl(Uri uri) {
    if (!uri.hasQuery) return uri.toString();
    final safeParameters = <String, String>{
      for (final entry in uri.queryParameters.entries)
        entry.key: entry.key.toLowerCase().contains('token')
            ? '[redacted]'
            : entry.value,
    };
    return uri.replace(queryParameters: safeParameters).toString();
  }

  Future<void> handlePortalCallback(PortalLoginCallback callback) async {
    if (callback.isCancelled) {
      final msg = callback.message?.trim().isNotEmpty == true
          ? callback.message!.trim()
          : 'You cancelled the tracker authentication.';
      state = state.copyWith(
        isLoading: false,
        error: msg,
      );
      return;
    }

    if (!callback.hasToken) {
      final msg = callback.message?.trim().isNotEmpty == true
          ? callback.message!.trim()
          : 'Authentication token is missing.';
      state = state.copyWith(
        isLoading: false,
        error: msg,
      );
      return;
    }

    await handlePortalToken(
      callback.token!,
      roleType: callback.roleType,
      userData: callback.userData,
      status: callback.status,
      message: callback.message,
    );
  }

  Future<void> handlePortalToken(
    String token, {
    String? roleType,
    Map<String, dynamic>? userData,
    String? status,
    String? message,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (status?.toLowerCase() == 'cancelled' ||
          status?.toLowerCase() == 'cancel') {
        throw Exception(
          message?.trim().isNotEmpty == true
              ? message!.trim()
              : 'You cancelled the tracker authentication.',
        );
      }
      if (token.trim().isEmpty) {
        throw Exception(
          message?.trim().isNotEmpty == true
              ? message!.trim()
              : 'Authentication token is missing.',
        );
      }
      if (userData == null) {
        throw Exception('User data is missing from callback.');
      }
      final roleRaw = userData['user_role'];
      if (roleRaw is! Map) {
        throw Exception('User role information is missing.');
      }
      final roleTypeFromJson = roleRaw['role_type']?.toString().trim() ?? '';
      if (roleTypeFromJson.isEmpty) {
        throw Exception('User role type is missing.');
      }

      final user = await _repo.signInWithPortalToken(
        token,
        userData: userData,
      );
      state = AuthState(user: user, isLoading: false);
    } catch (e, stackTrace) {
      debugPrint('Portal token authentication failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      state = AuthState(isLoading: false, error: _cleanErrorMessage(e));
    }
  }

  String _cleanErrorMessage(Object error) {
    var msg = error.toString();
    if (msg.startsWith('Exception: ')) {
      msg = msg.substring('Exception: '.length);
    }
    return msg.trim();
  }

  Future<void> handlePortalLoginCallback({
    required String? token,
    String? roleType,
    Map<String, dynamic>? userData,
    required BuildContext context,
  }) async {
    final receivedToken = token?.trim();
    debugPrint(
      'Portal login callback received; token present: '
      '${receivedToken?.isNotEmpty == true}',
    );

    if (!context.mounted) {
      debugPrint('Portal callback UI is no longer available');
      return;
    }

    final hasToken = receivedToken != null &&
        receivedToken.isNotEmpty &&
        receivedToken != 'null' &&
        receivedToken != 'undefined';

    AuthUser? loggedInUser;
    if (hasToken) {
      try {
        await handlePortalToken(receivedToken!, userData: userData);
        loggedInUser = state.user;
      } catch (e, stackTrace) {
        debugPrint('Error signing in with portal token: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    final user = loggedInUser ?? state.user;
    final displayRole = user?.rawRoleType ??
        roleType?.trim() ??
        (user?.role == AuthRole.admin ? 'Admin' : 'User');

    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(hasToken && user != null
              ? 'Login Successfully!'
              : 'Login Callback Error'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasToken && user != null) ...[
                  Text(
                    'Welcome, ${user.displayName}!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Email: ${user.email}'),
                  const SizedBox(height: 4),
                  Text('Role Type: $displayRole'),
                  if (user.organization != null) ...[
                    const SizedBox(height: 4),
                    Text('Organization: ${user.organization}'),
                  ],
                  if (user.designation != null) ...[
                    const SizedBox(height: 4),
                    Text('Designation: ${user.designation}'),
                  ],
                  if (user.department != null) ...[
                    const SizedBox(height: 4),
                    Text('Department: ${user.department}'),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Session token saved. You are now logged in.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'The callback did not include a valid token or authentication failed.',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    if (hasToken) {
      debugPrint('Portal callback processed successfully for ${user?.email}');
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState(isLoading: false);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
