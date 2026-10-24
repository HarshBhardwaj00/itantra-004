import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';

/// Top identity bar of the unified comms hub.
///
/// Mirrors the reference layout: back chevron, brand tile, node identity with
/// the active language, and a live mesh pill on the trailing edge. The brand
/// title and the language line are capped at one row (accessibility-safe —
/// the bar height stays linear under any text-scale setting), so the
/// surrounding session data always renders without wrapping bombs.
class CommsIdentityBar extends StatelessWidget {
  const CommsIdentityBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusActive,
    this.onBack,
    this.onStatusTap,
    this.onSubtitleTap,
    this.trailing,
  });

  /// Node brand, e.g. `iTantra`.
  final String title;

  /// Secondary identity line, e.g. `Hindi · hi`.
  final String subtitle;

  /// Mesh state caption, e.g. `Mesh Active`.
  final String statusLabel;

  /// True when the mesh link is live.
  final bool statusActive;

  final VoidCallback? onBack;
  final VoidCallback? onStatusTap;

  /// Opens the language pack selection screen when the language line is
  /// tapped. `null` keeps the line inert.
  final VoidCallback? onSubtitleTap;

  /// Optional trailing action (menu button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final titleSize = AppType.header(screenWidth);
    final subtitleSize = AppType.meta(screenWidth);
    final badgeSize = AppType.badge(screenWidth);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final showBrandTile = availableWidth >= 350.0;
        final responsiveTileSize =
            clampDouble(availableWidth * 0.085, 28.0, 40.0);
        final responsiveIconSize = responsiveTileSize * 0.48;
        final responsiveGap = clampDouble(availableWidth * 0.015, 3.0, 8.0);
        final responsiveRadius =
            clampDouble(availableWidth * 0.035, 8.0, 14.0);
        final responsiveDotSize = clampDouble(availableWidth * 0.016, 4.0, 7.0);

        return FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: availableWidth),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _RoundIconButton(
                  icon: LucideIcons.chevronLeft,
                  size: responsiveTileSize,
                  iconSize: responsiveIconSize,
                  radius: responsiveRadius,
                  onTap: onBack,
                  semanticLabel: 'Back',
                ),
                if (showBrandTile) ...[
                  SizedBox(width: responsiveGap),
                  Container(
                    width: responsiveTileSize,
                    height: responsiveTileSize,
                    decoration: BoxDecoration(
                      color: AppColors.iconSquircleBg,
                      borderRadius: BorderRadius.circular(responsiveRadius),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryEmerald.withValues(alpha: 0.18),
                          blurRadius: 12.0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      LucideIcons.mic,
                      size: responsiveIconSize,
                      color: AppColors.primaryEmerald,
                    ),
                  ),
                ],
                SizedBox(width: responsiveGap),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.15,
                          ),
                        ),
                      ),
                      SizedBox(
                          height:
                              clampDouble(screenWidth * 0.008, 2.0, 4.0)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _buildSubtitle(context, subtitleSize),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: responsiveGap),
                Flexible(
                  flex: 2,
                  child: _MeshPill(
                    label: statusLabel,
                    active: statusActive,
                    badgeSize: badgeSize,
                    dotSize: responsiveDotSize,
                    onTap: onStatusTap,
                  ),
                ),
                if (trailing != null) ...[
                  SizedBox(width: responsiveGap),
                  trailing!,
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// The language line of the identity bar.
  ///
  /// It stays a plain label until a tap handler is supplied, and it never
  /// truncates — the whole string is always readable.
  Widget _buildSubtitle(BuildContext context, double subtitleSize) {
    final label = Text(
      subtitle,
      style: TextStyle(
        fontSize: subtitleSize,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
        height: 1.25,
      ),
    );

    if (onSubtitleTap == null) return label;

    return Semantics(
      button: true,
      label: 'Change language',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8.0),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onSubtitleTap!();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: label),
                  SizedBox(
                    width: clampDouble(
                        MediaQuery.sizeOf(context).width * 0.012, 3.0, 5.0),
                  ),
                  Icon(
                    LucideIcons.chevronDown,
                    size: subtitleSize * 0.95,
                    color: AppColors.textMuted,
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

/// Rounded square icon button used for the back chevron and menu actions.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.radius,
    required this.semanticLabel,
    this.onTap,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final double radius;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: AppColors.surfaceBorder, width: 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap!();
                },
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: iconSize, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Emerald mesh status pill — the live/standby indicator of the hub.
class _MeshPill extends StatelessWidget {
  const _MeshPill({
    required this.label,
    required this.active,
    required this.badgeSize,
    required this.dotSize,
    this.onTap,
  });

  final String label;
  final bool active;
  final double badgeSize;
  final double dotSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final color = active
        ? AppColors.primaryEmeraldVibrant
        : AppColors.textSecondary;

    return Material(
      color: active ? AppColors.emeraldMintTint : AppColors.surfaceSecondary,
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
          padding: EdgeInsets.symmetric(
            horizontal: clampDouble(screenWidth * 0.016, 5.0, 10.0),
            vertical: clampDouble(screenWidth * 0.010, 4.0, 7.0),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? AppColors.emeraldMintBorder
                  : AppColors.surfaceBorder,
              width: 1.0,
            ),
          ),
          // Scale-down box so a squeezed pill shrinks its caption instead of
          // overflowing the identity row or wrapping the label mid-pill.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 6.0,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: clampDouble(screenWidth * 0.012, 4.0, 6.0)),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: badgeSize,
                      fontWeight: FontWeight.w700,
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
    );
  }
}
