import 'package:equatable/equatable.dart';

import '../../../domain/entities/geo_location_entity.dart';

sealed class RadarEvent extends Equatable {
  const RadarEvent();

  @override
  List<Object?> get props => [];
}

/// Screen opened (or retried): lock both fixes and start the dial.
final class RadarStarted extends RadarEvent {
  const RadarStarted();
}

/// Magnetometer pushed a new azimuth (0°-360°) for the rotating dial.
final class RadarHeadingChanged extends RadarEvent {
  const RadarHeadingChanged(this.headingDegrees, {this.live = true});

  final double headingDegrees;
  final bool live;

  @override
  List<Object?> get props => [headingDegrees, live];
}

/// Magnetometer unavailable (desktop, permission denied, sensor fault).
final class RadarSensorLost extends RadarEvent {
  const RadarSensorLost({this.reason = 'Sensor offline — dial holds North'});

  final String reason;

  @override
  List<Object?> get props => [reason];
}

/// "Recenter" tap: refresh the GPS fix and recompute range & bearing.
final class RadarRecenterRequested extends RadarEvent {
  const RadarRecenterRequested();
}

/// "Grid View" / "Radar View" corner toggle.
final class RadarViewToggled extends RadarEvent {
  const RadarViewToggled();
}

/// A radio frame with a valid GPS slot was decoded on the shared bus.
///
/// The radar folds it into [RadarState.activePeers] and immediately
/// recomputes live range and bearing — no screen refresh required.
final class RadarPeerPacketReceived extends RadarEvent {
  const RadarPeerPacketReceived({
    required this.callSign,
    required this.latitude,
    required this.longitude,
  });

  final String callSign;
  final double latitude;
  final double longitude;

  @override
  List<Object?> get props => [callSign, latitude, longitude];
}

/// The continuous receiver GPS stream pushed a fresh own-position fix.
final class RadarMyPositionChanged extends RadarEvent {
  const RadarMyPositionChanged(this.location);

  final GeoLocationEntity location;

  @override
  List<Object?> get props => [location];
}
