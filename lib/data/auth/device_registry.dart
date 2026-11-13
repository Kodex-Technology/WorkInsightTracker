import 'dart:io';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:witrack/core/config/app_env.dart';
import 'package:witrack/data/database/app_database.dart';

class DeviceRegistry {
  DeviceRegistry(this._db, this._prefs);

  final AppDatabase _db;
  final SharedPreferences _prefs;

  static const _deviceIdKey = 'witrack.device.id';

  Future<String> localDeviceId() async {
    final existing = _prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await _prefs.setString(_deviceIdKey, id);
    return id;
  }

  Future<Device> upsertForUser({
    required String localUserId,
    String? firebaseUid,
  }) async {
    final id = await localDeviceId();
    final now = DateTime.now().toUtc();
    final platform = Platform.isWindows
        ? 'windows'
        : Platform.isMacOS
            ? 'macos'
            : Platform.operatingSystem;
    final name = Platform.localHostname;

    final existing = await (_db.select(_db.devices)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();

    if (existing == null) {
      return _db.into(_db.devices).insertReturning(
            DevicesCompanion.insert(
              id: id,
              userId: localUserId,
              name: name,
              platform: platform,
              createdAt: now,
              firebaseUid: Value(firebaseUid),
              environment: Value(AppEnv.modeLabel.toLowerCase()),
              lastSeenAt: Value(now),
            ),
          );
    }

    await (_db.update(_db.devices)..where((t) => t.id.equals(id))).write(
      DevicesCompanion(
        userId: Value(localUserId),
        name: Value(name),
        platform: Value(platform),
        firebaseUid: Value(firebaseUid),
        environment: Value(AppEnv.modeLabel.toLowerCase()),
        lastSeenAt: Value(now),
      ),
    );
    return (await (_db.select(_db.devices)..where((t) => t.id.equals(id)))
            .getSingle());
  }
}
