import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';
import '../../services/audio/audio_player_service.dart';
import '../../services/speech/tts_service.dart';
import '../blocs/language/language_bloc.dart';
import '../blocs/language/language_event.dart';
import '../blocs/language/language_state.dart';

/// Screen 1B — Language Pack Selection.
///
/// This is the bridge between the home dashboard and the comms hub:
/// `Home → Select Language → Push-To-Talk / Receiver`. The operator picks the
/// working language of the device, hears a voice preview of the pack and only
/// then walks into the operational surfaces.
///
/// Design rules honoured by this screen:
/// * **Zero truncation** — no label is ever ellipsised or clipped. Every
///   string either fits on its own line or wraps onto the next one.
/// * **MediaQuery driven** — every dimension is derived from the live
///   viewport, so the layout holds on a 240 dp handset and on a tablet.
/// * **Keyboard safe** — the search field lives inside the scroll view and the
///   body is resized by the IME, so the Android keyboard can never clip it.
/// * **BLoC driven** — the pack list and the active language come from
///   [LanguageBloc] (Initial → Loading → Loaded → Error).
class LanguagePickerScreen extends StatefulWidget {
  const LanguagePickerScreen({super.key});

  @override
  State<LanguagePickerScreen> createState() => _LanguagePickerScreenState();
}

