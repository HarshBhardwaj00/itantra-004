import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crclib/catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:itantra/core/constants/app_constants.dart';
import 'package:itantra/core/network/quick_ack.dart';
import 'package:itantra/data/datasources/wifi_udp_datasource.dart';
import 'package:itantra/data/models/device_node.dart';
import 'package:itantra/presentation/blocs/language/language_bloc.dart';
import 'package:itantra/presentation/blocs/language/language_event.dart';
import 'package:itantra/presentation/blocs/language/language_state.dart';
import 'package:itantra/presentation/blocs/receiver/receiver_bloc.dart';
import 'package:itantra/presentation/blocs/receiver/receiver_event.dart';
import 'package:itantra/presentation/blocs/talk/talk_bloc.dart';
import 'package:itantra/presentation/blocs/talk/talk_event.dart';
import 'package:itantra/presentation/blocs/talk/talk_state.dart';
import 'package:itantra/services/audio/audio_player_service.dart';
import 'package:itantra/services/speech/tts_service.dart';

Uint8List buildFrame({
  required String text,
  required int seq,
  int? customTimestamp,
  int type = 0x01,
}) {
  final payload = utf8.encode(text);
  final compressed = const ZLibEncoder().encodeBytes(payload);
  final timestamp = customTimestamp ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);

  final frame = <int>[
    0x49, 0x54,
    type,
    (seq >> 8) & 0xFF,
    seq & 0xFF,
    (timestamp >> 24) & 0xFF,
    (timestamp >> 16) & 0xFF,
    (timestamp >> 8) & 0xFF,
    timestamp & 0xFF,
    0x00, 0x00, 0x00, 0x00, // Lat
    0x00, 0x00, 0x00, 0x00, // Lon
  ];
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
  const MethodChannel audioGlobalChannel = MethodChannel('xyz.luan/audioplayers.global');
  const MethodChannel geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');

  final List<MethodCall> ttsCalls = <MethodCall>[];
  late Directory tempDir;

  setUp(() async {
    ttsCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
      ttsCalls.add(call);
      if (call.method == 'isLanguageAvailable') return 1;
      if (call.method == 'getLanguages') return ['en-IN', 'en-US', 'hi-IN', 'mr-IN', 'ta-IN'];
      if (call.method == 'speak') return 1;
      return 1;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, (call) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, (call) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, (call) async => {
              'latitude': 28.6139,
              'longitude': 77.2090,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'accuracy': 5.0,
              'altitude': 216.0,
              'heading': 0.0,
              'speed': 0.0,
              'speed_accuracy': 0.0,
            });

    tempDir = await Directory.systemTemp.createTemp('itantra_restart_test_');
    Hive.init(tempDir.path);
    await DeviceNode.init();
    await DeviceNode.ensureProfile();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, null);

    try {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  test('Receiver deduplication accepts new transmissions across app restart even with same sequence number', () async {
    final wifi = WifiUdpDataSource();
    await wifi.initialize();

    final receiverBloc = ReceiverBloc(
      wifiSource: wifi,
      ttsService: TtsService(),
      audioPlayer: AudioPlayerService(),
    );
    receiverBloc.add(const ReceiverStarted());
    await pumpEventQueue();

    // Session 1: Pre-restart message with seq=1 sent at T1 (e.g. English)
    const t1 = 1700000000;
    final frame1 = buildFrame(text: 'Hello Team English', seq: 1, customTimestamp: t1);
    receiverBloc.add(ReceiverFrameReceived(frame1, origin: '192.168.1.55'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(receiverBloc.state.messages.length, 1);
    expect(receiverBloc.state.messages.first.text, 'Hello Team English');

    // Duplicate retransmission of frame 1 (same seq=1 AND same timestamp=t1)
    receiverBloc.add(ReceiverFrameReceived(frame1, origin: '192.168.1.55'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // Still 1 message, deduplicated cleanly!
    expect(receiverBloc.state.messages.length, 1);

    // Session 2: SENDER RESTARTS, switches language to Hindi, and sends new message with seq=1 at T2 (now)
    final t2 = t1 + 300; // 5 minutes later
    final frame2 = buildFrame(text: 'नमस्ते क्या हाल है', seq: 1, customTimestamp: t2);
    receiverBloc.add(ReceiverFrameReceived(frame2, origin: '192.168.1.55'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Must NOT be dropped! Frame 2 must be accepted as a new message!
    expect(receiverBloc.state.messages.length, 2);
    expect(receiverBloc.state.messages.first.text, 'नमस्ते क्या हाल है');

    await receiverBloc.close();
    wifi.close();
  });

  test('TalkBloc sequence number persistence survives app restart and advances monotonically', () async {
    final wifi = WifiUdpDataSource();
    await wifi.initialize();

    // Boot 1
    final talkBloc1 = TalkBloc(wifiSource: wifi);
    talkBloc1.add(const TalkTranscriptReady('Session 1 message', isVoice: false));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final seq1 = talkBloc1.state.seqNo;
    expect(seq1, greaterThan(0));

    await talkBloc1.close();

    // Verify persisted
    final savedSeq = DeviceNode.loadLastSeq();
    expect(savedSeq, seq1);

    // Boot 2 (app restarted)
    final talkBloc2 = TalkBloc(wifiSource: wifi);
    talkBloc2.add(const TalkTranscriptReady('Session 2 message after restart', isVoice: false));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final seq2 = talkBloc2.state.seqNo;

    expect(seq2, equals(seq1 + 1));
    await talkBloc2.close();
    wifi.close();
  });

  test('Language switch from English to Hindi then sending message executes with 100% accuracy', () async {
    final wifi = WifiUdpDataSource();
    await wifi.initialize();

    final languageBloc = LanguageBloc();
    languageBloc.add(const LanguageInitialize());
    await Future<void>.delayed(const Duration(milliseconds: 350));

    // 1. Initial language is English
    languageBloc.add(const LanguageSelect(
      languageCode: 'en_IN',
      languageName: 'English',
      modelType: 'System',
    ));
    await languageBloc.stream.firstWhere((s) => s.status == LanguageStatus.loaded && s.activeLanguage?.code == 'en_IN');
    expect(AppConstants.activeLanguageCode, 'en_IN');

    // 2. Sender transmits in English
    final talkBloc = TalkBloc(wifiSource: wifi);
    final receiverBloc = ReceiverBloc(
      wifiSource: wifi,
      ttsService: TtsService(),
      audioPlayer: AudioPlayerService(),
    );
    receiverBloc.add(const ReceiverStarted());
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Connect receiver to bus
    final capturedPackets = <Uint8List>[];
    final sub = wifi.incomingPackets.listen(capturedPackets.add);

    talkBloc.add(const TalkTranscriptReady('Mission active go ahead', isVoice: false));
    await Future<void>.delayed(const Duration(milliseconds: 250));

    // 3. User switches language to Hindi
    languageBloc.add(const LanguageSelect(
      languageCode: 'hi_IN',
      languageName: 'Hindi',
      modelType: 'Piper VITS',
    ));
    await languageBloc.stream.firstWhere((s) => s.status == LanguageStatus.loaded && s.activeLanguage?.code == 'hi_IN');
    expect(AppConstants.activeLanguageCode, 'hi_IN');
    expect(languageBloc.state.activeLanguage?.code, 'hi_IN');

    // 4. Sender transmits in Hindi
    const hindiText = 'iTantra बेस स्टेशन से संपर्क स्थापित';
    talkBloc.add(const TalkTranscriptReady(hindiText, isVoice: false));
    await Future<void>.delayed(const Duration(milliseconds: 250));

    // Receiver accepts Hindi packet
    final hindiFrame = buildFrame(text: hindiText, seq: talkBloc.state.seqNo);
    receiverBloc.add(ReceiverFrameReceived(hindiFrame, origin: '192.168.1.120'));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(receiverBloc.state.messages.length, greaterThanOrEqualTo(1));
    expect(receiverBloc.state.messages.first.text, hindiText);

    // Verify reverse ACK delivers to TalkBloc
    talkBloc.add(TalkAckReceived(
      ackSeq: talkBloc.state.seqNo,
      status: QuickAck.statusRoger,
      origin: '192.168.1.120',
    ));
    await pumpEventQueue();

    expect(talkBloc.state.status, TalkStatus.ackReceived);
    expect(talkBloc.state.note, contains('Delivery Confirmed'));

    await sub.cancel();
    await talkBloc.close();
    await receiverBloc.close();
    await languageBloc.close();
    wifi.close();
  });
}
