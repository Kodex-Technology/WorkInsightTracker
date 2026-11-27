import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:witrack/core/config/app_env.dart';
import 'package:witrack/data/auth/auth_repository.dart';
import 'package:witrack/data/database/app_database.dart';

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

  for (final portalRole in ['Admin', 'Super Admin', 'Employee', 'Manager']) {
    test(
      '$portalRole portal login and restored session use the user role',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final repository = AuthRepository(db, prefs);
        final user = await repository.signInWithPortalToken(
          'test-token',
          userData: {
            'id': 42,
            'email': 'person@example.com',
            'user_role': {'role_type': portalRole},
          },
        );

        expect(user.role, AuthRole.user);
        expect(user.rawRoleType, portalRole);
        await (db.update(db.users)..where((row) => row.id.equals(user.id)))
            .write(const UsersCompanion(role: Value('admin')));
        final restored = await repository.restoreSession();
        expect(restored?.role, AuthRole.user);
        expect(restored?.rawRoleType, portalRole);
      },
    );
  }

  test('portal login rejects a missing role type', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = AuthRepository(db, prefs);

    await expectLater(
      repository.signInWithPortalToken(
        'test-token',
        userData: {
          'email': 'person@example.com',
          'user_role': {'role_type': ' '},
        },
      ),
      throwsA(
        predicate(
          (error) => error.toString().contains('User role type is missing'),
        ),
      ),
    );
  });
}
