import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:witrack/core/config/app_env.dart';
import 'package:witrack/data/auth/auth_models.dart';

void main() {
  test('admin roles expose isAdmin', () {
    expect(AuthRole.admin.isAdmin, isTrue);
    expect(AuthRole.superAdmin.isAdmin, isTrue);
    expect(AuthRole.user.isAdmin, isFalse);
  });

  test('AuthUser extracts rawRoleType correctly from user_role JSON', () {
    final userData = {
      'id': 2,
      'email': 'admin@workinsight.demo',
      'first_name': 'Demo',
      'last_name': 'Admin',
      'user_role': {
        'role_name': 'Super Admin',
        'role_type': 'Admin',
        'user_roles': '{"role_type":"Admin","team_managment":{}}',
      },
    };

    final user = AuthUser(
      id: '2',
      email: 'admin@workinsight.demo',
      displayName: 'Demo Admin',
      userDataJson: jsonEncode(userData),
      role: AuthRole.admin,
    );

    expect(user.rawRoleType, 'Admin');
  });
}
