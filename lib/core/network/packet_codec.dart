import 'dart:typed_data';

import 'package:crclib/catalog.dart';

/// Coordinate block recovered from an inbound tactical frame.
///
/// The block is **8 bytes**: two IEEE-754 `float32` values (latitude then
/// longitude) read big-endian, exactly the layout emitted by the TalkBloc
/// packetizer.
class PeerFixFrame {
  const PeerFixFrame({
    required this.latitude,
    required this.longitude,
    required this.crcVerified,
  });

  final double latitude;
  final double longitude;

  /// CRC-16/XMODEM tail check result (false when the tail is missing).
  final bool crcVerified;

  bool get hasCoordinates =>
      !latitude.isNaN &&
      !longitude.isNaN &&
      latitude >= -90.0 &&
      latitude <= 90.0 &&
      longitude >= -180.0 &&
      longitude <= 180.0 &&
      !(latitude == 0.0 && longitude == 0.0);
}

/// Binary codec for the iTantra packet header.
///
/// Network concept: **Payload Deserialization & Coordinate Extraction** —
/// the receiver unpacks the sender latitude/longitude straight out of the
/// fixed GPS slot of the frame and validates it with CRC-16 before the
/// radar screen ever draws a blip.
class PacketCodec {
  PacketCodec._();

  static const int magic0 = 0x49;
  static const int magic1 = 0x54;

  /// 2 magic + 1 type + 2 seq + 4 unix timestamp = start of the GPS slot.
  static const int gpsOffset = 9;

  /// `float32 latitude` + `float32 longitude`.
  static const int coordinateBlockBytes = 8;

  /// Smallest frame that still carries a CRC tail: header + block + CRC.
  static const int minimumFrameBytes = gpsOffset + coordinateBlockBytes + 2;

  /// Unpacks the sender fix from a raw frame, or returns null when the
  /// header, the ranges or the CRC do not check out.
  static PeerFixFrame? decodePeerFix(Uint8List frame) {
    if (frame.length < minimumFrameBytes) return null;
    if (frame[0] != magic0 || frame[1] != magic1) return null;

    final data = ByteData.sublistView(frame);
    final latitude = data.getFloat32(gpsOffset, Endian.big);
    final longitude = data.getFloat32(gpsOffset + 4, Endian.big);

    final fix = PeerFixFrame(
      latitude: latitude,
      longitude: longitude,
      crcVerified: _crcMatches(frame),
    );
    if (!fix.hasCoordinates || !fix.crcVerified) return null;
    return fix;
  }

  /// Builds the 8-byte IEEE-754 coordinate block.
  static Uint8List encodeCoordinateBlock(double latitude, double longitude) {
    final data = ByteData(coordinateBlockBytes)
      ..setFloat32(0, latitude, Endian.big)
      ..setFloat32(4, longitude, Endian.big);
    return data.buffer.asUint8List();
  }

  /// Builds a complete, CRC-valid frame carrying only a coordinate block.
  /// Used by the offline seed path and by unit tests, and identical in
  /// layout to what a live radio datasource would hand over.
  static Uint8List buildFixFrame({
    required double latitude,
    required double longitude,
    int type = 0x01,
    int seq = 1,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final builder = BytesBuilder(copy: false)
      ..add(const <int>[magic0, magic1])
      ..add(<int>[type, (seq >> 8) & 0xFF, seq & 0xFF]);

    for (var shift = 24; shift >= 0; shift -= 8) {
      builder.add(<int>[(timestamp >> shift) & 0xFF]);
    }

    builder.add(encodeCoordinateBlock(latitude, longitude));

    final body = builder.toBytes();
    final crc = Crc16Xmodem().convert(body).toBigInt().toInt() & 0xFFFF;

    final frame = Uint8List(body.length + 2);
    frame.setAll(0, body);
    frame[frame.length - 2] = (crc >> 8) & 0xFF;
    frame[frame.length - 1] = crc & 0xFF;
    return frame;
  }

  static bool _crcMatches(Uint8List frame) {
    final data = ByteData.sublistView(frame);
    final expected = data.getUint16(frame.length - 2, Endian.big);
    final actual = Crc16Xmodem()
        .convert(frame.sublist(0, frame.length - 2))
        .toBigInt()
        .toInt() &
        0xFFFF;
    return expected == actual;
  }
}
