/// Future integration seams. Adapters map real external APIs onto these types.
/// Do not invent network calls here.
library;

enum AttendanceOutcome {
  notConfigured,
  loading,
  pending,
  confirmed,
  rejected,
  unauthorized,
  timeout,
  unknown,
  conflict,
}

abstract class UserProfileRepository {
  Future<Map<String, Object?>?> getProfile(String userId);
}

abstract class PolicyRepository {
  Future<Map<String, Object?>?> fetchRemotePolicy();
  Future<void> applyLocalSafeDefaults();
}

abstract class SyncRepository {
  Future<void> flushOutbox();
  Stream<String> syncStatus();
}

abstract class TrackingRepository {
  /// Local tracking only — never call remote services from the native engine.
  Future<void> startLocalSession({required String userId});
  Future<void> stopLocalSession({required String sessionId});
}

abstract class AttendanceRepository {
  Future<AttendanceOutcome> getAttendanceStatus();
  Future<AttendanceOutcome> checkIn({required String idempotencyKey});
  Future<AttendanceOutcome> checkOut({required String idempotencyKey});
  Future<List<Map<String, Object?>>> getAttendanceHistory();
  Future<Map<String, Object?>?> getCurrentShift();
}

/// Disabled attendance provider until ENABLE_ATTENDANCE_INTEGRATION + real API.
class NotConfiguredAttendanceRepository implements AttendanceRepository {
  const NotConfiguredAttendanceRepository();

  @override
  Future<AttendanceOutcome> checkIn({required String idempotencyKey}) async =>
      AttendanceOutcome.notConfigured;

  @override
  Future<AttendanceOutcome> checkOut({required String idempotencyKey}) async =>
      AttendanceOutcome.notConfigured;

  @override
  Future<List<Map<String, Object?>>> getAttendanceHistory() async => const [];

  @override
  Future<Map<String, Object?>?> getCurrentShift() async => null;

  @override
  Future<AttendanceOutcome> getAttendanceStatus() async =>
      AttendanceOutcome.notConfigured;
}
