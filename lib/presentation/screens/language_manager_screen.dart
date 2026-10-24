import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';
import '../../data/models/device_node.dart';
import '../../services/audio/audio_player_service.dart';
import '../../services/model/model_path_resolver.dart';
import '../../services/speech/tts_service.dart';
import '../blocs/language/language_bloc.dart';
import '../blocs/language/language_event.dart';
import '../blocs/language/language_state.dart';
import '../blocs/talk/talk_bloc.dart';
import '../blocs/talk/talk_event.dart';

/// Screen 6 — Offline Language Pack Manager.
///
/// Displays an active memory gauge and a grid of 10 Indian language packs.
/// Tapping a language card unloads the current model and loads the selected one.
/// "Test Voice" speaks a confirmation phrase using the newly loaded model.
/// Back navigation returns to Home PTT (Screen 2) with the language chip updated.
class LanguageManagerScreen extends StatefulWidget {
  const LanguageManagerScreen({super.key});

  @override
  State<LanguageManagerScreen> createState() => _LanguageManagerScreenState();
}

class _LanguageManagerScreenState extends State<LanguageManagerScreen> {
  LanguageBloc? _localLanguageBloc;
  TalkBloc? _localTalkBloc;
  late LanguageBloc _languageBloc;
  late TalkBloc _talkBloc;
  late final TtsService _tts;
  StreamSubscription? _languageSubscription;
  bool _blocsBound = false;

  @override
  void initState() {
    super.initState();
    ModelPathResolver.ensureInitialized();
    _tts = TtsService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_blocsBound) return;
    _blocsBound = true;

    final sharedLang =
        context.findAncestorWidgetOfExactType<BlocProvider<LanguageBloc>>();
    if (sharedLang != null) {
      _languageBloc = context.read<LanguageBloc>();
    } else {
      _localLanguageBloc = LanguageBloc()..add(const LanguageInitialize());
      _languageBloc = _localLanguageBloc!;
    }

    final sharedTalk =
        context.findAncestorWidgetOfExactType<BlocProvider<TalkBloc>>();
    if (sharedTalk != null) {
      _talkBloc = context.read<TalkBloc>();
    } else {
      _localTalkBloc = TalkBloc();
      _talkBloc = _localTalkBloc!;
    }

