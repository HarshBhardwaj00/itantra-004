import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';

/// Circular Push-To-Talk walkie button with a lime ring glow and a
/// radial soundwave that pulses while the mic is open.
///
/// Two gestures are supported on the same surface:
///  * **hold** — classic push-to-talk, the take is sent on release
///  * **tap** — record and review, the take is staged for the operator
class PttButton extends StatefulWidget {
  const PttButton({
    super.key,
    required this.isRecording,
    required this.voiceDetected,
    required this.onStart,
    required this.onEnd,
    required this.onCancel,
    this.onTap,
    this.elapsedMsOverride,
  });

  final bool isRecording;
  final bool voiceDetected;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onCancel;

  /// Short tap gesture — toggles a record-and-review take.
  final VoidCallback? onTap;

  /// Optional hook for tests to simulate touch durations deterministically.
  final int Function()? elapsedMsOverride;

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  DateTime? _pointerDownTime;
  Offset? _pointerDownGlobal;
  bool _isPointerDown = false;
  bool _dragCancelled = false;
  bool _pointerDownWasAlreadyRecording = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant PttButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRecording != widget.isRecording) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.isRecording) {
      _waveController.repeat();
    } else {
      _waveController.stop();
      _waveController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event, double buttonSize) {
    // 1. Geometrical circular boundary check — strictly reject any touch outside the circle
    final radius = buttonSize / 2;
    final center = Offset(radius, radius);
    if ((event.localPosition - center).distance > radius) {
      return;
    }

    if (_isPointerDown) return;
    _isPointerDown = true;
    _dragCancelled = false;
    _pointerDownTime = DateTime.now();
    _pointerDownGlobal = event.position;
    _pointerDownWasAlreadyRecording = widget.isRecording;

    if (!widget.isRecording) {
      widget.onStart();
    }
  }

  void _onPointerMove(PointerMoveEvent event, double buttonSize) {
    if (!_isPointerDown || _dragCancelled) return;

    // Detect scroll gesture or drag movement beyond touch slop threshold
    if (_pointerDownGlobal != null) {
      final travel = (event.position - _pointerDownGlobal!).distance;
      if (travel > 14.0) {
        _dragCancelled = true;
        _isPointerDown = false;
        widget.onCancel();
        return;
      }
    }

    // Detect if finger slipped outside button perimeter
    final radius = buttonSize / 2;
    final center = Offset(radius, radius);
    if ((event.localPosition - center).distance > radius + 12.0) {
      _dragCancelled = true;
      _isPointerDown = false;
      widget.onCancel();
      return;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_dragCancelled) {
      _dragCancelled = false;
      return;
    }
    if (!_isPointerDown) return;
    _isPointerDown = false;

    final elapsed = widget.elapsedMsOverride != null
        ? widget.elapsedMsOverride!()
        : (_pointerDownTime != null
            ? DateTime.now().difference(_pointerDownTime!).inMilliseconds
            : 1000);

    // If the mic was ALREADY recording when pointer went down,
    // this tap is an explicit command to stop recording and finish the take.
    if (_pointerDownWasAlreadyRecording) {
      widget.onEnd();
      return;
    }

    // Accidental micro-touch or brush (< 120ms): cancel immediately, do not open mic!
    if (elapsed < 120 && !widget.voiceDetected) {
      widget.onCancel();
      return;
    }

    // Deliberate tap (120ms - 350ms) without speech: toggle tap-to-record review mode
    if (elapsed < 350 && !widget.voiceDetected && widget.onTap != null) {
      // The recording is ALREADY running (started in _onPointerDown).
      // Keep it active and notify onTap to switch to review mode.
      widget.onTap!();
    } else {
      // Standard Push-To-Talk release (> 350ms or voice detected): finish and auto-send!
      widget.onEnd();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (!_isPointerDown) return;
    _isPointerDown = false;
    _dragCancelled = false;
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    final shortestSide = math.min(screenWidth, screenHeight);
    final idleSize =
        clampDouble(shortestSide * 0.34, 100.0, 160.0);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;

          // The wave ring sits around the idle button and grows with the
          // recording sweep, so derive the wave from the requested size and
          // then clamp it to whatever width the host row actually offers.
          // This keeps normal devices pixel-identical while ultra-narrow
          // hosts (split view, tiny windows) shrink instead of overflowing.
          final requestedWave = idleSize *
              (widget.isRecording ? 1.08 : 1.0) *
              1.32;
          final waveSize = availableWidth.isFinite
              ? math.min(requestedWave, availableWidth)
              : requestedWave;
          final buttonSize = widget.isRecording
              ? math.min(idleSize * 1.08, waveSize / 1.32)
              : math.min(idleSize, waveSize / 1.32);
          final borderWidth = clampDouble(screenWidth * 0.008, 2.0, 3.0);
          final iconSize = buttonSize * 0.34;

          return SizedBox(
            width: waveSize,
            height: waveSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
            // Soundwave animation is purely visual — ignore pointer events
            // so empty corners and wave margins never intercept touches!
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size.square(waveSize),
                    painter: _SoundwavePainter(
                      phase: _waveController.value,
                      active: widget.isRecording,
                      voiceDetected: widget.voiceDetected,
                    ),
                  );
                },
              ),
            ),
            // Circular button: touch is strictly clipped and hit-tested
            // exclusively inside the circular button bounds.
            ClipOval(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => _onPointerDown(e, buttonSize),
                onPointerMove: (e) => _onPointerMove(e, buttonSize),
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryEmerald,
                    border: Border.all(
                      color: AppColors.primaryEmerald,
                      width: borderWidth,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryEmerald.withValues(
                          alpha: widget.isRecording ? 0.45 : 0.25,
                        ),
                        blurRadius: widget.isRecording ? 38.0 : 26.0,
                        spreadRadius: widget.isRecording ? 6.0 : 2.0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      LucideIcons.mic,
                      size: iconSize,
                      color: AppColors.textWhite,
                    ),
                  ),
                ),
              ),
            ),
          ],
            ),
          );
        },
      ),
    );
  }
}

