import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:witrack/core/config/app_env.dart';
import 'package:witrack/data/auth/auth_models.dart';

/// HTTP integration for attendance and screenshots; native capture stays local.
class TrackerApiController {
  Uri get _base {
    final uri = Uri.parse(AppEnv.apiBaseUrl);
    if (uri.path.endsWith('/api/')) return uri;
    if (uri.path.endsWith('/api')) return uri.replace(path: '${uri.path}/');
    return uri.replace(path: '${uri.path.replaceFirst(RegExp(r'/$'), '')}/api');
  }

  Map<String, String> _headers(AuthUser user) => {
        'Accept': 'application/json',
        if (user.token?.isNotEmpty == true)
          'Authorization': 'Bearer ${user.token}',
      };

  Future<void> syncAttendance({
    required AuthUser user,
    required String sessionId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int idleMs,
    required int pausedMs,
    String? projectId,
    String? note,
  }) async {
    if (user.token?.isNotEmpty != true) {
      // ignore: avoid_print
      print('[witrack.attendance] skipped: signed-in user has no API token (local development accounts cannot update server attendance).');
      return;
    }
   
    final userData = _userData(user);
    final employmentId = userData['employee_id_tracker_activity'] ??
        userData['attendance_user_id'] ??
        userData['id'] ??
        user.id;
    final from = startedAt.toUtc().millisecondsSinceEpoch ~/ 1000;
    final to = endedAt.toUtc().millisecondsSinceEpoch ~/ 1000;
    final payload = <String, Object?>{
      'id': sessionId,
      'employmentId': employmentId,
      'from': from,
      'to': to,
      'idleMs': idleMs,
      'pausedMs': pausedMs,
      'note': note ?? '',
      'projectId': projectId,
    };
    final uri = _base.resolve('tracker/attendance');
    // ignore: avoid_print
    print('[witrack.attendance] POST $uri (${endedAt.isAtSameMomentAs(startedAt) ? 'check-in' : 'attendance update/check-out'})');
    final response = await http.post(
      uri,
      headers: {..._headers(user), 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // ignore: avoid_print
      print('[witrack.attendance] rejected HTTP ${response.statusCode}: ${response.body}');
      throw Exception('Attendance sync failed (${response.statusCode}): ${response.body}');
    }
    final startLocal = _karachiIso(from);
    final endLocal = _karachiIso(to);
    // ignore: avoid_print
    print('[witrack.attendance] sent ${jsonEncode({...payload, 'fromLocal': startLocal, 'toLocal': endLocal, 'timezone': 'Asia/Karachi'})}');
    // ignore: avoid_print
    print('[witrack.attendance] response HTTP ${response.statusCode}: ${response.body}');
  }

  String _karachiIso(int epochSeconds) {
    final shifted = DateTime.fromMillisecondsSinceEpoch(
      epochSeconds * 1000,
      isUtc: true,
    ).add(const Duration(hours: 5));
    return shifted.toIso8601String().replaceFirst(RegExp(r'Z$'), '+05:00');
  }

  Map<String, dynamic> _userData(AuthUser user) {
    final json = user.userDataJson;
    if (json == null || json.isEmpty) return const {};
    try {
      final decoded = jsonDecode(json);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
    } catch (_) {
      return const {};
    }
  }



  Future<void> uploadScreenshot({
    required AuthUser user,
    required Uint8List pngBytes,
    required String sessionId,
    required int displayIndex,
    required DateTime takenAt,
  }) async {
    if (user.token?.isNotEmpty != true ) return;
    final request = http.MultipartRequest(
      'POST',
      _base.resolve('tracker/screenshots'),
    )..headers.addAll(_headers(user));
    request.fields.addAll({
      'session_id': sessionId,
      'display_index': '$displayIndex',
      'taken_at': takenAt.toUtc().toIso8601String(),
    });
    request.files.add(http.MultipartFile.fromBytes(
      'screenshot',
      pngBytes,
      filename: 'capture-${takenAt.millisecondsSinceEpoch}-$displayIndex.png',
    ));
    final streamed = await request.send();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Screenshot API failed (${streamed.statusCode}).');
    }
  }
}
