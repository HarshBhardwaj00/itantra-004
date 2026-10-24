import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';
import '../../data/models/comms_entry.dart';
import '../../services/audio/audio_player_service.dart';
import '../../services/speech/tts_service.dart';
import '../blocs/comms/comms_log_bloc.dart';
import '../blocs/comms/comms_log_event.dart';
import '../blocs/comms/comms_log_state.dart';
import '../widgets/tactical_dock.dart';

/// Screen 4 â€” Comms Log & Store-Retry Queue.
///
/// Transmission history with Stop-and-Wait ARQ acknowledgement tracking,
/// DTN store-and-forward queue inspection, on-demand Piper Hindi TTS
/// replay and a force-retransmit escape hatch for stuck packets.
class CommsLogScreen extends StatefulWidget {
  const CommsLogScreen({super.key});

  @override
  State<CommsLogScreen> createState() => _CommsLogScreenState();
}

class _CommsLogScreenState extends State<CommsLogScreen> {
  late final CommsLogBloc _bloc;
  late final TtsService _tts;
  late final AudioPlayerService _player;
  final TextEditingController _composeController = TextEditingController();

  bool _ttsChecked = false;
  bool _ttsReady = false;
  int? _playingSeq;
  Timer? _stopGuard;

  /// Semantic amber for the "queued / retrying" state â€” the shared palette
  /// owns brand colors; this is a status-only accent used sparingly.
  static const Color _queuedAmber = Color(0xFFE8B923);

  @override
  void initState() {
    super.initState();
    _bloc = CommsLogBloc()..add(const CommsLogFetch());
    _tts = TtsService();
    _player = AudioPlayerService();
  }

