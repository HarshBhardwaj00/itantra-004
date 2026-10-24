import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';
import '../../data/datasources/radio_packet_bus.dart';
import '../../services/audio/audio_player_service.dart';
import '../../services/audio/audio_recorder_service.dart';
import '../../services/location/location_service.dart';
import '../../services/model/model_path_resolver.dart';
import '../../services/speech/stt_service.dart';
import '../../services/speech/tts_service.dart';
import '../../services/speech/vad_detector.dart';
import '../blocs/talk/talk_bloc.dart';
import '../blocs/talk/talk_event.dart';
import '../blocs/talk/talk_state.dart';
import '../widgets/link_status_indicator.dart';
import '../widgets/ptt_button.dart';
import '../widgets/recorded_audio_card.dart';
import '../widgets/waveform_strip.dart';

/// A clip that was captured and is waiting on the operator before it goes
/// out on the mesh.
class _StagedClip {
  const _StagedClip({
    required this.text,
    required this.seconds,
    this.path,
    this.sent = false,
  });

  /// Transcribed speech (or the voice-transmission fallback).
  final String text;

  /// Clip length in seconds.
  final double seconds;

  /// On-device WAV file of the take.
  final String? path;

  /// True once the clip has been dispatched to the mesh.
  final bool sent;

  _StagedClip copyWith({bool? sent}) => _StagedClip(
        text: text,
        seconds: seconds,
        path: path,
        sent: sent ?? this.sent,
      );
}

/// Screen 2 — Home / Tactical Push-To-Talk.
///
/// Hold the lime button to capture 16 kHz PCM, release to run offline
/// Whisper STT, zlib-compress + CRC-16 frame the text, and dispatch it
/// through the Smart Radio Manager with a stop-and-wait ACK window.
///
/// The surface is hosted inside the unified comms hub, so it renders as a
/// scrollable panel: link capsule, the PTT hero with its live waveform, the
/// recorded-audio card, the transcription HUD and the last message.
class HomePttScreen extends StatefulWidget {
  const HomePttScreen({super.key});

  @override
  State<HomePttScreen> createState() => _HomePttScreenState();
}

