import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';

/// Top status capsule: [WiFi 12 ms | LoRa Standby | Queue 0].
/// Segments live in a Wrap so narrow phones get a second row instead
/// of clipped or truncated text. Tap opens the Radio Manager screen.
class LinkStatusIndicator extends StatelessWidget {
  const LinkStatusIndicator({
    super.key,
    required this.wifiAlive,
    required this.wifiLatencyMs,
    required this.loraActive,
    required this.queueCount,
    this.onTap,
  });

  final bool wifiAlive;
  final int wifiLatencyMs;
  final bool loraActive;
  final int queueCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final badgeSize = clampDouble(screenWidth * 0.028, 10.0, 12.0);
    final iconSize = clampDouble(screenWidth * 0.034, 12.0, 15.0);
    final edgePad = clampDouble(screenWidth * 0.024, 8.0, 14.0);
    final pillPad = clampDouble(screenWidth * 0.020, 6.0, 12.0);
    final pillGap = clampDouble(screenWidth * 0.012, 4.0, 8.0);
    final dotSize = clampDouble(screenWidth * 0.020, 6.0, 9.0);

    final wifiLabel = wifiAlive ? 'WiFi $wifiLatencyMs ms' : 'WiFi Down';
    final loraLabel = loraActive ? 'LoRa Active' : 'LoRa Standby';

    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: edgePad,
            vertical: clampDouble(edgePad * 0.7, 5.0, 10.0),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
          ),
          child: Row(
            children: [
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: wifiAlive ? AppColors.primaryEmerald : AppColors.alertRed,
                  boxShadow: [
                    BoxShadow(
                      color: (wifiAlive
                              ? AppColors.primaryEmerald
                              : AppColors.alertRed)
                          .withValues(alpha: 0.55),
                      blurRadius: 8.0,
                    ),
                  ],
                ),
              ),
              SizedBox(width: pillGap),
              Expanded(
                child: Wrap(
                  spacing: pillGap,
                  runSpacing: pillGap,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildPill(
                      screenWidth: screenWidth,
                      icon: LucideIcons.wifi,
                      label: wifiLabel,
                      color: wifiAlive ? AppColors.primaryEmerald : AppColors.alertRed,
                      badgeSize: badgeSize,
                      iconSize: iconSize,
                      pillPad: pillPad,
                    ),
                    _buildPill(
                      screenWidth: screenWidth,
                      icon: LucideIcons.radio,
                      label: loraLabel,
                      color: loraActive
                          ? AppColors.primaryEmeraldVibrant
                          : AppColors.textSecondary,
                      badgeSize: badgeSize,
                      iconSize: iconSize,
                      pillPad: pillPad,
                    ),
                    _buildPill(
                      screenWidth: screenWidth,
                      icon: LucideIcons.hourglass,
                      label: 'Queue $queueCount',
                      color: queueCount > 0
                          ? AppColors.primaryEmerald
                          : AppColors.textSecondary,
                      badgeSize: badgeSize,
                      iconSize: iconSize,
                      pillPad: pillPad,
                    ),
                  ],
                ),
              ),
              SizedBox(width: pillGap),
              Icon(
                LucideIcons.chevronRight,
                size: iconSize + 4.0,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPill({
    required double screenWidth,
    required IconData icon,
    required String label,
    required Color color,
    required double badgeSize,
    required double iconSize,
    required double pillPad,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: pillPad,
        vertical: clampDouble(screenWidth * 0.010, 3.0, 7.0),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: color),
            SizedBox(width: clampDouble(screenWidth * 0.010, 3.0, 5.0)),
            Flexible(
              child: Text(
                label,
                softWrap: false,
                style: TextStyle(
                  fontSize: badgeSize,
                  fontWeight: FontWeight.w600,
                  color: color,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
