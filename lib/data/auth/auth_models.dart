import 'package:witrack/core/config/app_env.dart';

enum AuthFlowStage {
  idle,
  failure,
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.firebaseUid,
    this.role = AuthRole.user,
    this.isLocalDev = false,
  });

  final String id;
  final String email;
  final String displayName;
  final String? firebaseUid;
  final AuthRole role;
  final bool isLocalDev;

  bool get isAdmin => role.isAdmin;

  bool get isDevAdmin =>
      isLocalDev && role.isAdmin && AppEnv.allowLocalDevAuth;
}
