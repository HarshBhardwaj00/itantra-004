import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crclib/catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itantra/core/theme/app_theme.dart';
import 'package:itantra/data/datasources/radio_packet_bus.dart';
import 'package:itantra/presentation/screens/receiver_screen.dart';

const MethodChannel _geoChannel =
    MethodChannel('flutter.baseflow.com/geolocator');
const MethodChannel _ttsChannel = MethodChannel('flutter_tts');
const MethodChannel _audioGlobalChannel =
    MethodChannel('xyz.luan/audioplayers.global');
const MethodChannel _audioGlobalEventsChannel =
    MethodChannel('xyz.luan/audioplayers.global/events');
const MethodChannel _audioChannel = MethodChannel('xyz.luan/audioplayers');

final Set<String> _registeredPlayerIds = <String>{};

void _mockChannels(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _geoChannel,
    (call) async {
      if (call.method == 'isLocationServiceEnabled') return false;
      return null;
    },
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _ttsChannel,
    (call) async {
      if (call.method == 'speak') return 1;
      if (call.method == 'stop') return 1;
      if (call.method == 'isLanguageAvailable') return 1;
      return null;
    },
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _audioGlobalChannel,
    (call) async {
      return 1;
    },
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _audioGlobalEventsChannel,
    (call) async {
      return null;
    },
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _audioChannel,
    (call) async {
      final playerId = (call.arguments as Map?)?['playerId']?.toString();
      if (playerId != null && playerId.isNotEmpty && !_registeredPlayerIds.contains(playerId)) {
        _registeredPlayerIds.add(playerId);
        final ch = MethodChannel('xyz.luan/audioplayers/events/$playerId');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          ch,
          (eventCall) async => null,
        );
      }
      if (call.method == 'setSourceUrl' && playerId != null) {
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'xyz.luan/audioplayers/events/$playerId',
          const StandardMethodCodec().encodeSuccessEnvelope({
            'event': 'audio.onPrepared',
            'value': true,
          }),
          (_) {},
        );
      }
      return 1;
    },
  );
}

/// Mirrors the TalkBloc packetizer: magic + type + seq + timestamp + GPS +
/// zlib payload + CRC-16 tail.
Uint8List buildFrame(
  String text, {
  double lat = 28.6139,
  double lon = 77.2090,
  int seq = 7,
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

Future<void> pumpReceiver(WidgetTester tester) async {
  _mockChannels(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: const ReceiverScreen(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  final testSizes = [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ];

  for (final size in testSizes) {
    testWidgets(
        'renders ReceiverScreen at ${size.width}x${size.height} without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpReceiver(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Receiver'), findsOneWidget);
      expect(find.text('Listen · Track · Reply'), findsOneWidget);
      expect(find.text('Signal Vector'), findsNothing);
      expect(find.text('Listen Pipeline'), findsNothing);
      expect(find.text('Quick Reply'), findsNothing);
      expect(find.text('Roger'), findsNothing);
      expect(find.text('Standby'), findsNothing);
      expect(find.text('Replay Queue'), findsOneWidget);
      expect(find.text('No Traffic Yet'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'decodes a long inbound frame into a full untruncated message card (320x568)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpReceiver(tester);

    const longText =
        'Flood water rising fast near the northern bridge, team Bravo '
        'stranded with two injured personnel, send rope rescue and a boat '
        'immediately, coordinates shared over the tactical radio link';

    RadioPacketBus.instance.publish(
      RadioFrame(
        buildFrame(longText, seq: 42),
        origin: '192.168.43.99',
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text(longText), findsOneWidget);
    expect(find.textContaining('Seq 42'), findsOneWidget);
    expect(find.text('No Traffic Yet'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'clicking play button triggers text to speech conversion for Senhal message without hanging',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpReceiver(tester);

    // Auto-play speaks the frame, so stop it first to reach the idle 'Play' chip
    RadioPacketBus.instance.publish(
      RadioFrame(
        buildFrame('Senhal', seq: 1),
        origin: '192.168.170.151',
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Senhal'), findsOneWidget);

    // If auto-play started speaking, stop it; otherwise the chip is idle 'Play'.
    final stopChip = find.text('Stop');
    if (tester.any(stopChip)) {
      await tester.ensureVisible(stopChip);
      await tester.tap(stopChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    final playBtn = find.text('Play');
    expect(playBtn, findsOneWidget);

    await tester.ensureVisible(playBtn);
    await tester.tap(playBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The mocked TTS resolves instantly, so the chip may already have flipped
    // back to 'Play'; either state is valid — the key is that nothing hangs.
    expect(tester.takeException(), isNull);

    // Stop playback
    final stopBtn = find.text('Stop');
    if (tester.any(stopBtn)) {
      await tester.tap(stopBtn);
      await tester.pump();
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
