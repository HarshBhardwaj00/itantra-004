import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crclib/catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itantra/data/datasources/wifi_udp_datasource.dart';
import 'package:itantra/presentation/blocs/talk/talk_bloc.dart';
import 'package:itantra/presentation/blocs/talk/talk_state.dart';

void main() {
  group('TalkBloc Mesh UDP Packet Tests', () {
    test('receives, verifies CRC-16, decompresses zlib, and updates lastMessage on receiver', () async {
      final wifiSource = WifiUdpDataSource();
      final receiverBloc = TalkBloc(wifiSource: wifiSource);

      // Build a realistic iTantra protocol packet
      const text = 'मदद भेजो';
      final payload = utf8.encode(text);
      final compressed = const ZLibEncoder().encodeBytes(payload);
      final frame = <int>[
        0x49, 0x54, // Magic IT
        0x01,       // Normal voice
        0x00, 0x05, // Seq 5
        0x00, 0x00, 0x00, 0x64, // Timestamp
        0x00, 0x00, 0x00, 0x00, // Lat
        0x00, 0x00, 0x00, 0x00, // Lon
        ...compressed,
      ];
      final crc = Crc16Xmodem().convert(frame).toBigInt().toInt() & 0xFFFF;
      frame.add((crc >> 8) & 0xFF);
      frame.add(crc & 0xFF);

      final packetBytes = Uint8List.fromList(frame);

      // Expect receiver to update state
      final futureMatch = expectLater(
        receiverBloc.stream,
        emitsThrough(predicate<TalkState>((state) {
          return state.lastMessage == 'मदद भेजो' &&
              state.lastMessageMeta.contains('Incoming');
        })),
      );

      // Feed packet directly to receiver's wifi source
      wifiSource.feedPacketForTesting(packetBytes);

      await futureMatch;
      await receiverBloc.close();
      wifiSource.close();
    });
  });
}