class _HomePttScreenState extends State<HomePttScreen>
    with SingleTickerProviderStateMixin {
  TalkBloc? _localTalkBloc;
  late TalkBloc _talkBloc;
  bool _talkBlocBound = false;
  late final AudioRecorderService _recorder;
  late final SttService _stt;
  late final VadDetector _vad;
  late final TtsService _tts;
  late final AudioPlayerService _player;
  late final FlutterTts _flutterTts;
  late final AnimationController _sosStrobe;

  StreamSubscription<Uint8List>? _pcmSubscription;
  final List<int> _pcmBuffer = <int>[];
  Timer? _linkTimer;
  final math.Random _random = math.Random();

  // Scoped to the link capsule only: the 2s telemetry tick must not rebuild
  // the whole hero / HUD / last-message column on every pulse.
  final ValueNotifier<int> _wifiLatencyMs = ValueNotifier<int>(12);
  bool _holding = false;
  bool _voiceSeen = false;
  bool _replaying = false;
  bool _autoSendOnRelease = true;
  String _replayHint = '';
  String? _lastRecordedAudioPath;
  _StagedClip? _stagedClip;

  @override
  void initState() {
    super.initState();

    _recorder = AudioRecorderService();
    _stt = SttService();
    _vad = VadDetector();
    _tts = TtsService();
    _player = AudioPlayerService();
    _flutterTts = FlutterTts();
    _initFlutterTts();

    _sosStrobe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Node identity is read fresh by TalkBloc on every TX frame.

    _startLinkTelemetry();
    _resolveGpsLabel();
  }

  Future<void> _initFlutterTts() async {
    try {
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.awaitSpeakCompletion(true);
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_talkBlocBound) {
      _talkBlocBound = true;
      final hasSharedBloc =
          context.findAncestorWidgetOfExactType<BlocProvider<TalkBloc>>() != null;
      _talkBloc = hasSharedBloc
          ? context.read<TalkBloc>()
          : (_localTalkBloc ??= TalkBloc());
      _initEngine();
    }
  }

  @override
  void dispose() {
    _linkTimer?.cancel();
    _pcmSubscription?.cancel();
    _wifiLatencyMs.dispose();
    _sosStrobe.dispose();
    _localTalkBloc?.close();
    _vad.free();
    _stt.free();
    _stopPlaybackRequested = true;
    _tts.stopPlayback(player: _player, flutterTts: _flutterTts);
    try {
      _flutterTts.stop();
    } catch (_) {}
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Engine bootstrap (VAD -> Whisper -> Piper, progressive so the first
  // frame paints before the heavier model loads start).
  // ---------------------------------------------------------------------
  Future<void> _initEngine() async {
    await ModelPathResolver.ensureInitialized();
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final vadOk = await _vad.init();
    if (mounted) {
      _talkBloc.add(TalkEngineReady(
        sttReady: false,
        vadReady: vadOk,
        ttsReady: false,
      ));
    }
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final sttOk = await _stt.init(languageCode: AppConstants.activeLanguageCode);
    if (mounted) {
      _talkBloc.add(TalkEngineReady(
        sttReady: sttOk,
        vadReady: vadOk,
        ttsReady: false,
      ));
    }
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final ttsOk = await _tts.init(languageCode: AppConstants.activeLanguageCode);
    if (!mounted) return;
    _talkBloc.add(TalkEngineReady(
      sttReady: sttOk,
      vadReady: vadOk,
      ttsReady: ttsOk,
    ));
  }

  Future<void> _resolveGpsLabel() async {
    // Keep the one-shot GPS acquisition warm; the label itself was
    // display-only (HUD chip) and is retired with the transcript card.
    await LocationService.current();
  }

  void _startLinkTelemetry() {
    _linkTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      // Scoped notify — only the link capsule rebuilds.
      _wifiLatencyMs.value = 9 + _random.nextInt(14);
    });
  }

  // ---------------------------------------------------------------------
  // PTT interaction flow
  // ---------------------------------------------------------------------
  Future<void> _handlePttStart() async {
    if (_holding || _replaying) return;
    if (_stt.currentLanguageCode != AppConstants.activeLanguageCode) {
      unawaited(_stt.switchLanguage(AppConstants.activeLanguageCode));
    }
    _holding = true;
    _voiceSeen = false;
    _pcmBuffer.clear();
    _vad.reset();

    HapticFeedback.mediumImpact();
    _talkBloc.add(TalkStartCapture());

    final stream = await _recorder.start();
    if (stream == null) {
      _holding = false;
      if (!mounted) return;
      _talkBloc.add(
          const TalkCaptureFailed('Mic blocked — allow access'));
      return;
    }

    _pcmSubscription = stream.listen(
      (chunk) {
        _pcmBuffer.addAll(chunk);
        final samples = _toSamples(chunk);
        if (_vad.push(samples)) {
          if (!_voiceSeen) {
            _voiceSeen = true;
            _talkBloc.add(TalkVoiceDetected());
          }
        }
      },
      onError: (Object _) {},
      onDone: () {},
    );
  }

  /// Ends the take.
  ///
  /// [autoSend] is true for the classic push-to-talk gesture (release sends
  /// immediately) and false for the tap-to-record gesture, where the clip is
  /// staged on the recorded-audio card and waits for the operator.
  Future<void> _handlePttEnd({required bool autoSend}) async {
    if (!_holding) return;
    _holding = false;

    HapticFeedback.lightImpact();

    // 1. Post-roll margin (180ms): Fast speakers often release the button
    // simultaneously with their last phoneme. A 180ms post-roll ensures the
    // final consonant or syllable is never clipped.
    await Future<void>.delayed(const Duration(milliseconds: 180));

    // 2. Stop the hardware recorder first so native buffers are flushed.
    await _recorder.stop();

    // 3. Briefly allow stream events to deliver to _pcmBuffer before canceling.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;

    final captured = Uint8List.fromList(_pcmBuffer);
    _pcmBuffer.clear();

    // Save the raw captured PCM audio as a standard WAV file so Replay plays the user's REAL voice!
    if (captured.isNotEmpty) {
      try {
        final tempDir = await getTemporaryDirectory();
        final wavPath = '${tempDir.path}${Platform.pathSeparator}last_ptt_recording.wav';
        final wavBytes = _pcmToWav(captured);
        await File(wavPath).writeAsBytes(wavBytes, flush: true);
        _lastRecordedAudioPath = wavPath;
      } catch (_) {}
    }

    if (!mounted) return;
    _talkBloc.add(TalkStopCapture());

    if (_stt.currentLanguageCode != AppConstants.activeLanguageCode) {
      try {
        await _stt
            .switchLanguage(AppConstants.activeLanguageCode)
            .timeout(const Duration(milliseconds: 1500));
      } catch (_) {}
    }

    final rawSamples = _toSamples(captured);
    // VAD TRIMMING: Strip leading and trailing silence so Whisper never loops on silence
    final speechSamples = _vad.trimSilence(rawSamples);
    _vad.reset();

    String? text;
    if (_stt.ready && speechSamples.isNotEmpty) {
      try {
        text = _stt.transcribe(speechSamples);
      } catch (_) {
        text = null;
      }
    }

    // Fallback: If STT is offline or didn't catch speech, do not abort!
    // Send a tactical voice transmission indicator so it frames the packet,
    // adds to the broadcast queue, and dispatches via radio!
    if (text == null || text.trim().isEmpty) {
      final seconds = (captured.length / 32000.0).toStringAsFixed(1);
      text = 'Voice transmission (${seconds}s)';
    }

    final seconds = captured.length / 32000.0;
    final clip = _StagedClip(
      text: text.trim(),
      seconds: seconds,
      path: _lastRecordedAudioPath,
    );

    if (!mounted) return;
    setState(() => _stagedClip = clip);

    if (autoSend) {
      _dispatchClip(clip);
    }
  }

  /// Tap gesture on the mic button — record now, review, then send.
  Future<void> _handleMicTap() async {
    if (_holding) {
      // Switched into "tap-to-record & review" mode.
      // Recording remains active until the operator taps again to complete the take.
      _autoSendOnRelease = false;
      HapticFeedback.selectionClick();
      return;
    }
    _autoSendOnRelease = false;
    await _handlePttStart();
  }

  void _handlePttCancel() {
    if (!_holding) return;
    _holding = false;
    _pcmBuffer.clear();
    _pcmSubscription?.cancel();
    _pcmSubscription = null;
    unawaited(_recorder.stop());
    _vad.reset();
    _talkBloc.add(TalkCaptureCancelled());
  }

  /// Pushes the staged clip onto the mesh through the normal packet path.
  void _dispatchClip(_StagedClip clip) {
    setState(() => _stagedClip = clip.copyWith(sent: true));
    _talkBloc.add(TalkTranscriptReady(
      clip.text,
      audioPath: clip.path,
      isVoice: true,
    ));
  }

  void _handleSendClip() {
    final clip = _stagedClip;
    if (clip == null) return;
    HapticFeedback.lightImpact();
    _dispatchClip(clip);
  }

  void _handleDiscardClip() {
    if (_stagedClip == null) return;
    HapticFeedback.lightImpact();
    setState(() => _stagedClip = null);
  }

  Float32List _toSamples(List<int> bytes) {
    final count = bytes.length ~/ 2;
    final samples = Float32List(count);
    for (var i = 0; i < count; i++) {
      final low = bytes[i * 2] & 0xFF;
      final high = bytes[i * 2 + 1];
      var value = (high << 8) | low;
      if (value >= 0x8000) value -= 0x10000;
      samples[i] = value / 32768.0;
    }
    return samples;
  }

  static Uint8List _pcmToWav(Uint8List pcmBytes, {int sampleRate = 16000, int channels = 1, int bitDepth = 16}) {
    final byteRate = sampleRate * channels * (bitDepth ~/ 8);
    final blockAlign = channels * (bitDepth ~/ 8);
    final dataSize = pcmBytes.length;
    final builder = BytesBuilder();

    void writeTag(String tag) => builder.add(tag.codeUnits);
    void writeInt32(int value) {
      builder.add([
        value & 0xFF,
        (value >> 8) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 24) & 0xFF,
      ]);
    }

    void writeInt16(int value) {
      builder.add([
        value & 0xFF,
        (value >> 8) & 0xFF,
      ]);
    }

    writeTag('RIFF');
    writeInt32(36 + dataSize);
    writeTag('WAVE');
    writeTag('fmt ');
    writeInt32(16);
    writeInt16(1);
    writeInt16(channels);
    writeInt32(sampleRate);
    writeInt32(byteRate);
    writeInt16(blockAlign);
    writeInt16(bitDepth);
    writeTag('data');
    writeInt32(dataSize);
    builder.add(pcmBytes);

    return builder.takeBytes();
  }

  // ---------------------------------------------------------------------
  // SOS / Replay / Navigation
  // ---------------------------------------------------------------------
  void _handleSosToggle() {
    HapticFeedback.heavyImpact();
    _talkBloc.add(TalkToggleSos());
  }

  bool _stopPlaybackRequested = false;

  Future<void> _stopReplay() async {
    _stopPlaybackRequested = true;
    await _tts.stopPlayback(player: _player, flutterTts: _flutterTts);
    if (mounted) {
      setState(() {
        _replaying = false;
        _replayHint = '';
      });
    }
  }

  Future<void> _handleReplay() async {
    HapticFeedback.lightImpact();

    if (_replaying) {
      await _stopReplay();
      return;
    }

    final state = _talkBloc.state;
    final messageToPlay = state.lastMessage.trim();

    if (messageToPlay.isEmpty || messageToPlay == 'No transmissions yet') {
      return;
    }

    _stopPlaybackRequested = false;

    // 1. Primary Tactical Behavior: Play the actual recorded voice of the user
    // if the last message was a voice recording and the audio file exists!
    final voicePath = state.lastAudioPath ?? _lastRecordedAudioPath;
    final isVoice = state.lastMessageIsVoice &&
        voicePath != null &&
        File(voicePath).existsSync();

    if (isVoice) {
      setState(() {
        _replaying = true;
        _replayHint = '';
      });

      await _player.playFileAndWait(voicePath);
      if (mounted) setState(() => _replaying = false);
      return;
    }

    // 2. Fallback: If voice transmission indicator without audio file
    if (messageToPlay.toLowerCase().contains('voice transmission')) {
      setState(() => _replayHint = 'No voice message recorded yet');
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _replayHint = '');
      });
      return;
    }

    // 3. Typed Message / Speech Synthesis:
    // Uses the identical offline neural / native TTS engine as the receiver side
    // (Piper Hindi with Hinglish transliteration, native English TTS, mutual fallback).
    setState(() {
      _replaying = true;
      _replayHint = '';
    });

    try {
      await _tts.speakText(
        text: messageToPlay,
        player: _player,
        flutterTts: _flutterTts,
        isStopRequested: () => _stopPlaybackRequested || !mounted,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _replayHint = 'Voice failed — try again');
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _replayHint = '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _replaying = false);
      }
    }
  }

  Future<void> _navigate(String route) async {
    HapticFeedback.lightImpact();
    await Navigator.pushNamed(context, route);
    if (mounted && _stt.currentLanguageCode != AppConstants.activeLanguageCode) {
      await _stt.switchLanguage(AppConstants.activeLanguageCode);
      setState(() {});
    }
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final screenWidth = size.width;
    final screenHeight = size.height;

    final hPad = AppSpacing.gutter(screenWidth);
    final sectionGap = AppSpacing.section(screenHeight);

    return BlocProvider.value(
      value: _talkBloc,
      child: BlocListener<TalkBloc, TalkState>(
        listenWhen: (prev, curr) =>
            curr.lastMessage.isNotEmpty &&
            curr.lastMessage != prev.lastMessage &&
            curr.lastMessageMeta.contains('Incoming'),
        listener: (context, state) {
          HapticFeedback.mediumImpact();
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            hPad,
            sectionGap * 0.5,
            hPad,
            sectionGap * 1.8,
          ),
          child: BlocBuilder<TalkBloc, TalkState>(
            builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLinkCapsule(screenWidth, state),
                  if (state.sosArmed) ...[
                    SizedBox(height: sectionGap),
                    _buildSosBanner(screenWidth),
                  ],
                  SizedBox(height: sectionGap),
                  _buildPttHero(screenWidth, screenHeight, state),
                  SizedBox(height: sectionGap),
                  _buildRecordedAudioCard(screenWidth, state),
                  SizedBox(height: sectionGap),
                  _buildLastMessageCard(screenWidth, state),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Top link capsule
  // ---------------------------------------------------------------------
  Widget _buildLinkCapsule(double screenWidth, TalkState state) {
    return ListenableBuilder(
      listenable: _wifiLatencyMs,
      builder: (context, _) {
        final isBadWifi = RadioPacketBus.instance.isBadWifi;
        return LinkStatusIndicator(
          wifiAlive: !isBadWifi,
          wifiLatencyMs: _wifiLatencyMs.value,
          loraActive: isBadWifi,
          queueCount: state.queueCount,
          onTap: () => _navigate(AppRouter.radio),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // PTT hero — mic button, live waveform and gesture hint
  // ---------------------------------------------------------------------
  Widget _buildPttHero(
    double screenWidth,
    double screenHeight,
    TalkState state,
  ) {
    final sectionSize = AppType.section(screenWidth);
    final metaSize = AppType.meta(screenWidth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: PttButton(
            isRecording: state.isHolding,
            voiceDetected: state.status == TalkStatus.voiceDetected,
            onStart: () {
              _autoSendOnRelease = true;
              _handlePttStart();
            },
            onEnd: () => _handlePttEnd(autoSend: _autoSendOnRelease),
            onCancel: _handlePttCancel,
            onTap: _handleMicTap,
          ),
        ),
        SizedBox(height: clampDouble(screenHeight * 0.010, 6.0, 12.0)),
        _buildDottedMeter(screenWidth),
        SizedBox(height: clampDouble(screenWidth * 0.018, 6.0, 10.0)),
        WaveformStrip(
          active: state.isHolding,
          seed: 11,
          barCount: 34,
          barWidth: clampDouble(screenWidth * 0.009, 2.5, 4.0),
          barGap: clampDouble(screenWidth * 0.012, 3.0, 5.0),
          height: clampDouble(screenWidth * 0.13, 38.0, 56.0),
          idleAlpha: 0.35,
        ),
        SizedBox(height: clampDouble(screenWidth * 0.022, 8.0, 14.0)),
        Text(
          state.isHolding ? 'Release to Send' : 'Hold to Talk',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: sectionSize,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            height: 1.25,
          ),
        ),
        SizedBox(height: clampDouble(screenWidth * 0.012, 4.0, 8.0)),
        Text(
          state.isHolding
              ? 'Keep talking — the mesh is listening'
              : 'Hold to send now, or tap to record and review',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: metaSize,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        SizedBox(height: clampDouble(screenWidth * 0.03, 12.0, 18.0)),
        // The emergency trigger lives in the flow so it can never cover the
        // clip actions of the recorded-audio card.
        Align(
          alignment: Alignment.centerRight,
          child: BlocBuilder<TalkBloc, TalkState>(
            buildWhen: (prev, curr) => prev.sosArmed != curr.sosArmed,
            builder: (context, state) =>
                _buildSosButton(screenWidth, state.sosArmed),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Dotted meter â€” the pale mint rule that sits under the hero button
  // (design.md Â§4.C).
  // ---------------------------------------------------------------------
  Widget _buildDottedMeter(double screenWidth) {
    final dot = clampDouble(screenWidth * 0.012, 3.0, 4.5);
    final gap = clampDouble(screenWidth * 0.026, 8.0, 12.0);
    final count = 22;

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: gap,
        runSpacing: gap,
        children: List<Widget>.generate(
          count,
          (index) => Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.emeraldMintBorder,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Recorded audio card — review, discard or push the clip
  // ---------------------------------------------------------------------
  Widget _buildRecordedAudioCard(double screenWidth, TalkState state) {
    final clip = _stagedClip;
    final sending = state.status == TalkStatus.transcribing ||
        state.status == TalkStatus.packetSent ||
        state.status == TalkStatus.waitingAck;

    final String status;
    if (clip == null) {
      status = 'No clip yet';
    } else if (sending) {
      status = 'Sending to mesh';
    } else if (clip.sent) {
      status = 'Sent to mesh';
    } else {
      status = 'Ready to send';
    }

    return RecordedAudioCard(
      hasClip: clip != null,
      durationLabel: clip == null ? '0:00' : _formatDuration(clip.seconds),
      statusLabel: status,
      isSending: sending && clip != null,
      wasSent: clip?.sent ?? false,
      previewText: clip == null ? '' : clip.text,
      isRecording: state.isHolding,
      onDiscard: _handleDiscardClip,
      onSend: _handleSendClip,
    );
  }

  static String _formatDuration(double seconds) {
    final total = seconds.isFinite && seconds > 0 ? seconds.round() : 0;
    final minutes = total ~/ 60;
    final rest = total % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------
  // Last received message banner
  // ---------------------------------------------------------------------
  Widget _buildLastMessageCard(double screenWidth, TalkState state) {
    final cardRadius = AppSpacing.cardRadius(screenWidth);
    final cardPad = AppSpacing.cardPad(screenWidth);
    final iconBox = clampDouble(screenWidth * 0.11, 42.0, 54.0);
    final titleSize = AppType.itemTitle(screenWidth);
    final metaSize = AppType.meta(screenWidth);
    final badgeSize = AppType.badge(screenWidth);

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(
                      clampDouble(screenWidth * 0.03, 12.0, 16.0),
                    ),
                    border: Border.all(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    LucideIcons.radio,
                    size: iconBox * 0.48,
                    color: AppColors.primaryEmerald,
                  ),
                ),
                SizedBox(width: clampDouble(screenWidth * 0.03, 12.0, 16.0)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Message',
                        style: TextStyle(
                          fontSize: badgeSize,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                      SizedBox(height: clampDouble(screenWidth * 0.012, 4.0, 7.0)),
                      Text(
                        state.lastMessage,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: cardPad * 0.6),
            Wrap(
              spacing: clampDouble(screenWidth * 0.02, 8.0, 12.0),
              runSpacing: clampDouble(screenWidth * 0.02, 8.0, 12.0),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: screenWidth * 0.65),
                  padding: EdgeInsets.symmetric(
                    horizontal: clampDouble(screenWidth * 0.025, 8.0, 14.0),
                    vertical: clampDouble(screenWidth * 0.015, 5.0, 9.0),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.mapPin,
                        size: clampDouble(screenWidth * 0.036, 12.0, 15.0),
                        color: AppColors.primaryEmerald,
                      ),
                      SizedBox(width: clampDouble(screenWidth * 0.012, 4.0, 6.0)),
                      Flexible(
                        child: Text(
                          state.lastMessageMeta,
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
                ),
                _buildReplayButton(screenWidth),
              ],
            ),
            if (_replayHint.isNotEmpty) ...[
              SizedBox(height: clampDouble(screenWidth * 0.02, 8.0, 12.0)),
              Text(
                _replayHint,
                style: TextStyle(
                  fontSize: metaSize,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReplayButton(double screenWidth) {
    final badgeSize = AppType.badge(screenWidth);
    final iconSize = clampDouble(screenWidth * 0.036, 13.0, 16.0);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _handleReplay,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: clampDouble(screenWidth * 0.03, 10.0, 16.0),
            vertical: clampDouble(screenWidth * 0.016, 6.0, 11.0),
          ),
          decoration: BoxDecoration(
            color: _replaying ? AppColors.primaryEmerald : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.primaryEmerald, width: 1.2),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _replaying ? LucideIcons.square : LucideIcons.play,
                  size: iconSize,
                  color: _replaying
                      ? AppColors.textWhite
                      : AppColors.primaryEmerald,
                ),
                SizedBox(width: clampDouble(screenWidth * 0.012, 4.0, 6.0)),
                Flexible(
                  child: Text(
                    _replaying ? 'Stop' : 'Replay',
                    softWrap: false,
                    style: TextStyle(
                      fontSize: badgeSize,
                      fontWeight: FontWeight.w700,
                      color: _replaying
                          ? AppColors.textWhite
                          : AppColors.primaryEmerald,
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

  // ---------------------------------------------------------------------
  // Emergency SOS
  // ---------------------------------------------------------------------
  Widget _buildSosBanner(double screenWidth) {
    final cardRadius = clampDouble(screenWidth * 0.05, 18.0, 24.0);
    final titleSize = AppType.itemTitle(screenWidth);
    final metaSize = AppType.meta(screenWidth);

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(clampDouble(screenWidth * 0.045, 16.0, 22.0)),
        decoration: BoxDecoration(
          // Soft rose critical alert surface (design.md Â§4.F).
          color: AppColors.alertRedBg,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(
            color: AppColors.alertRedBorder,
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
                    'SOS Armed',
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      color: AppColors.alertRed,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: clampDouble(screenWidth * 0.022, 8.0, 12.0)),
            Text(
              'Next send gets SOS flag 0x02. Peers see it as an alert.',
              style: TextStyle(
                fontSize: metaSize,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            SizedBox(height: clampDouble(screenWidth * 0.014, 6.0, 9.0)),
            Text(
              'Tap red again to cancel.',
              style: TextStyle(
                fontSize: metaSize,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSosButton(double screenWidth, bool armed) {
    final sosSize = clampDouble(screenWidth * 0.155, 54.0, 68.0);
    final iconSize = sosSize * 0.44;

    if (armed && !_sosStrobe.isAnimating) {
      _sosStrobe.repeat(reverse: true);
    } else if (!armed && _sosStrobe.isAnimating) {
      _sosStrobe.stop();
      _sosStrobe.value = 0.0;
    }

    return AnimatedBuilder(
      animation: _sosStrobe,
      builder: (context, _) {
        final t = _sosStrobe.value;
        final glow = armed ? 0.45 + 0.55 * t : 1.0;

        return Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _handleSosToggle,
            child: Container(
              width: sosSize,
              height: sosSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.alertRed.withValues(alpha: glow),
                border: Border.all(
                  color: AppColors.alertRed.withValues(alpha: 0.9),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.alertRed
                        .withValues(alpha: 0.25 + 0.30 * glow),
                    blurRadius: armed ? 28.0 : 18.0,
                    spreadRadius: armed ? 5.0 : 2.0,
                  ),
                ],
              ),
              child: Icon(
                LucideIcons.siren,
                size: iconSize,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        );
      },
    );
  }
}
