import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:witrack/core/config/app_env.dart';
import 'package:witrack/data/auth/auth_models.dart';
import 'package:witrack/data/auth/device_registry.dart';
import 'package:witrack/data/database/app_database.dart';

export 'package:witrack/data/auth/auth_models.dart';

class AuthRepository {
  AuthRepository(this._db, this._prefs, {DeviceRegistry? devices})
      : _devices = devices ?? DeviceRegistry(_db, _prefs);

  final AppDatabase _db;
  final SharedPreferences _prefs;
  final DeviceRegistry _devices;

  static const _sessionKey = 'witrack.session.userId';
  static const _devEmail = 'dev@witrack.local';
  static const _adminEmail = 'admin@witrack.local';

  Future<AuthUser?> restoreSession() async {
    final userId = _prefs.getString(_sessionKey);
    if (userId == null) return null;
    final row = await (_db.select(_db.users)..where((t) => t.id.equals(userId)))
        .getSingleOrNull();
    if (row == null) {
      await _prefs.remove(_sessionKey);
      return null;
    }
    final user = _toLocalUser(row);
    if (user.isDevAdmin && !AppEnv.allowLocalAdminTesting) {
      await signOut();
      return null;
    }
    if (!AppEnv.allowLocalDevAuth &&
        (user.email == _devEmail || user.email == _adminEmail)) {
      await signOut();
      return null;
    }
    return user;
  }

  Future<AuthUser> signInLocalDev() async {
    if (!AppEnv.allowLocalDevAuth) {
      throw StateError('Local development login is disabled in production.');
    }
    return _signInLocal(
      email: _devEmail,
      displayName: 'Witrack Developer',
      role: AuthRole.user,
    );
  }

  Future<AuthUser> signInLocalAdmin() async {
    if (!AppEnv.allowLocalAdminTesting) {
      throw StateError('Local admin testing is disabled in production.');
    }
    return _signInLocal(
      email: _adminEmail,
      displayName: 'Development Admin',
      role: AuthRole.admin,
    );
  }