class _SoundwavePainter extends CustomPainter {
  _SoundwavePainter({
    required this.phase,
    required this.active,
    required this.voiceDetected,
  });

  final double phase;
  final bool active;
  final bool voiceDetected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const bars = 44;
    final radius = size.width * 0.395;
    final baseLength = size.width * 0.045;

    final paint = Paint()..strokeCap = StrokeCap.round;

    if (active) {
      // Pulsating ripple rings around the hero button (design.md §4.C).
      final ripplePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.008
        ..color = AppColors.primaryEmerald.withValues(alpha: 0.12);
      for (var ring = 0; ring < 2; ring++) {
        final wave = (phase + ring * 0.5) % 1.0;
        ripplePaint.color = AppColors.primaryEmerald
            .withValues(alpha: 0.16 * (1.0 - wave).abs());
        canvas.drawCircle(
          center,
          radius + wave * size.width * 0.075,
          ripplePaint,
        );
      }
    }

    for (var i = 0; i < bars; i++) {
      final angle = -math.pi / 2 + (i * 2 * math.pi / bars);
      final direction = Offset(math.cos(angle), math.sin(angle));

      final wobble = math.sin(i * 0.85 + phase * math.pi * 4).abs();
      final secondary = math.sin(i * 1.7 - phase * math.pi * 6).abs();
      final energy = voiceDetected ? 1.0 : 0.55;

      final length = active
          ? baseLength * (0.5 + 1.7 * wobble * secondary * energy)
          : baseLength * 0.42;

      final alpha = active
          ? (voiceDetected ? 0.55 + wobble * 0.45 : 0.30 + wobble * 0.30)
          : 0.16;

      paint
        ..color = AppColors.primaryEmerald.withValues(alpha: alpha)
        ..strokeWidth = size.width * (active ? 0.022 : 0.016);

      canvas.drawLine(
        center + direction * radius,
        center + direction * (radius + length),
        paint,
      );
    }

    if (active) {
      final ringPaint = Paint()
        ..color = AppColors.primaryEmerald
            .withValues(alpha: 0.20 + 0.18 * math.sin(phase * math.pi * 2).abs())
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.010;
      canvas.drawCircle(center, radius - size.width * 0.030, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoundwavePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.active != active ||
      oldDelegate.voiceDetected != voiceDetected;
}
