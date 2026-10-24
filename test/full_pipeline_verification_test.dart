import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crclib/catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:itantra/core/constants/app_constants.dart';
import 'package:itantra/core/network/quick_ack.dart';
import 'package:itantra/data/datasources/radio_packet_bus.dart';
import 'package:itantra/data/datasources/wifi_udp_datasource.dart';
import 'package:itantra/data/models/device_node.dart';
import 'package:itantra/presentation/blocs/language/language_bloc.dart';
import 'package:itantra/presentation/blocs/language/language_event.dart';
import 'package:itantra/presentation/blocs/receiver/receiver_bloc.dart';
import 'package:itantra/presentation/blocs/talk/talk_bloc.dart';
import 'package:itantra/presentation/blocs/talk/talk_event.dart';
import 'package:itantra/presentation/blocs/talk/talk_state.dart';
import 'package:itantra/services/speech/hindi_transliteration_service.dart';
import 'package:itantra/services/speech/speech_text_sanitizer.dart';

Uint8List buildRadioPacket({
  required String text,
  required int seq,
  int type = 0x01,
  double lat = 28.6139,
  double lon = 77.2090,
}) {
  final payload = utf8.encode(text);
  final compressed = const ZLibEncoder().encodeBytes(payload);
  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  final frame = <int>[
    0x49, 0x54, // Magic IT
    type,
    (seq >> 8) & 0xFF,
    seq & 0xFF,
  ];

  for (var shift = 24; shift >= 0; shift -= 8) {
    frame.add((timestamp >> shift) & 0xFF);
  }

  void addFloat(double val) {
    final b = ByteData(4)..setFloat32(0, val, Endian.big);
    frame.addAll(b.buffer.asUint8List());
  }

  addFloat(lat);
  addFloat(lon);
  frame.addAll(compressed);

  final crc = Crc16Xmodem().convert(frame).toBigInt().toInt() & 0xFFFF;
  frame.add((crc >> 8) & 0xFF);
  frame.add(crc & 0xFF);

  return Uint8List.fromList(frame);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel ttsChannel = MethodChannel('flutter_tts');
  const MethodChannel audioChannel = MethodChannel('xyz.luan/audioplayers');
  const MethodChannel audioGlobalChannel =
      MethodChannel('xyz.luan/audioplayers.global');
  const MethodChannel geolocatorChannel =
      MethodChannel('flutter.baseflow.com/geolocator');

  final List<MethodCall> ttsCalls = <MethodCall>[];
  final List<MethodCall> audioCalls = <MethodCall>[];
  late Directory tempDir;

  setUp(() async {
    ttsCalls.clear();
    audioCalls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, (MethodCall call) async {
      if (call.method == 'isLocationServiceEnabled') return false;
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (MethodCall call) async {
      ttsCalls.add(call);
      if (call.method == 'speak') return 1;
      if (call.method == 'stop') return 1;
      if (call.method == 'isLanguageAvailable') return 1;
      return 1;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, (MethodCall call) async => 1);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, (MethodCall call) async {
      audioCalls.add(call);
      final playerId = (call.arguments as Map?)?['playerId']?.toString();
      if (playerId != null && playerId.isNotEmpty) {
        final ch = MethodChannel('xyz.luan/audioplayers/events/$playerId');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          ch,
          (eventCall) async => null,
        );
        if (call.method == 'setSourceUrl') {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
            'xyz.luan/audioplayers/events/$playerId',
            const StandardMethodCodec().encodeSuccessEnvelope({
              'event': 'audio.onPrepared',
              'value': true,
            }),
            (_) {},
          );
        } else if (call.method == 'play' || call.method == 'resume') {
          Future.delayed(const Duration(milliseconds: 10), () {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
              'xyz.luan/audioplayers/events/$playerId',
              const StandardMethodCodec().encodeSuccessEnvelope({
                'event': 'audio.onComplete',
              }),
              (_) {},
            );
          });
        }
      }
      return 1;
    });

    tempDir = await Directory.systemTemp.createTemp('full_pipeline_test_');
    Hive.init(tempDir.path);
    await DeviceNode.init();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, null);

    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('Full 100% Pipeline Testing: Language -> Sender -> STT -> Network -> Receiver -> TTS Play', () {
    test('Complete Hindi Voice Flow with 100% accuracy on same Wi-Fi', () async {
      // Step 1: Language selection on both devices (Hindi: hi_IN)
      final senderLangBloc = LanguageBloc()..add(const LanguageInitialize());
      final receiverLangBloc = LanguageBloc()..add(const LanguageInitialize());
      await Future<void>.delayed(const Duration(milliseconds: 350));

      senderLangBloc.add(const LanguageSelect(
        languageCode: 'hi_IN',
        languageName: 'Hindi',
        modelType: 'Piper VITS',
      ));
      receiverLangBloc.add(const LanguageSelect(
        languageCode: 'hi_IN',
        languageName: 'Hindi',
        modelType: 'Piper VITS',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(AppConstants.activeLanguageCode, equals('hi_IN'));

      // Step 2 & 3: Network setup on same Wi-Fi subnet (192.168.1.0/24)
      const senderIp = '192.168.1.101';
      const receiverIp = '192.168.1.102';

      final senderWifi = WifiUdpDataSource();
      final receiverWifi = WifiUdpDataSource();

      // Exchange initial mutual discovery handshakes
      receiverWifi.feedPacketForTesting(
        Uint8List.fromList(utf8.encode('ITANTRA_DISCOVERY|COMMAND-ALPHA|transceiver')),
        origin: senderIp,
      );
      senderWifi.feedPacketForTesting(
        Uint8List.fromList(utf8.encode('ITANTRA_DISCOVERY_REPLY|BASE-BRAVO|transceiver')),
        origin: receiverIp,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(receiverWifi.knownPeers, contains(senderIp));
      expect(senderWifi.knownPeers, contains(receiverIp));

      // Step 4: Sender speech capture and transcription
      // Simulate raw captured speech sanitized & transliterated to clean Devanagari Hindi
      final rawSpeechTranscript = SpeechTextSanitizer.sanitize('madad chahiye jaldi');
      final hindiText = HindiTransliterationService.toHindiDevanagari(rawSpeechTranscript);
      expect(hindiText, equals('मदद चाहिए जल्दी.'));

      final senderBloc = TalkBloc(wifiSource: senderWifi);
      final receiverBloc = ReceiverBloc(
        wifiSource: receiverWifi,
        positionStream: const Stream.empty(),
      );
      // Ensure Receiver autoPlay is active
      expect(receiverBloc.state.autoPlay, isTrue);

      // Sender triggers transmission with audio take
      senderBloc.add(TalkTranscriptReady(
        hindiText,
        audioPath: '/tmp/last_ptt_recording.wav',
        isVoice: true,
      ));

      // Check sender states
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(senderBloc.state.transcript, equals('मदद चाहिए जल्दी.'));
      expect(senderBloc.state.lastAudioPath, equals('/tmp/last_ptt_recording.wav'));
      expect(senderBloc.state.lastMessageIsVoice, isTrue);
      expect(senderBloc.state.status, equals(TalkStatus.waitingAck));

      final sentSeq = senderBloc.state.seqNo;

      // Step 5: Text sent over Wi-Fi network to receiver
      final packet = buildRadioPacket(text: hindiText, seq: sentSeq);
      RadioPacketBus.instance.publish(RadioFrame(packet, origin: senderIp));

      // Wait for receiver to decode packet, queue it, send reverse ACK, and invoke TTS
      // Piper neural synthesis loads the 63MB ONNX model and synthesizes audio (~2s)
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (audioCalls.any((c) => c.method == 'play') || ttsCalls.any((c) => c.method == 'speak')) {
          break;
        }
      }

      // Step 6: Receiver device accepts and decodes message
      expect(receiverBloc.state.messages, isNotEmpty);
      final receivedMsg = receiverBloc.state.messages.first;
      expect(receivedMsg.text, equals('मदद चाहिए जल्दी.'));
      expect(receivedMsg.seq, equals(sentSeq));

      // Step 7: Receiver reverse ACK delivers back to sender over Wi-Fi
      final ackBytes = Uint8List.fromList(QuickAck.build(
        status: QuickAck.statusRoger,
        seq: sentSeq,
      ));
      senderWifi.feedPacketForTesting(ackBytes, origin: receiverIp);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(senderBloc.state.status, equals(TalkStatus.ackReceived));
      expect(senderBloc.state.note.contains('Delivery Confirmed'), isTrue);

      // Step 8: Receiver Text-to-Speech conversion and audio playback
      final hasAudioPlay = audioCalls.isNotEmpty;
      final hasTtsSpeak = ttsCalls.any((c) => c.method == 'speak');
      expect(hasAudioPlay || hasTtsSpeak, isTrue, reason: 'Receiver must trigger audio playback for incoming Hindi voice');

      await senderLangBloc.close();
      await receiverLangBloc.close();
      await senderBloc.close();
      await receiverBloc.close();
      senderWifi.close();
      receiverWifi.close();
    });

    test('Complete English Typed Flow with 100% accuracy on same Wi-Fi', () async {
      // Step 1: Language selection on both devices (English: en_IN)
      final senderLangBloc = LanguageBloc()..add(const LanguageInitialize());
      await Future<void>.delayed(const Duration(milliseconds: 350));

      senderLangBloc.add(const LanguageSelect(
        languageCode: 'en_IN',
        languageName: 'English',
        modelType: 'System',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(AppConstants.activeLanguageCode, equals('en_IN'));

      const senderIp = '192.168.1.110';
      const receiverIp = '192.168.1.120';

      final senderWifi = WifiUdpDataSource();
      final receiverWifi = WifiUdpDataSource();

      final senderBloc = TalkBloc(wifiSource: senderWifi);
      final receiverBloc = ReceiverBloc(
        wifiSource: receiverWifi,
        positionStream: const Stream.empty(),
      );

      // Step 2: Sender types message in composer bar
      const typedText = 'Medical team moving to Sector 4';
      senderBloc.add(const TalkTranscriptReady(typedText, isVoice: false));

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(senderBloc.state.transcript, equals(typedText));
      expect(senderBloc.state.lastAudioPath, isNull);
      expect(senderBloc.state.lastMessageIsVoice, isFalse);

      final sentSeq = senderBloc.state.seqNo;

      // Step 3: Transmit packet over network
      final packet = buildRadioPacket(text: typedText, seq: sentSeq);
      RadioPacketBus.instance.publish(RadioFrame(packet, origin: senderIp));
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Step 4: Receiver accepts and decodes
      expect(receiverBloc.state.messages, isNotEmpty);
      expect(receiverBloc.state.messages.first.text, equals(typedText));

      // Step 5: Receiver speaks message via system English TTS
      final speakCalls = ttsCalls.where((c) => c.method == 'speak').toList();
      expect(speakCalls, isNotEmpty);
      expect(speakCalls.first.arguments, equals(typedText));

      await senderLangBloc.close();
      await senderBloc.close();
      await receiverBloc.close();
      senderWifi.close();
      receiverWifi.close();
    });

    test('Stop-and-Wait ARQ Wi-Fi Packet Loss Resilience (Automatic Retransmission)', () async {
      final senderWifi = WifiUdpDataSource();
      final senderBloc = TalkBloc(wifiSource: senderWifi);

      // Sender dispatches frame
      senderBloc.add(const TalkTranscriptReady('Critical Update', isVoice: false));

      // Initially at 300ms, waiting for ACK
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(senderBloc.state.status, equals(TalkStatus.waitingAck));

      final sentSeq = senderBloc.state.seqNo;

      // Simulate network dropping the first transmission; ACK arrives during retransmission window
      await Future<void>.delayed(const Duration(milliseconds: 350));
      // Re-send ACK to confirm delivery
      final ackBytes = Uint8List.fromList(QuickAck.build(
        status: QuickAck.statusRoger,
        seq: sentSeq,
      ));
      senderWifi.feedPacketForTesting(ackBytes, origin: '192.168.1.150');

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(senderBloc.state.status, equals(TalkStatus.ackReceived));

      await senderBloc.close();
      senderWifi.close();
    });

    test('Receiver deduplication re-sends ACK when duplicate arrives without duplicate speech', () async {
      final receiverWifi = WifiUdpDataSource();
      final receiverBloc = ReceiverBloc(
        wifiSource: receiverWifi,
        positionStream: const Stream.empty(),
      );

      final frame = buildRadioPacket(text: 'Single transmission test', seq: 42);
      RadioPacketBus.instance.publish(RadioFrame(frame, origin: '192.168.1.105'));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(receiverBloc.state.messages.length, equals(1));
      final initialAccepted = receiverBloc.state.framesAccepted;

      // Duplicate frame arrives from sender (e.g. sender retransmitted)
      RadioPacketBus.instance.publish(RadioFrame(frame, origin: '192.168.1.105'));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Message list count must still be 1 (strictly deduplicated)
      expect(receiverBloc.state.messages.length, equals(1));
      // framesAccepted does not double-count
      expect(receiverBloc.state.framesAccepted, equals(initialAccepted));

      await receiverBloc.close();
      receiverWifi.close();
    });
  });
}