    _languageSubscription = _languageBloc.stream.listen((state) {
      if (state.activeLanguage != null && state.status == LanguageStatus.loaded) {
        _talkBloc.add(TalkEngineReady(
          sttReady: _talkBloc.state.sttReady,
          vadReady: _talkBloc.state.vadReady,
          ttsReady: state.activeLanguage!.code == 'en_IN' || _tts.ready,
        ));
      }
    });
  }

  void _onLanguageSelected(LanguagePack pack) {
    AppConstants.activeLanguageCode = pack.code;
    AppConstants.activeLanguageName = pack.name;
    DeviceNode.saveActiveLanguage(pack.code, pack.name);

    if (pack.code != 'en_IN') {
      _tts.switchLanguage(pack.code);
    }

    _languageBloc.add(LanguageSelect(
      languageCode: pack.code,
      languageName: pack.name,
      modelType: pack.modelType,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${pack.name} is now active for PTT & transcription.'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _languageSubscription?.cancel();
    _localLanguageBloc?.close();
    _localTalkBloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final screenWidth = size.width;
    final screenHeight = size.height;
    final hPad = clampDouble(screenWidth * 0.045, 12.0, 20.0);
    final vPad = clampDouble(screenHeight * 0.018, 10.0, 16.0);
    final cardRadius = clampDouble(screenWidth * 0.055, 20.0, 28.0);
    final cardPadding = clampDouble(screenWidth * 0.045, 16.0, 22.0);
    final sectionGap = clampDouble(screenHeight * 0.02, 12.0, 20.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, true);
      },
      child: MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _languageBloc),
        BlocProvider.value(value: _talkBloc),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: true,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, 0),
                child: _buildHeader(context, screenWidth),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom == 0
                        ? 16.0
                        : MediaQuery.paddingOf(context).bottom,
                    top: vPad,
                    left: hPad,
                    right: hPad,
                  ),
                  child: BlocBuilder<LanguageBloc, LanguageState>(
                    builder: (context, state) {
                      if (state.status == LanguageStatus.loading) {
                        return _buildLoadingState(context, screenWidth);
                      } else if (state.status == LanguageStatus.error) {
                        return _buildErrorState(context, screenWidth, state.errorMessage ?? 'Unknown error');
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMemoryGauge(context, screenWidth, cardRadius, cardPadding, state),
                          SizedBox(height: sectionGap),
                          _buildSectionTitle(context, screenWidth, 'Language Packs'),
                          SizedBox(height: clampDouble(screenWidth * 0.02, 8.0, 12.0)),
                          _buildLanguageGrid(context, screenWidth, cardRadius, cardPadding, state),
                        ],
                      );
                    },
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

  Widget _buildHeader(BuildContext context, double screenWidth) {
    final metaSize = clampDouble(screenWidth * 0.033, 12.0, 14.0);

    return Row(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12.0),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context, true);
            },
            borderRadius: BorderRadius.circular(12.0),
            child: Container(
              padding: EdgeInsets.all(clampDouble(screenWidth * 0.025, 8.0, 12.0)),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Language Manager',
                style: TextStyle(
                  fontSize: clampDouble(screenWidth * 0.052, 18.0, 22.0),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.15,
                ),
              ),
              SizedBox(height: clampDouble(screenWidth * 0.008, 3.0, 5.0)),
              Text(
                'Offline voice models and RAM',
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
      ],
    );
  }

  Widget _buildMemoryGauge(
    BuildContext context,
    double screenWidth,
    double cardRadius,
    double cardPadding,
    LanguageState state,
  ) {
    final gaugeHeight = clampDouble(screenWidth * 0.08, 28.0, 36.0);
    final labelSize = clampDouble(screenWidth * 0.033, 12.0, 14.0);
    final valueSize = clampDouble(screenWidth * 0.045, 16.0, 20.0);
    final iconSize = clampDouble(screenWidth * 0.05, 20.0, 24.0);

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(clampDouble(screenWidth * 0.02, 8.0, 10.0)),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldMintTint,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Icon(
                    LucideIcons.memoryStick,
                    color: AppColors.primaryEmerald,
                    size: iconSize,
                  ),
                ),
                SizedBox(width: clampDouble(screenWidth * 0.03, 12.0, 16.0)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Model RAM',
                        style: TextStyle(
                          fontSize: labelSize,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          height: 1.25,
                        ),
                      ),
                      SizedBox(height: clampDouble(screenWidth * 0.005, 2.0, 4.0)),
                      Text(
                        state.memoryLabel,
                        style: TextStyle(
                          fontSize: valueSize,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'monospace',
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: clampDouble(screenWidth * 0.02, 8.0, 12.0)),
                Flexible(
                  child: _buildMemoryStatusChip(context, screenWidth, state),
                ),
              ],
            ),
            SizedBox(height: cardPadding * 0.6),
            ClipRRect(
              borderRadius: BorderRadius.circular(gaugeHeight / 2),
              child: Container(
                height: gaugeHeight,
                width: double.infinity,
                color: AppColors.surfaceSecondary,
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: state.memoryRatio.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: state.memoryRatio > 0.85
                                ? [AppColors.alertRed, AppColors.alertRed.withValues(alpha: 0.7)]
                                : state.memoryRatio > 0.6
                                    ? [Colors.orange, Colors.orange.withValues(alpha: 0.7)]
                                    : [AppColors.primaryEmerald, AppColors.primaryEmeraldVibrant],
                          ),
                          borderRadius: BorderRadius.circular(gaugeHeight / 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.02, 8.0, 12.0)),
            Wrap(
              spacing: clampDouble(screenWidth * 0.02, 8.0, 12.0),
              runSpacing: clampDouble(screenWidth * 0.01, 4.0, 6.0),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (state.activeLanguage != null)
                  _buildActiveBadge(
                    context,
                    screenWidth,
                    state.activeLanguage!,
                  ),
                _buildLegendDot(context, screenWidth, AppColors.primaryEmerald, 'Optimal (<60%)'),
                _buildLegendDot(context, screenWidth, Colors.orange, 'Moderate (60-85%)'),
                _buildLegendDot(context, screenWidth, AppColors.alertRed, 'High (>85%)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Status pill of the RAM gauge — the health word of the current footprint.
  Widget _buildMemoryStatusChip(
    BuildContext context,
    double screenWidth,
    LanguageState state,
  ) {
    final badgeSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);
    final color = switch (state.memoryStatus) {
      'Optimal' => AppColors.primaryEmerald,
      'Moderate' => Colors.orange,
      _ => AppColors.alertRed,
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: clampDouble(screenWidth * 0.025, 9.0, 13.0),
        vertical: clampDouble(screenWidth * 0.012, 5.0, 8.0),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.0),
      ),
      child: Text(
        state.memoryStatus,
        style: TextStyle(
          fontSize: badgeSize,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildActiveBadge(
    BuildContext context,
    double screenWidth,
    LanguagePack pack,
  ) {
    final badgeSize = clampDouble(screenWidth * 0.030, 11.0, 12.0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: clampDouble(screenWidth * 0.025, 10.0, 14.0),
        vertical: clampDouble(screenWidth * 0.012, 5.0, 8.0),
      ),
      decoration: BoxDecoration(
        color: AppColors.emeraldMintTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.emeraldMintBorder, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: clampDouble(screenWidth * 0.018, 7.0, 9.0),
            height: clampDouble(screenWidth * 0.018, 7.0, 9.0),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryEmerald),
          ),
          SizedBox(width: clampDouble(screenWidth * 0.012, 5.0, 7.0)),
          Flexible(
            child: Text(
              toTitleCase(pack.name),
              style: TextStyle(
                fontSize: badgeSize,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryEmerald,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(BuildContext context, double screenWidth, Color color, String label) {
    final dotSize = clampDouble(screenWidth * 0.02, 7.0, 9.0);
    final labelSize = clampDouble(screenWidth * 0.030, 11.0, 13.0);

    return Container(
      constraints: BoxConstraints(maxWidth: screenWidth * 0.6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          SizedBox(width: clampDouble(screenWidth * 0.01, 4.0, 6.0)),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, double screenWidth, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: clampDouble(screenWidth * 0.042, 15.0, 17.0),
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildLanguageGrid(
    BuildContext context,
    double screenWidth,
    double cardRadius,
    double cardPadding,
    LanguageState state,
  ) {
    return RepaintBoundary(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: state.languagePacks.length,
        separatorBuilder: (_, _) =>
            SizedBox(height: clampDouble(screenWidth * 0.025, 10.0, 14.0)),
        itemBuilder: (context, index) {
          final pack = state.languagePacks[index];
          final isActive = state.activeLanguage?.code == pack.code;
          final isTesting = state.testingLanguageCode == pack.code;

          return _LanguageCard(
            pack: pack,
            isActive: isActive,
            isTesting: isTesting,
            onSelect: () {
              HapticFeedback.lightImpact();
              if (!isActive) {
                _onLanguageSelected(pack);
              }
            },
            onTestVoice: () {
              HapticFeedback.lightImpact();
              _languageBloc.add(LanguageTestVoice(pack.code));
              _testVoice(pack);
            },
            screenWidth: screenWidth,
            cardRadius: cardRadius,
            cardPadding: cardPadding,
          );
        },
      ),
    );
  }

  Future<void> _testVoice(LanguagePack pack) async {
    final player = AudioPlayerService();

    if (pack.code == 'en_IN') {
      try {
        final tts = FlutterTts();
        await tts.setLanguage('en-IN');
        await tts.speak(pack.testPhrase);
      } catch (_) {}
      await player.dispose();
      return;
    }

    if (pack.code == 'hi_IN') {
      if (_tts.ready || pack.code == AppConstants.activeLanguageCode) {
        final path = await _tts.synthesizeToFile(pack.testPhrase);
        if (path != null && mounted) {
          await player.playFile(path);
          await Future.any<void>([
            player.onComplete.first,
            Future<void>.delayed(const Duration(seconds: 10)),
          ]);
          await player.dispose();
          return;
        }
      }
      try {
        final tts = FlutterTts();
        await tts.setLanguage('hi-IN');
        await tts.speak(pack.testPhrase);
      } catch (_) {}
      await player.dispose();
      return;
    }

    // Try system TTS for other regional languages (Marathi, Tamil, Bengali, Telugu, etc.)
    bool spoken = false;
    try {
      final tts = FlutterTts();
      final ttsCode = pack.code.replaceAll('_', '-');
      bool isAvail = false;
      try {
        final res = await tts.isLanguageAvailable(ttsCode);
        isAvail = res == true || res == 1 || res == '1';
      } catch (_) {
        // Fallback for Windows desktop or platforms without isLanguageAvailable
        isAvail = true;
      }
      if (isAvail) {
        await tts.setLanguage(ttsCode);
        await tts.speak(pack.testPhrase);
        spoken = true;
      }
    } catch (_) {}

    if (!spoken && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pack.name} offline model not downloaded. English and Hindi are ready offline.'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    await player.dispose();
  }

  Widget _buildLoadingState(BuildContext context, double screenWidth) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(clampDouble(screenWidth * 0.1, 40.0, 60.0)),
        child: Column(
          children: [
            SizedBox(
              width: clampDouble(screenWidth * 0.15, 50.0, 70.0),
              height: clampDouble(screenWidth * 0.15, 50.0, 70.0),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryEmerald),
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.04, 16.0, 24.0)),
            Text(
              'Loading Language Packs...',
              style: TextStyle(
                fontSize: clampDouble(screenWidth * 0.042, 15.0, 17.0),
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, double screenWidth, String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(clampDouble(screenWidth * 0.1, 40.0, 60.0)),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(clampDouble(screenWidth * 0.05, 18.0, 24.0)),
              decoration: BoxDecoration(
                color: AppColors.alertRedBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.alertCircle,
                color: AppColors.alertRed,
                size: clampDouble(screenWidth * 0.07, 28.0, 36.0),
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.03, 12.0, 16.0)),
            Text(
              'Failed to Load',
              style: TextStyle(
                fontSize: clampDouble(screenWidth * 0.042, 15.0, 17.0),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.015, 6.0, 8.0)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: clampDouble(screenWidth * 0.03, 11.0, 13.0),
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.04, 16.0, 24.0)),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _languageBloc.add(const LanguageInitialize());
              },
              icon: Icon(LucideIcons.refreshCw, size: clampDouble(screenWidth * 0.045, 18.0, 20.0)),
              label: Text(
                'Retry',
                style: TextStyle(fontSize: clampDouble(screenWidth * 0.038, 14.0, 16.0)),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: clampDouble(screenWidth * 0.08, 32.0, 48.0),
                  vertical: clampDouble(screenWidth * 0.035, 14.0, 18.0),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final LanguagePack pack;
  final bool isActive;
  final bool isTesting;
  final VoidCallback onSelect;
  final VoidCallback onTestVoice;
  final double screenWidth;
  final double cardRadius;
  final double cardPadding;

  const _LanguageCard({
    required this.pack,
    required this.isActive,
    required this.isTesting,
    required this.onSelect,
    required this.onTestVoice,
    required this.screenWidth,
    required this.cardRadius,
    required this.cardPadding,
  });

  @override
  Widget build(BuildContext context) {
    final iconBox = clampDouble(screenWidth * 0.09, 36.0, 48.0);
    final titleSize = clampDouble(screenWidth * 0.038, 14.0, 16.0);
    final scriptSize = clampDouble(screenWidth * 0.033, 12.0, 14.0);
    final metaSize = clampDouble(screenWidth * 0.03, 11.0, 13.0);
    final badgeSize = clampDouble(screenWidth * 0.028, 10.0, 12.0);
    final buttonSize = clampDouble(screenWidth * 0.035, 13.0, 15.0);

    final borderColor = isActive
        ? AppColors.selectedBorder
        : (pack.availability == LanguageAvailability.installed
            ? AppColors.emeraldMintBorder
            : AppColors.surfaceBorder);

    final bgColor = isActive
        ? AppColors.selectedSurface
        : AppColors.surfaceCard;

    final pastel = LanguagePalette.of(pack.code);

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(cardRadius),
          child: Container(
            padding: EdgeInsets.all(cardPadding),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(color: borderColor, width: isActive ? 2.0 : 1.0),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: iconBox,
                      height: iconBox,
                      decoration: BoxDecoration(
                        color: pastel.background,
                        borderRadius: BorderRadius.circular(clampDouble(screenWidth * 0.025, 10.0, 14.0)),
                        border: Border.all(
                          color: isActive
                              ? AppColors.emeraldMintBorder
                              : Colors.transparent,
                          width: 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          pack.script.characters.first,
                          style: TextStyle(
                            fontSize: clampDouble(screenWidth * 0.045, 18.0, 24.0),
                            fontWeight: FontWeight.w700,
                            color: pastel.foreground,
                            fontFamily: AppFonts.forLanguageCode(pack.code),
                            fontFamilyFallback: AppFonts.fallback,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: clampDouble(screenWidth * 0.025, 10.0, 14.0)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            toTitleCase(pack.name),
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          SizedBox(height: clampDouble(screenWidth * 0.005, 2.0, 4.0)),
                          Text(
                            pack.script,
                            style: TextStyle(
                              fontSize: scriptSize,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: clampDouble(screenWidth * 0.015, 6.0, 8.0)),
                    Flexible(
                      child: _buildStatusBadge(screenWidth, badgeSize),
                    ),
                  ],
                ),
                SizedBox(height: cardPadding * 0.5),
                Wrap(
                  spacing: clampDouble(screenWidth * 0.015, 6.0, 8.0),
                  runSpacing: clampDouble(screenWidth * 0.01, 4.0, 6.0),
                  children: [
                    _buildMetaChip(screenWidth, metaSize, LucideIcons.cpu, pack.modelType),
                    _buildMetaChip(screenWidth, metaSize, LucideIcons.database, '${pack.estimatedSizeMB} MB'),
                  ],
                ),
                SizedBox(height: clampDouble(screenWidth * 0.03, 10.0, 14.0)),
                if (!isActive && pack.availability != LanguageAvailability.active) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onTestVoice,
                      icon: isTesting
                          ? SizedBox(
                              width: buttonSize,
                              height: buttonSize,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.textWhite),
                              ),
                            )
                          : Icon(LucideIcons.volume2, size: buttonSize),
                      label: Text(
                        isTesting ? 'Testing...' : 'Test Voice',
                        style: TextStyle(
                          fontSize: clampDouble(screenWidth * 0.03, 11.0, 13.0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: clampDouble(screenWidth * 0.025, 10.0, 14.0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      ),
                    ),
                  ),
                ] else if (isActive) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onTestVoice,
                      icon: isTesting
                          ? SizedBox(
                              width: buttonSize,
                              height: buttonSize,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryEmerald),
                              ),
                            )
                          : Icon(LucideIcons.volume2, size: buttonSize, color: AppColors.primaryEmerald),
                      label: Text(
                        isTesting ? 'Testing...' : 'Test Voice',
                        style: TextStyle(
                          fontSize: clampDouble(screenWidth * 0.03, 11.0, 13.0),
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryEmerald,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: clampDouble(screenWidth * 0.025, 10.0, 14.0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        side: const BorderSide(color: AppColors.primaryEmerald, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(double screenWidth, double badgeSize) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (pack.availability) {
      case LanguageAvailability.active:
        badgeColor = AppColors.primaryEmerald;
        badgeText = 'Active';
        badgeIcon = LucideIcons.checkCircle2;
        break;
      case LanguageAvailability.installed:
        badgeColor = AppColors.primaryEmeraldVibrant;
        badgeText = 'Ready';
        badgeIcon = LucideIcons.download;
        break;
      case LanguageAvailability.available:
        badgeColor = AppColors.textMuted;
        badgeText = 'Download';
        badgeIcon = LucideIcons.arrowDownCircle;
        break;
    }

    return Container(
      constraints: BoxConstraints(maxWidth: screenWidth * 0.35),
      padding: EdgeInsets.symmetric(
        horizontal: clampDouble(screenWidth * 0.02, 8.0, 10.0),
        vertical: clampDouble(screenWidth * 0.01, 4.0, 6.0),
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: clampDouble(screenWidth * 0.03, 11.0, 13.0), color: badgeColor),
          SizedBox(width: clampDouble(screenWidth * 0.01, 4.0, 5.0)),
          Flexible(
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: badgeSize,
                fontWeight: FontWeight.w700,
                color: badgeColor,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(double screenWidth, double metaSize, IconData icon, String label) {
    return Container(
      constraints: BoxConstraints(maxWidth: screenWidth * 0.45),
      padding: EdgeInsets.symmetric(
        horizontal: clampDouble(screenWidth * 0.02, 8.0, 10.0),
        vertical: clampDouble(screenWidth * 0.01, 4.0, 6.0),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: clampDouble(screenWidth * 0.03, 11.0, 13.0), color: AppColors.textMuted),
          SizedBox(width: clampDouble(screenWidth * 0.01, 4.0, 5.0)),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: metaSize,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}