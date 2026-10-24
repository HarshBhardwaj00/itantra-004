import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';
import '../blocs/language/language_bloc.dart';
import '../blocs/language/language_state.dart';
import '../blocs/receiver/receiver_bloc.dart';
import '../blocs/receiver/receiver_state.dart';
import '../blocs/talk/talk_bloc.dart';
import '../blocs/talk/talk_event.dart';
import '../widgets/comms_composer_bar.dart';
import '../widgets/comms_identity_bar.dart';
import '../widgets/comms_mode_switcher.dart';
import 'home_ptt_screen.dart';
import 'receiver_screen.dart';

/// The unified comms hub.
///
/// Sender and receiver share one screen: the same app bar, the same bottom
/// dock and the same router entry point. Switching modes swaps the panel
/// inside an [IndexedStack], so the live transcript, the UDP listener and the
/// replay queue all survive the switch.
class CommsHubScreen extends StatefulWidget {
  const CommsHubScreen({
    super.key,
    this.initialMode = CommsMode.sender,
  });

  /// Mode the hub opens with.
  final CommsMode initialMode;

  @override
  State<CommsHubScreen> createState() => _CommsHubScreenState();
}

class _CommsHubScreenState extends State<CommsHubScreen> {
  late CommsMode _mode = widget.initialMode;
  final TextEditingController _composerController = TextEditingController();
  final FocusNode _composerFocus = FocusNode();
  bool _hasReceiverBloc = false;
  bool _hasLanguageBloc = false;

