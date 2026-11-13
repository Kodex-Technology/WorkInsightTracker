/// Future backend response envelope — adapters map any provider payload here.
/// Do not hardcode field names from a specific vendor in UI/domain code.
sealed class ApiResult<T> {
  const ApiResult();
}

class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.data, {this.raw});

  final T data;

  /// Original decoded JSON (or map) for forward-compatible extra fields.
  final Map<String, Object?>? raw;
}

class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure({
    required this.code,
    required this.message,
    this.statusCode,
    this.retryable = false,
    this.raw,
  });

  final String code;
  final String message;
  final int? statusCode;
  final bool retryable;
  final Map<String, Object?>? raw;
}

class ApiLoading<T> extends ApiResult<T> {
  const ApiLoading();
}

class ApiNotConfigured<T> extends ApiResult<T> {
  const ApiNotConfigured([this.reason = 'Provider not configured']);

  final String reason;
}

/// Soft-parse helpers for dynamic backend maps (unknown shapes).
extension DynamicMapX on Map<String, Object?> {
  String? stringOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    return v.toString();
  }

  bool? boolOrNull(String key) {
    final v = this[key];
    if (v is bool) return v;
    if (v is String) {
      if (v.toLowerCase() == 'true') return true;
      if (v.toLowerCase() == 'false') return false;
    }
    return null;
  }

  Map<String, Object?>? mapOrNull(String key) {
    final v = this[key];
    if (v is Map<String, Object?>) return v;
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val));
    }
    return null;
  }
}
