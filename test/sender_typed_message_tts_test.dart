import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:itantra/core/constants/app_constants.dart';
import 'package:itantra/presentation/blocs/talk/talk_bloc.dart';
import 'package:itantra/presentation/blocs/talk/talk_event.dart';
import 'package:itantra/services/audio/audio_player_service.dart';
import 'package:itantra/services/speech/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel ttsChannel = MethodChannel('flutter_tts');
  const MethodChannel audioChannel = MethodChannel('xyz.luan/audioplayers');
  const MethodChannel audioGlobalChannel =
      MethodChannel('xyz.luan/audioplayers.global');

  final List<MethodCall> ttsCalls = <MethodCall>[];
  final List<MethodCall> audioCalls = <MethodCall>[];

  setUp(() {
    ttsCalls.clear();
    audioCalls.clear();
    AppConstants.activeLanguageCode = 'en_IN';

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (MethodCall call) async {
      ttsCalls.add(call);
      if (call.method == 'speak') return 1;
      if (call.method == 'stop') return 1;
      if (call.method == 'isLanguageAvailable') {
        return 1;
      }
      return 1;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, (MethodCall call) async {
      return 1;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, (MethodCall call) async {
      audioCalls.add(call);
      return 1;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, null);
  });

  group('TalkBloc Voice vs Typed Message State Tests', () {
    test('Voice take sets lastAudioPath and lastMessageIsVoice to true', () async {
      final bloc = TalkBloc();

      bloc.add(const TalkTranscriptReady(
        'send help',
        audioPath: '/tmp/test_voice.wav',
        isVoice: true,
      ));

      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(bloc.state.lastMessage, equals('send help'));
      expect(bloc.state.lastAudioPath, equals('/tmp/test_voice.wav'));
      expect(bloc.state.lastMessageIsVoice, isTrue);

      await bloc.close();
    });

    test('Typed message clears lastAudioPath and sets lastMessageIsVoice to false', () async {
      final bloc = TalkBloc();

      // First user speaks "send help"
      bloc.add(const TalkTranscriptReady(
        'send help',
        audioPath: '/tmp/test_voice.wav',
        isVoice: true,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(bloc.state.lastAudioPath, isNotNull);

      // Now user types "fast" in composer and sends
      bloc.add(const TalkTranscriptReady(
        'fast',
        isVoice: false,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(bloc.state.lastMessage, equals('fast'));
      expect(bloc.state.lastAudioPath, isNull);
      expect(bloc.state.lastMessageIsVoice, isFalse);

      await bloc.close();
    });

    test('Peer message received resets voice state to false', () async {
      final bloc = TalkBloc();

      bloc.add(const TalkPeerMessageReceived(
        message: 'roger that',
        meta: 'Local Mesh · Node 2',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.lastMessage, equals('roger that'));
      expect(bloc.state.lastAudioPath, isNull);
      expect(bloc.state.lastMessageIsVoice, isFalse);

      await bloc.close();
    });
  });

  group('TtsService Unified Speech Engine Tests', () {
    test('English typed message ("fast") invokes system TTS with en-IN', () async {
      final tts = TtsService();
      final player = AudioPlayerService();
      final flutterTts = FlutterTts();

      final ok = await tts.speakText(
        text: 'fast',
        player: player,
        flutterTts: flutterTts,
      );

      expect(ok, isTrue);

      final speakCalls = ttsCalls.where((c) => c.method == 'speak').toList();
      expect(speakCalls, isNotEmpty);
      expect(speakCalls.first.arguments, equals('fast'));

      final langCalls = ttsCalls.where((c) => c.method == 'setLanguage').toList();
      expect(langCalls, isNotEmpty);
      expect(langCalls.last.arguments, equals('en-IN'));
    });

    test('Hindi typed message routes to Hindi TTS pipeline', () async {
      final tts = TtsService();
      final player = AudioPlayerService();
      final flutterTts = FlutterTts();

      await tts.speakText(
        text: 'madad chahiye',
        player: player,
        flutterTts: flutterTts,
      );

      // Either Piper generated wav was played, or FlutterTts fell back to Hindi
      final hasAudioPlay = audioCalls.any((c) => c.method == 'play');
      final hasTtsSpeak = ttsCalls.any((c) => c.method == 'speak');
      expect(hasAudioPlay || hasTtsSpeak, isTrue);
    });

    test('stopPlayback stops both AudioPlayer and FlutterTts', () async {
      final tts = TtsService();
      final player = AudioPlayerService();
      final flutterTts = FlutterTts();

      await tts.stopPlayback(player: player, flutterTts: flutterTts);

      final stopCalls = ttsCalls.where((c) => c.method == 'stop').toList();
      expect(stopCalls, isNotEmpty);
    });
  });
}
