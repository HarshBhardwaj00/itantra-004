import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../blocs/alert/alert_bloc.dart';
import '../blocs/alert/alert_state.dart';
import '../blocs/alert/alert_event.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';

/// Screen 7: Critical Emergency SOS Siren Overlay (Global Modal).
///
/// Network concept: **Interrupt-Driven Priority Queuing (QoS Level 0)** —
/// Full-screen non-dismissible modal that hijacks the UI when MsgType == 0x02
/// packet arrives. Forces max volume, loops siren, speaks alert via Piper TTS.
/// Only dismissed by deliberate "Slide to Acknowledge" gesture which sends
/// ALERT_ACKNOWLEDGED packet and navigates to Tactical Radar for rescue.
class EmergencyDialog extends StatefulWidget {
  const EmergencyDialog({required this.alertState, super.key});

  final AlertState alertState;

  @override
  State<EmergencyDialog> createState() => _EmergencyDialogState();
}

class _EmergencyDialogState extends State<EmergencyDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _strobeController;
  late final AnimationController _pulseController;
  late final AnimationController _iconScaleController;
  late final Animation<double> _strobeAnimation;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _iconScaleAnimation;

  double _sliderValue = 0.0;
  bool _sliderCompleted = false;
  Timer? _ttsRepeatTimer;

  @override
  void initState() {
    super.initState();

    // Disable system back button and gestures while dialog is open.
    SystemChannels.platform.setMethodCallHandler((call) async {
      if (call.method == 'SystemNavigator.pop') {
        return false; // Prevent back navigation
      }
      return null;
    });

    _strobeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _iconScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _strobeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _strobeController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _iconScaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _iconScaleController, curve: Curves.easeInOut),
    );

    // Repeat TTS announcement every 8 seconds while alert active.
    _ttsRepeatTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && !_sliderCompleted) {
        context.read<AlertBloc>().add(const AlertTestTriggered());
      }
    });
  }

  @override
  void dispose() {
    _strobeController.dispose();
    _pulseController.dispose();
    _iconScaleController.dispose();
    _ttsRepeatTimer?.cancel();
    SystemChannels.platform.setMethodCallHandler(null);
    super.dispose();
  }

  void _onSliderChanged(double value) {
    setState(() => _sliderValue = value);

    if (value >= 1.0 && !_sliderCompleted) {
      _sliderCompleted = true;
      HapticFeedback.heavyImpact();
      context.read<AlertBloc>().add(const AlertAcknowledged());
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final screenWidth = size.width;
    final screenHeight = size.height;

    // Responsive sizing using clampDouble for all dimensions.
    final hPad = clampDouble(screenWidth * 0.05, 16.0, 24.0);
    final vPad = clampDouble(screenHeight * 0.025, 16.0, 28.0);
    final cardRadius = clampDouble(screenWidth * 0.055, 20.0, 28.0);
    final iconBoxSize = clampDouble(screenWidth * 0.22, 80.0, 140.0);
    final headerSize = clampDouble(screenWidth * 0.052, 18.0, 22.0);
    final bodySize = clampDouble(screenWidth * 0.038, 14.0, 16.0);
    final metaSize = clampDouble(screenWidth * 0.033, 12.0, 14.0);
    final sliderHeight = clampDouble(screenHeight * 0.07, 56.0, 72.0);
    final gap = clampDouble(screenHeight * 0.018, 10.0, 16.0);
    final smallGap = clampDouble(screenHeight * 0.01, 6.0, 10.0);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // Swallow back button press - do nothing
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_strobeAnimation, _pulseAnimation]),
        builder: (context, _) {
                          final strobeOpacity = _strobeAnimation.value;
                          final bgColor = Color.lerp(
                            AppColors.alertRedBg,
                            AppColors.alertRed,
                            strobeOpacity * 0.35,
                          )!;

          return Material(
            color: bgColor,
            child: SafeArea(
              bottom: true,
              child: Stack(
                children: [
                  // Full-screen strobe overlay.
                  Positioned.fill(
                    child: IgnorePointer(
                        child: AnimatedOpacity(
                        opacity: strobeOpacity * 0.18,
                        duration: const Duration(milliseconds: 60),
                        child: Container(color: AppColors.alertRed),
                      ),
                    ),
                  ),

                  // Main content column.
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      hPad,
                      vPad,
                      hPad,
                      vPad + sliderHeight + smallGap + bottomInset,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Warning icon with pulse animation.
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            _pulseAnimation,
                            _iconScaleAnimation,
                          ]),
                          builder: (context, _) {
                            return Transform.scale(
                              scale: _pulseAnimation.value *
                                  _iconScaleAnimation.value,
                              child: Container(
                                width: iconBoxSize,
                                height: iconBoxSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.alertRedBg,
                                  border: Border.all(
                                    color: AppColors.alertRedAccent,
                                    width: 2.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.alertRed
                                          .withValues(alpha: 0.4 * _pulseAnimation.value),
                                      blurRadius: clampDouble(screenWidth * 0.08, 24.0, 48.0),
                                      spreadRadius: clampDouble(screenWidth * 0.02, 4.0, 8.0),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  LucideIcons.alertTriangle,
                                  size: iconBoxSize * 0.55,
                                  color: AppColors.alertRed,
                                ),
                              ),
                            );
                          },
                        ),

                        SizedBox(height: gap * 1.5),

                        // SOS Header.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18.0,
                            vertical: 8.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.alertRed,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'SOS EMERGENCY ALERT',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: headerSize,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textWhite,
                              height: 1.2,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                        SizedBox(height: smallGap),

                        // Distress intel card.
                        _buildDistressCard(
                          context,
                          screenWidth,
                          cardRadius,
                          bodySize,
                          metaSize,
                          gap,
                          smallGap,
                        ),

                        SizedBox(height: gap * 1.5),

                        // Instruction text.
                        Text(
                          'Slide right to acknowledge and stop siren',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: metaSize,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Slide-to-Acknowledge Slider at bottom.
                  Positioned(
                    left: hPad,
                    right: hPad,
                    bottom: vPad + bottomInset,
                    child: _buildSlideSlider(
                      context,
                      screenWidth,
                      sliderHeight,
                      cardRadius,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDistressCard(
    BuildContext context,
    double screenWidth,
    double cardRadius,
    double bodySize,
    double metaSize,
    double gap,
    double smallGap,
  ) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(clampDouble(screenWidth * 0.05, 18.0, 24.0)),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(
            color: AppColors.alertRed.withValues(alpha: 0.6),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.alertRed.withValues(alpha: 0.25),
              blurRadius: clampDouble(screenWidth * 0.06, 20.0, 32.0),
              spreadRadius: clampDouble(screenWidth * 0.015, 2.0, 6.0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sender row.
            _buildInfoRow(
              context,
              screenWidth,
              icon: LucideIcons.badgeAlert,
              iconColor: AppColors.alertRed,
              label: 'SENDER',
              value: widget.alertState.senderCallSign,
              bodySize: bodySize,
              metaSize: metaSize,
            ),

            SizedBox(height: gap),

            Divider(
              color: AppColors.surfaceBorder,
              height: 1.0,
              thickness: 1.0,
            ),

            SizedBox(height: gap),

            // Location row.
            _buildInfoRow(
              context,
              screenWidth,
              icon: LucideIcons.navigation,
              iconColor: AppColors.primaryEmerald,
              label: 'LOCATION',
              value: '${widget.alertState.distanceLabel} ${widget.alertState.bearingLabel}',
              bodySize: bodySize,
              metaSize: metaSize,
            ),

            SizedBox(height: gap),

            Divider(
              color: AppColors.surfaceBorder,
              height: 1.0,
              thickness: 1.0,
            ),

            SizedBox(height: gap),

            // Transcribed message row.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.mic,
                      size: clampDouble(screenWidth * 0.045, 16.0, 19.0),
                      color: AppColors.primaryEmeraldVibrant,
                    ),
                    SizedBox(width: clampDouble(screenWidth * 0.025, 10.0, 14.0)),
                    Flexible(
                      child: Text(
                        'VOICE MESSAGE',
                        style: TextStyle(
                          fontSize: metaSize,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          letterSpacing: 0.4,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: smallGap),
                Text(
                  widget.alertState.transcribedText,
                  style: TextStyle(
                    fontSize: bodySize,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    double screenWidth, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required double bodySize,
    required double metaSize,
  }) {
    final iconBox = clampDouble(screenWidth * 0.11, 40.0, 48.0);
    final gap = clampDouble(screenWidth * 0.03, 12.0, 16.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: iconBox,
          height: iconBox,
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: Icon(icon, size: iconBox * 0.48, color: iconColor),
        ),
        SizedBox(width: gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: metaSize,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: clampDouble(screenWidth * 0.008, 3.0, 5.0)),
              Text(
                value,
                style: TextStyle(
                  fontSize: bodySize,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlideSlider(
    BuildContext context,
    double screenWidth,
    double sliderHeight,
    double cardRadius,
  ) {
    final trackRadius = BorderRadius.circular(sliderHeight / 2);
    final labelSize = clampDouble(screenWidth * 0.033, 12.0, 14.0);
    final arrowSize = clampDouble(screenWidth * 0.055, 20.0, 26.0);

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: sliderHeight,
          decoration: BoxDecoration(
            borderRadius: trackRadius,
            color: AppColors.surfaceCard,
            border: Border.all(
              color: _sliderValue > 0.5 ? AppColors.primaryEmerald : AppColors.alertRed,
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: (_sliderValue > 0.5 ? AppColors.primaryEmerald : AppColors.alertRed)
                    .withValues(alpha: 0.3),
                blurRadius: 16.0,
                spreadRadius: 1.0,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background track with gradient.
              Container(
                decoration: BoxDecoration(
                  borderRadius: trackRadius,
                  gradient: LinearGradient(
                    colors: _sliderValue > 0.5
                        ? [
                            AppColors.emeraldMintTint,
                            AppColors.primaryEmerald.withValues(alpha: 0.15),
                          ]
                        : [
                            AppColors.alertRedBg,
                            AppColors.alertRed.withValues(alpha: 0.15),
                          ],
                  ),
                ),
              ),

              // Instruction text on track.
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: sliderHeight * 0.7,
                  ),
                  child: Text(
                    _sliderValue >= 1.0
                        ? 'ACKNOWLEDGED'
                        : 'Slide to Acknowledge',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: labelSize,
                      fontWeight: FontWeight.w700,
                      color: _sliderValue > 0.5
                          ? AppColors.primaryEmeraldDark
                          : AppColors.textPrimary,
                      letterSpacing: 0.5,
                      height: 1.25,
                    ),
                  ),
                ),
              ),

              // Draggable thumb.
              AnimatedAlign(
                alignment: Alignment(
                  -1.0 + (2.0 * _sliderValue.clamp(0.0, 1.0)),
                  0.0,
                ),
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final renderBox = context.findRenderObject() as RenderBox?;
                    if (renderBox == null) return;

                    final width = renderBox.size.width;
                    final localPos = renderBox.globalToLocal(details.globalPosition);
                    final newValue = (localPos.dx / width).clamp(0.0, 1.0);
                    _onSliderChanged(newValue);
                  },
                  onHorizontalDragEnd: (_) {
                    if (_sliderValue < 1.0) {
                      _onSliderChanged(0.0); // Snap back if not completed
                    }
                  },
                  child: Container(
                    width: sliderHeight,
                    height: sliderHeight,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _sliderValue >= 1.0 ? AppColors.primaryEmerald : AppColors.alertRed,
                      boxShadow: [
                        BoxShadow(
                          color: (_sliderValue >= 1.0
                                  ? AppColors.primaryEmerald
                                  : AppColors.alertRed)
                              .withValues(alpha: 0.4),
                          blurRadius: 12.0,
                          spreadRadius: 2.0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _sliderValue >= 1.0
                          ? Icon(
                              LucideIcons.check,
                              size: arrowSize,
                              color: AppColors.textWhite,
                            )
                          : Icon(
                              LucideIcons.chevronRight,
                              size: arrowSize,
                              color: AppColors.textWhite,
                            ),
                    ),
                  ),
                ),
              ),

              // Completion checkmark overlay.
              if (_sliderValue >= 1.0)
                Positioned.fill(
                  child: Center(
                    child: AnimatedScale(
                      scale: _sliderCompleted ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.elasticOut,
                      child: Icon(
                        LucideIcons.checkCircle2,
                        size: clampDouble(screenWidth * 0.12, 40.0, 56.0),
                        color: AppColors.primaryEmerald,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}