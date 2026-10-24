// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crclib/catalog.dart';

void main() async {
  final text = 'Senhal, position alpha received.';
  final payload = ZLibEncoder().encode(text.codeUnits);

  final frame = BytesBuilder();
  frame.addByte(0x49);
  frame.addByte(0x54);
  frame.addByte(0x01);
  frame.addByte(0x00);
  frame.addByte(0x01);
  frame.add([
    0x00, 0x00, 0x00, 0x00,
  ]);
  final bd = ByteData(8);
  bd.setFloat32(0, 28.6139, Endian.big);
  bd.setFloat32(4, 77.2090, Endian.big);
  frame.add(bd.buffer.asUint8List());
  frame.add(payload);
  frame.add([0x00, 0x00]);

  final bytes = frame.toBytes();
  final crc = Crc16Xmodem().convert(bytes.sublist(0, bytes.length - 2)).toBigInt().toInt() & 0xFFFF;
  final out = Uint8List.fromList(bytes);
  out[out.length - 2] = (crc >> 8) & 0xFF;
  out[out.length - 1] = crc & 0xFF;

  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final sent = socket.send(out, InternetAddress('127.0.0.1'), 45454);
  print('sent $sent bytes, crc=$crc, len=${out.length}');
  socket.close();
}
