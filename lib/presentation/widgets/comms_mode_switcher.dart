import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';

/// Bottom mode switcher of the unified comms hub.
///
/// Sender and receiver live on the same screen, so the switcher is the only
/// thing that changes between the two operational surfaces. The active tab
/// carries the lime underline indicator used by the reference layout.
class CommsModeSwitcher extends StatelessWidget {
  const CommsModeSwitcher({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final CommsMode mode;
  final ValueChanged<CommsMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    final iconSize = clampDouble(screenWidth * 0.052, 20.0, 24.0);
    final labelSize = AppType.badge(screenWidth);
    final itemGap = clampDouble(screenWidth * 0.012, 4.0, 6.0);
    final indicatorWidth = clampDouble(screenWidth * 0.16, 42.0, 62.0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(
          clampDouble(screenWidth * 0.06, 20.0, 26.0),
        ),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 18.0,
            offset: const Offset(0.0, 8.0),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        vertical: clampDouble(screenHeight * 0.012, 8.0, 12.0),
        horizontal: clampDouble(screenWidth * 0.015, 6.0, 10.0),
      ),
      child: Row(
        children: [
          _buildTab(
            context,
            screenWidth,
            CommsMode.sender,
            LucideIcons.mic,
            'Sender',
            iconSize,
            labelSize,
            itemGap,
            indicatorWidth,
          ),
          _buildTab(
            context,
            screenWidth,
            CommsMode.receiver,
            LucideIcons.headphones,
            'Receiver',
            iconSize,
            labelSize,
            itemGap,
            indicatorWidth,
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
    BuildContext context,
    double screenWidth,
    CommsMode tab,
    IconData icon,
    String label,
    double iconSize,
    double labelSize,
    double itemGap,
    double indicatorWidth,
  ) {
    final active = tab == mode;
    final color = active ? AppColors.primaryEmerald : AppColors.textMuted;

    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: '$label mode',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(
            clampDouble(screenWidth * 0.04, 14.0, 18.0),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (active) return;
              HapticFeedback.lightImpact();
              onChanged(tab);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: clampDouble(screenWidth * 0.012, 5.0, 8.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Solid emerald indicator line pinned to the top edge of
                  // the active tab (design.md §4.H).
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: active ? indicatorWidth : 0.0,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  SizedBox(height: clampDouble(screenWidth * 0.018, 6.0, 9.0)),
                  Icon(icon, size: iconSize, color: color),
                  SizedBox(height: itemGap),
                  // Scale-down instead of wrap so the tab never grows taller
                  // on narrow phones (no "Receiv / er" line split, no clipping).
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: labelSize,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        color: color,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
