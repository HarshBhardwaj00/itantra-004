import 'package:equatable/equatable.dart';

/// A live peer contact recovered from an inbound tactical frame.
///
/// Populated by [RadarBloc] whenever the shared radio bus hands over a
/// frame whose GPS slot decodes cleanly, so the radar can plot every
/// node instead of a single hard-coded sender.
class PeerNode extends Equatable {
  const PeerNode({
    required this.callSign,
    required this.latitude,
    required this.longitude,
    required this.lastSeen,
    this.isMock = false,
  });

  final String callSign;
  final double latitude;
  final double longitude;
  final DateTime lastSeen;

  /// True when the fix came from the offline seed instead of a live frame.
  final bool isMock;

  PeerNode copyWith({
    String? callSign,
    double? latitude,
    double? longitude,
    DateTime? lastSeen,
    bool? isMock,
  }) {
    return PeerNode(
      callSign: callSign ?? this.callSign,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastSeen: lastSeen ?? this.lastSeen,
      isMock: isMock ?? this.isMock,
    );
  }

  @override
  List<Object?> get props => [callSign, latitude, longitude, lastSeen, isMock];
}