  @override
  void initState() {
    super.initState();
    CommsHubState.mode.value = widget.initialMode;
    CommsHubState.mode.addListener(_handleGlobalModeChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hasReceiverBloc =
        context.findAncestorWidgetOfExactType<BlocProvider<ReceiverBloc>>() !=
            null;
    _hasLanguageBloc =
        context.findAncestorWidgetOfExactType<BlocProvider<LanguageBloc>>() !=
            null;
  }

  @override
  void dispose() {
    CommsHubState.mode.removeListener(_handleGlobalModeChanged);
    _composerController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Mode handling
  // ---------------------------------------------------------------------
  void _handleGlobalModeChanged() {
    if (!mounted) return;
    final next = CommsHubState.mode.value;
    if (next == _mode) return;
    setState(() => _mode = next);
  }

  void _handleModeSelected(CommsMode mode) {
    if (mode == _mode) return;
    HapticFeedback.lightImpact();

    // The shared handle performs the rebuild, so every surface stays in sync.
    CommsHubState.mode.value = mode;

    if (mode != CommsMode.sender) {
      _composerFocus.unfocus();
    }
  }

  // ---------------------------------------------------------------------
  // Composer â€” the keyboard safe "add record" form of the hub
  // ---------------------------------------------------------------------
  void _handleSend() {
    final text = _composerController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();

    try {
      context.read<TalkBloc>().add(TalkTranscriptReady(text, isVoice: false));
    } catch (_) {
      // The talk engine is not available in this context â€” the text stays
      // in the field so the operator does not lose the message.
      return;
    }

    _composerController.clear();
    _composerFocus.unfocus();
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    final hPad = AppSpacing.gutter(screenWidth);
    final topGap = clampDouble(screenHeight * 0.012, 8.0, 14.0);
    final gap = clampDouble(screenHeight * 0.012, 8.0, 14.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RepaintBoundary(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, topGap, hPad, 0.0),
                child: _buildIdentityBar(),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _mode.index,
                children: [
                  TickerMode(
                    enabled: _mode == CommsMode.sender,
                    child: const HomePttScreen(),
                  ),
                  TickerMode(
                    enabled: _mode == CommsMode.receiver,
                    child: const ReceiverScreen(),
                  ),
                ],
              ),
            ),
            // Isolated bottom dock leaf widget: listens to keyboard insets
            // locally without triggering rebuilds of the entire hub,
            // IndexedStack, HomePttScreen, or ReceiverScreen.
            _HubBottomDock(
              mode: _mode,
              composerController: _composerController,
              composerFocus: _composerFocus,
              onSend: _handleSend,
              onModeSelected: _handleModeSelected,
              hPad: hPad,
              gap: gap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityBar() {
    Widget identity(String subtitle, bool meshActive) {
      return CommsIdentityBar(
        title: 'iTantra',
        subtitle: subtitle,
        statusLabel: meshActive ? 'Mesh Active' : 'Mesh Standby',
        statusActive: meshActive,
        onBack: _handleBack,
        onSubtitleTap: _handleLanguageTap,
      );
    }

    if (_hasLanguageBloc && _hasReceiverBloc) {
      return BlocBuilder<LanguageBloc, LanguageState>(
        buildWhen: (prev, curr) => prev.activeLanguage != curr.activeLanguage,
        builder: (context, languageState) {
          return BlocBuilder<ReceiverBloc, ReceiverState>(
            buildWhen: (prev, curr) => prev.listening != curr.listening,
            builder: (context, receiverState) => identity(
              _languageSubtitle(languageState),
              receiverState.listening,
            ),
          );
        },
      );
    }

    if (_hasLanguageBloc) {
      return BlocBuilder<LanguageBloc, LanguageState>(
        buildWhen: (prev, curr) => prev.activeLanguage != curr.activeLanguage,
        builder: (context, languageState) =>
            identity(_languageSubtitle(languageState), false),
      );
    }

    if (_hasReceiverBloc) {
      return BlocBuilder<ReceiverBloc, ReceiverState>(
        buildWhen: (prev, curr) => prev.listening != curr.listening,
        builder: (context, receiverState) =>
            identity(_languageSubtitle(null), receiverState.listening),
      );
    }

    return identity(_languageSubtitle(null), false);
  }

  void _handleBack() {
    HapticFeedback.lightImpact();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    // The hub is the root of the stack â€” fall back to the home dashboard so
    // the operator can pick another surface.
    navigator.pushReplacementNamed(AppRouter.home);
  }

  /// Opens the language pack picker straight from the app bar, so the
  /// operator can switch the working language without leaving the console.
  void _handleLanguageTap() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushNamed(AppRouter.selectLanguage);
  }

  String _languageSubtitle([LanguageState? state]) {
    final name = toTitleCase(
      state?.activeLanguage?.name ?? AppConstants.activeLanguageName,
    );
    final code = (state?.activeLanguage?.code ?? AppConstants.activeLanguageCode)
        .split('_')
        .first;
    if (name.isEmpty) return code;
    if (code.isEmpty) return name;
    return '$name \u00B7 $code';
  }
}

/// Isolated bottom dock leaf widget:
/// Encapsulates the keyboard-sensitive [CommsComposerBar] and [CommsModeSwitcher].
/// By confining [MediaQuery.viewInsetsOf] to this leaf, keyboard slide-up
/// transitions never trigger rebuilds of the entire hub, IndexedStack,
/// HomePttScreen, or ReceiverScreen.
class _HubBottomDock extends StatelessWidget {
  const _HubBottomDock({
    required this.mode,
    required this.composerController,
    required this.composerFocus,
    required this.onSend,
    required this.onModeSelected,
    required this.hPad,
    required this.gap,
  });

  final CommsMode mode;
  final TextEditingController composerController;
  final FocusNode composerFocus;
  final VoidCallback onSend;
  final ValueChanged<CommsMode> onModeSelected;
  final double hPad;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final systemBottom = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPad = keyboard > 0
        ? clampDouble(screenWidth * 0.022, 8.0, 12.0)
        : (systemBottom == 0 ? 16.0 : systemBottom);

    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mode == CommsMode.sender) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                hPad,
                0.0,
                hPad,
                keyboard > 0
                    ? clampDouble(screenWidth * 0.022, 8.0, 12.0)
                    : gap,
              ),
              child: CommsComposerBar(
                controller: composerController,
                focusNode: composerFocus,
                onSend: onSend,
              ),
            ),
          ],
          if (keyboard == 0)
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0.0, hPad, bottomPad),
              child: CommsModeSwitcher(
                mode: mode,
                onChanged: onModeSelected,
              ),
            ),
        ],
      ),
    );
  }
}
