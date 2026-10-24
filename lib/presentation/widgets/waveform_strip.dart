import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Animated lime waveform used as the live signal visual on the sender
/// surface and as the static clip preview inside the recorded-audio card.
///
/// The painter is isolated inside a [RepaintBoundary] so the 120 Hz Impeller
/// pipeline only repaints the strip itself — never the surrounding card.
class WaveformStrip extends StatefulWidget {
  const WaveformStrip({
    super.key,
    required this.active,
    this.seed = 3,
    this.barCount = 26,
    this.barWidth = 3.0,
    this.barGap = 3.0,
    this.height = 42.0,
    this.color,
    this.idleAlpha = 0.30,
    this.activeAlpha = 1.0,
  });

  /// When true the bars animate like a live microphone signal.
  final bool active;

  /// Deterministic seed so the idle silhouette stays identical between
  /// rebuilds (no random flicker on every frame).
  final int seed;

  final int barCount;
  final double barWidth;
  final double barGap;
  final double height;
  final Color? color;
  final double idleAlpha;
  final double activeAlpha;

  @override
  State<WaveformStrip> createState() => _WaveformStripState();
}

class _WaveformStripState extends State<WaveformStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant WaveformStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.active) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Live recording bars use the vivid emerald, recorded/feed previews use
    // the soft sage mint (design.md §2).
    final color = widget.color ??
        (widget.active ? AppColors.waveformActive : AppColors.waveformPreview);

    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _WaveformPainter(
                phase: _controller.value,
                active: widget.active,
                seed: widget.seed,
                barCount: widget.barCount,
                barWidth: widget.barWidth,
                barGap: widget.barGap,
                color: color,
                idleAlpha: widget.idleAlpha,
                activeAlpha: widget.activeAlpha,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.phase,
    required this.active,
    required this.seed,
    required this.barCount,
    required this.barWidth,
    required this.barGap,
    required this.color,
    required this.idleAlpha,
    required this.activeAlpha,
  });

  final double phase;
  final bool active;
  final int seed;
  final int barCount;
  final double barWidth;
  final double barGap;
  final Color color;
  final double idleAlpha;
  final double activeAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    if (barCount <= 0 || size.width <= 0) return;

    final slot = barWidth + barGap;
    final maxBars = math.max(1, (size.width / slot).floor());
    final count = math.min(barCount, maxBars);
    final usedWidth = count * slot - barGap;
    final startX = math.max(0.0, (size.width - usedWidth) / 2.0);
    final midY = size.height / 2.0;
    final maxHalf = midY * 0.92;

    final paint = Paint()..strokeCap = StrokeCap.round;

    for (var i = 0; i < count; i++) {
      final double factor;
      if (active) {
        final wobble = math.sin(i * 0.74 + phase * math.pi * 2).abs();
        final detail = math.sin(i * 1.63 - phase * math.pi * 3).abs();
        factor = 0.22 + 0.78 * wobble * (0.45 + 0.55 * detail);
      } else {
        // Stable silhouette derived from the seed — same shape every frame.
        final wobble = math.sin(i * 0.74 + seed * 1.37).abs();
        final detail = math.sin(i * 1.63 - seed * 0.91).abs();
        factor = 0.18 + 0.62 * wobble * (0.4 + 0.6 * detail);
      }

      final half = math.max(barWidth * 0.6, maxHalf * factor);
      final alpha = active ? activeAlpha : idleAlpha;

      paint
        ..color = color.withValues(alpha: alpha * (0.45 + 0.55 * factor))
        ..strokeWidth = barWidth;

      final x = startX + i * slot + barWidth / 2;
      canvas.drawLine(Offset(x, midY - half), Offset(x, midY + half), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    if (oldDelegate.active != active ||
        oldDelegate.barCount != barCount ||
        oldDelegate.seed != seed ||
        oldDelegate.color != color) {
      return true;
    }
    return oldDelegate.phase != phase;
  }
}
