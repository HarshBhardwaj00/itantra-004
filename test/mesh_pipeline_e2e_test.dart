import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crclib/catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:itantra/core/network/quick_ack.dart';
import 'package:itantra/data/datasources/radio_packet_bus.dart';
import 'package:itantra/data/datasources/wifi_udp_datasource.dart';
import 'package:itantra/data/models/device_node.dart';
import 'package:itantra/presentation/blocs/receiver/receiver_bloc.dart';
import 'package:itantra/presentation/blocs/receiver/receiver_event.dart';
import 'package:itantra/presentation/blocs/talk/talk_bloc.dart';
import 'package:itantra/presentation/blocs/talk/talk_event.dart';
import 'package:itantra/presentation/blocs/talk/talk_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel ttsChannel = MethodChannel('flutter_tts');
  const MethodChannel audioChannel = MethodChannel('xyz.luan/audioplayers');
  const MethodChannel audioGlobalChannel =
      MethodChannel('xyz.luan/audioplayers.global');

  late Directory tempDir;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (MethodCall call) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, (MethodCall call) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, (MethodCall call) async => 1);

    tempDir = await Directory.systemTemp.createTemp('mesh_e2e_test_');
    Hive.init(tempDir.path);
    await DeviceNode.init();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, null);

    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('End-to-End Mesh Network Communication Pipeline', () {
    test('Sender transmits packet -> Receiver validates & auto-replies ACK -> Sender confirms delivery', () async {
      final senderWifi = WifiUdpDataSource();
      final receiverWifi = WifiUdpDataSource();

      final senderBloc = TalkBloc(wifiSource: senderWifi);
      final receiverBloc = ReceiverBloc(
        wifiSource: receiverWifi,
        positionStream: const Stream.empty(),
      );

      // Disable auto-play to focus on data packet pipeline
      receiverBloc.add(const ReceiverAutoPlayToggled());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 1. Simulate peer discovery handshake: Sender and Receiver discover each other
      const senderIp = '192.168.1.100';
      const receiverIp = '192.168.1.150';

      receiverWifi.feedPacketForTesting(
        Uint8List.fromList(utf8.encode('ITANTRA_DISCOVERY|RESCUE-ALPHA-01|transceiver')),
        origin: senderIp,
      );
      senderWifi.feedPacketForTesting(
        Uint8List.fromList(utf8.encode('ITANTRA_DISCOVERY_REPLY|BASE-BRAVO-02|transceiver')),
        origin: receiverIp,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(receiverWifi.knownPeers, contains(senderIp));
      expect(senderWifi.knownPeers, contains(receiverIp));

      // 2. Sender dispatches a typed message: "Emergency team moving to Sector 7"
      senderBloc.add(const TalkTranscriptReady(
        'Emergency team moving to Sector 7',
        isVoice: false,
      ));

      // Wait for 200ms PACKET SENT flash to settle into waitingAck window
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Verify sender framed packet and entered waitingAck window
      expect(senderBloc.state.transcript, equals('Emergency team moving to Sector 7'));
      expect(senderBloc.state.status, equals(TalkStatus.waitingAck));

      final sentSeq = senderBloc.state.seqNo;
      expect(sentSeq, greaterThan(0));

      // 3. Packet arrives at receiver over the network
      final payload = utf8.encode('Emergency team moving to Sector 7');
      final compressed = const ZLibEncoder().encodeBytes(payload);
      final frame = <int>[
        0x49, 0x54, // Magic
        0x01,       // Normal
        (sentSeq >> 8) & 0xFF,
        sentSeq & 0xFF,
        0x00, 0x00, 0x00, 0x01, // Timestamp
        0x00, 0x00, 0x00, 0x00, // Lat
        0x00, 0x00, 0x00, 0x00, // Lon
        ...compressed,
      ];
      final crc = Crc16Xmodem().convert(frame).toBigInt().toInt() & 0xFFFF;
      frame.add((crc >> 8) & 0xFF);
      frame.add(crc & 0xFF);

      final packetBytes = Uint8List.fromList(frame);

      // Deliver frame to receiver's radio bus
      RadioPacketBus.instance.publish(RadioFrame(packetBytes, origin: senderIp));

      await Future<void>.delayed(const Duration(milliseconds: 150));

      // 4. Verify receiver accepted, decoded, and stored message
      expect(receiverBloc.state.messages, isNotEmpty);
      expect(receiverBloc.state.messages.first.text, equals('Emergency team moving to Sector 7'));
      expect(receiverBloc.state.messages.first.seq, equals(sentSeq));

      // 5. Simulate reverse ACK generated by receiver reaching the sender over the network
      final ackBytes = Uint8List.fromList(QuickAck.build(
        status: QuickAck.statusRoger,
        seq: sentSeq,
      ));
      senderWifi.feedPacketForTesting(ackBytes, origin: receiverIp);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // 6. Verify sender received ACK and confirmed delivery!
      expect(senderBloc.state.status, equals(TalkStatus.ackReceived));
      expect(senderBloc.state.note.contains('Delivery Confirmed'), isTrue);
      expect(senderBloc.state.note.contains('Roger'), isTrue);

      await senderBloc.close();
      await receiverBloc.close();
      senderWifi.close();
      receiverWifi.close();
    });

    test('SOS packet correctly sets priority flag 0x02 and alerts receiver', () async {
      final receiverWifi = WifiUdpDataSource();
      final receiverBloc = ReceiverBloc(
        wifiSource: receiverWifi,
        positionStream: const Stream.empty(),
      );

      // Build SOS frame (type 0x02)
      const text = 'MAYDAY SOS - FLASH FLOOD AT BRIDGE';
      final payload = utf8.encode(text);
      final compressed = const ZLibEncoder().encodeBytes(payload);
      final frame = <int>[
        0x49, 0x54, // Magic
        0x02,       // SOS Alert
        0x00, 0x42, // Seq 66
        0x00, 0x00, 0x00, 0x02, // Time
        0x00, 0x00, 0x00, 0x00, // Lat
        0x00, 0x00, 0x00, 0x00, // Lon
        ...compressed,
      ];
      final crc = Crc16Xmodem().convert(frame).toBigInt().toInt() & 0xFFFF;
      frame.add((crc >> 8) & 0xFF);
      frame.add(crc & 0xFF);

      final packetBytes = Uint8List.fromList(frame);
      RadioPacketBus.instance.publish(RadioFrame(packetBytes, origin: '192.168.1.77'));

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(receiverBloc.state.messages, isNotEmpty);
      final msg = receiverBloc.state.messages.first;
      expect(msg.isSos, isTrue);
      expect(msg.msgType, equals(0x02));
      expect(msg.text, equals(text));

      await receiverBloc.close();
      receiverWifi.close();
    });
  });
}
