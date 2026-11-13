import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text()();
  DateTimeColumn get createdAt => dateTime()();
  /// Firebase Auth UID when linked; stable local [id] remains FK for tracking.
  TextColumn get firebaseUid => text().nullable()();
  TextColumn get authProvider => text().nullable()();
  DateTimeColumn get linkedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Devices extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get platform => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get firebaseUid => text().nullable()();
  TextColumn get environment => text().nullable()();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Workspaces extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Clients extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get name => text()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get clientId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get color => text().withDefault(const Constant('#6366F1'))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text()();
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TrackingSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get workspaceId => text().nullable()();
  TextColumn get projectId => text().nullable()();
  TextColumn get taskId => text().nullable()();
  TextColumn get state => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get activeMs => integer().withDefault(const Constant(0))();
  IntColumn get idleMs => integer().withDefault(const Constant(0))();
  IntColumn get pausedMs => integer().withDefault(const Constant(0))();
  BoolColumn get isManual => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SessionEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text()();
  TextColumn get type => text()();
  DateTimeColumn get at => dateTime()();
  TextColumn get payload => text().nullable()();
}

class ActivitySamples extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text()();
  DateTimeColumn get sampledAt => dateTime()();
  IntColumn get secondsSinceLastInput => integer()();
  BoolColumn get isActiveSignal => boolean()();
  TextColumn get foregroundApp => text().nullable()();
}

class IdleIntervals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
}

class AppUsageIntervals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text()();
  TextColumn get appName => text()();
  TextColumn get exeName => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
}

class Screenshots extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get projectId => text().nullable()();
  TextColumn get taskId => text().nullable()();
  /// Local calendar day `yyyy-MM-dd` for stable day filters (timezone-safe listing).
  TextColumn get takenDay => text().nullable()();
  IntColumn get displayIndex => integer()();
  DateTimeColumn get takenAt => dateTime()();
  TextColumn get filePath => text()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  IntColumn get byteSize => integer().withDefault(const Constant(0))();
  BoolColumn get isTestCapture => boolean().withDefault(const Constant(false))();
  /// Extensible JSON bag for future backend/sync fields — never required to read.
  TextColumn get metadataJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class PermissionStates extends Table {
  TextColumn get id => text()();
  TextColumn get permission => text()();
  TextColumn get status => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get processed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AuditEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get payload => text().nullable()();
  DateTimeColumn get at => dateTime()();
}

@DriftDatabase(
  tables: [
    Users,
    Devices,
    Workspaces,
    Clients,
    Projects,
    Tasks,
    TrackingSessions,
    SessionEvents,
    ActivitySamples,
    IdleIntervals,
    AppUsageIntervals,
    Screenshots,
    AppSettings,
    PermissionStates,
    SyncOutbox,
    AuditEvents,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(devices);
            await m.createTable(workspaces);
            await m.createTable(clients);
            await m.createTable(projects);
            await m.createTable(tasks);
            await m.createTable(idleIntervals);
            await m.createTable(appUsageIntervals);
            await m.createTable(screenshots);
            await m.createTable(appSettings);
            await m.createTable(permissionStates);
            await m.createTable(syncOutbox);
            await m.createTable(auditEvents);
            await m.addColumn(trackingSessions, trackingSessions.workspaceId);
            await m.addColumn(trackingSessions, trackingSessions.projectId);
            await m.addColumn(trackingSessions, trackingSessions.taskId);
            await m.addColumn(trackingSessions, trackingSessions.isManual);
            await m.addColumn(trackingSessions, trackingSessions.note);
          }
          if (from < 3) {
            await m.addColumn(users, users.firebaseUid);
            await m.addColumn(users, users.authProvider);
            await m.addColumn(users, users.linkedAt);
            await m.addColumn(devices, devices.firebaseUid);
            await m.addColumn(devices, devices.environment);
            await m.addColumn(devices, devices.lastSeenAt);
          }
          if (from < 4) {
            await m.addColumn(screenshots, screenshots.taskId);
            await m.addColumn(screenshots, screenshots.takenDay);
            await m.addColumn(screenshots, screenshots.metadataJson);
          }
        },
      );

  static QueryExecutor _open() {
    return driftDatabase(name: 'witrack');
  }
}
