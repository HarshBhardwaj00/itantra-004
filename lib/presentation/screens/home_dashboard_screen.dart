import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';

/// Screen 0 - the iTantra landing page.
///
/// One hero (the mic squircle, the brand copy, the capability pills and
/// "Ultra-Low Latency") and one call to action pinned above the bottom edge.
/// Everything is sized from the live `MediaQuery`, and the body is the
/// scroll-safe onboarding shell: the column always spans the viewport, the
/// hero drinks the leftover space, and on a short device the intrinsic height
/// simply grows past the fold and scrolls instead of overflowing.
class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _HomeDashboardView();
  }
}

class _HomeDashboardView extends StatefulWidget {
  const _HomeDashboardView();

  @override
  State<_HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends State<_HomeDashboardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------
  void _handleGetStarted() {
    HapticFeedback.lightImpact();
    // The device profile is provisioned at boot, so the operator goes
    // straight into the language picker and from there into the console.
    context.pushRoute(AppRouter.selectLanguage);
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final double w = context.screenWidth;
    final double h = context.screenHeight;
    final double gutter = AppSpacing.gutter(w);
    final double topPad = clampDouble(h * 0.02, 10.0, 18.0);
    final double bottomPad = clampDouble(h * 0.022, 12.0, 20.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: true,
        child: LayoutBuilder(
          builder: (context, viewportConstraints) {
            // ConstrainedBox raises the column to at least the viewport, so
            // [Expanded] keeps the hero centred on a tall device and the CTA
            // hugs the bottom edge; the vertical scroll view makes the whole
            // stack scroll on whatever is too short to fit.
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: viewportConstraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      topPad,
                      gutter,
                      bottomPad,
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: RepaintBoundary(child: _buildHero(context)),
                          ),
                        ),
                        _buildBottomCta(context),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Hero - the brand block of the landing page
  // ---------------------------------------------------------------------
  Widget _buildHero(BuildContext context) {
    final double w = context.screenWidth;
    final double h = context.screenHeight;
    // The smaller of the two dimensions drives the mark and the vertical
    // rhythm, so a short or slanted window compresses the hero gracefully
    // instead of pushing widgets off screen.
    final double s = math.min(w, h * 0.75);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildLogoTile(s),
        SizedBox(height: clampDouble(s * 0.048, 16.0, 30.0)),
        Text(
          'iTantra',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: clampDouble(w * 0.078, 26.0, 36.0),
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: 1.6,
            height: 1.1,
          ),
        ),
        SizedBox(height: clampDouble(s * 0.018, 6.0, 12.0)),
        Text(
          'Local Neural Speech & Edge Walkie-Talkie',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppType.meta(w),
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        SizedBox(height: clampDouble(s * 0.034, 14.0, 24.0)),
        Wrap(
          spacing: AppSpacing.chip(w),
          runSpacing: AppSpacing.chip(w),
          alignment: WrapAlignment.center,
          children: [
            _buildHeroPill(w, label: '10 Indian Languages'),
            _buildHeroPill(w, label: '100% Offline', accent: true),
          ],
        ),
        SizedBox(height: clampDouble(s * 0.028, 12.0, 18.0)),
        Text(
          'Ultra-Low Latency',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppType.badge(w),
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 1.1,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoTile(double s) {
    final double tileSize = clampDouble(s * 0.235, 78.0, 112.0);
    final double radius = clampDouble(tileSize * 0.28, 22.0, 30.0);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final double t = _pulse.value;
          return Container(
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              // Dark slate squircle with the emerald mic glyph — the brand
              // mark of the Light Neural system (design.md §4.A).
              color: AppColors.iconSquircleBg,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color:
                      AppColors.primaryEmerald.withValues(alpha: 0.18 + t * 0.10),
                  blurRadius: 22 + t * 12,
                  spreadRadius: 1 + t * 2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                LucideIcons.mic,
                color: AppColors.primaryEmerald,
                size: tileSize * 0.42,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroPill(
    double w, {
    required String label,
    bool accent = false,
  }) {
    final Color foreground =
        accent ? AppColors.primaryEmerald : AppColors.textSlate;
    final double dot = clampDouble(w * 0.018, 6.0, 8.0);
    final double innerGap = clampDouble(w * 0.017, 6.0, 8.0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: clampDouble(w * 0.036, 11.0, 15.0),
        vertical: clampDouble(w * 0.021, 7.0, 9.0),
      ),
      decoration: BoxDecoration(
        color: accent ? AppColors.emeraldMintTint : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent
              ? AppColors.primaryEmerald.withValues(alpha: 0.20)
              : AppColors.surfaceBorder,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (accent) ...[
            Container(
              width: dot,
              height: dot,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryEmerald,
              ),
            ),
            SizedBox(width: innerGap),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppType.badge(w),
                fontWeight: FontWeight.w600,
                color: foreground,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Bottom call to action
  // ---------------------------------------------------------------------
  Widget _buildBottomCta(BuildContext context) {
    final double w = context.screenWidth;
    final double h = context.screenHeight;
    final double ctaHeight = clampDouble(w * 0.16, 52.0, 62.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: ctaHeight),
          child: ElevatedButton(
            onPressed: _handleGetStarted,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryEmerald,
              foregroundColor: AppColors.textWhite,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  clampDouble(w * 0.05, 16.0, 20.0),
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: clampDouble(w * 0.03, 12.0, 18.0),
                vertical: clampDouble(w * 0.03, 12.0, 16.0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'Get Started',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppType.button(w) + 1.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      height: 1.25,
                    ),
                  ),
                ),
                SizedBox(width: clampDouble(w * 0.022, 8.0, 10.0)),
                Icon(
                  LucideIcons.arrowRight,
                  size: clampDouble(w * 0.05, 18.0, 21.0),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: clampDouble(h * 0.015, 8.0, 12.0)),
        Text(
          'Instant Indian Language Synthesizer · Edge P2P',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppType.badge(w),
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
