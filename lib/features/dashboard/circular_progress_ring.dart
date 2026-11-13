import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Soft “3D” circular progress — gradient arc, inner well, outer rim.
class CircularProgressRing extends StatelessWidget {
  const CircularProgressRing({
    super.key,
    required this.value,
    required this.label,
    required this.caption,
    required this.color,
    this.size = 96,
  });

  /// 0..1
  final double value;
  final String label;
  final String caption;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final clamped = value.clamp(0.0, 1.0);
    final pct = (clamped * 100).round();

    return SizedBox(
      width: size + 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(
                progress: clamped,
                color: color,
                track: theme.brightness == Brightness.dark
                    ? const Color(0xFF163247)
                    : theme.dividerColor.withValues(alpha: 0.55),
                well: theme.brightness == Brightness.dark
                    ? const Color(0xFF0A1C2A)
                    : theme.colorScheme.surface,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$pct%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            caption,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.well,
  });

  final double progress;
  final Color color;
  final Color track;
  final Color well;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final stroke = radius * 0.14;

    // Outer rim (subtle depth)
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: 0.22),
    );

    // Inner well
    canvas.drawCircle(
      center,
      radius - stroke - 4,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.alphaBlend(color.withValues(alpha: 0.10), well),
            well,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    final rect = Rect.fromCircle(center: center, radius: radius - stroke / 2 - 2);

    // Track
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = track,
    );

    if (progress <= 0) return;

    final sweep = math.pi * 2 * progress;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..color = color.withValues(alpha: 0.35);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, glow);

    final shader = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + sweep,
      colors: [
        Color.lerp(color, Colors.white, 0.35)!,
        color,
        Color.lerp(color, Colors.black, 0.18)!,
      ],
      stops: const [0.0, 0.55, 1.0],
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );

    // Highlight bead at tip
    final tipAngle = -math.pi / 2 + sweep;
    final tipR = radius - stroke / 2 - 2;
    final tip = Offset(
      center.dx + tipR * math.cos(tipAngle),
      center.dy + tipR * math.sin(tipAngle),
    );
    canvas.drawCircle(
      tip,
      stroke * 0.42,
      Paint()..color = Color.lerp(color, Colors.white, 0.45)!,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.track != track ||
        oldDelegate.well != well;
  }
}
