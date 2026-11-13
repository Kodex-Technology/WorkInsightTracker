import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:witrack/data/database/app_database.dart';

class ScreenshotFilter {
  const ScreenshotFilter({this.day, this.projectId, this.taskId});

  /// Local calendar day `yyyy-MM-dd`. Null = all days.
  final String? day;
  final String? projectId;
  final String? taskId;

  ScreenshotFilter copyWith({
    String? day,
    String? projectId,
    String? taskId,
    bool clearDay = false,
    bool clearProject = false,
    bool clearTask = false,
  }) {
    return ScreenshotFilter(
      day: clearDay ? null : (day ?? this.day),
      projectId: clearProject ? null : (projectId ?? this.projectId),
      taskId: clearTask ? null : (taskId ?? this.taskId),
    );
  }
}

class ScreenshotStore {
  ScreenshotStore(this._db, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final AppDatabase _db;
  final FlutterSecureStorage _storage;
  final _uuid = const Uuid();

  static const _secureKeyName = 'witrack.screenshot.aes';
  static const _keyFileName = '.screenshot_aes.key';
  static final _dayFormat = DateFormat('yyyy-MM-dd');

  enc.Key? _cachedKey;
  Future<enc.Key>? _keyLoad;

  static String dayKey(DateTime localTime) => _dayFormat.format(localTime);

  Future<Directory> _dir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'screenshots'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  File _keyFile(Directory dir) => File(p.join(dir.path, _keyFileName));

  Future<void> _safeSecureWrite(String value) async {
    try {
      await _storage.write(key: _secureKeyName, value: value);
    } catch (_) {
      // Some macOS debug/profile setups can miss keychain entitlements.
      // Keep the on-disk key as the source of truth instead of failing capture.
    }
  }

  Future<String?> _safeSecureRead() async {
    try {
      return await _storage.read(key: _secureKeyName);
    } catch (_) {
      return null;
    }
  }

  /// Stable key: prefer on-disk file (survives secure-storage wipe), then
  /// migrate from secure storage, else create once. Never race-regenerate.
  Future<enc.Key> _aesKey() {
    final cached = _cachedKey;
    if (cached != null) return Future.value(cached);
    return _keyLoad ??= _loadOrCreateKey().then((key) {
      _cachedKey = key;
      return key;
    });
  }

  Future<Iterable<Directory>> _legacyScreenshotDirs(Directory current) async {
    final parent = current.parent; // …/Witrack/<ProductName>
    final company = parent.parent; // …/Witrack
    if (!await company.exists()) return const [];
    // ProductName briefly became "WorkInsight Tracker" and split storage.
    final candidates = <Directory>[
      Directory(p.join(company.path, 'Witrack', 'screenshots')),
      Directory(p.join(company.path, 'WorkInsight Tracker', 'screenshots')),
      current,
    ];
    return candidates;
  }

  Future<enc.Key> _loadOrCreateKey() async {
    final dir = await _dir();
    final file = _keyFile(dir);

    // 1) Key file beside screenshots (stable across display-name changes).
    for (final shotDir in await _legacyScreenshotDirs(dir)) {
      final candidate = _keyFile(shotDir);
      if (!await candidate.exists()) continue;
      final raw = (await candidate.readAsString()).trim();
      if (raw.isEmpty) continue;
      await file.writeAsString(raw, flush: true);
      await _safeSecureWrite(raw);
      return enc.Key.fromBase64(raw);
    }

    if (await file.exists()) {
      final raw = (await file.readAsString()).trim();
      if (raw.isNotEmpty) {
        await _safeSecureWrite(raw);
        return enc.Key.fromBase64(raw);
      }
    }

    // 2) Flutter secure storage for the *current* support path.
    final fromSecure = await _safeSecureRead();
    if (fromSecure != null && fromSecure.isNotEmpty) {
      await file.writeAsString(fromSecure, flush: true);
      return enc.Key.fromBase64(fromSecure);
    }

    // 3) Create once — never race-regenerate (single-flight via _keyLoad).
    final key = enc.Key.fromSecureRandom(32);
    await file.writeAsString(key.base64, flush: true);
    await _safeSecureWrite(key.base64);
    return key;
  }

  enc.Encrypter _encrypter(enc.Key key, {required String mode}) {
    if (mode == 'cbc') {
      return enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    }
    // Legacy default from encrypt package (SIC + PKCS7).
    return enc.Encrypter(enc.AES(key, mode: enc.AESMode.sic));
  }

  /// Persist encrypted capture with filterable dimensions for local UI + future sync.
  Future<Screenshot> persistCapture({
    required String sessionId,
    String? projectId,
    String? taskId,
    required int displayIndex,
    required int width,
    required int height,
    required Uint8List pngBytes,
    bool isTestCapture = false,
    DateTime? takenAt,
    Map<String, Object?>? metadata,
  }) async {
    final key = await _aesKey();
    final iv = enc.IV.fromSecureRandom(16);
    const mode = 'cbc';
    final encrypted = _encrypter(
      key,
      mode: mode,
    ).encryptBytes(pngBytes, iv: iv);

    final id = _uuid.v4();
    final dir = await _dir();
    final file = File(p.join(dir.path, '$id.bin'));
    final payload = jsonEncode({
      'v': 2,
      'mode': mode,
      'iv': iv.base64,
      'data': encrypted.base64,
    });
    await file.writeAsString(payload, flush: true);

    final at = (takenAt ?? DateTime.now()).toUtc();
    final localDay = dayKey(at.toLocal());

    return _db
        .into(_db.screenshots)
        .insertReturning(
          ScreenshotsCompanion.insert(
            id: id,
            sessionId: sessionId,
            projectId: Value(projectId),
            taskId: Value(taskId),
            takenDay: Value(localDay),
            displayIndex: displayIndex,
            takenAt: at,
            filePath: file.path,
            width: width,
            height: height,
            byteSize: Value(pngBytes.length),
            isTestCapture: Value(isTestCapture),
            metadataJson: Value(
              metadata == null || metadata.isEmpty
                  ? null
                  : jsonEncode(metadata),
            ),
          ),
        );
  }

  Future<Uint8List?> readDecrypted(Screenshot row) async {
    try {
      final file = File(row.filePath);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final payload = Map<String, dynamic>.from(decoded);
      final ivB64 = payload['iv'];
      final dataB64 = payload['data'];
      if (ivB64 is! String || dataB64 is! String) return null;

      final key = await _aesKey();
      final iv = enc.IV.fromBase64(ivB64);
      final data = enc.Encrypted.fromBase64(dataB64);
      final declared = payload['mode'] as String?;

      final modes = <String>[?declared, 'sic', 'cbc'];
      final tried = <String>{};
      for (final mode in modes) {
        if (!tried.add(mode)) continue;
        try {
          final bytes = _encrypter(key, mode: mode).decryptBytes(data, iv: iv);
          return Uint8List.fromList(bytes);
        } catch (_) {
          // try next mode
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Stream<List<Screenshot>> watchRecent({int limit = 200}) {
    return watchFiltered(const ScreenshotFilter(), limit: limit);
  }

  Stream<List<Screenshot>> watchFiltered(
    ScreenshotFilter filter, {
    int limit = 200,
  }) {
    final query = _db.select(_db.screenshots)
      ..orderBy([(t) => OrderingTerm.desc(t.takenAt)])
      ..limit(limit);

    if (filter.day != null) {
      final day = filter.day!;
      // Exact local calendar day only (no ±hours leakage into adjacent days).
      final startLocal = DateTime.parse(day); // yyyy-MM-dd → local midnight
      final endLocal = startLocal.add(const Duration(days: 1));
      final startUtc = startLocal.toUtc();
      final endUtc = endLocal.toUtc();
      query.where(
        (t) =>
            t.takenDay.equals(day) |
            (t.takenDay.isNull() &
                t.takenAt.isBiggerOrEqualValue(startUtc) &
                t.takenAt.isSmallerThanValue(endUtc)),
      );
    }
    if (filter.projectId != null) {
      query.where((t) => t.projectId.equals(filter.projectId!));
    }
    if (filter.taskId != null) {
      query.where((t) => t.taskId.equals(filter.taskId!));
    }

    return query.watch();
  }

  Future<List<String>> distinctTakenDays({int limit = 60}) async {
    final rows =
        await (_db.select(_db.screenshots)
              ..orderBy([(t) => OrderingTerm.desc(t.takenAt)])
              ..limit(500))
            .get();
    final days = <String>{};
    for (final row in rows) {
      final day = row.takenDay ?? dayKey(row.takenAt.toLocal());
      days.add(day);
      if (days.length >= limit) break;
    }
    final list = days.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  Future<void> deleteScreenshot(String id) async {
    final row = await (_db.select(
      _db.screenshots,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row != null) {
      final file = File(row.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await (_db.delete(_db.screenshots)..where((t) => t.id.equals(id))).go();
  }
}
