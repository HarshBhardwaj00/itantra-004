import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';
import 'waveform_strip.dart';

/// "Recorded Audio" card of the sender surface.
///
/// Mirrors the reference layout: a play badge, the clip title, the duration
/// and delivery state, the clip waveform and the two clip actions. The
/// actions live in their own tier below the title so nothing is ever
/// crowded or clipped.
class RecordedAudioCard extends StatelessWidget {
  const RecordedAudioCard({
    super.key,
    required this.hasClip,
    required this.durationLabel,
    required this.statusLabel,
    required this.isSending,
    required this.wasSent,
    required this.onDiscard,
    required this.onSend,
    this.previewText = '',
    this.isRecording = false,
  });

  /// True when a clip is staged for review.
  final bool hasClip;

  /// Clip duration, e.g. `0:04`.
  final String durationLabel;

  /// Delivery state, e.g. `Ready to send`.
  final String statusLabel;

  /// True while the clip is being pushed to the mesh.
  final bool isSending;

  /// True when the staged clip already reached the mesh.
  final bool wasSent;

  final VoidCallback onDiscard;
  final VoidCallback onSend;

  /// Optional transcript preview of the staged clip.
  final String previewText;

  /// True while the microphone is open.
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final cardRadius = AppSpacing.cardRadius(screenWidth);
    final cardPad = AppSpacing.cardPad(screenWidth);
    final iconBox = clampDouble(screenWidth * 0.11, 42.0, 54.0);
    final titleSize = AppType.itemTitle(screenWidth);
    final metaSize = AppType.meta(screenWidth);
    final buttonSize = AppType.button(screenWidth);

    final accent = hasClip ? AppColors.primaryEmerald : AppColors.textMuted;

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPad),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: hasClip
                        ? AppColors.emeraldAvatarBg
                        : AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(
                      clampDouble(screenWidth * 0.03, 12.0, 16.0),
                    ),
                    border: Border.all(
                      color: hasClip
                          ? AppColors.emeraldMintBorder
                          : AppColors.surfaceBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    hasClip ? LucideIcons.play : LucideIcons.micOff,
                    size: iconBox * 0.46,
                    color: accent,
                  ),
                ),
                SizedBox(width: clampDouble(screenWidth * 0.03, 12.0, 16.0)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Recorded Audio',
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      SizedBox(height: clampDouble(screenWidth * 0.012, 4.0, 7.0)),
                      Text(
                        hasClip
                            ? '$durationLabel · $statusLabel'
                            : 'No clip yet — hold the mic',
                        style: TextStyle(
                          fontSize: metaSize,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      if (previewText.isNotEmpty) ...[
                        SizedBox(height: clampDouble(screenWidth * 0.012, 4.0, 7.0)),
                        Text(
                          previewText,
                          style: TextStyle(
                            fontSize: metaSize,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: cardPad * 0.5),
            WaveformStrip(
              active: isRecording,
              seed: 5,
              barCount: 30,
              barWidth: clampDouble(screenWidth * 0.009, 2.5, 4.0),
              barGap: clampDouble(screenWidth * 0.011, 3.0, 5.0),
              height: clampDouble(screenWidth * 0.11, 34.0, 48.0),
              idleAlpha: hasClip ? 0.55 : 0.25,
            ),
            SizedBox(height: cardPad * 0.5),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 240.0;
                final discardAction = _ClipAction(
                  icon: LucideIcons.x,
                  label: 'Discard',
                  fontSize: buttonSize,
                  filled: false,
                  onTap: hasClip ? onDiscard : null,
                );
                final sendAction = _ClipAction(
                  icon: LucideIcons.send,
                  label: wasSent ? 'Resend' : 'Send Audio',
                  fontSize: buttonSize,
                  filled: true,
                  busy: isSending,
                  onTap: hasClip && !isSending ? onSend : null,
                );

                if (isCompact) {
                  return Column(
                    children: [
                      sendAction,
                      SizedBox(height: clampDouble(screenWidth * 0.02, 6.0, 10.0)),
                      discardAction,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: discardAction),
                    SizedBox(width: clampDouble(screenWidth * 0.025, 8.0, 14.0)),
                    Expanded(child: sendAction),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Clip action pill — outline variant for discard, lime variant for send.
class _ClipAction extends StatelessWidget {
  const _ClipAction({
    required this.icon,
    required this.label,
    required this.fontSize,
    required this.filled,
    this.busy = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final double fontSize;
  final bool filled;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final iconSize = clampDouble(screenWidth * 0.038, 14.0, 18.0);

    final background =
        filled ? AppColors.primaryEmerald : AppColors.surfaceCard;
    final foreground =
        filled ? AppColors.textWhite : AppColors.textSlate;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: clampDouble(screenWidth * 0.025, 8.0, 14.0),
            horizontal: clampDouble(screenWidth * 0.02, 6.0, 12.0),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: filled ? AppColors.primaryEmerald : AppColors.surfaceBorder,
              width: 1.0,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: foreground,
                    ),
                  )
                else
                  Icon(icon, size: iconSize, color: foreground),
                SizedBox(width: clampDouble(screenWidth * 0.012, 3.0, 6.0)),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