class _LanguagePickerScreenState extends State<LanguagePickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final TtsService _tts = TtsService();

  AudioPlayerService? _player;

  /// Set only when the screen owns its own bloc (isolated tests / deep links).
  LanguageBloc? _localBloc;
  late LanguageBloc _bloc;
  bool _blocBound = false;

  final ValueNotifier<String> _queryNotifier = ValueNotifier<String>('');
  String? _speakingCode;

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_blocBound) return;
    _blocBound = true;

    final shared = context.findAncestorWidgetOfExactType<BlocProvider<LanguageBloc>>();
    if (shared != null) {
      _bloc = context.read<LanguageBloc>();
      if (_bloc.state.status == LanguageStatus.initial) {
        _bloc.add(const LanguageInitialize());
      }
    } else {
      _localBloc = LanguageBloc()..add(const LanguageInitialize());
      _bloc = _localBloc!;
    }
  }

  @override
  void dispose() {
    _queryNotifier.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _localBloc?.close();
    unawaited(_player?.dispose());
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Interaction
  // ---------------------------------------------------------------------
  void _handleSearchChanged(String value) {
    _queryNotifier.value = value.trim().toLowerCase();
  }

  void _handleSelect(LanguagePack pack) {
    HapticFeedback.lightImpact();
    if (pack.code == _bloc.state.activeLanguage?.code) return;

    _bloc.add(
      LanguageSelect(
        languageCode: pack.code,
        languageName: pack.name,
        modelType: pack.modelType,
      ),
    );
  }

  void _handleBack() {
    HapticFeedback.lightImpact();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(AppRouter.home);
  }

  void _handleConfirm() {
    HapticFeedback.lightImpact();
    _searchFocus.unfocus();

    final navigator = Navigator.of(context);

    // The choice is already persisted by the bloc, so the hub picks it up
    // as soon as it is on screen.
    var hubBelow = false;
    navigator.popUntil((route) {
      if (AppRouter.isHubRoute(route.settings.name)) {
        hubBelow = true;
        return true;
      }
      return route.isFirst;
    });

    if (hubBelow) {
      // A console is already on the stack — simply return to it.
      return;
    }

    navigator.pushNamed(AppRouter.comms);
  }

  /// Speaks the sample phrase of [pack] with the offline voice when the pack
  /// is installed and with the system voice otherwise.
  Future<void> _handlePreview(LanguagePack pack) async {
    HapticFeedback.lightImpact();
    if (_speakingCode != null) return;

    setState(() => _speakingCode = pack.code);

    try {
      if (pack.code == 'hi_IN') {
        final ready = _tts.ready || await _tts.init(languageCode: 'hi_IN');
        if (ready) {
          final path = await _tts.synthesizeToFile(pack.testPhrase);
          if (path != null) {
            final player = _player ??= AudioPlayerService();
            await player.playFile(path);
            await Future.any<void>([
              player.onComplete.first,
              Future<void>.delayed(const Duration(seconds: 8)),
            ]);
            return;
          }
        }
      }

      final tts = FlutterTts();
      final voiceCode = pack.code.replaceAll('_', '-');
      bool available = false;
      try {
        final res = await tts.isLanguageAvailable(voiceCode);
        available = res == true || res == 1 || res == '1';
      } catch (_) {
        // Fallback for Windows desktop or platforms without isLanguageAvailable
        available = true;
      }
      if (available) {
        await tts.setLanguage(voiceCode);
        await tts.speak(pack.testPhrase);
        return;
      }

      if (mounted) {
        _showNote('${pack.name} voice needs a pack download');
      }
    } catch (_) {
      if (mounted) _showNote('Voice preview failed, try again');
    } finally {
      if (mounted) setState(() => _speakingCode = null);
    }
  }

  void _showNote(String message) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
              fontSize: AppType.meta(screenWidth),
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          backgroundColor: AppColors.surfaceSecondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 2200),
        ),
      );
  }

  // ---------------------------------------------------------------------
  // Filtering
  // ---------------------------------------------------------------------
  List<LanguagePack> _filterPacks(List<LanguagePack> packs, String query) {
    if (query.isEmpty) return packs;
    return packs.where((pack) {
      final name = pack.name.toLowerCase();
      final script = pack.script.toLowerCase();
      final code = pack.code.toLowerCase();
      final short = code.split('_').first;
      return name.contains(query) ||
          script.contains(query) ||
          code.contains(query) ||
          short.startsWith(query);
    }).toList();
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    // Responsive gutter that adapts from compact windows to large desktop screens.
    final gutter = clampDouble(screenWidth * 0.045, 8.0, 24.0);

    return BlocProvider<LanguageBloc>.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: true,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680.0),
              child: Column(
                children: [
                  RepaintBoundary(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        clampDouble(screenHeight * 0.014, 8.0, 16.0),
                        gutter,
                        0.0,
                      ),
                      child: _buildHeader(context, screenWidth),
                    ),
                  ),
                  Expanded(
                    child: BlocBuilder<LanguageBloc, LanguageState>(
                      builder: (context, state) {
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            gutter,
                            clampDouble(screenHeight * 0.014, 8.0, 16.0),
                            gutter,
                            clampDouble(screenHeight * 0.02, 10.0, 20.0),
                          ),
                          child: _buildBody(context, state, screenWidth),
                        );
                      },
                    ),
                  ),
                  // Isolated bottom CTA dock: listens to keyboard insets locally
                  // without triggering rebuilds of the entire language picker
                  // or language catalogue during IME open/close.
                  _LanguagePickerCtaDock(
                    gutter: gutter,
                    screenWidth: screenWidth,
                    onConfirm: _handleConfirm,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header — back chevron, title and the one line explainer
  // ---------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, double screenWidth) {
    final headerSize = clampDouble(screenWidth * 0.052, 14.0, 22.0);
    final metaSize = clampDouble(screenWidth * 0.033, 11.0, 14.0);
    final backSize = clampDouble(screenWidth * 0.095, 28.0, 44.0);
    final gap = clampDouble(screenWidth * 0.03, 8.0, 16.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          label: 'Back',
          child: Material(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(
              clampDouble(screenWidth * 0.035, 10.0, 16.0),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _handleBack,
              child: SizedBox(
                width: backSize,
                height: backSize,
                child: Icon(
                  LucideIcons.chevronLeft,
                  color: AppColors.textPrimary,
                  size: backSize * 0.52,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Language',
                  style: TextStyle(
                    fontSize: headerSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.15,
                  ),
                ),
              ),
              SizedBox(height: clampDouble(screenWidth * 0.008, 2.0, 5.0)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pick your working language',
                  style: TextStyle(
                    fontSize: metaSize,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Body — search, result caption and the language rows
  // ---------------------------------------------------------------------
  Widget _buildBody(
    BuildContext context,
    LanguageState state,
    double screenWidth,
  ) {
    if (state.status == LanguageStatus.error) {
      return _buildErrorState(context, screenWidth);
    }

    final packs = state.languagePacks;
    final active = state.activeLanguage;
    final loading = state.status == LanguageStatus.loading ||
        state.status == LanguageStatus.initial;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          child: _buildSearchField(context, screenWidth),
        ),
        SizedBox(height: clampDouble(screenWidth * 0.03, 10.0, 14.0)),
        if (loading)
          _buildLoadingState(context, screenWidth)
        else
          ValueListenableBuilder<String>(
            valueListenable: _queryNotifier,
            builder: (context, query, _) {
              final visible = _filterPacks(packs, query);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildResultCaption(context, screenWidth, visible.length, packs.length),
                  SizedBox(height: clampDouble(screenWidth * 0.03, 10.0, 14.0)),
                  if (visible.isEmpty)
                    _buildEmptyState(context, screenWidth)
                  else
                    RepaintBoundary(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < visible.length; i++) ...[
                            _buildLanguageRow(
                              context,
                              screenWidth,
                              visible[i],
                              isActive: active?.code == visible[i].code,
                            ),
                            if (i != visible.length - 1)
                              SizedBox(
                                height: clampDouble(screenWidth * 0.025, 8.0, 12.0),
                              ),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Search field — keyboard safe, and the placeholder is drawn by hand so
  // Flutter never puts an ellipsis on it.
  // ---------------------------------------------------------------------
  Widget _buildSearchField(BuildContext context, double screenWidth) {
    final fieldSize = clampDouble(screenWidth * 0.033, 11.0, 14.0);
    final iconSize = clampDouble(screenWidth * 0.045, 14.0, 20.0);
    final radius = AppSpacing.innerRadius(screenWidth);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: clampDouble(screenWidth * 0.04, 8.0, 18.0),
        vertical: clampDouble(screenWidth * 0.012, 2.0, 8.0),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.search,
            size: iconSize,
            color: AppColors.textMuted,
          ),
          SizedBox(width: clampDouble(screenWidth * 0.028, 6.0, 12.0)),
          Expanded(
            child: Stack(
              children: [
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  keyboardType: TextInputType.text,
                  onChanged: _handleSearchChanged,
                  scrollPadding: const EdgeInsets.only(bottom: 120.0),
                  style: TextStyle(
                    fontSize: fieldSize,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    // The placeholder is drawn by hand below so the field
                    // never falls back to Flutter's ellipsising hint.
                    hintText: null,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: clampDouble(screenWidth * 0.028, 8.0, 15.0),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    if (value.text.isNotEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Positioned.fill(
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Search languages',
                              style: TextStyle(
                                fontSize: fieldSize,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textMuted,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: clampDouble(screenWidth * 0.02, 4.0, 10.0)),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _searchController.clear();
                        _handleSearchChanged('');
                      },
                      child: SizedBox(
                        width: iconSize + 6.0,
                        height: iconSize + 6.0,
                        child: Icon(
                          LucideIcons.x,
                          size: iconSize,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResultCaption(
    BuildContext context,
    double screenWidth,
    int shown,
    int total,
  ) {
    final badgeSize = clampDouble(screenWidth * 0.030, 10.0, 12.0);
    final label = shown == total
        ? '$total of $total languages'
        : '$shown of $total languages';

    return Row(
      children: [
        Icon(
          LucideIcons.languages,
          size: clampDouble(screenWidth * 0.035, 12.0, 16.0),
          color: AppColors.primaryEmerald,
        ),
        SizedBox(width: clampDouble(screenWidth * 0.02, 4.0, 10.0)),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                fontSize: badgeSize,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // One language row — code badge, native script, english name,
  // voice preview and the selection marker. Dynamically adapts between
  // a horizontal row on regular/wide viewports and a multi-tier card
  // on compact/narrow viewports so it NEVER overflows.
  // ---------------------------------------------------------------------
  Widget _buildLanguageRow(
    BuildContext context,
    double screenWidth,
    LanguagePack pack, {
    required bool isActive,
  }) {
    final speaking = _speakingCode == pack.code;
    final pastel = LanguagePalette.of(pack.code);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        // Dynamically compute responsive padding and sizes from the card width.
        final pad = clampDouble(cardWidth * 0.04, 8.0, 18.0);
        final radius = AppSpacing.innerRadius(screenWidth);
        final gap = clampDouble(cardWidth * 0.028, 6.0, 12.0);
        final badge = clampDouble(cardWidth * 0.10, 24.0, 40.0);
        final titleSize = AppType.itemTitle(screenWidth);
        final metaSize = AppType.meta(screenWidth);
        final speakSize = clampDouble(cardWidth * 0.10, 26.0, 40.0);
        final dotSize = clampDouble(cardWidth * 0.06, 16.0, 24.0);

        final innerWidth = cardWidth - (pad * 2);

        // Language code badge (e.g. "HI", "EN")
        final badgeWidget = Container(
          width: badge,
          height: badge,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pastel.background,
            borderRadius: BorderRadius.circular(
              clampDouble(badge * 0.35, 8.0, 14.0),
            ),
            border: Border.all(
              color: isActive
                  ? AppColors.emeraldMintBorder
                  : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Text(
            pack.code.split('_').first.toUpperCase(),
            style: TextStyle(
              fontSize: badge * 0.36,
              fontWeight: FontWeight.w700,
              color: pastel.foreground,
              height: 1.1,
            ),
          ),
        );

        // Native script & English title column
        final titleSubtitleColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              pack.script,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.25,
                // Native script is rendered with the bundled Noto
                // family of that language (design.md §8.3).
                fontFamily: AppFonts.forLanguageCode(pack.code),
                fontFamilyFallback: AppFonts.fallback,
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.008, 2.0, 4.0)),
            Text(
              toTitleCase(pack.name),
              style: TextStyle(
                fontSize: metaSize,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        );

        final speakBtn = _buildSpeakButton(
          context,
          screenWidth,
          pack: pack,
          size: speakSize,
          busy: speaking,
        );

        final selectionDot = _buildSelectionDot(screenWidth, dotSize, isActive);

        // Responsive layout selection:
        // Tier 1: Single Row (innerWidth >= 170.0)
        // Tier 2: 2-Tier Stack (110.0 <= innerWidth < 170.0)
        // Tier 3: 3-Tier Stack (innerWidth < 110.0)
        Widget content;

        if (innerWidth >= 170.0) {
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              badgeWidget,
              SizedBox(width: gap),
              Expanded(child: titleSubtitleColumn),
              SizedBox(width: gap),
              speakBtn,
              SizedBox(width: gap),
              selectionDot,
            ],
          );
        } else if (innerWidth >= 110.0) {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  badgeWidget,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      speakBtn,
                      SizedBox(width: gap),
                      selectionDot,
                    ],
                  ),
                ],
              ),
              SizedBox(height: gap),
              titleSubtitleColumn,
            ],
          );
        } else {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  badgeWidget,
                  selectionDot,
                ],
              ),
              const SizedBox(height: 4.0),
              titleSubtitleColumn,
              const SizedBox(height: 6.0),
              speakBtn,
            ],
          );
        }

        return Material(
          color: isActive ? AppColors.selectedSurface : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _handleSelect(pack),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: isActive
                      ? AppColors.selectedBorder
                      : AppColors.surfaceBorder,
                  width: isActive ? 1.5 : 1.0,
                ),
              ),
              child: content,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpeakButton(
    BuildContext context,
    double screenWidth, {
    required LanguagePack pack,
    required double size,
    required bool busy,
  }) {
    final iconSize = size * 0.46;

    return Semantics(
      button: true,
      label: 'Preview ${pack.name} voice',
      child: Material(
        color: AppColors.audioPreviewBg,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.surfaceBorder, width: 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : () => _handlePreview(pack),
          child: SizedBox(
            width: size,
            height: size,
            child: busy
                ? Center(
                    child: SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(AppColors.primaryEmerald),
                      ),
                    ),
                  )
                : Icon(
                    LucideIcons.volume2,
                    size: iconSize,
                    color: AppColors.audioPreviewIcon,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionDot(
    double screenWidth,
    double size,
    bool isActive,
  ) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.primaryEmeraldVibrant : Colors.transparent,
        border: Border.all(
          color: isActive
              ? AppColors.primaryEmeraldVibrant
              : AppColors.radioUnselected,
          width: 1.6,
        ),
      ),
      child: isActive
          ? Icon(
              LucideIcons.check,
              size: size * 0.56,
              color: AppColors.textWhite,
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------
  // Loading / error / empty
  // ---------------------------------------------------------------------
  Widget _buildLoadingState(BuildContext context, double screenWidth) {
    final rows = 4;
    final gap = clampDouble(screenWidth * 0.025, 8.0, 12.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(
        rows,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: Container(
            height: clampDouble(screenWidth * 0.175, 60.0, 76.0),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(
                AppSpacing.innerRadius(screenWidth),
              ),
              border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, double screenWidth) {
    final sectionSize = AppType.section(screenWidth);
    final metaSize = AppType.meta(screenWidth);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.cardPad(screenWidth)),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius(screenWidth)),
        border: Border.all(
          color: AppColors.alertRed.withValues(alpha: 0.45),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.alertTriangle,
                size: clampDouble(screenWidth * 0.05, 20.0, 24.0),
                color: AppColors.alertRed,
              ),
              SizedBox(width: clampDouble(screenWidth * 0.025, 8.0, 12.0)),
              Expanded(
                child: Text(
                  'Pack List Failed',
                  style: TextStyle(
                    fontSize: sectionSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.alertRed,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: clampDouble(screenWidth * 0.025, 10.0, 14.0)),
          Text(
            'The offline pack list did not load. Retry to open it again.',
            style: TextStyle(
              fontSize: metaSize,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: clampDouble(screenWidth * 0.045, 14.0, 20.0)),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _bloc.add(const LanguageInitialize());
              },
              icon: Icon(
                LucideIcons.refreshCw,
                size: clampDouble(screenWidth * 0.045, 16.0, 20.0),
              ),
              label: Text(
                'Retry',
                style: TextStyle(
                  fontSize: AppType.button(screenWidth),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryEmerald,
                side: BorderSide(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.45),
                  width: 1.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    clampDouble(screenWidth * 0.045, 14.0, 18.0),
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  vertical: clampDouble(screenWidth * 0.03, 12.0, 15.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, double screenWidth) {
    final sectionSize = AppType.section(screenWidth);
    final metaSize = AppType.meta(screenWidth);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: clampDouble(screenWidth * 0.06, 18.0, 28.0),
        horizontal: AppSpacing.innerPad(screenWidth),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppSpacing.innerRadius(screenWidth)),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: clampDouble(screenWidth * 0.24, 72.0, 100.0),
            height: clampDouble(screenWidth * 0.24, 72.0, 100.0),
            child: Lottie.asset(
              'assets/lottie/empty_state.json',
              repeat: true,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                LucideIcons.searchX,
                size: clampDouble(screenWidth * 0.10, 34.0, 46.0),
                color: AppColors.textMuted,
              ),
            ),
          ),
          SizedBox(height: clampDouble(screenWidth * 0.035, 10.0, 16.0)),
          Text(
            'No Language Found',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: sectionSize,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          SizedBox(height: 6.0),
          Text(
            'Try the English name or the native script.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: metaSize,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Isolated bottom CTA dock:
/// Listens to keyboard insets locally without triggering rebuilds of the
/// entire language picker screen or language catalogue during IME open/close.
class _LanguagePickerCtaDock extends StatelessWidget {
  const _LanguagePickerCtaDock({
    required this.gutter,
    required this.screenWidth,
    required this.onConfirm,
  });

  final double gutter;
  final double screenWidth;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final ctaBottom = keyboard > 0
        ? clampDouble(screenWidth * 0.022, 6.0, 12.0)
        : (bottomInset == 0 ? 16.0 : bottomInset);

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 0.0, gutter, ctaBottom),
        child: _ConfirmCtaButton(
          screenWidth: screenWidth,
          onConfirm: onConfirm,
        ),
      ),
    );
  }
}

class _ConfirmCtaButton extends StatelessWidget {
  const _ConfirmCtaButton({
    required this.screenWidth,
    required this.onConfirm,
  });

  final double screenWidth;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final labelSize = clampDouble(screenWidth * 0.036, 12.0, 15.0) + 1.0;
    final iconSize = clampDouble(screenWidth * 0.05, 15.0, 21.0);
    final ctaHeight = clampDouble(screenWidth * 0.155, 46.0, 62.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: ctaHeight),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryEmerald,
                foregroundColor: AppColors.textWhite,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    clampDouble(screenWidth * 0.05, 14.0, 20.0),
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: clampDouble(screenWidth * 0.03, 10.0, 18.0),
                  vertical: clampDouble(screenWidth * 0.03, 10.0, 16.0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Confirm & Continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: labelSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                  if (screenWidth >= 160) ...[
                    SizedBox(width: clampDouble(screenWidth * 0.02, 4.0, 10.0)),
                    Icon(
                      LucideIcons.arrowRight,
                      size: iconSize,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: clampDouble(screenWidth * 0.022, 6.0, 10.0)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Offline voice and text for the whole mesh',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: clampDouble(screenWidth * 0.030, 10.0, 12.0),
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