  Future<AuthUser> signInWithPortalToken(
    String token, {
    String? roleType,
    Map<String, dynamic>? userData,
  }) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) {
      throw Exception('Authentication token is missing.');
    }
    if (userData == null) {
      throw Exception('User data is missing.');
    }

    final email = userData['email']?.toString().trim();
    if (email == null || email.isEmpty) {
      throw Exception('The portal user email is missing.');
    }

    final firstName = userData['first_name']?.toString();
    final lastName = userData['last_name']?.toString();
    final profileImage = userData['profile_image']?.toString();
    final department = userData['department']?.toString() ??
        userData['sub_department']?.toString();

    String? designationName;
    final desigRaw = userData['designation'];
    if (desigRaw is Map) {
      designationName = desigRaw['designation_name']?.toString() ??
          desigRaw['description']?.toString() ??
          desigRaw['name']?.toString();
    } else if (desigRaw is String) {
      designationName = desigRaw;
    }
    designationName ??= userData['designation_name']?.toString();

    String? orgName;
    final orgRaw = userData['organization'];
    if (orgRaw is Map) {
      orgName = orgRaw['name']?.toString();
    } else if (orgRaw is String) {
      orgName = orgRaw;
    }

    final displayName = (firstName != null &&
            firstName.trim().isNotEmpty &&
            lastName != null &&
            lastName.trim().isNotEmpty)
        ? '${firstName.trim()} ${lastName.trim()}'
        : (firstName?.trim().isNotEmpty == true
            ? firstName!.trim()
            : (userData['name']?.toString() ?? 'Portal User'));

    final userRoleRaw = userData['user_role'];
    if (userRoleRaw is! Map) {
      throw Exception('User role information is missing.');
    }
    final normalizedRole =
        (userRoleRaw['role_type']?.toString().trim() ?? '').toLowerCase();
    if (normalizedRole.isEmpty) {
      throw Exception('User role type is missing.');
    }

    final AuthRole role;
    if (normalizedRole == 'admin') {
      role = AuthRole.admin;
    } else if (normalizedRole == 'employee') {
      role = AuthRole.user;
    } else {
      throw Exception('Unsupported portal role: ${userRoleRaw['role_type']}');
    }

    final roleStr = role == AuthRole.admin ? 'admin' : 'user';
    final userDataJsonStr = jsonEncode(userData);

    final portalUuid = userData['uuid']?.toString().trim();
    final portalId = userData['id']?.toString().trim();
    final stablePortalId = portalUuid != null && portalUuid.isNotEmpty
        ? 'portal_$portalUuid'
        : (portalId != null && portalId.isNotEmpty
            ? 'portal_$portalId'
            : null);

    User? existing;
    if (stablePortalId != null) {
      existing = await (_db.select(_db.users)
            ..where((t) => t.id.equals(stablePortalId)))
          .getSingleOrNull();
    }
    existing ??= await (_db.select(_db.users)
          ..where((t) => t.email.equals(email)))
        .getSingleOrNull();

    final user = existing ??
        await _db.into(_db.users).insertReturning(
              UsersCompanion.insert(
                id: stablePortalId ?? const Uuid().v4(),
                email: email,
                displayName: displayName,
                createdAt: DateTime.now().toUtc(),
                authProvider: const Value('portal'),
                role: Value(roleStr),
                firstName: Value(firstName),
                lastName: Value(lastName),
                profileImage: Value(profileImage),
                department: Value(department),
                designation: Value(designationName),
                organization: Value(orgName),
                userDataJson: Value(userDataJsonStr),
              ),
            );

    await (_db.update(_db.users)..where((t) => t.id.equals(user.id)))
        .write(UsersCompanion(
      email: Value(email),
      role: Value(roleStr),
      displayName: Value(displayName),
      firstName: Value(firstName),
      lastName: Value(lastName),
      profileImage: Value(profileImage),
      department: Value(department),
      designation: Value(designationName),
      organization: Value(orgName),
      userDataJson: Value(userDataJsonStr),
    ));

    await _prefs.setString(_sessionKey, user.id);
    await _devices.upsertForUser(localUserId: user.id);

    return AuthUser(
      id: user.id,
      email: email,
      displayName: displayName,
      firstName: firstName,
      lastName: lastName,
      profileImage: profileImage,
      department: department,
      designation: designationName,
      organization: orgName,
      userDataJson: userDataJsonStr,
      role: role,
      isLocalDev: false,
    );
  }

  Future<AuthUser> _signInLocal({
    required String email,
    required String displayName,
    required AuthRole role,
  }) async {
    final existing = await (_db.select(_db.users)
          ..where((t) => t.email.equals(email)))
        .getSingleOrNull();

    final user = existing ??
        await _db.into(_db.users).insertReturning(
              UsersCompanion.insert(
                id: const Uuid().v4(),
                email: email,
                displayName: displayName,
                createdAt: DateTime.now().toUtc(),
                authProvider: const Value('local'),
              ),
            );

    await _prefs.setString(_sessionKey, user.id);
    await _devices.upsertForUser(localUserId: user.id);
    return AuthUser(
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      firebaseUid: user.firebaseUid,
      role: role,
      isLocalDev: true,
    );
  }

  Future<void> signOut() async {
    await _prefs.remove(_sessionKey);
  }

  Future<void> resetTestAccount() async {
    await signOut();
    await (_db.delete(_db.users)
          ..where((t) => t.email.isIn(const [_devEmail, _adminEmail])))
        .go();
  }

  /// Local registered users for admin testing (no remote directory yet).
  Stream<List<User>> watchRegisteredUsers() {
    return (_db.select(_db.users)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  AuthUser _toLocalUser(User row) {
    final isAdminLocal =
        AppEnv.allowLocalAdminTesting && row.email == _adminEmail;
    final rowRole = row.role == 'admin' ? AuthRole.admin : AuthRole.user;
    final role = isAdminLocal ? AuthRole.admin : rowRole;
    return AuthUser(
      id: row.id,
      email: row.email,
      displayName: row.displayName,
      firstName: row.firstName,
      lastName: row.lastName,
      profileImage: row.profileImage,
      department: row.department,
      designation: row.designation,
      organization: row.organization,
      userDataJson: row.userDataJson,
      firebaseUid: row.firebaseUid,
      role: role,
      isLocalDev: row.authProvider == 'local' ||
          row.email == _devEmail ||
          row.email == _adminEmail,
    );
  }
}
