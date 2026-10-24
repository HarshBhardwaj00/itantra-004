import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crclib/catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itantra/data/datasources/wifi_udp_datasource.dart';
import 'package:itantra/presentation/blocs/talk/talk_bloc.dart';
import 'package:itantra/presentation/blocs/talk/talk_event.dart';

Uint8List buildFrame(int seq, String text) {
  final payload = utf8.encode(text);
  final compressed = const ZLibEncoder().encodeBytes(payload);
  final frame = <int>[
    0x49, 0x54, // Magic
    0x01,       // Normal
    (seq >> 8) & 0xFF,
    seq & 0xFF,
    0x00, 0x00, 0x00, 0x64, // Time
    0x00, 0x00, 0x00, 0x00, // Lat
    0x00, 0x00, 0x00, 0x00, // Lon
    ...compressed,
  ];
  final crc = Crc16Xmodem().convert(frame).toBigInt().toInt() & 0xFFFF;
  frame.add((crc >> 8) & 0xFF);
  frame.add(crc & 0xFF);
  return Uint8List.fromList(frame);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TalkBloc strictly rejects self-transmitted sequence numbers (no loopback echo)', () async {
    final wifiSource = WifiUdpDataSource();
    final talkBloc = TalkBloc(wifiSource: wifiSource);

    // 1. Simulate sending a message on sender device
    talkBloc.add(const TalkTranscriptReady('Help me'));
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(talkBloc.state.lastMessage, equals('Help me'));
    expect(talkBloc.state.lastMessageMeta.contains('Local Mesh'), isTrue);

    final sentSeq = talkBloc.state.seqNo;
    expect(sentSeq, greaterThan(0));

    // 2. Now simulate loopback: the network delivers the exact same packet with sentSeq back to wifiSource
    final loopbackPacket = buildFrame(sentSeq, 'Help me');
    wifiSource.feedPacketForTesting(loopbackPacket);

    await Future<void>.delayed(const Duration(milliseconds: 100));

    // The state should NOT be overwritten as an "Incoming" peer message!
    expect(talkBloc.state.lastMessageMeta.contains('Incoming'), isFalse);
    expect(talkBloc.state.lastMessageMeta.contains('Local Mesh'), isTrue);

    // 3. Now verify an actual peer packet with a different sequence IS accepted
    final peerPacket = buildFrame(999, 'Peer message');
    wifiSource.feedPacketForTesting(peerPacket);

    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Peer message should be accepted
    expect(talkBloc.state.lastMessage, equals('Peer message'));
    expect(talkBloc.state.lastMessageMeta.contains('Incoming'), isTrue);

    await talkBloc.close();
    wifiSource.close();
  });
}
