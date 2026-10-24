import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:itantra/core/network/haversine.dart';
import 'package:itantra/core/network/packet_codec.dart';
import 'package:itantra/presentation/blocs/radar/radar_state.dart';

void main() {
  group('GeoMath — seed pair (28.6139,77.2090) -> (28.6250,77.2216)', () {
    const myLat = 28.6139;
    const myLon = 77.2090;
    const peerLat = 28.6250;
    const peerLon = 77.2216;

    test('haversine range lands at 1.7 KM', () {
      final meters =
          GeoMath.distanceMeters(myLat, myLon, peerLat, peerLon);
      expect(meters, inInclusiveRange(1740.0, 1752.0));
      expect(GeoMath.formatDistance(meters), '1.7 KM');
    });

    test('forward azimuth is exactly 45 degrees', () {
      final bearing =
          GeoMath.bearingDegrees(myLat, myLon, peerLat, peerLon);
      expect(bearing, inInclusiveRange(44.5, 45.5));
      expect(GeoMath.formatDegrees(bearing), '45\u00B0');
      expect(GeoMath.compassPoint(bearing), 'NORTH-EAST');
    });

    test('hero banner reads 1.7 KM • NORTH-EAST (45°)', () {
      const state = RadarState(
        distanceMeters: 1745.6,
        bearingDegrees: 45.0,
      );
      expect(state.bannerLabel, '1.7 KM \u2022 NORTH-EAST (45\u00B0)');
    });
  });

  group('GeoMath label rules', () {
    test('distance labels are short and complete', () {
      expect(GeoMath.formatDistance(820), '820 M');
      expect(GeoMath.formatDistance(994), '994 M');
      expect(GeoMath.formatDistance(1000), '1 KM');
      expect(GeoMath.formatDistance(3000), '3 KM');
      expect(GeoMath.formatDistance(0), '0 M');
    });

    test('degrees never render as 360', () {
      expect(GeoMath.formatDegrees(360), '0\u00B0');
      expect(GeoMath.formatDegrees(-45), '315\u00B0');
      expect(GeoMath.formatDegrees(45.4), '45\u00B0');
    });

    test('normalize wraps into [0, 360)', () {
      expect(GeoMath.normalize(370), 10);
      expect(GeoMath.normalize(-10), 350);
      expect(GeoMath.normalize(360), 0);
    });
  });

  group('PacketCodec coordinate block', () {
    test('round-trips the seed peer frame', () {
      final frame = PacketCodec.buildFixFrame(
        latitude: 28.6250,
        longitude: 77.2216,
        seq: 7,
      );
      expect(frame.length, PacketCodec.minimumFrameBytes);

      final fix = PacketCodec.decodePeerFix(frame);
      expect(fix, isNotNull);
      expect(fix!.crcVerified, isTrue);
      expect(fix.hasCoordinates, isTrue);
      expect(fix.latitude, closeTo(28.6250, 1e-5));
      expect(fix.longitude, closeTo(77.2216, 1e-5));
    });

    test('rejects a corrupted CRC tail', () {
      final frame = PacketCodec.buildFixFrame(
        latitude: 28.6250,
        longitude: 77.2216,
      );
      frame[frame.length - 1] ^= 0xFF;
      expect(PacketCodec.decodePeerFix(frame), isNull);
    });

    test('rejects a bad magic header', () {
      final frame = PacketCodec.buildFixFrame(
        latitude: 28.6250,
        longitude: 77.2216,
      );
      frame[0] = 0x00;
      expect(PacketCodec.decodePeerFix(frame), isNull);
    });

    test('rejects truncated frames', () {
      final frame = PacketCodec.buildFixFrame(
        latitude: 28.6250,
        longitude: 77.2216,
      );
      expect(
        PacketCodec.decodePeerFix(
          Uint8List.sublistView(frame, 0, PacketCodec.minimumFrameBytes - 1),
        ),
        isNull,
      );
    });

    test('rejects out-of-range coordinates even with a valid CRC', () {
      final block = PacketCodec.encodeCoordinateBlock(120.0, 77.0);
      final body = BytesBuilder(copy: false)
        ..add(const <int>[PacketCodec.magic0, PacketCodec.magic1, 0x01, 0, 1])
        ..add(Uint8List(4))
        ..add(block);
      final bytes = body.toBytes();

      final frame = Uint8List(bytes.length + 2)
        ..setAll(0, bytes)
        ..setAll(bytes.length, <int>[0x00, 0x00]);
      expect(PacketCodec.decodePeerFix(frame), isNull);
    });
  });

  group('RadarState telemetry getters', () {
    const loaded = RadarState(
      distanceMeters: 1745.6,
      bearingDegrees: 45.0,
      spanMeters: 3000.0,
    );

    test('labels and chips stay ellipsis-free', () {
      expect(loaded.spanLabel, 'Span 3 KM');
      expect(loaded.rangeRingsLabel, 'Rings 1 KM \u00B7 2 KM');
      expect(loaded.headingLabel, 'Heading 0\u00B0');
      expect(loaded.headingStatusLabel, 'Sensor Offline');
      expect(loaded.directionLabel, 'NORTH-EAST');
    });

    test('blipFraction keeps the blip inside the rings', () {
      expect(loaded.blipFraction, closeTo(1745.6 / 3000.0, 1e-9));
      expect(
        const RadarState(distanceMeters: 1.0, spanMeters: 3000.0)
            .blipFraction,
        0.05,
      );
      expect(
        const RadarState(distanceMeters: 90000.0, spanMeters: 3000.0)
            .blipFraction,
        1.0,
      );
      expect(const RadarState().blipFraction, 0.05);
    });
  });
}
