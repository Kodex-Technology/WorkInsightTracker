import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:witrack/data/database/app_database.dart';

class SessionRepository {
  SessionRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Future<String> createSession({
    required String userId,
    String? workspaceId,
    String? projectId,
    String? taskId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    await _db.into(_db.trackingSessions).insert(
          TrackingSessionsCompanion.insert(
            id: id,
            userId: userId,
            workspaceId: Value(workspaceId),
            projectId: Value(projectId),
            taskId: Value(taskId),
            state: 'tracking',
            startedAt: now,
          ),
        );
    await addEvent(sessionId: id, type: 'started');
    return id;
  }

  Future<void> updateState({
    required String sessionId,
    required String state,
  }) async {
    await (_db.update(_db.trackingSessions)
          ..where((t) => t.id.equals(sessionId)))
        .write(TrackingSessionsCompanion(state: Value(state)));
    await addEvent(sessionId: sessionId, type: 'state:$state');
  }

  Future<void> updateDurations({
    required String sessionId,
    required int activeMs,
    required int idleMs,
    required int pausedMs,
  }) async {
    await (_db.update(_db.trackingSessions)
          ..where((t) => t.id.equals(sessionId)))
        .write(
          TrackingSessionsCompanion(
            activeMs: Value(activeMs),
            idleMs: Value(idleMs),
            pausedMs: Value(pausedMs),
          ),
        );
  }

  Future<void> completeSession({
    required String sessionId,
    required int activeMs,
    required int idleMs,
    required int pausedMs,
  }) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.trackingSessions)
          ..where((t) => t.id.equals(sessionId)))
        .write(
          TrackingSessionsCompanion(
            state: const Value('stopped'),
            endedAt: Value(now),
            activeMs: Value(activeMs),
            idleMs: Value(idleMs),
            pausedMs: Value(pausedMs),
          ),
        );
    await addEvent(sessionId: sessionId, type: 'stopped');
  }

  Future<void> addEvent({
    required String sessionId,
    required String type,
    String? payload,
  }) async {
    await _db.into(_db.sessionEvents).insert(
          SessionEventsCompanion.insert(
            sessionId: sessionId,
            type: type,
            at: DateTime.now().toUtc(),
            payload: Value(payload),
          ),
        );
  }

  Future<void> addActivitySample({
    required String sessionId,
    required DateTime sampledAt,
    required int secondsSinceLastInput,
    required bool isActiveSignal,
    String? foregroundApp,
  }) async {
    await _db.into(_db.activitySamples).insert(
          ActivitySamplesCompanion.insert(
            sessionId: sessionId,
            sampledAt: sampledAt.toUtc(),
            secondsSinceLastInput: secondsSinceLastInput,
            isActiveSignal: isActiveSignal,
            foregroundApp: Value(foregroundApp),
          ),
        );
  }

  Future<void> openAppUsage({
    required String sessionId,
    required String appName,
    String? exeName,
    required DateTime at,
  }) async {
    await closeOpenAppUsage(sessionId: sessionId, at: at);
    await _db.into(_db.appUsageIntervals).insert(
          AppUsageIntervalsCompanion.insert(
            sessionId: sessionId,
            appName: appName,
            exeName: Value(exeName),
            startedAt: at.toUtc(),
          ),
        );
  }

  Future<void> closeOpenAppUsage({
    required String sessionId,
    required DateTime at,
  }) async {
    final open = await (_db.select(_db.appUsageIntervals)
          ..where(
            (t) => t.sessionId.equals(sessionId) & t.endedAt.isNull(),
          ))
        .get();
    for (final row in open) {
      await (_db.update(_db.appUsageIntervals)
            ..where((t) => t.id.equals(row.id)))
          .write(AppUsageIntervalsCompanion(endedAt: Value(at.toUtc())));
    }
  }

  Future<void> openIdleInterval({
    required String sessionId,
    required DateTime at,
  }) async {
    await _db.into(_db.idleIntervals).insert(
          IdleIntervalsCompanion.insert(
            sessionId: sessionId,
            startedAt: at.toUtc(),
          ),
        );
  }

  Future<void> closeOpenIdleInterval({
    required String sessionId,
    required DateTime at,
  }) async {
    final open = await (_db.select(_db.idleIntervals)
          ..where(
            (t) => t.sessionId.equals(sessionId) & t.endedAt.isNull(),
          ))
        .get();
    for (final row in open) {
      await (_db.update(_db.idleIntervals)..where((t) => t.id.equals(row.id)))
          .write(IdleIntervalsCompanion(endedAt: Value(at.toUtc())));
    }
  }

  Stream<List<TrackingSession>> watchRecentSessions({int limit = 20}) {
    return (_db.select(_db.trackingSessions)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(limit))
        .watch();
  }

  /// Sessions that started on the user's local calendar day.
  Stream<List<TrackingSession>> watchSessionsForLocalDay({
    required String userId,
    required DateTime localDay,
  }) {
    final localStart = DateTime(localDay.year, localDay.month, localDay.day);
    final localEnd = localStart.add(const Duration(days: 1));
    final start = localStart.toUtc();
    final end = localEnd.toUtc();
    return (_db.select(_db.trackingSessions)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.startedAt.isBiggerOrEqualValue(start) &
                t.startedAt.isSmallerThanValue(end),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .watch();
  }

  /// [localDay] is a calendar day in the user's local timezone.
  /// Bounds are converted to UTC so events stored in UTC match the local day.
  Stream<List<SessionEvent>> watchEventsForDay(DateTime localDay) {
    final localStart = DateTime(localDay.year, localDay.month, localDay.day);
    final localEnd = localStart.add(const Duration(days: 1));
    final start = localStart.toUtc();
    final end = localEnd.toUtc();
    return (_db.select(_db.sessionEvents)
          ..where((t) => t.at.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.asc(t.at)]))
        .watch();
  }

  Future<List<AppUsageInterval>> appUsageForSession(String sessionId) {
    return (_db.select(_db.appUsageIntervals)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
  }

  Future<Duration> trackedToday(String userId) async {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day).toUtc();
    final rows = await (_db.select(_db.trackingSessions)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.startedAt.isBiggerOrEqualValue(dayStart),
          ))
        .get();
    var ms = 0;
    for (final row in rows) {
      ms += row.activeMs + row.idleMs + row.pausedMs;
    }
    return Duration(milliseconds: ms);
  }

  /// Sessions whose [startedAt] falls in the local calendar range
  /// `[localStartDay, localEndDayExclusive)`.
  Future<List<TrackingSession>> sessionsInLocalRange({
    required String userId,
    required DateTime localStartDay,
    required DateTime localEndDayExclusive,
  }) {
    final start = DateTime(
      localStartDay.year,
      localStartDay.month,
      localStartDay.day,
    ).toUtc();
    final end = DateTime(
      localEndDayExclusive.year,
      localEndDayExclusive.month,
      localEndDayExclusive.day,
    ).toUtc();
    return (_db.select(_db.trackingSessions)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.startedAt.isBiggerOrEqualValue(start) &
                t.startedAt.isSmallerThanValue(end),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
  }
}
