import 'dart:convert';

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
    this.token,
    this.firstName,
    this.lastName,
    this.profileImage,
    this.department,
    this.designation,
    this.organization,
    this.userDataJson,
    this.firebaseUid,
    this.role = AuthRole.user,
    this.isLocalDev = false,
  });

  final String id;
  final String email;
  final String displayName;
  final String? token;
  final String? firstName;
  final String? lastName;
  final String? profileImage;
  final String? department;
  final String? designation;
  final String? organization;
  final String? userDataJson;
  final String? firebaseUid;
  final AuthRole role;
  final bool isLocalDev;

  bool get isAdmin => role.isAdmin;

  bool get isDevAdmin =>
      isLocalDev && role.isAdmin && AppEnv.allowLocalDevAuth;

  /// Returns the specific role type string extracted from portal user data.
  String? get rawRoleType {
    if (userDataJson == null || userDataJson!.isEmpty) return null;
    try {
      final decoded = jsonDecode(userDataJson!);
      if (decoded is Map<String, dynamic>) {
        final userRoleRaw = decoded['user_role'];
        if (userRoleRaw is Map) {
          final directType = userRoleRaw['role_type']?.toString();
          if (directType != null && directType.trim().isNotEmpty) {
            return directType.trim();
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
