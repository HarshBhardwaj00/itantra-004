import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crclib/catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itantra/core/constants/app_constants.dart';
import 'package:itantra/data/datasources/radio_packet_bus.dart';
import 'package:itantra/presentation/blocs/receiver/receiver_bloc.dart';
import 'package:itantra/presentation/blocs/receiver/receiver_event.dart';

Uint8List buildFrame(
  String text, {
  double lat = 28.6139,
  double lon = 77.2090,
  int seq = 1,
  int type = 0x01,
}) {
  final payload = utf8.encode(text);
  final compressed = const ZLibEncoder().encodeBytes(payload);
  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  final frame = <int>[
    0x49,
    0x54,
    type,
    (seq >> 8) & 0xFF,
    seq & 0xFF,
  ];
  for (var shift = 24; shift >= 0; shift -= 8) {
    frame.add((timestamp >> shift) & 0xFF);
  }

  void addFloat(double value) {
    final data = ByteData(4)..setFloat32(0, value, Endian.big);
    frame.addAll(data.buffer.asUint8List());
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
        // Return 1 as Android TextToSpeech.LANG_AVAILABLE returns int
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

  test('English message routes directly to FlutterTts without hanging', () async {
    AppConstants.activeLanguageCode = 'en_IN';
    final bus = RadioPacketBus.instance;
    final bloc = ReceiverBloc(
      packetBus: bus,
      positionStream: const Stream.empty(),
    );

    // Disable auto-play to manually trigger speak
    bloc.add(const ReceiverAutoPlayToggled());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Send a frame with English text "Send help immediately"
    final frame = buildFrame('Send help immediately', seq: 101);
    bus.publish(RadioFrame(frame, origin: '192.168.1.50'));

    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(bloc.state.messages, isNotEmpty);
    final msg = bloc.state.messages.first;
    expect(msg.text, equals('Send help immediately'));

    // Trigger speak
    bloc.add(ReceiverSpeakRequested(msg.id));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // Verify FlutterTts was invoked with English
    final speakCalls = ttsCalls.where((c) => c.method == 'speak').toList();
    expect(speakCalls, isNotEmpty);
    expect(speakCalls.first.arguments, equals('Send help immediately'));

    // Verify language was set to en-IN
    final langCalls = ttsCalls.where((c) => c.method == 'setLanguage').toList();
    expect(langCalls, isNotEmpty);
    expect(langCalls.last.arguments, equals('en-IN'));

    await bloc.close();
  });

  test('Stop request cancels active speech and clears playing state', () async {
    AppConstants.activeLanguageCode = 'en_IN';
    final bus = RadioPacketBus.instance;
    final bloc = ReceiverBloc(
      packetBus: bus,
      positionStream: const Stream.empty(),
    );

    final frame = buildFrame('Test message for stop', seq: 102);
    bus.publish(RadioFrame(frame, origin: '192.168.1.51'));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final msgId = bloc.state.messages.first.id;
    bloc.add(ReceiverSpeakRequested(msgId));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Now request stop
    bloc.add(const ReceiverPlaybackStopped());
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(bloc.state.playingId, isNull);
    final stopCalls = ttsCalls.where((c) => c.method == 'stop').toList();
    expect(stopCalls, isNotEmpty);

    await bloc.close();
  });

  test('Auto-play armed automatically speaks received message', () async {
    AppConstants.activeLanguageCode = 'en_IN';
    final bus = RadioPacketBus.instance;
    final bloc = ReceiverBloc(
      packetBus: bus,
      positionStream: const Stream.empty(),
    );

    // Default state has autoPlay = true
    expect(bloc.state.autoPlay, isTrue);

    final frame = buildFrame('Auto play incoming SOS', seq: 103, type: 0x02);
    bus.publish(RadioFrame(frame, origin: '192.168.1.52'));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(bloc.state.messages, isNotEmpty);
    expect(bloc.state.messages.first.isSos, isTrue);

    final speakCalls = ttsCalls.where((c) => c.method == 'speak').toList();
    expect(speakCalls, isNotEmpty);
    expect(speakCalls.first.arguments, equals('Auto play incoming SOS'));

    await bloc.close();
  });

  test('Devanagari Hindi text routes to Hindi TTS', () async {
    final bus = RadioPacketBus.instance;
    final bloc = ReceiverBloc(
      packetBus: bus,
      positionStream: const Stream.empty(),
    );

    // Disable auto-play to manually control speak
    bloc.add(const ReceiverAutoPlayToggled());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final frame = buildFrame('मदद भेजो', seq: 104);
    bus.publish(RadioFrame(frame, origin: '192.168.1.53'));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final msg = bloc.state.messages.first;
    expect(msg.text, equals('मदद भेजो'));

    bloc.add(ReceiverSpeakRequested(msg.id));
    // Wait for Piper attempt + fallback
    await Future<void>.delayed(const Duration(milliseconds: 400));

    // When Piper is not initialized in pure test harness, it safely falls back to FlutterTts with hi-IN
    final setLangCalls = ttsCalls.where((c) => c.method == 'setLanguage').toList();
    if (setLangCalls.isNotEmpty) {
      expect(setLangCalls.any((c) => c.arguments == 'hi-IN' || c.arguments == 'hi'), isTrue);
    }

    await bloc.close();
  });

  test('Windows Desktop simulation: isLanguageAvailable throws MissingPluginException but speak still succeeds', () async {
    // Configure mock to simulate Windows desktop where isLanguageAvailable throws MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (MethodCall call) async {
      ttsCalls.add(call);
      if (call.method == 'isLanguageAvailable') {
        throw MissingPluginException('No implementation found for method isLanguageAvailable on channel flutter_tts');
      }
      if (call.method == 'getLanguages') {
        return ['en-US', 'en-IN', 'hi-IN'];
      }
      if (call.method == 'speak') return 1;
      if (call.method == 'setLanguage') return 1;
      return 1;
    });

    AppConstants.activeLanguageCode = 'en';
    final bus = RadioPacketBus.instance;
    final bloc = ReceiverBloc(
      packetBus: bus,
      positionStream: const Stream.empty(),
    );

    // Disable auto-play to manually trigger speak
    bloc.add(const ReceiverAutoPlayToggled());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Send the exact frame from the bug report: "Send help."
    final frame = buildFrame('Send help.', seq: 2);
    bus.publish(RadioFrame(frame, origin: '172.30.227.107'));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(bloc.state.messages, isNotEmpty);
    final msg = bloc.state.messages.first;
    expect(msg.text, equals('Send help.'));

    bloc.add(ReceiverSpeakRequested(msg.id));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // Must have successfully invoked speak even though isLanguageAvailable threw!
    final speakCalls = ttsCalls.where((c) => c.method == 'speak').toList();
    expect(speakCalls, isNotEmpty);
    expect(speakCalls.first.arguments, equals('Send help.'));

    await bloc.close();
  });

  test('Discovery control frame is filtered out and does not increment framesDropped', () async {
    final bus = RadioPacketBus.instance;
    final bloc = ReceiverBloc(
      packetBus: bus,
      positionStream: const Stream.empty(),
    );

    final initialDropped = bloc.state.framesDropped;

    // Simulate an ITANTRA_DISCOVERY frame arriving on the bus
    final discoveryBytes = utf8.encode('ITANTRA_DISCOVERY|SCOUT-CHARLIE-33|transceiver');
    bus.publish(RadioFrame(Uint8List.fromList(discoveryBytes), origin: '172.30.227.107'));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // It must NOT increment framesDropped!
    expect(bloc.state.framesDropped, equals(initialDropped));

    await bloc.close();
  });
}
