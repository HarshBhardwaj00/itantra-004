import 'dart:typed_data';

import '../../core/network/packet_codec.dart';
import '../../domain/entities/geo_location_entity.dart';
import '../../services/location/location_service.dart';

/// A coordinate fix together with its provenance.
class RadarFix {
  const RadarFix({required this.location, required this.isMock});

  final GeoLocationEntity location;

  /// True when the value came from the offline seed frame instead of a
  /// live GPS fix / live radio frame.
  final bool isMock;
}

/// Data layer for Screen 3 (Tactical Radar & Direction).
///
/// * My position  -> `geolocator` live fix, offline seed as fallback.
/// * Peer position -> last raw radio frame decoded by [PacketCodec],
///   offline seed frame as fallback so the screen still renders with
///   zero connectivity.
class RadarRepository {
  RadarRepository();

  /// Latest raw packet handed over by the radio layer. When the UDP / LoRa
  /// datasource receives a peer frame it can assign it here; the next
  /// radar refresh deserializes the 8-byte coordinate block from it.
  Uint8List? lastPeerFrame;

  static const double seedMyLatitude = 28.6139;
  static const double seedMyLongitude = 77.2090;
  static const double seedMyAltitude = 210.0;
  static const double seedMyAccuracy = 5.0;

  static const double seedPeerLatitude = 28.6250;
  static const double seedPeerLongitude = 77.2216;
  static const double seedPeerAccuracy = 4.0;

  Future<RadarFix> myLocation() async {
    final live = await LocationService.current();
    if (live.hasFix) return RadarFix(location: live, isMock: false);

    return RadarFix(
      location: GeoLocationEntity(
        latitude: seedMyLatitude,
        longitude: seedMyLongitude,
        accuracyMeters: seedMyAccuracy,
        altitudeMeters: seedMyAltitude,
        capturedAt: DateTime.now(),
      ),
      isMock: true,
    );
  }

  Future<RadarFix> peerLocation() async {
    final frame = lastPeerFrame;
    if (frame != null) {
      final decoded = PacketCodec.decodePeerFix(frame);
      if (decoded != null) {
        return RadarFix(
          location: GeoLocationEntity(
            latitude: decoded.latitude,
            longitude: decoded.longitude,
            accuracyMeters: seedPeerAccuracy,
            capturedAt: DateTime.now(),
          ),
          isMock: false,
        );
      }
    }

    final seed = PacketCodec.buildFixFrame(
      latitude: seedPeerLatitude,
      longitude: seedPeerLongitude,
      seq: 7,
    );
    final decoded = PacketCodec.decodePeerFix(seed);
    if (decoded == null) {
      return RadarFix(location: GeoLocationEntity.none(), isMock: true);
    }

    return RadarFix(
      location: GeoLocationEntity(
        latitude: decoded.latitude,
        longitude: decoded.longitude,
        accuracyMeters: seedPeerAccuracy,
        capturedAt: DateTime.now(),
      ),
      isMock: true,
    );
  }
}
