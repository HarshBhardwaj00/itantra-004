import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/network/haversine.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';
import '../../domain/entities/geo_location_entity.dart';
import '../blocs/radar/radar_bloc.dart';
import '../blocs/radar/radar_event.dart';
import '../blocs/radar/radar_state.dart';
import '../widgets/tactical_dock.dart';

/// Screen 3 — Tactical Radar & Direction.
///
/// Dark military HUD with a 360° magnetometer-driven compass dial, a
/// glowing peer blip, the hero telemetry banner and an offline 2D vector
/// grid fallback. Everything is derived from pure math (Haversine +
/// azimuth) — no AI model runs on this screen.
class TacticalRadarScreen extends StatefulWidget {
  const TacticalRadarScreen({super.key});

  @override
  State<TacticalRadarScreen> createState() => _TacticalRadarScreenState();
}

class _TacticalRadarScreenState extends State<TacticalRadarScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blipPulse;

  /// Only used when the screen is pumped without the app-level provider
  /// (unit tests / standalone previews). The live app reuses the single
  /// `RadarBloc` created in `main.dart` so background packets are never lost.
  RadarBloc? _localBloc;
  bool _startDispatched = false;

  /// Per-contact blip colours so multiple peers are visually distinct.
  static const List<Color> _blipPalette = <Color>[
    AppColors.primaryEmerald,
    Color(0xFF4FC3F7),
    Color(0xFFFFB74D),
    Color(0xFFE57373),
    Color(0xFFBA68C8),
    Color(0xFF4DD0E1),
  ];

  @override
  void initState() {
    super.initState();
    _blipPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final hasSharedBloc =
        context.findAncestorWidgetOfExactType<BlocProvider<RadarBloc>>() != null;

    final bloc = hasSharedBloc
        ? context.read<RadarBloc>()
        : (_localBloc ??= RadarBloc());

    if (!_startDispatched && bloc.state.status == RadarStatus.initial) {
      _startDispatched = true;
      bloc.add(const RadarStarted());
    }
  }

  @override
  void dispose() {
    _localBloc?.close();
    _blipPulse.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final screenWidth = size.width;
    final screenHeight = size.height;

    final hPad = clampDouble(screenWidth * 0.045, 12.0, 20.0);
    final sectionGap = clampDouble(screenHeight * 0.016, 10.0, 16.0);
    final topPad = clampDouble(screenHeight * 0.015, 10.0, 16.0);
    final dockHeight = clampDouble(screenHeight * 0.085, 66.0, 84.0);
    final dockBottom = clampDouble(screenHeight * 0.012, 8.0, 14.0);
    final scrollReserve = dockHeight + dockBottom + sectionGap;

    return BlocProvider<RadarBloc>.value(
      value: _localBloc ?? context.read<RadarBloc>(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: true,
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, 0.0),
                    child: _buildHeader(context, screenWidth),
                  ),
                  Expanded(
                    child: BlocBuilder<RadarBloc, RadarState>(
                      builder: (context, state) {
                        if (!state.hasFixes) {
                          if (state.status == RadarStatus.error) {
                            return _buildErrorView(
                              context,
                              state,
                              screenWidth,
                              screenHeight,
                              scrollReserve,
                            );
                          }
                          return _buildLoadingView(
                            context,
                            screenWidth,
                            screenHeight,
                            scrollReserve,
                          );
                        }
                        return _buildBody(
                          context,
                          state,
                          screenWidth,
                          screenHeight,
                          hPad,
                          sectionGap,
                          scrollReserve,
                        );
                      },
                    ),
                  ),
                ],
              ),
              Positioned(
                left: hPad,
                right: hPad,
                bottom: dockBottom,
                child: TacticalDock(
                  active: DockDestination.radar,
                  onSelect: _handleDockSelect,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------
  void _handleBack() {
    HapticFeedback.lightImpact();
    Navigator.of(context).maybePop();
  }

  void _handleDockSelect(DockDestination destination) {
    if (destination == DockDestination.radar) return;
    context.goToDock(destination);
  }

  void _handleRecenter(BuildContext context) {
    HapticFeedback.lightImpact();
    context.read<RadarBloc>().add(const RadarRecenterRequested());
  }

  void _handleViewToggle(BuildContext context) {
    HapticFeedback.lightImpact();
    context.read<RadarBloc>().add(const RadarViewToggled());
  }

  void _handleRetry(BuildContext context) {
    HapticFeedback.lightImpact();
    context.read<RadarBloc>().add(const RadarStarted());
  }

  // ---------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, double screenWidth) {
    final headerSize = clampDouble(screenWidth * 0.052, 18.0, 22.0);

    return BlocBuilder<RadarBloc, RadarState>(
      builder: (context, state) {
        return Row(
          children: [
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _handleBack,
                child: Padding(
                  padding: EdgeInsets.all(clampDouble(screenWidth * 0.016, 6.0, 9.0)),
                  child: Icon(
                    LucideIcons.chevronLeft,
                    color: AppColors.textPrimary,
                    size: clampDouble(screenWidth * 0.06, 24.0, 28.0),
                  ),
                ),
              ),
            ),
            SizedBox(width: clampDouble(screenWidth * 0.03, 12.0, 16.0)),
            Expanded(
              child: Text(
                'Tactical Radar',
                style: TextStyle(
                  fontSize: headerSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(width: clampDouble(screenWidth * 0.02, 8.0, 12.0)),
            Flexible(child: _buildHeaderBadge(context, state, screenWidth)),
          ],
        );
      },
    );
  }

  Widget _buildHeaderBadge(
    BuildContext context,
    RadarState state,
    double screenWidth,
  ) {
    final label = switch (state.status) {
      RadarStatus.error => 'FAULT',
      RadarStatus.loading || RadarStatus.initial => 'SYNC',
      RadarStatus.loaded => state.anyMock ? 'DEMO' : 'LIVE',
    };
    final color = switch (state.status) {
      RadarStatus.error => AppColors.alertRed,
      RadarStatus.loading || RadarStatus.initial => AppColors.textSecondary,
      RadarStatus.loaded => AppColors.primaryEmerald,
    };

    return _buildStatusBadge(
      context,
      label: label,
      color: color,
      icon: LucideIcons.satellite,
    );
  }

  // ---------------------------------------------------------------------
  // Scrollable body
  // ---------------------------------------------------------------------
  Widget _buildBody(
    BuildContext context,
    RadarState state,
    double screenWidth,
    double screenHeight,
    double hPad,
    double sectionGap,
    double scrollReserve,
  ) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        top: sectionGap,
        left: hPad,
        right: hPad,
        bottom: scrollReserve + (bottomInset == 0 ? 0.0 : bottomInset),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTelemetryBanner(context, state, screenWidth),
          SizedBox(height: sectionGap),
          _buildRadarCard(context, state, screenWidth, screenHeight),
          SizedBox(height: sectionGap),
          if (state.hasLivePeers) ...[
            _buildPeerRoster(context, state, screenWidth),
            SizedBox(height: sectionGap),
          ],
          _buildCoordinatesCard(context, state, screenWidth),
          SizedBox(height: sectionGap),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Hero telemetry banner
  // ---------------------------------------------------------------------
  Widget _buildTelemetryBanner(
    BuildContext context,
    RadarState state,
    double screenWidth,
  ) {
    final cardRadius = clampDouble(screenWidth * 0.06, 20.0, 26.0);
    final cardPad = clampDouble(screenWidth * 0.05, 18.0, 26.0);
    final metricSize = clampDouble(screenWidth * 0.065, 20.0, 26.0);
    final metaSize = clampDouble(screenWidth * 0.033, 12.0, 14.0);
    final gap = clampDouble(screenWidth * 0.02, 8.0, 12.0);

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPad),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(
            color: AppColors.primaryEmerald.withValues(alpha: 0.35),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryEmerald.withValues(alpha: 0.06),
              blurRadius: 22.0,
              spreadRadius: 1.0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Wrap(
              spacing: gap,
              runSpacing: gap,
              alignment: WrapAlignment.center,
              children: [
                _buildStatusBadge(
                  context,
                  label: 'PEER LOCK',
                  color: AppColors.primaryEmerald,
                  icon: LucideIcons.target,
                ),
                _buildStatusBadge(
                  context,
                  label: state.anyMock ? 'DEMO FIX' : 'LIVE FIX',
                  color: state.anyMock
                      ? AppColors.textSecondary
                      : AppColors.primaryEmerald,
                  icon: LucideIcons.mapPin,
                ),
              ],
            ),
            SizedBox(height: gap),
            Text(
              state.bannerLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: metricSize,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryEmerald,
                height: 1.24,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: gap * 0.75),
            Text(
              state.note.isNotEmpty
                  ? state.note
                  : 'Range and bearing to sender node',
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
    );
  }

  // ---------------------------------------------------------------------
  // Radar / grid card
  // ---------------------------------------------------------------------
  Widget _buildRadarCard(
    BuildContext context,
    RadarState state,
    double screenWidth,
    double screenHeight,
  ) {
    final cardRadius = clampDouble(screenWidth * 0.06, 20.0, 26.0);
    final cardPad = clampDouble(screenWidth * 0.05, 18.0, 26.0);
    final sectionSize = clampDouble(screenWidth * 0.042, 15.0, 17.0);
    final iconSize = clampDouble(screenWidth * 0.05, 19.0, 22.0);
    final gap = clampDouble(screenWidth * 0.03, 12.0, 16.0);
    final radarSize = _radarSizeFor(screenWidth, screenHeight);
    final showingCompass = state.view == RadarView.compass;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  showingCompass ? LucideIcons.radar : LucideIcons.layoutGrid,
                  size: iconSize,
                  color: AppColors.primaryEmerald,
                ),
                SizedBox(width: clampDouble(screenWidth * 0.02, 7.0, 10.0)),
                Expanded(
                  child: Text(
                    showingCompass ? 'Direction Dial' : 'Vector Grid',
                    style: TextStyle(
                      fontSize: sectionSize,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: clampDouble(screenWidth * 0.015, 6.0, 10.0)),
                Flexible(child: _buildHeadingChip(context, state, screenWidth)),
              ],
            ),
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: _buildControlButton(
                    context,
                    icon: LucideIcons.crosshair,
                    label: 'Recenter',
                    active: false,
                    onTap: () => _handleRecenter(context),
                  ),
                ),
                SizedBox(width: clampDouble(screenWidth * 0.02, 8.0, 12.0)),
                Flexible(
                  child: _buildControlButton(
                    context,
                    icon:
                        showingCompass ? LucideIcons.layoutGrid : LucideIcons.radar,
                    label: showingCompass ? 'Grid View' : 'Radar View',
                    active: showingCompass,
                    onTap: () => _handleViewToggle(context),
                  ),
                ),
              ],
            ),
            SizedBox(height: gap * 0.9),
            Center(
              child: SizedBox.square(
                dimension: radarSize,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.94, end: 1.0).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: showingCompass
                      ? _buildCompassView(state, radarSize)
                      : _buildGridView(context, state, radarSize),
                ),
              ),
            ),
            SizedBox(height: gap * 0.85),
            Wrap(
              spacing: clampDouble(screenWidth * 0.02, 8.0, 12.0),
              runSpacing: clampDouble(screenWidth * 0.02, 8.0, 12.0),
              children: [
                _buildChip(context, state.contactCountLabel, AppColors.primaryEmerald),
                _buildChip(context, state.spanLabel, AppColors.primaryEmerald),
                _buildChip(
                  context,
                  showingCompass ? 'North-Up Dial' : 'North-Up Plot',
                  AppColors.textSecondary,
                ),
                _buildChip(
                  context,
                  showingCompass ? state.rangeRingsLabel : 'Offline Mode',
                  AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompassView(RadarState state, double radarSize) {
    return RepaintBoundary(
      key: const ValueKey<String>('compass-view'),
      child: AnimatedBuilder(
        animation: _blipPulse,
        builder: (context, _) {
          return CustomPaint(
            size: Size.square(radarSize),
            painter: _CompassDialPainter(
              headingDeg: state.headingDegrees,
              blips: _blipsFor(state),
              spanMeters: state.spanMeters,
              pulse: _blipPulse.value,
              peerLocked: state.peerLocked,
            ),
          );
        },
      ),
    );
  }

  /// Maps every plotted contact to a coloured blip spec, keeping the seed
  /// fallback identical to the original single-peer rendering.
  List<_RadarBlip> _blipsFor(RadarState state) {
    final contacts = state.contacts;
    return <_RadarBlip>[
      for (var i = 0; i < contacts.length; i++)
        _RadarBlip(
          callSign: contacts[i].callSign,
          bearingDeg: contacts[i].bearingDegrees,
          fraction: contacts[i].fraction(state.spanMeters),
          distanceLabel: contacts[i].distanceLabel,
          color: _blipPalette[i % _blipPalette.length],
        ),
    ];
  }

  Widget _buildGridView(
    BuildContext context,
    RadarState state,
    double radarSize,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final badgeSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);
    final labelWidth = radarSize * 0.44;
    final edge = clampDouble(radarSize * 0.03, 5.0, 10.0);
    final blips = _blipsFor(state);

    final peerLabels = <Widget>[
      for (final blip in blips)
        _buildGridPeerLabel(blip, radarSize, labelWidth, badgeSize),
    ];

    return RepaintBoundary(
      key: const ValueKey<String>('grid-view'),
      child: SizedBox.square(
        dimension: radarSize,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(
                  blips: blips,
                  pulse: _blipPulse.value,
                  peerLocked: state.peerLocked,
                ),
              ),
            ),
            Positioned(
              top: edge,
              left: 0.0,
              right: 0.0,
              child: Text(
                'N',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: badgeSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Positioned(
              bottom: edge,
              left: 0.0,
              right: 0.0,
              child: Text(
                'S',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: badgeSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Positioned(
              left: edge,
              top: 0.0,
              bottom: 0.0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'W',
                  style: TextStyle(
                    fontSize: badgeSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Positioned(
              right: edge,
              top: 0.0,
              bottom: 0.0,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'E',
                  style: TextStyle(
                    fontSize: badgeSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Positioned(
              left: (radarSize - labelWidth) / 2,
              top: radarSize * 0.5 + radarSize * 0.05,
              child: SizedBox(
                width: labelWidth,
                child: Text(
                  'YOU',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: badgeSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
            ...peerLabels,
          ],
        ),
      ),
    );
  }

  Widget _buildGridPeerLabel(
    _RadarBlip blip,
    double radarSize,
    double labelWidth,
    double badgeSize,
  ) {
    final offset = _peerGridOffset(
      Size.square(radarSize),
      blip.bearingDeg,
      blip.fraction,
    );
    final left = clampDouble(
      offset.dx - labelWidth / 2,
      4.0,
      radarSize - labelWidth - 4.0,
    );
    final top = clampDouble(
      offset.dy + radarSize * 0.055,
      4.0,
      radarSize - (badgeSize * 2.8),
    );

    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: labelWidth,
        child: Text(
          blip.callSign,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: badgeSize,
            fontWeight: FontWeight.w700,
            color: blip.color,
            height: 1.25,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Corner controls
  // ---------------------------------------------------------------------
  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final badgeSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);
    final iconSize = clampDouble(screenWidth * 0.04, 15.0, 17.0);
    final hPad = clampDouble(screenWidth * 0.03, 11.0, 16.0);
    final vPad = clampDouble(screenWidth * 0.02, 8.0, 12.0);

    return Material(
      color: active ? AppColors.emeraldMintTint : AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  active ? AppColors.primaryEmerald : AppColors.surfaceBorder,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: active
                    ? AppColors.primaryEmerald
                    : AppColors.textSecondary,
              ),
              SizedBox(width: clampDouble(screenWidth * 0.014, 5.0, 7.0)),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: badgeSize,
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.primaryEmerald : AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeadingChip(
    BuildContext context,
    RadarState state,
    double screenWidth,
  ) {
    final badgeSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);
    final live = state.headingLive;
    final color = live ? AppColors.primaryEmerald : AppColors.textSecondary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: clampDouble(screenWidth * 0.028, 10.0, 14.0),
        vertical: clampDouble(screenWidth * 0.014, 5.0, 8.0),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: clampDouble(screenWidth * 0.02, 7.0, 9.0),
            height: clampDouble(screenWidth * 0.02, 7.0, 9.0),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          SizedBox(width: clampDouble(screenWidth * 0.014, 5.0, 7.0)),
          Flexible(
            child: Text(
              state.headingStatusLabel,
              style: TextStyle(
                fontSize: badgeSize,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Multi-peer roster
  // ---------------------------------------------------------------------
  Widget _buildPeerRoster(
    BuildContext context,
    RadarState state,
    double screenWidth,
  ) {
    final cardRadius = clampDouble(screenWidth * 0.06, 20.0, 26.0);
    final cardPad = clampDouble(screenWidth * 0.05, 18.0, 26.0);
    final sectionSize = clampDouble(screenWidth * 0.042, 15.0, 17.0);
    final titleSize = clampDouble(screenWidth * 0.036, 13.0, 15.0);
    final metaSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);
    final gap = clampDouble(screenWidth * 0.03, 12.0, 16.0);
    final contacts = state.contacts;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.radio,
                  size: clampDouble(screenWidth * 0.05, 19.0, 22.0),
                  color: AppColors.primaryEmerald,
                ),
                SizedBox(width: clampDouble(screenWidth * 0.02, 7.0, 10.0)),
                Expanded(
                  child: Text(
                    'Network Contacts',
                    style: TextStyle(
                      fontSize: sectionSize,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    state.contactCountLabel,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: metaSize,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      height: 1.25,
                    ),
                  ),
                ),              ],
            ),
            SizedBox(height: gap),
            for (var i = 0; i < contacts.length; i++) ...[
              _buildPeerRosterRow(
                contacts[i],
                _blipPalette[i % _blipPalette.length],
                titleSize,
                metaSize,
                screenWidth,
              ),
              if (i != contacts.length - 1) SizedBox(height: gap * 0.7),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeerRosterRow(
    RadarContact contact,
    Color color,
    double titleSize,
    double metaSize,
    double screenWidth,
  ) {
    return Row(
      children: [
        Container(
          width: clampDouble(screenWidth * 0.026, 9.0, 11.0),
          height: clampDouble(screenWidth * 0.026, 9.0, 11.0),
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        SizedBox(width: clampDouble(screenWidth * 0.025, 9.0, 12.0)),
        Expanded(
          child: Text(
            contact.callSign,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
        ),
        SizedBox(width: clampDouble(screenWidth * 0.02, 8.0, 12.0)),
        Flexible(
          child: Text(
            '${contact.distanceLabel} · ${contact.bearingLabel}',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: metaSize,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Coordinates telemetry card
  // ---------------------------------------------------------------------
  Widget _buildCoordinatesCard(
    BuildContext context,
    RadarState state,
    double screenWidth,
  ) {
    final cardRadius = clampDouble(screenWidth * 0.06, 20.0, 26.0);
    final cardPad = clampDouble(screenWidth * 0.05, 18.0, 26.0);
    final sectionSize = clampDouble(screenWidth * 0.042, 15.0, 17.0);
    final gap = clampDouble(screenWidth * 0.03, 12.0, 16.0);

    final GeoLocationEntity? myFix = state.myFix;
    final GeoLocationEntity? peerFix = state.peerFix;
    if (myFix == null || peerFix == null) return const SizedBox.shrink();

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.map,
                  size: clampDouble(screenWidth * 0.05, 19.0, 22.0),
                  color: AppColors.primaryEmerald,
                ),
                SizedBox(width: clampDouble(screenWidth * 0.02, 7.0, 10.0)),
                Expanded(
                  child: Text(
                    'Coordinates',
                    style: TextStyle(
                      fontSize: sectionSize,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: gap),
            _buildFixRow(
              context,
              screenWidth: screenWidth,
              icon: LucideIcons.navigation,
              iconTint: AppColors.primaryEmerald,
              title: 'My Position',
              caption: '${state.myCallSign} · Receiver',
              latitude: myFix.latitude,
              longitude: myFix.longitude,
              chips: [
                (myFix.altitudeLabel, AppColors.textSecondary),
                (myFix.accuracyLabel, AppColors.textSecondary),
              ],
            ),
            SizedBox(height: gap * 0.8),
            _buildDivider(screenWidth),
            SizedBox(height: gap * 0.8),
            _buildFixRow(
              context,
              screenWidth: screenWidth,
              icon: LucideIcons.mapPin,
              iconTint: AppColors.primaryEmeraldVibrant,
              title: 'Sender Position',
              caption: '${state.peerCallSign} · Peer node',
              latitude: peerFix.latitude,
              longitude: peerFix.longitude,
              chips: [
                ('Accuracy ${peerFix.accuracyLabel}', AppColors.primaryEmerald),
                (
                  state.peerFixMock ? 'Seed Frame' : 'Live Packet',
                  AppColors.textSecondary,
                ),
              ],
            ),
            SizedBox(height: gap * 0.8),
            _buildDivider(screenWidth),
            SizedBox(height: gap * 0.8),
            Text(
              'Computed Telemetry',
              style: TextStyle(
                fontSize: clampDouble(screenWidth * 0.030, 11.0, 12.0),
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.4,
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.02, 8.0, 12.0)),
            Wrap(
              spacing: clampDouble(screenWidth * 0.02, 8.0, 12.0),
              runSpacing: clampDouble(screenWidth * 0.02, 8.0, 12.0),
              children: [
                _buildChip(
                  context,
                  'Haversine ${state.distanceLabel}',
                  AppColors.primaryEmerald,
                ),
                _buildChip(
                  context,
                  'Azimuth ${state.bearingLabel}',
                  AppColors.primaryEmerald,
                ),
                _buildChip(context, state.spanLabel, AppColors.textSecondary),
                _buildChip(
                  context,
                  state.headingStatusLabel,
                  AppColors.textSecondary,
                ),
                _buildChip(context, 'IEEE-754 · 8 B', AppColors.textSecondary),
                _buildChip(context, 'CRC-16 Verified', AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixRow(
    BuildContext context, {
    required double screenWidth,
    required IconData icon,
    required Color iconTint,
    required String title,
    required String caption,
    required double latitude,
    required double longitude,
    required List<(String, Color)> chips,
  }) {
    final iconBox = clampDouble(screenWidth * 0.11, 40.0, 48.0);
    final titleSize = clampDouble(screenWidth * 0.038, 14.0, 16.0);
    final metaSize = clampDouble(screenWidth * 0.033, 12.0, 14.0);
    final badgeSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);
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
              color: iconTint.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: Icon(icon, size: iconBox * 0.46, color: iconTint),
        ),
        SizedBox(width: gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: badgeSize,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: clampDouble(screenWidth * 0.012, 4.0, 7.0)),
              Text(
                '${_latitudeLabel(latitude)}, ${_longitudeLabel(longitude)}',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              SizedBox(height: clampDouble(screenWidth * 0.01, 4.0, 6.0)),
              Text(
                caption,
                style: TextStyle(
                  fontSize: metaSize,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              SizedBox(height: clampDouble(screenWidth * 0.02, 8.0, 12.0)),
              Wrap(
                spacing: clampDouble(screenWidth * 0.018, 7.0, 10.0),
                runSpacing: clampDouble(screenWidth * 0.018, 7.0, 10.0),
                children: chips
                    .map((chip) => _buildChip(context, chip.$1, chip.$2))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(double screenWidth) {
    return Container(
      width: double.infinity,
      height: 1.0,
      color: AppColors.surfaceBorder,
      margin: EdgeInsets.symmetric(
        horizontal: clampDouble(screenWidth * 0.005, 2.0, 4.0),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Loading / error states
  // ---------------------------------------------------------------------
  Widget _buildLoadingView(
    BuildContext context,
    double screenWidth,
    double screenHeight,
    double scrollReserve,
  ) {
    final hPad = clampDouble(screenWidth * 0.045, 12.0, 20.0);
    final sectionGap = clampDouble(screenHeight * 0.016, 10.0, 16.0);
    final cardRadius = clampDouble(screenWidth * 0.06, 20.0, 26.0);
    final radarSize = _radarSizeFor(screenWidth, screenHeight);
    final bannerHeight = clampDouble(screenHeight * 0.14, 96.0, 140.0);
    final cardHeight = clampDouble(screenHeight * 0.18, 120.0, 180.0);

    return AnimatedBuilder(
      animation: _blipPulse,
      builder: (context, _) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hPad, sectionGap, hPad, scrollReserve),
          child: Opacity(
            opacity: 0.4 + 0.3 * _blipPulse.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSkeleton(
                  width: double.infinity,
                  height: bannerHeight,
                  radius: cardRadius,
                ),
                SizedBox(height: sectionGap),
                Center(
                  child: _buildSkeleton(
                    width: radarSize,
                    height: radarSize,
                    radius: radarSize / 2,
                  ),
                ),
                SizedBox(height: sectionGap),
                _buildSkeleton(
                  width: double.infinity,
                  height: cardHeight,
                  radius: cardRadius,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeleton({
    required double width,
    required double height,
    required double radius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
      ),
    );
  }

  Widget _buildErrorView(
    BuildContext context,
    RadarState state,
    double screenWidth,
    double screenHeight,
    double scrollReserve,
  ) {
    final hPad = clampDouble(screenWidth * 0.045, 12.0, 20.0);
    final sectionSize = clampDouble(screenWidth * 0.042, 15.0, 17.0);
    final metaSize = clampDouble(screenWidth * 0.033, 12.0, 14.0);
    final gap = clampDouble(screenHeight * 0.02, 10.0, 18.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        hPad,
        clampDouble(screenHeight * 0.05, 24.0, 48.0),
        hPad,
        scrollReserve,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.satellite,
            size: clampDouble(screenWidth * 0.18, 64.0, 96.0),
            color: AppColors.textMuted,
          ),
          SizedBox(height: gap),
          Text(
            'Fix Unavailable',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: sectionSize,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: gap * 0.5),
          Text(
            state.note.isNotEmpty
                ? state.note
                : 'Location services are blocked for this device',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: metaSize,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: gap),
          Material(
            color: AppColors.primaryEmerald,
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => _handleRetry(context),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: clampDouble(screenWidth * 0.06, 22.0, 30.0),
                  vertical: clampDouble(screenWidth * 0.032, 12.0, 16.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.refreshCw,
                      size: clampDouble(screenWidth * 0.04, 15.0, 17.0),
                      color: AppColors.textWhite,
                    ),
                    SizedBox(width: clampDouble(screenWidth * 0.02, 7.0, 10.0)),
                    Flexible(
                      child: Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: clampDouble(screenWidth * 0.038, 14.0, 16.0),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textWhite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Shared atoms
  // ---------------------------------------------------------------------
  Widget _buildStatusBadge(
    BuildContext context, {
    required String label,
    required Color color,
    IconData? icon,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final badgeSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);
    final iconSize = clampDouble(screenWidth * 0.034, 12.0, 14.0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: clampDouble(screenWidth * 0.028, 10.0, 14.0),
        vertical: clampDouble(screenWidth * 0.014, 5.0, 8.0),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: color),
            SizedBox(width: clampDouble(screenWidth * 0.012, 4.0, 6.0)),
          ] else ...[
            Container(
              width: clampDouble(screenWidth * 0.02, 7.0, 9.0),
              height: clampDouble(screenWidth * 0.02, 7.0, 9.0),
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            SizedBox(width: clampDouble(screenWidth * 0.012, 4.0, 6.0)),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: badgeSize,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.3,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, Color color) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final badgeSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: clampDouble(screenWidth * 0.03, 11.0, 15.0),
        vertical: clampDouble(screenWidth * 0.017, 6.0, 9.0),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              softWrap: true,
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
    );
  }
}

// -----------------------------------------------------------------------
// Layout + label helpers
// -----------------------------------------------------------------------

double _radarSizeFor(double screenWidth, double screenHeight) {
  return clampDouble(
    math.min(screenWidth * 0.84, screenHeight * 0.40),
    220.0,
    360.0,
  );
}

String _latitudeLabel(double value) {
  final suffix = value >= 0 ? 'N' : 'S';
  return '${value.abs().toStringAsFixed(4)}\u00B0 $suffix';
}

String _longitudeLabel(double value) {
  final suffix = value >= 0 ? 'E' : 'W';
  return '${value.abs().toStringAsFixed(4)}\u00B0 $suffix';
}

/// Shared peer position used by the grid painter and its text labels.
Offset _peerGridOffset(Size size, double bearingDeg, double fraction) {
  final angle = bearingDeg * math.pi / 180.0;
  final reach = math.min(size.width, size.height) * 0.40 * fraction;
  return Offset(
    size.width / 2 + math.sin(angle) * reach,
    size.height / 2 - math.cos(angle) * reach,
  );
}

// -----------------------------------------------------------------------
// Blip spec shared by both painters
// -----------------------------------------------------------------------
class _RadarBlip {
  const _RadarBlip({
    required this.callSign,
    required this.bearingDeg,
    required this.fraction,
    required this.distanceLabel,
    required this.color,
  });

  final String callSign;
  final double bearingDeg;
  final double fraction;
  final String distanceLabel;
  final Color color;
}

// -----------------------------------------------------------------------
// Compass dial painter (rotates with the magnetometer)
// -----------------------------------------------------------------------
class _CompassDialPainter extends CustomPainter {
  _CompassDialPainter({
    required this.headingDeg,
    required this.blips,
    required this.spanMeters,
    required this.pulse,
    required this.peerLocked,
  });

  final double headingDeg;
  final List<_RadarBlip> blips;
  final double spanMeters;
  final double pulse;
  final bool peerLocked;

  static const List<String> _marks = <String>[
    '0\u00B0 N',
    '45\u00B0',
    '90\u00B0 E',
    '135\u00B0',
    '180\u00B0 S',
    '225\u00B0',
    '270\u00B0 W',
    '315\u00B0',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final outer = shortest / 2;
    final degToRad = math.pi / 180.0;

    final labelPx = clampDouble(outer * 0.10, 11.0, 14.0);
    final labelPainters = <TextPainter>[];
    var maxHalfWidth = 0.0;

    for (var i = 0; i < _marks.length; i++) {
      final color = i == 0
          ? AppColors.primaryEmerald
          : i.isEven
              ? AppColors.textPrimary
              : AppColors.textSecondary;
      final painter = TextPainter(
        text: TextSpan(
          text: _marks[i],
          style: TextStyle(
            fontSize: labelPx,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.0,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainters.add(painter);
      maxHalfWidth = math.max(maxHalfWidth, painter.width / 2);
    }

    final labelRadius = outer - maxHalfWidth - 3.0;
    final tickOuter = labelRadius - maxHalfWidth - 4.0;
    final tickLength = math.max(6.0, shortest * 0.032);
    final discRadius = tickOuter - tickLength - 4.0;
    if (discRadius <= 14.0) return;

    // 1 — radar disc, rim and outer ring.
    canvas.drawCircle(
      center,
      discRadius,
      Paint()..color = AppColors.surfaceSecondary,
    );
    canvas.drawCircle(
      center,
      discRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.surfaceBorder,
    );
    canvas.drawCircle(
      center,
      outer - 1.0,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = AppColors.surfaceBorder.withValues(alpha: 0.7),
    );

    // 2 — range rings at one third and two thirds of the span.
    for (final fraction in const [0.3333333, 0.6666667]) {
      canvas.drawCircle(
        center,
        discRadius * fraction,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = AppColors.surfaceBorder,
      );
    }

    // 3 — heading axis (screen up = where the phone points).
    _dashedLine(
      canvas,
      center,
      Offset(center.dx, center.dy - discRadius + 15.0),
      Paint()
        ..color = AppColors.primaryEmerald.withValues(alpha: 0.35)
        ..strokeWidth = 1.2,
      5.0,
      5.0,
    );

    final pointer = Path()
      ..moveTo(center.dx, center.dy - discRadius + 14.0)
      ..lineTo(center.dx - shortest * 0.03, center.dy - discRadius + 3.0)
      ..lineTo(center.dx + shortest * 0.03, center.dy - discRadius + 3.0)
      ..close();
    canvas.drawPath(pointer, Paint()..color = AppColors.primaryEmerald);

    // 4 — bearing line and glowing blip for every contact.
    if (peerLocked) {
      for (final blipData in blips) {
        final angle = (blipData.bearingDeg - headingDeg) * degToRad;
        final reach = discRadius * blipData.fraction;
        final blip = center +
            Offset(math.sin(angle) * reach, -math.cos(angle) * reach);
        final color = blipData.color;

        _dashedLine(
          canvas,
          center,
          blip,
          Paint()
            ..color = color.withValues(alpha: 0.30)
            ..strokeWidth = 1.4,
          4.0,
          6.0,
        );

        final glow = math.max(11.0, discRadius * 0.18) * (0.88 + 0.24 * pulse);
        canvas.drawCircle(
          blip,
          glow,
          Paint()..color = color.withValues(alpha: 0.10 + 0.05 * pulse),
        );
        canvas.drawCircle(
          blip,
          glow * 0.58,
          Paint()..color = color.withValues(alpha: 0.20 + 0.08 * pulse),
        );
        canvas.drawCircle(
          blip,
          math.max(4.5, discRadius * 0.055),
          Paint()..color = color,
        );
        canvas.drawCircle(
          blip,
          math.max(7.5, discRadius * 0.09),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = color.withValues(alpha: 0.75),
        );
      }
    }

    // 5 — my position marker.
    final meRadius = math.max(4.0, discRadius * 0.055);
    canvas.drawCircle(center, meRadius, Paint()..color = AppColors.background);
    canvas.drawCircle(
      center,
      meRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = AppColors.primaryEmerald,
    );

    // 6 — range labels along the lower axis.
    final ringStyle = TextStyle(
      fontSize: clampDouble(outer * 0.085, 11.0, 12.0),
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
      height: 1.0,
    );
    _paintRingLabel(
      canvas,
      center,
      discRadius / 3,
      GeoMath.formatDistance(spanMeters / 3),
      ringStyle,
    );
    _paintRingLabel(
      canvas,
      center,
      discRadius * 2 / 3,
      GeoMath.formatDistance(spanMeters * 2 / 3),
      ringStyle,
    );

    // 7 — degree ticks rotating with the dial.
    final inner = discRadius + 2.0;
    final minorOuter =
        inner + (tickOuter - inner) * 0.45;
    for (var angle = 0; angle < 360; angle += 5) {
      final screen = (angle - headingDeg) * degToRad;
      final direction = Offset(math.sin(screen), -math.cos(screen));
      final isCardinal = angle % 90 == 0;
      final isMajor = angle % 45 == 0;

      final paint = Paint()
        ..strokeWidth = isCardinal ? 2.0 : (isMajor ? 1.5 : 1.0)
        ..color = isCardinal
            ? AppColors.primaryEmerald.withValues(alpha: 0.9)
            : isMajor
                ? AppColors.textSecondary.withValues(alpha: 0.9)
                : AppColors.textMuted.withValues(alpha: 0.7);

      canvas.drawLine(
        center + direction * inner,
        center + direction * (isMajor ? tickOuter : minorOuter),
        paint,
      );
    }

    // 8 — degree + cardinal labels (positions rotate, glyphs stay upright).
    for (var i = 0; i < labelPainters.length; i++) {
      final screen = (i * 45.0 - headingDeg) * degToRad;
      final position = center +
          Offset(
            math.sin(screen) * labelRadius,
            -math.cos(screen) * labelRadius,
          );
      final painter = labelPainters[i];
      painter.paint(
        canvas,
        position - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  void _paintRingLabel(
    Canvas canvas,
    Offset center,
    double radius,
    String text,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final position = Offset(
      center.dx,
      center.dy + radius + painter.height * 0.7,
    );
    painter.paint(canvas, position - Offset(painter.width / 2, 0));
  }

  void _dashedLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint,
    double dash,
    double gap,
  ) {
    final delta = to - from;
    final total = delta.distance;
    if (total < 0.5 || dash <= 0.0 || gap <= 0.0) return;

    final direction = delta / total;
    var cursor = 0.0;
    while (cursor < total) {
      final end = math.min(cursor + dash, total);
      canvas.drawLine(
        from + direction * cursor,
        from + direction * end,
        paint,
      );
      cursor = end + gap;
    }
  }

  @override
  bool shouldRepaint(_CompassDialPainter old) {
    return old.headingDeg != headingDeg ||
        !_sameBlips(old.blips, blips) ||
        old.spanMeters != spanMeters ||
        old.pulse != pulse ||
        old.peerLocked != peerLocked;
  }
}

bool _sameBlips(List<_RadarBlip> a, List<_RadarBlip> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].callSign != b[i].callSign ||
        a[i].bearingDeg != b[i].bearingDeg ||
        a[i].fraction != b[i].fraction ||
        a[i].color != b[i].color) {
      return false;
    }
  }
  return true;
}

// -----------------------------------------------------------------------
// Offline vector grid painter (north-up)
// -----------------------------------------------------------------------
class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.blips,
    required this.pulse,
    required this.peerLocked,
  });

  final List<_RadarBlip> blips;
  final double pulse;
  final bool peerLocked;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.07;
    final bounds = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    canvas.drawRRect(bounds, Paint()..color = AppColors.surfaceSecondary);

    const divisions = 8;
    final linePaint = Paint()
      ..color = AppColors.surfaceBorder
      ..strokeWidth = 1.0;
    for (var i = 1; i < divisions; i++) {
      final x = size.width * i / divisions;
      final y = size.height * i / divisions;
      canvas.drawLine(Offset(x, 0.0), Offset(x, size.height), linePaint);
      canvas.drawLine(Offset(0.0, y), Offset(size.width, y), linePaint);
    }

    final axisPaint = Paint()
      ..color = AppColors.primaryEmerald.withValues(alpha: 0.16)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(0.0, center.dy),
      Offset(size.width, center.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx, 0.0),
      Offset(center.dx, size.height),
      axisPaint,
    );

    if (peerLocked) {
      for (final blipData in blips) {
        final peer =
            _peerGridOffset(size, blipData.bearingDeg, blipData.fraction);
        final color = blipData.color;

        final linePaintBlink = Paint()
          ..color = color.withValues(alpha: 0.32)
          ..strokeWidth = 1.4;
        _dashed(canvas, center, peer, linePaintBlink, 4.0, 6.0);

        final glow = math.max(11.0, math.min(size.width, size.height) * 0.055) *
            (0.88 + 0.24 * pulse);
        canvas.drawCircle(
          peer,
          glow,
          Paint()..color = color.withValues(alpha: 0.10 + 0.05 * pulse),
        );
        canvas.drawCircle(
          peer,
          glow * 0.58,
          Paint()..color = color.withValues(alpha: 0.20 + 0.08 * pulse),
        );
        canvas.drawCircle(
          peer,
          math.max(4.5, math.min(size.width, size.height) * 0.016),
          Paint()..color = color,
        );
        canvas.drawCircle(
          peer,
          math.max(7.5, math.min(size.width, size.height) * 0.026),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = color.withValues(alpha: 0.75),
        );
      }
    }

    final meRadius = math.max(4.5, math.min(size.width, size.height) * 0.018);
    canvas.drawCircle(center, meRadius, Paint()..color = AppColors.background);
    canvas.drawCircle(
      center,
      meRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = AppColors.primaryEmerald,
    );

    canvas.drawRRect(
      bounds,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.surfaceBorder,
    );
  }

  void _dashed(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint,
    double dash,
    double gap,
  ) {
    final delta = to - from;
    final total = delta.distance;
    if (total < 0.5 || dash <= 0.0 || gap <= 0.0) return;

    final direction = delta / total;
    var cursor = 0.0;
    while (cursor < total) {
      final end = math.min(cursor + dash, total);
      canvas.drawLine(
        from + direction * cursor,
        from + direction * end,
        paint,
      );
      cursor = end + gap;
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) {
    return !_sameBlips(old.blips, blips) ||
        old.pulse != pulse ||
        old.peerLocked != peerLocked;
  }
}
