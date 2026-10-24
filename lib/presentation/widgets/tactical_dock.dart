import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';

/// Floating tactical dock (Sender · Radar · Logs · Radio · Receiver) shared by
/// the secondary operational screens.
///
/// Labels are short enough to render complete on the smallest supported
/// phone, and they soft-wrap instead of ellipsising so nothing is ever
/// truncated.
class TacticalDock extends StatelessWidget {
  const TacticalDock({
    super.key,
    required this.active,
    required this.onSelect,
  });

  /// Destination that owns the dock (highlights its tab).
  final DockDestination? active;

  /// Tab tap callback carrying the destination.
  final ValueChanged<DockDestination> onSelect;

  static const List<(IconData, String, DockDestination)> _items =
      <(IconData, String, DockDestination)>[
    (LucideIcons.mic, 'Sender', DockDestination.sender),
    (LucideIcons.radar, 'Radar', DockDestination.radar),
    (LucideIcons.scrollText, 'Logs', DockDestination.logs),
    (LucideIcons.radio, 'Radio', DockDestination.radio),
    (LucideIcons.headphones, 'Receiver', DockDestination.receiver),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    final radius = clampDouble(screenWidth * 0.06, 20.0, 26.0);
    final iconSize = clampDouble(screenWidth * 0.052, 20.0, 24.0);
    final labelSize = AppType.badge(screenWidth);
    final itemGap = clampDouble(screenWidth * 0.01, 4.0, 6.0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(radius),
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
        vertical: clampDouble(screenHeight * 0.014, 9.0, 14.0),
        horizontal: clampDouble(screenWidth * 0.012, 4.0, 8.0),
      ),
      child: Row(
        children: _items.map((item) {
          final (icon, label, destination) = item;
          final isActive = destination == active;

          return Expanded(
            child: Material(
              color: isActive
                  ? AppColors.emeraldMintTint
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14.0),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(14.0),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSelect(destination);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: clampDouble(screenWidth * 0.004, 2.0, 4.0),
                    vertical: clampDouble(screenWidth * 0.012, 5.0, 8.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: iconSize,
                        color: isActive
                            ? AppColors.primaryEmerald
                            : AppColors.textMuted,
                      ),
                      SizedBox(height: itemGap),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: labelSize,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w400,
                          color: isActive
                              ? AppColors.primaryEmerald
                              : AppColors.textMuted,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
