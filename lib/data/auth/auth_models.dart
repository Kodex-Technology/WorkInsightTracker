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
}
