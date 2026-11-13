import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witrack/data/database/app_database.dart';
import 'package:witrack/data/providers.dart';
import 'package:witrack/domain/tracking/tracking_state.dart';
import 'package:witrack/features/tracking/tracking_controller.dart';

final recentActivityProvider = StreamProvider<List<ActivitySample>>((ref) {
  final sessionId = ref.watch(
    trackingControllerProvider.select((s) => s.sessionId),
  );
  // Live signal so the chart reacts even between DB sample writes.
  ref.watch(
    trackingControllerProvider.select(
      (s) => (
        s.isActiveSignal,
        s.secondsSinceLastInput,
        s.active,
        s.idle,
      ),
    ),
  );
  final db = ref.watch(appDatabaseProvider);
  if (sessionId == null) {
    return Stream.value(const <ActivitySample>[]);
  }
  return (db.select(db.activitySamples)
        ..where((t) => t.sessionId.equals(sessionId))
        ..orderBy([(t) => OrderingTerm.desc(t.sampledAt)])
        ..limit(72))
      .watch();
});

/// Activity intensity 0..1 from idle age (peaks when input is fresh).
double activityLevel({
  required bool isActiveSignal,
  required int secondsSinceLastInput,
}) {
  if (!isActiveSignal) return 0.06;
  final s = secondsSinceLastInput;
  if (s <= 1) return 1.0;
  if (s <= 2) return 0.88;
  if (s <= 4) return 0.68;
  if (s <= 7) return 0.42;
  return 0.22;
}

double activityLevelFromSample(ActivitySample sample) => activityLevel(
      isActiveSignal: sample.isActiveSignal,
      secondsSinceLastInput: sample.secondsSinceLastInput,
    );

class ActivitySparkline extends ConsumerWidget {
  const ActivitySparkline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final samples = ref.watch(recentActivityProvider);
    final liveActive = ref.watch(
      trackingControllerProvider.select((s) => s.isActiveSignal),
    );
    final liveSeconds = ref.watch(
      trackingControllerProvider.select((s) => s.secondsSinceLastInput),
    );
    final status = ref.watch(
      trackingControllerProvider.select((s) => s.status),
    );
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return samples.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const SizedBox(height: 120),
      error: (error, stackTrace) => const SizedBox(height: 120),
      data: (rows) {
        final chronological = rows.reversed.toList(growable: false);
        final values = chronological
            .map(activityLevelFromSample)
            .toList(growable: true);

        // Append a live tip so the mountain moves in real time.
        final sessionOpen = status == TrackingStatus.tracking ||
            status == TrackingStatus.idle ||
            status == TrackingStatus.paused;
        if (sessionOpen && liveSeconds != null) {
          values.add(
            activityLevel(
              isActiveSignal: liveActive == true,
              secondsSinceLastInput: liveSeconds,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Activity mountain', style: theme.textTheme.labelLarge),
                const Spacer(),
                if (sessionOpen)
                  Text(
                    liveActive == true ? 'Live · active' : 'Live · quiet',
                    style: theme.textTheme.bodySmall?.copyWith(color: accent),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(
                painter: _MountainPainter(
                  values: values,
                  peak: accent,
                  base: theme.colorScheme.surfaceContainerHighest,
                  grid: theme.dividerColor,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              values.isEmpty
                  ? 'Start tracking — peaks rise with input, valleys when idle.'
                  : 'Peaks = recent input · valleys = idle/quiet · updates live.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

class _MountainPainter extends CustomPainter {
  _MountainPainter({
    required this.values,
    required this.peak,
    required this.base,
    required this.grid,
  });

  final List<double> values;
  final Color peak;
  final Color base;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final pad = 4.0;
    final chart = Rect.fromLTWH(
      pad,
      pad,
      size.width - pad * 2,
      size.height - pad * 2,
    );

    // Soft floor grid
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = chart.bottom - (chart.height * i / 4);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    if (values.isEmpty) {
      final quiet = Paint()..color = grid.withValues(alpha: 0.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(chart.left, chart.bottom - 2, chart.width, 2),
          const Radius.circular(2),
        ),
        quiet,
      );
      return;
    }

    final pts = <Offset>[];
    final n = values.length;
    for (var i = 0; i < n; i++) {
      final t = n == 1 ? 0.0 : i / (n - 1);
      final x = chart.left + chart.width * t;
      final v = values[i].clamp(0.0, 1.0);
      final y = chart.bottom - chart.height * (0.08 + v * 0.9);
      pts.add(Offset(x, y));
    }

    final line = _smoothPath(pts);
    final fill = Path.from(line)
      ..lineTo(pts.last.dx, chart.bottom)
      ..lineTo(pts.first.dx, chart.bottom)
      ..close();

    final shader = ui.Gradient.linear(
      Offset(chart.left, chart.top),
      Offset(chart.left, chart.bottom),
      [
        peak.withValues(alpha: 0.55),
        peak.withValues(alpha: 0.18),
        peak.withValues(alpha: 0.02),
      ],
      const [0.0, 0.55, 1.0],
    );
    canvas.drawPath(fill, Paint()..shader = shader);

    // Depth band (pseudo-3D thickness under the ridge)
    final depth = Path();
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      final d = Offset(p.dx + 1.5, p.dy + 4);
      if (i == 0) {
        depth.moveTo(d.dx, d.dy);
      } else {
        depth.lineTo(d.dx, d.dy);
      }
    }
    for (var i = pts.length - 1; i >= 0; i--) {
      depth.lineTo(pts[i].dx, pts[i].dy);
    }
    depth.close();
    canvas.drawPath(
      depth,
      Paint()..color = peak.withValues(alpha: 0.12),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = peak
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = peak
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Highlight crest dots on local peaks
    for (var i = 1; i < pts.length - 1; i++) {
      if (values[i] >= values[i - 1] && values[i] >= values[i + 1] && values[i] > 0.55) {
        canvas.drawCircle(
          pts[i],
          2.6,
          Paint()..color = peak.withValues(alpha: 0.9),
        );
      }
    }
  }

  Path _smoothPath(List<Offset> pts) {
    final path = Path();
    if (pts.isEmpty) return path;
    path.moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 1) return path;
    if (pts.length == 2) {
      path.lineTo(pts[1].dx, pts[1].dy);
      return path;
    }
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[math.max(0, i - 1)];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[math.min(pts.length - 1, i + 2)];
      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _MountainPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.peak != peak;
}