  @override
  void dispose() {
    _stopGuard?.cancel();
    _composeController.dispose();
    _bloc.close();
    unawaited(_player.dispose());
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Speaker replay â€” offline Piper Hindi TTS on demand
  // ---------------------------------------------------------------------
  Future<void> _handleSpeakerTap(CommsEntry entry) async {
    HapticFeedback.lightImpact();

    if (_playingSeq == entry.seqNo) {
      await _player.stop();
      _stopGuard?.cancel();
      if (mounted) setState(() => _playingSeq = null);
      return;
    }

    if (!_ttsChecked) {
      _ttsChecked = true;
      _ttsReady = await _tts.init();
    }

    if (!_ttsReady) {
      _flashNote('Hindi voice pack offline â€” replay unavailable');
      return;
    }

    if (!mounted) return;
    setState(() => _playingSeq = entry.seqNo);

    final path = await _tts.synthesizeToFile(entry.text);
    if (!mounted) return;

    if (path == null) {
      setState(() => _playingSeq = null);
      _flashNote('Voice synthesis failed â€” try again');
      return;
    }

    await _player.playFile(path);
    if (!mounted) return;

    _stopGuard?.cancel();
    _stopGuard = Timer(const Duration(seconds: 14), () {
      if (mounted && _playingSeq == entry.seqNo) {
        setState(() => _playingSeq = null);
      }
    });
    unawaited(_player.onComplete.first.then((_) {
      _stopGuard?.cancel();
      if (mounted && _playingSeq == entry.seqNo) {
        setState(() => _playingSeq = null);
      }
    }));
  }

  void _flashNote(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppColors.surfaceSecondary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2200),
      ));
  }

  // ---------------------------------------------------------------------
  // Force-retry dialog â€” bypasses the ARQ backoff window
  // ---------------------------------------------------------------------
  Future<void> _showForceRetryDialog(CommsEntry entry) async {
    HapticFeedback.lightImpact();

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final w = MediaQuery.sizeOf(dialogContext).width;
        final hPad = clampDouble(w * 0.06, 18.0, 26.0);
        final titleSize = clampDouble(w * 0.042, 15.0, 17.0);
        final bodySize = clampDouble(w * 0.033, 12.0, 14.0);
        final badgeSize = clampDouble(w * 0.030, 11.0, 12.0);

        return AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(clampDouble(w * 0.055, 18.0, 24.0)),
            side: const BorderSide(color: AppColors.surfaceBorder, width: 1.0),
          ),
          title: Row(
            children: [
              Icon(
                LucideIcons.wifiOff,
                size: clampDouble(w * 0.05, 18.0, 22.0),
                color: _queuedAmber,
              ),
              SizedBox(width: clampDouble(w * 0.02, 7.0, 10.0)),
              Expanded(
                child: Text(
                  'Link Down',
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Packet ${entry.seqHex} retried ${entry.retryCount} times. '
            'Force retry now?',
            style: TextStyle(
              fontSize: bodySize,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          actionsPadding: EdgeInsets.fromLTRB(
            hPad,
            0.0,
            hPad,
            clampDouble(w * 0.04, 14.0, 20.0),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: _dialogButton(
                    context: dialogContext,
                    label: 'Wait',
                    icon: LucideIcons.clock,
                    filled: false,
                    onTap: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                SizedBox(width: clampDouble(w * 0.03, 10.0, 14.0)),
                Expanded(
                  child: _dialogButton(
                    context: dialogContext,
                    label: 'Retry Now',
                    icon: LucideIcons.send,
                    filled: true,
                    badgeSize: badgeSize,
                    onTap: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (proceed == true && mounted) {
      _bloc.add(CommsLogForceRetry(entry.seqNo));
    }
  }

  Widget _dialogButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
    double? badgeSize,
  }) {
    final w = MediaQuery.sizeOf(context).width;
    final textSize = badgeSize ?? clampDouble(w * 0.034, 12.0, 14.0);

    return Material(
      color: filled ? AppColors.primaryEmerald : AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: clampDouble(w * 0.035, 12.0, 18.0),
            vertical: clampDouble(w * 0.028, 10.0, 14.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: clampDouble(w * 0.036, 13.0, 15.0),
                color: filled ? AppColors.textWhite : AppColors.textSecondary,
              ),
              SizedBox(width: clampDouble(w * 0.014, 5.0, 7.0)),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: textSize,
                    fontWeight: FontWeight.w700,
                    color: filled
                        ? AppColors.textWhite
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Compose sheet â€” keyboard-safe "add record" form
  // ---------------------------------------------------------------------
  Future<void> _openComposer() async {
    HapticFeedback.lightImpact();
    _composeController.clear();

    var markSos = false;

    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (builderCtx, setSheetState) {
            final mq = MediaQuery.of(sheetContext);
            final w = mq.size.width;
            final h = mq.size.height;
            final viewInsets = mq.viewInsets.bottom;
            final sheetPad = clampDouble(w * 0.05, 18.0, 24.0);
            final titleSize = clampDouble(w * 0.042, 15.0, 17.0);
            final metaSize = clampDouble(w * 0.033, 12.0, 14.0);
            final badgeSize = clampDouble(w * 0.030, 11.0, 12.0);
            final maxSheetHeight = h - viewInsets - mq.padding.top - 24.0;

            return Padding(
              padding: EdgeInsets.only(bottom: viewInsets),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxSheetHeight),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(clampDouble(w * 0.06, 20.0, 28.0)),
                    ),
                    border: const Border(
                      top: BorderSide(color: AppColors.surfaceBorder, width: 1.0),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    sheetPad,
                    sheetPad * 0.6,
                    sheetPad,
                    sheetPad +
                        (mq.padding.bottom == 0 ? 12.0 : mq.padding.bottom),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: clampDouble(w * 0.1, 36.0, 44.0),
                          height: 4.0,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBorder,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      SizedBox(height: clampDouble(w * 0.035, 12.0, 16.0)),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.pencil,
                            size: clampDouble(w * 0.045, 17.0, 20.0),
                            color: AppColors.primaryEmerald,
                          ),
                          SizedBox(width: clampDouble(w * 0.02, 7.0, 10.0)),
                          Expanded(
                            child: Text(
                              'New Packet',
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Material(
                            color: AppColors.surfaceSecondary,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => Navigator.of(sheetContext).pop(false),
                              child: Padding(
                                padding: EdgeInsets.all(clampDouble(w * 0.02, 7.0, 10.0)),
                                child: Icon(
                                  LucideIcons.x,
                                  size: clampDouble(w * 0.04, 15.0, 18.0),
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: clampDouble(w * 0.025, 9.0, 12.0)),
                      Text(
                        'Text is framed, CRC tagged and sent.',
                        style: TextStyle(
                          fontSize: metaSize,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: clampDouble(w * 0.035, 12.0, 16.0)),
                      TextField(
                        controller: _composeController,
                        // Grows with the text â€” a long packet is never clipped.
                        maxLines: null,
                        minLines: 3,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: clampDouble(w * 0.038, 14.0, 16.0),
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          height: 1.45,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Type the message text',
                        ),
                      ),
                      SizedBox(height: clampDouble(w * 0.03, 10.0, 14.0)),
                      Wrap(
                        spacing: clampDouble(w * 0.02, 8.0, 12.0),
                        runSpacing: clampDouble(w * 0.02, 8.0, 12.0),
                        children: [
                          _composeChip(
                            context: sheetContext,
                            icon: LucideIcons.siren,
                            label: markSos ? 'SOS Flag On' : 'SOS Flag Off',
                            active: markSos,
                            badgeSize: badgeSize,
                            onTap: () =>
                                setSheetState(() => markSos = !markSos),
                          ),
                          _composeChip(
                            context: sheetContext,
                            icon: LucideIcons.shieldCheck,
                            label: 'CRC-16 Auto',
                            active: false,
                            badgeSize: badgeSize,
                            onTap: () {},
                          ),
                          _composeChip(
                            context: sheetContext,
                            icon: LucideIcons.database,
                            label: 'Queue If Down',
                            active: false,
                            badgeSize: badgeSize,
                            onTap: () {},
                          ),
                        ],
                      ),
                      SizedBox(height: clampDouble(w * 0.04, 14.0, 20.0)),
                      Row(
                        children: [
                          Expanded(
                            child: _dialogButton(
                              context: sheetContext,
                              label: 'Draft',
                              icon: LucideIcons.archive,
                              filled: false,
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(false),
                            ),
                          ),
                          SizedBox(width: clampDouble(w * 0.03, 10.0, 14.0)),
                          Expanded(
                            child: _dialogButton(
                              context: sheetContext,
                              label: 'Send',
                              icon: LucideIcons.send,
                              filled: true,
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ),
              ),
            );
          },
        );
      },
    );

    if (sent == true && mounted) {
      final text = _composeController.text.trim();
      if (text.isEmpty) {
        _flashNote('Empty packet discarded');
      } else {
        _bloc.add(CommsLogSendText(text: text, isSos: false));
      }
    }
    _composeController.clear();
  }

  Widget _composeChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool active,
    required double badgeSize,
    required VoidCallback onTap,
  }) {
    final w = MediaQuery.sizeOf(context).width;
    final color = active ? AppColors.primaryEmerald : AppColors.textSecondary;

    return Material(
      color: active ? AppColors.emeraldMintTint : AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: clampDouble(w * 0.03, 11.0, 15.0),
            vertical: clampDouble(w * 0.017, 6.0, 9.0),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: clampDouble(w * 0.034, 12.0, 14.0), color: color),
              SizedBox(width: clampDouble(w * 0.014, 5.0, 7.0)),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: badgeSize,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

    return BlocProvider<CommsLogBloc>.value(
      value: _bloc,
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
                    child: BlocBuilder<CommsLogBloc, CommsLogState>(
                      builder: (context, state) {
                        switch (state.status) {
                          case CommsLogStatus.initial:
                          case CommsLogStatus.loading:
                            return _buildLoadingView(
                              context,
                              screenWidth,
                              screenHeight,
                              scrollReserve,
                            );
                          case CommsLogStatus.error:
                            return _buildErrorView(
                              context,
                              state,
                              screenWidth,
                              scrollReserve,
                            );
                          case CommsLogStatus.loaded:
                            return _buildBody(
                              context,
                              state,
                              screenWidth,
                              screenHeight,
                              hPad,
                              sectionGap,
                              scrollReserve,
                            );
                        }
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
                  active: DockDestination.logs,
                  onSelect: _handleDockSelect,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDockSelect(DockDestination destination) {
    if (destination == DockDestination.logs) return;
    context.goToDock(destination);
  }

  // ---------------------------------------------------------------------
  // Header â€” back, title, compose
  // ---------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, double screenWidth) {
    final headerSize = clampDouble(screenWidth * 0.052, 18.0, 22.0);
    final iconButton = clampDouble(screenWidth * 0.11, 40.0, 46.0);

    return Row(
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).maybePop();
            },
            child: Padding(
              padding:
                  EdgeInsets.all(clampDouble(screenWidth * 0.016, 6.0, 9.0)),
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
            'Comms Log',
            style: TextStyle(
              fontSize: headerSize,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
        ),
        SizedBox(width: clampDouble(screenWidth * 0.02, 8.0, 12.0)),
        Material(
          color: AppColors.emeraldMintTint,
          shape: CircleBorder(
            side: BorderSide(
              color: AppColors.emeraldMintBorder,
              width: 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _openComposer,
            child: SizedBox(
              width: iconButton,
              height: iconButton,
              child: Icon(
                LucideIcons.plus,
                size: clampDouble(screenWidth * 0.05, 19.0, 22.0),
                color: AppColors.primaryEmerald,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Loaded body
  // ---------------------------------------------------------------------
  Widget _buildBody(
    BuildContext context,
    CommsLogState state,
    double screenWidth,
    double screenHeight,
    double hPad,
    double sectionGap,
    double scrollReserve,
  ) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final visible = state.visibleEntries;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        top: sectionGap,
        left: hPad,
        right: hPad,
        bottom: scrollReserve + (bottomInset == 0 ? 16.0 : bottomInset),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RepaintBoundary(
            child: _SummaryBar(state: state, screenWidth: screenWidth),
          ),
          SizedBox(height: sectionGap),
          _buildFilterPills(context, state, screenWidth),
          SizedBox(height: sectionGap),
          _buildSectionTitle(context, state, screenWidth),
          SizedBox(height: sectionGap * 0.7),
          if (visible.isEmpty)
            _buildEmptyTimeline(context, state, screenWidth, screenHeight)
          else
            RepaintBoundary(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    _buildTicketCard(
                      context,
                      visible[i],
                      screenWidth,
                      state,
                    ),
                    if (i != visible.length - 1)
                      SizedBox(
                          height: clampDouble(screenWidth * 0.028, 10.0, 14.0)),
                  ],
                ],
              ),
            ),
          SizedBox(height: sectionGap),
          _buildClearDeliveredButton(context, screenWidth),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Summary bar â€” Sent | ACK | Queued | Saved
  // ---------------------------------------------------------------------
  Widget _buildSectionTitle(
    BuildContext context,
    CommsLogState state,
    double screenWidth,
  ) {
    final sectionSize = clampDouble(screenWidth * 0.042, 15.0, 17.0);
    final badgeSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);
    final count = state.visibleEntries.length;

    return Row(
      children: [
        Icon(
          LucideIcons.scrollText,
          size: clampDouble(screenWidth * 0.045, 17.0, 20.0),
          color: AppColors.primaryEmerald,
        ),
        SizedBox(width: clampDouble(screenWidth * 0.02, 7.0, 10.0)),
        Expanded(
          child: Text(
            'Timeline',
            style: TextStyle(
              fontSize: sectionSize,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: clampDouble(screenWidth * 0.028, 10.0, 14.0),
              vertical: clampDouble(screenWidth * 0.014, 5.0, 8.0),
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
            ),
            child: Text(
              '$count Packet${count == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: badgeSize,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.25,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Filter pills â€” All Â· SOS Â· Pending
  // ---------------------------------------------------------------------
  Widget _buildFilterPills(
    BuildContext context,
    CommsLogState state,
    double screenWidth,
  ) {
    final items = <(CommsFilter, String, int)>[
      (CommsFilter.all, 'All', state.totalSent),
      (CommsFilter.sosOnly, 'SOS Only', state.sosCount),
      (CommsFilter.pending, 'Pending', state.queuedCount),
    ];

    final badgeSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);
    final pillPad = clampDouble(screenWidth * 0.032, 12.0, 17.0);
    final pillGap = clampDouble(screenWidth * 0.02, 8.0, 12.0);

    return Wrap(
      spacing: pillGap,
      runSpacing: pillGap,
      children: items.map((item) {
        final (filter, label, count) = item;
        final active = state.filter == filter;
        final tint = filter == CommsFilter.sosOnly && !active
            ? AppColors.alertRed
            : AppColors.textSecondary;

        return Material(
          color: active ? AppColors.primaryEmerald : AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              HapticFeedback.lightImpact();
              _bloc.add(CommsLogFilterChanged(filter));
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: pillPad,
                vertical: clampDouble(screenWidth * 0.02, 8.0, 12.0),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active
                      ? AppColors.primaryEmerald
                      : (filter == CommsFilter.sosOnly
                          ? AppColors.alertRed.withValues(alpha: 0.4)
                          : AppColors.surfaceBorder),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: badgeSize,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? AppColors.textWhite
                            : (filter == CommsFilter.sosOnly
                                ? AppColors.alertRed
                                : AppColors.textPrimary),
                      ),
                    ),
                  ),
                  SizedBox(width: clampDouble(screenWidth * 0.014, 5.0, 7.0)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: clampDouble(screenWidth * 0.016, 6.0, 8.0),
                      vertical: 2.0,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.textWhite.withValues(alpha: 0.14)
                          : AppColors.surfaceBorder.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: badgeSize,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? AppColors.textWhite
                            : (filter == CommsFilter.sosOnly
                                ? AppColors.alertRed
                                : tint),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------
  // Ticket card â€” call-sign, timestamp, text, status, bytes, speaker
  // ---------------------------------------------------------------------
  Widget _buildTicketCard(
    BuildContext context,
    CommsEntry entry,
    double screenWidth,
    CommsLogState state,
  ) {
    final cardRadius = clampDouble(screenWidth * 0.06, 20.0, 26.0);
    final cardPad = clampDouble(screenWidth * 0.05, 18.0, 26.0);
    final titleSize = clampDouble(screenWidth * 0.038, 14.0, 16.0);
    final bodySize = clampDouble(screenWidth * 0.036, 13.0, 15.0);
    final metaSize = clampDouble(screenWidth * 0.033, 12.0, 14.0);
    final chipGap = clampDouble(screenWidth * 0.02, 8.0, 12.0);
    final speakerSize = clampDouble(screenWidth * 0.115, 42.0, 52.0);

    final isQueued = entry.status == PacketStatus.queued;
    final isPlaying = _playingSeq == entry.seqNo;

    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(cardRadius),
        onTap: isQueued ? () => _showForceRetryDialog(entry) : null,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(cardPad),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(
              color: entry.isSos
                  ? AppColors.alertRed.withValues(alpha: 0.45)
                  : (isQueued
                      ? _queuedAmber.withValues(alpha: 0.35)
                      : AppColors.surfaceBorder),
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.callSign,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                  SizedBox(width: chipGap),
                  Flexible(
                    child: Text(
                      _timeLabel(entry.timestamp),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: metaSize,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: clampDouble(screenWidth * 0.028, 10.0, 14.0)),
              Text(
                entry.text,
                style: TextStyle(
                  fontSize: bodySize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
              SizedBox(height: clampDouble(screenWidth * 0.03, 11.0, 15.0)),
              Wrap(
                spacing: chipGap,
                runSpacing: chipGap,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _statusBadge(context, entry, screenWidth),
                  if (entry.isSos)
                    _metaChip(
                      context,
                      icon: LucideIcons.siren,
                      label: 'SOS 0x02',
                      color: AppColors.alertRed,
                      screenWidth: screenWidth,
                    ),
                  _metaChip(
                    context,
                    icon: LucideIcons.hash,
                    label: entry.seqHex,
                    color: AppColors.textSecondary,
                    screenWidth: screenWidth,
                  ),
                  _metaChip(
                    context,
                    icon: LucideIcons.arrowRightLeft,
                    label:
                        '${_byteLabel(entry.originalBytes)} to ${_byteLabel(entry.sentBytes)}',
                    color: AppColors.primaryEmeraldVibrant,
                    screenWidth: screenWidth,
                  ),
                ],
              ),
              if (isQueued) ...[
                SizedBox(height: clampDouble(screenWidth * 0.024, 9.0, 12.0)),
                Text(
                  'Tap to force retry now',
                  style: TextStyle(
                    fontSize: metaSize,
                    fontWeight: FontWeight.w400,
                    color: _queuedAmber,
                    height: 1.35,
                  ),
                ),
              ],
              SizedBox(height: clampDouble(screenWidth * 0.028, 10.0, 14.0)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.isMock ? 'Demo seed frame' : 'Live frame',
                      style: TextStyle(
                        fontSize: clampDouble(screenWidth * 0.030, 11.0, 12.0),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ),
                  SizedBox(width: chipGap),
                  _speakerButton(
                    context,
                    entry: entry,
                    playing: isPlaying,
                    size: speakerSize,
                    screenWidth: screenWidth,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(
    BuildContext context,
    CommsEntry entry,
    double screenWidth,
  ) {
    final badgeSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);

    final (label, color) = switch (entry.status) {
      PacketStatus.ackDelivered => ('ACK ${entry.ackLatencyMs} ms', AppColors.primaryEmerald),
      PacketStatus.queued => ('Retry ${entry.retryInSec}s', _queuedAmber),
      PacketStatus.crcDropped => ('CRC Drop', AppColors.alertRed),
    };

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
          Container(
            width: clampDouble(screenWidth * 0.02, 7.0, 9.0),
            height: clampDouble(screenWidth * 0.02, 7.0, 9.0),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          SizedBox(width: clampDouble(screenWidth * 0.014, 5.0, 7.0)),
          Text(
            label,
            style: TextStyle(
              fontSize: badgeSize,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required double screenWidth,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: clampDouble(screenWidth * 0.026, 9.0, 13.0),
        vertical: clampDouble(screenWidth * 0.015, 5.0, 8.0),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: clampDouble(screenWidth * 0.032, 11.0, 13.0),
            color: color,
          ),
          SizedBox(width: clampDouble(screenWidth * 0.012, 4.0, 6.0)),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: clampDouble(screenWidth * 0.030, 11.0, 12.0),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _speakerButton(
    BuildContext context, {
    required CommsEntry entry,
    required bool playing,
    required double size,
    required double screenWidth,
  }) {
    return Material(
      color: playing ? AppColors.primaryEmerald : AppColors.emeraldMintTint,
      shape: CircleBorder(
        side: BorderSide(
          color: playing
              ? AppColors.primaryEmerald
              : AppColors.emeraldMintBorder,
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _handleSpeakerTap(entry),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            playing ? LucideIcons.square : LucideIcons.volume2,
            size: size * 0.42,
            color: playing ? AppColors.textWhite : AppColors.primaryEmerald,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Clear delivered history
  // ---------------------------------------------------------------------
  Widget _buildClearDeliveredButton(BuildContext context, double screenWidth) {
    final titleSize = clampDouble(screenWidth * 0.038, 14.0, 16.0);
    final metaSize = clampDouble(screenWidth * 0.033, 12.0, 14.0);
    final cardRadius = clampDouble(screenWidth * 0.05, 18.0, 24.0);

    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(cardRadius),
        onTap: () {
          HapticFeedback.lightImpact();
          _bloc.add(const CommsLogClearDelivered());
          _flashNote('Delivered history cleared â€” queue kept safe');
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(clampDouble(screenWidth * 0.045, 16.0, 22.0)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: clampDouble(screenWidth * 0.11, 40.0, 48.0),
                height: clampDouble(screenWidth * 0.11, 40.0, 48.0),
                decoration: BoxDecoration(
                  color: AppColors.alertRedBg,
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(
                    color: AppColors.alertRedBorder,
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  LucideIcons.trash2,
                  size: clampDouble(screenWidth * 0.05, 18.0, 21.0),
                  color: AppColors.alertRed,
                ),
              ),
              SizedBox(width: clampDouble(screenWidth * 0.03, 12.0, 16.0)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clear Delivered',
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: clampDouble(screenWidth * 0.012, 4.0, 7.0)),
                    Text(
                      'Removes ACKed packets â€” queue stays safe',
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
              SizedBox(width: clampDouble(screenWidth * 0.02, 7.0, 10.0)),
              Icon(
                LucideIcons.chevronRight,
                size: clampDouble(screenWidth * 0.045, 17.0, 20.0),
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Loading skeleton / error / empty
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
    final summaryHeight = clampDouble(screenHeight * 0.16, 110.0, 150.0);
    final cardHeight = clampDouble(screenHeight * 0.24, 170.0, 230.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.35, end: 0.75),
      duration: const Duration(milliseconds: 760),
      curve: Curves.easeInOut,
      builder: (context, opacity, child) => Opacity(
        opacity: opacity,
        child: child,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(hPad, sectionGap, hPad, scrollReserve),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _skeletonBox(width: double.infinity, height: summaryHeight, radius: cardRadius, screenWidth: screenWidth),
            SizedBox(height: sectionGap),
            _skeletonBox(width: double.infinity, height: clampDouble(screenWidth * 0.11, 40.0, 48.0), radius: 999, screenWidth: screenWidth),
            SizedBox(height: sectionGap),
            _skeletonBox(width: double.infinity, height: cardHeight, radius: cardRadius, screenWidth: screenWidth),
            SizedBox(height: sectionGap * 0.8),
            _skeletonBox(width: double.infinity, height: cardHeight * 0.9, radius: cardRadius, screenWidth: screenWidth),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBox({
    required double width,
    required double height,
    required double radius,
    required double screenWidth,
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
    CommsLogState state,
    double screenWidth,
    double scrollReserve,
  ) {
    final hPad = clampDouble(screenWidth * 0.045, 12.0, 20.0);
    final sectionSize = clampDouble(screenWidth * 0.042, 15.0, 17.0);
    final metaSize = clampDouble(screenWidth * 0.033, 12.0, 14.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        hPad,
        clampDouble(screenWidth * 0.12, 48.0, 72.0),
        hPad,
        scrollReserve,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.serverCrash,
            size: clampDouble(screenWidth * 0.18, 64.0, 96.0),
            color: AppColors.textMuted,
          ),
          SizedBox(height: clampDouble(screenWidth * 0.04, 14.0, 20.0)),
          Text(
            'Store Offline',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: sectionSize,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: clampDouble(screenWidth * 0.02, 8.0, 12.0)),
          Text(
            state.note.isNotEmpty
                ? state.note
                : 'Hive queue could not be opened on this device',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: metaSize,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: clampDouble(screenWidth * 0.04, 14.0, 20.0)),
          Material(
            color: AppColors.primaryEmerald,
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                HapticFeedback.lightImpact();
                _bloc.add(const CommsLogFetch());
              },
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
                          fontSize:
                              clampDouble(screenWidth * 0.038, 14.0, 16.0),
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

  Widget _buildEmptyTimeline(
    BuildContext context,
    CommsLogState state,
    double screenWidth,
    double screenHeight,
  ) {
    final sectionSize = clampDouble(screenWidth * 0.042, 15.0, 17.0);
    final metaSize = clampDouble(screenWidth * 0.033, 12.0, 14.0);

    final (title, hint) = switch (state.filter) {
      CommsFilter.all => (
          'No Packets Yet',
          'Frames appear here after the first transmission',
        ),
      CommsFilter.sosOnly => (
          'No SOS Frames',
          'Emergency packets will surface in this view',
        ),
      CommsFilter.pending => (
          'Queue Empty',
          'Every packet has been acknowledged',
        ),
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: clampDouble(screenHeight * 0.05, 28.0, 48.0),
        horizontal: clampDouble(screenWidth * 0.05, 18.0, 26.0),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius:
            BorderRadius.circular(clampDouble(screenWidth * 0.06, 20.0, 26.0)),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
      ),
      child: Column(
        children: [
          Icon(
            LucideIcons.inbox,
            size: clampDouble(screenWidth * 0.14, 52.0, 72.0),
            color: AppColors.textMuted,
          ),
          SizedBox(height: clampDouble(screenWidth * 0.03, 10.0, 14.0)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: sectionSize,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: clampDouble(screenWidth * 0.015, 5.0, 8.0)),
          Text(
            hint,
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
    );
  }

  // ---------------------------------------------------------------------
  // Small formatters
  // ---------------------------------------------------------------------
  String _timeLabel(DateTime time) {
    final now = DateTime.now();
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return 'Today $hh:$mm';
    if (diff == 1) return 'Yest $hh:$mm';
    return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')} $hh:$mm';
  }

  String _byteLabel(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

// -----------------------------------------------------------------------
// Summary bar widget â€” isolated for RepaintBoundary reuse
// -----------------------------------------------------------------------
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.state, required this.screenWidth});

  final CommsLogState state;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final cardRadius = clampDouble(screenWidth * 0.06, 20.0, 26.0);
    final cardPad = clampDouble(screenWidth * 0.045, 16.0, 22.0);
    final metricSize = clampDouble(screenWidth * 0.065, 20.0, 26.0);
    final badgeSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);

    final metrics = <({IconData icon, String label, String value, Color tint})>[
      (
        icon: LucideIcons.send,
        label: 'Sent',
        value: '${state.totalSent}',
        tint: AppColors.textPrimary,
      ),
      (
        icon: LucideIcons.checkCheck,
        label: 'ACK',
        value: '${state.ackCount}',
        tint: AppColors.primaryEmerald,
      ),
      (
        icon: LucideIcons.database,
        label: 'Queued',
        value: '${state.queuedCount}',
        tint: const Color(0xFFE8B923),
      ),
      (
        icon: LucideIcons.gauge,
        label: 'Saved',
        value: '${state.bandwidthSavedPercent.toStringAsFixed(1)}%',
        tint: AppColors.primaryEmeraldVibrant,
      ),
    ];

    return Container(
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
                LucideIcons.activity,
                size: clampDouble(screenWidth * 0.045, 17.0, 20.0),
                color: AppColors.primaryEmerald,
              ),
              SizedBox(width: clampDouble(screenWidth * 0.02, 7.0, 10.0)),
              Expanded(
                child: Text(
                  'Network Summary',
                  style: TextStyle(
                    fontSize: clampDouble(screenWidth * 0.042, 15.0, 17.0),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: cardPad * 0.6),
          LayoutBuilder(
            builder: (context, constraints) {
              final breakpoint = AppBreakpoint.fromWidth(screenWidth);
              final columns = breakpoint.isLarge ? 3 : 2;
              final gap = clampDouble(screenWidth * 0.03, 12.0, 16.0);
              final cellPad = clampDouble(screenWidth * 0.028, 10.0, 14.0);
              final iconBox = clampDouble(screenWidth * 0.10, 36.0, 40.0);
              final cellWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;

              // The row height is derived from the content, so a counter is
              // never crushed and the label never has to be cut off.
              final contentHeight = cellPad * 2 +
                  iconBox +
                  gap * 0.5 +
                  metricSize * 1.15 +
                  gap * 0.35 +
                  badgeSize * 1.25;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: gap,
                  childAspectRatio: cellWidth / contentHeight,
                ),
                itemCount: metrics.length,
                itemBuilder: (context, index) {
                  final m = metrics[index];
                  return Container(
                    padding: EdgeInsets.all(cellPad),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(
                        clampDouble(screenWidth * 0.035, 12.0, 16.0),
                      ),
                      border: Border.all(
                        color: AppColors.surfaceBorder,
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: iconBox,
                          height: iconBox,
                          decoration: BoxDecoration(
                            color: AppColors.emeraldMintTint,
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Icon(
                            m.icon,
                            size: iconBox * 0.5,
                            color: AppColors.primaryEmerald,
                          ),
                        ),
                        SizedBox(height: gap * 0.5),
                        Text(
                          m.value,
                          style: TextStyle(
                            fontSize: metricSize,
                            fontWeight: FontWeight.w800,
                            color: m.tint,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: gap * 0.35),
                        Text(
                          m.label,
                          style: TextStyle(
                            fontSize: badgeSize,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          if (state.note.isNotEmpty) ...[
            SizedBox(height: cardPad * 0.55),
            Text(
              state.note,
              style: TextStyle(
                fontSize: badgeSize,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
