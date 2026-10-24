import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';
import '../blocs/receiver/receiver_bloc.dart';
import '../blocs/receiver/receiver_event.dart';
import '../blocs/receiver/receiver_state.dart';

/// Screen 6 — Receiver / Base-Station monitor.
///
/// Listens on the shared radio bus, verifies magic bytes + CRC-16, inflates
/// the zlib payload and speaks every message through Piper (or system TTS).
/// Quick replies still go back as a 6-byte ACK frame through the bloc; the
/// vector/pipeline/quick-reply panels are intentionally not rendered here.
/// Every label on this screen is short enough to render in full — text wraps
/// instead of truncating, on any phone size.
///
/// The surface is hosted inside the unified comms hub, so it renders as a
/// scrollable panel next to the sender surface.
class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen>
    with SingleTickerProviderStateMixin {
  ReceiverBloc? _localBloc;
  late ReceiverBloc _receiverBloc;
  bool _blocBound = false;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_blocBound) return;
    _blocBound = true;

    ReceiverBloc? sharedBloc;
    try {
      sharedBloc = context.read<ReceiverBloc>();
    } catch (_) {
      sharedBloc = null;
    }
    _receiverBloc = sharedBloc ?? (_localBloc ??= ReceiverBloc());
    if (_localBloc != null) {
      _receiverBloc.add(const ReceiverStarted());
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _localBloc?.close();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Build — the panel is hosted by the unified comms hub, so it only owns
  // its own scroll surface and header row.
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final screenWidth = size.width;
    final screenHeight = size.height;
    final hPad = AppSpacing.gutter(screenWidth);
    final sectionGap = AppSpacing.section(screenHeight);

    return BlocProvider.value(
      value: _receiverBloc,
      child: BlocConsumer<ReceiverBloc, ReceiverState>(
        listenWhen: (prev, curr) =>
            curr.messages.length > prev.messages.length,
        listener: (_, _) => HapticFeedback.mediumImpact(),
        builder: (context, state) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              hPad,
              sectionGap * 0.5,
              hPad,
              sectionGap,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPanelHeader(screenWidth, state),
                SizedBox(height: sectionGap),
                _buildBody(
                  state,
                  screenWidth,
                  screenHeight,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Panel header — surface identity + live listen pill (nothing ellipsises)
  // ---------------------------------------------------------------------
  Widget _buildPanelHeader(double screenWidth, ReceiverState state) {
    final headerSize = AppType.section(screenWidth);
    final metaSize = AppType.meta(screenWidth);
    final badgeSize = AppType.badge(screenWidth);
    final iconBox = clampDouble(screenWidth * 0.10, 36.0, 44.0);
    final gap = clampDouble(screenWidth * 0.025, 8.0, 12.0);
    final radius = clampDouble(screenWidth * 0.035, 12.0, 16.0);
    final dotSize = clampDouble(screenWidth * 0.018, 6.0, 8.0);

    final live = state.listening;
    final statusColor = live ? AppColors.primaryEmerald : AppColors.textSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: iconBox,
          height: iconBox,
          decoration: BoxDecoration(
            color: AppColors.emeraldMintTint,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: AppColors.emeraldMintBorder,
              width: 1.0,
            ),
          ),
          child: Icon(
            LucideIcons.headphones,
            size: iconBox * 0.48,
            color: AppColors.primaryEmerald,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Receiver',
                style: TextStyle(
                  fontSize: headerSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.15,
                ),
              ),
              SizedBox(height: clampDouble(screenWidth * 0.008, 3.0, 5.0)),
              Text(
                'Listen · Track · Reply',
                style: TextStyle(
                  fontSize: metaSize,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: gap),
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: clampDouble(screenWidth * 0.025, 8.0, 14.0),
              vertical: clampDouble(screenWidth * 0.014, 5.0, 8.0),
            ),
            decoration: BoxDecoration(
              color: live ? AppColors.emeraldMintTint : AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: live
                    ? AppColors.emeraldMintBorder
                    : AppColors.surfaceBorder,
                width: 1.0,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.55),
                          blurRadius: 8.0,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: clampDouble(screenWidth * 0.012, 4.0, 6.0)),
                  Text(
                    state.listeningLabel,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: badgeSize,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Body — 4-state lifecycle
  // ---------------------------------------------------------------------
  Widget _buildBody(
    ReceiverState state,
    double screenWidth,
    double screenHeight,
  ) {
    switch (state.status) {
      case ReceiverStatus.initial:
      case ReceiverStatus.loading:
        return _buildLoading(screenWidth, screenHeight);
      case ReceiverStatus.error:
        return _buildError(screenWidth, state);
      case ReceiverStatus.loaded:
        return _buildQueueSection(screenWidth, state);
    }
  }

  // ---------------------------------------------------------------------
  // Loading skeleton (pulsing)
  // ---------------------------------------------------------------------
  Widget _buildLoading(double screenWidth, double screenHeight) {
    final cardRadius = clampDouble(screenWidth * 0.06, 20.0, 26.0);
    final cardPad = clampDouble(screenWidth * 0.05, 18.0, 26.0);
    final metaSize = clampDouble(screenWidth * 0.033, 12.0, 14.0);
    final barHeight = clampDouble(screenHeight * 0.03, 16.0, 26.0);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final opacity = 0.35 + 0.35 * _pulse.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
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
                  Opacity(
                    opacity: opacity,
                    child: Container(
                      width: double.infinity,
                      height: clampDouble(screenHeight * 0.06, 40.0, 64.0),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                    ),
                  ),
                  SizedBox(height: cardPad * 0.6),
                  Opacity(
                    opacity: opacity,
                    child: Container(
                      width: double.infinity,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: sectionGapFor(screenWidth)),
            Opacity(
              opacity: opacity,
              child: Container(
                width: double.infinity,
                height: clampDouble(screenHeight * 0.12, 90.0, 150.0),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(cardRadius),
                  border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
                ),
              ),
            ),
            SizedBox(height: sectionGapFor(screenWidth)),
            Text(
              'Binding UDP 45454 — locking GPS fix',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: metaSize,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );
      },
    );
  }

  double sectionGapFor(double screenWidth) =>
      clampDouble(screenWidth * 0.035, 12.0, 18.0);

  // ---------------------------------------------------------------------
  // Error / retry
  // ---------------------------------------------------------------------
  Widget _buildError(double screenWidth, ReceiverState state) {
    final cardRadius = clampDouble(screenWidth * 0.06, 20.0, 26.0);
    final cardPad = clampDouble(screenWidth * 0.05, 18.0, 26.0);
    final sectionSize = clampDouble(screenWidth * 0.042, 15.0, 17.0);
    final metaSize = clampDouble(screenWidth * 0.033, 12.0, 14.0);

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPad),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(
            color: AppColors.alertRed.withValues(alpha: 0.5),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.alertTriangle,
                  size: clampDouble(screenWidth * 0.05, 20.0, 24.0),
                  color: AppColors.alertRed,
                ),
                SizedBox(width: clampDouble(screenWidth * 0.02, 8.0, 12.0)),
                Expanded(
                  child: Text(
                    'Radio Offline',
                    style: TextStyle(
                      fontSize: sectionSize,
                      fontWeight: FontWeight.w700,
                      color: AppColors.alertRed,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: clampDouble(screenWidth * 0.025, 10.0, 14.0)),
            Text(
              state.note.isEmpty
                  ? 'Radio bus unavailable — retry to reopen the socket'
                  : state.note,
              style: TextStyle(
                fontSize: metaSize,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.04, 14.0, 20.0)),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: AppColors.primaryEmerald,
                borderRadius: BorderRadius.circular(999),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _receiverBloc.add(const ReceiverStarted());
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: clampDouble(screenWidth * 0.035, 12.0, 18.0),
                    ),
                    child: Text(
                      'Retry Bind',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: clampDouble(screenWidth * 0.036, 13.0, 15.0),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textWhite,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ---------------------------------------------------------------------
  // Replay queue
  // ---------------------------------------------------------------------
  Widget _buildQueueSection(double screenWidth, ReceiverState state) {
    final sectionSize = clampDouble(screenWidth * 0.042, 15.0, 17.0);
    final badgeSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);
    final gap = clampDouble(screenWidth * 0.025, 10.0, 14.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.scrollText,
              size: clampDouble(screenWidth * 0.045, 17.0, 20.0),
              color: AppColors.primaryEmerald,
            ),
            SizedBox(width: clampDouble(screenWidth * 0.02, 7.0, 10.0)),
            Expanded(
              child: Text(
                'Replay Queue',
                style: TextStyle(
                  fontSize: sectionSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (state.messages.isNotEmpty)
              Flexible(
                child: Text(
                  '${state.queueCount} Saved',
                  style: TextStyle(
                    fontSize: badgeSize,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: gap),
        if (state.messages.isEmpty)
          _buildEmptyState(screenWidth)
        else
          ...state.messages.map(
            (message) => Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: _buildMessageCard(screenWidth, state, message),
            ),
          ),
        if (state.messages.isNotEmpty) ...[
          SizedBox(height: clampDouble(screenWidth * 0.01, 4.0, 8.0)),
          Material(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _receiverBloc.add(ReceiverHistoryCleared());
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: clampDouble(screenWidth * 0.03, 12.0, 16.0),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
                ),
                child: Text(
                  'Clear Queue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: clampDouble(screenWidth * 0.033, 12.0, 14.0),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(double screenWidth) {
    final cardRadius = clampDouble(screenWidth * 0.06, 20.0, 26.0);
    final cardPad = clampDouble(screenWidth * 0.05, 18.0, 26.0);
    final sectionSize = clampDouble(screenWidth * 0.042, 15.0, 17.0);
    final metaSize = clampDouble(screenWidth * 0.033, 12.0, 14.0);

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
          children: [
            Icon(
              LucideIcons.headphones,
              size: clampDouble(screenWidth * 0.12, 36.0, 48.0),
              color: AppColors.textMuted,
            ),
            SizedBox(height: clampDouble(screenWidth * 0.03, 12.0, 16.0)),
            Text(
              'No Traffic Yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: sectionSize,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.018, 6.0, 10.0)),
            Text(
              'Sender packets decode here automatically — magic, CRC and zlib all verified.',
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

  Widget _buildMessageCard(
    double screenWidth,
    ReceiverState state,
    ReceivedMessage message,
  ) {
    final cardRadius = clampDouble(screenWidth * 0.06, 20.0, 26.0);
    final cardPad = clampDouble(screenWidth * 0.05, 18.0, 26.0);
    final iconBox = clampDouble(screenWidth * 0.11, 42.0, 54.0);
    final titleSize = clampDouble(screenWidth * 0.038, 14.0, 16.0);
    final bodySize = clampDouble(screenWidth * 0.038, 14.0, 16.0);
    final badgeSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);
    final chipGap = clampDouble(screenWidth * 0.02, 8.0, 12.0);

    final playing = state.playingId == message.id;

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPad),
        decoration: BoxDecoration(
          color: message.isSos ? AppColors.alertRedBg : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(
            color: message.isSos
                ? AppColors.alertRedBorder
                : AppColors.surfaceBorderSubtle,
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: message.isSos
                        ? AppColors.alertBtnBg
                        : AppColors.emeraldAvatarBg,
                    borderRadius: BorderRadius.circular(
                      clampDouble(screenWidth * 0.03, 12.0, 16.0),
                    ),
                    border: Border.all(
                      color: message.isSos
                          ? AppColors.alertBtnBorder
                          : AppColors.emeraldMintBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    message.isSos ? LucideIcons.siren : LucideIcons.radio,
                    size: iconBox * 0.46,
                    color: message.isSos
                        ? AppColors.alertRed
                        : AppColors.primaryEmerald,
                  ),
                ),
                SizedBox(width: clampDouble(screenWidth * 0.03, 12.0, 16.0)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: chipGap,
                        runSpacing: clampDouble(screenWidth * 0.012, 4.0, 7.0),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            message.callSign,
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (message.isSos)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: clampDouble(screenWidth * 0.02, 7.0, 12.0),
                                vertical: clampDouble(screenWidth * 0.008, 3.0, 5.0),
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.alertRed,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'SOS',
                                style: TextStyle(
                                  fontSize: badgeSize,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textWhite,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: clampDouble(screenWidth * 0.018, 6.0, 10.0)),
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: bodySize,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: cardPad * 0.55),
            Wrap(
              spacing: chipGap,
              runSpacing: chipGap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildChip(
                  screenWidth,
                  LucideIcons.clock,
                  DateFormat('HH:mm:ss').format(message.receivedAt),
                  AppColors.textMuted,
                ),
                _buildChip(
                  screenWidth,
                  LucideIcons.hash,
                  'Seq ${message.seq}',
                  AppColors.textMuted,
                ),
                if (message.distanceLabel != null)
                  _buildChip(
                    screenWidth,
                    LucideIcons.mapPin,
                    '${message.distanceLabel} ${message.directionLabel ?? ""}'
                        .trim(),
                    AppColors.primaryEmeraldVibrant,
                  ),
                _buildReplayChip(screenWidth, message, playing),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplayChip(
    double screenWidth,
    ReceivedMessage message,
    bool playing,
  ) {
    final badgeSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);
    final iconSize = clampDouble(screenWidth * 0.036, 13.0, 16.0);

    return Material(
      color: playing ? AppColors.primaryEmerald : AppColors.emeraldAvatarBg,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          HapticFeedback.lightImpact();
          if (playing) {
            _receiverBloc.add(const ReceiverPlaybackStopped());
          } else {
            _receiverBloc.add(ReceiverSpeakRequested(message.id));
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: clampDouble(screenWidth * 0.028, 10.0, 16.0),
            vertical: clampDouble(screenWidth * 0.014, 5.0, 9.0),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: playing
                  ? AppColors.primaryEmerald
                  : AppColors.emeraldMintBorder,
              width: 1.0,
            ),
          ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              playing ? LucideIcons.square : LucideIcons.play,
              size: iconSize,
              color: playing ? AppColors.textWhite : AppColors.primaryEmerald,
            ),
            SizedBox(width: clampDouble(screenWidth * 0.012, 4.0, 6.0)),
            Text(
              playing ? 'Stop' : 'Play',
              softWrap: false,
              style: TextStyle(
                fontSize: badgeSize,
                fontWeight: FontWeight.w700,
                color: playing ? AppColors.textWhite : AppColors.primaryEmerald,
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildChip(
    double screenWidth,
    IconData icon,
    String label,
    Color color,
  ) {
    final badgeSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);
    final iconSize = clampDouble(screenWidth * 0.034, 12.0, 15.0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: clampDouble(screenWidth * 0.025, 8.0, 14.0),
        vertical: clampDouble(screenWidth * 0.014, 5.0, 8.0),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: color),
            SizedBox(width: clampDouble(screenWidth * 0.012, 4.0, 6.0)),
            Text(
              label,
              softWrap: false,
              style: TextStyle(
                fontSize: badgeSize,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
