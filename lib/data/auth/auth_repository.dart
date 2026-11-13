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
    return AuthUser(
      id: row.id,
      email: row.email,
      displayName: row.displayName,
      firebaseUid: row.firebaseUid,
      role: isAdminLocal ? AuthRole.admin : AuthRole.user,
      isLocalDev: row.authProvider == 'local' ||
          row.email == _devEmail ||
          row.email == _adminEmail,
    );
  }
}
