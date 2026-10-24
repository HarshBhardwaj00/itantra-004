import 'package:equatable/equatable.dart';

import '../../../core/network/haversine.dart';
import '../../../data/models/peer_node.dart';
import '../../../domain/entities/geo_location_entity.dart';

/// One plotted contact on the dial / grid.
class RadarContact extends Equatable {
  const RadarContact({
    required this.callSign,
    required this.distanceMeters,
    required this.bearingDegrees,
    this.isMock = false,
  });

  final String callSign;
  final double distanceMeters;
  final double bearingDegrees;
  final bool isMock;

  String get distanceLabel => GeoMath.formatDistance(distanceMeters);
  String get bearingLabel => GeoMath.formatDegrees(bearingDegrees);

  /// 0.05 - 1.0 radial position of the blip inside the dial rings.
  double fraction(double spanMeters) {
    if (spanMeters <= 0) return 1.0;
    final value = distanceMeters / spanMeters;
    if (value < 0.05) return 0.05;
    if (value > 1.0) return 1.0;
    return value;
  }

  @override
  List<Object?> get props =>
      [callSign, distanceMeters, bearingDegrees, isMock];
}

/// 4-state network lifecycle for the radar screen.
enum RadarStatus {
  /// Bloc created, nothing requested yet.
  initial,

  /// Fix lock in progress (skeleton shimmer).
  loading,

  /// Both fixes decoded — banner, dial and coordinates are populated.
  loaded,

  /// Location services blocked (retryable).
  error,
}

/// Compass dial vs offline vector grid.
enum RadarView {
  compass,
  grid,
}

class RadarState extends Equatable {
  const RadarState({
    this.status = RadarStatus.initial,
    this.view = RadarView.compass,
    this.myFix,
    this.peerFix,
    this.myFixMock = true,
    this.peerFixMock = true,
    this.myCallSign = 'RESCUE-ALPHA-01',
    this.peerCallSign = 'RESCUE-BRAVO-12',
    this.headingDegrees = 0.0,
    this.headingLive = false,
    this.distanceMeters = 0.0,
    this.bearingDegrees = 0.0,
    this.spanMeters = 3000.0,
    this.activePeers = const <String, PeerNode>{},
    this.note = '',
  });

  final RadarStatus status;
  final RadarView view;
  final GeoLocationEntity? myFix;
  final GeoLocationEntity? peerFix;

  /// Seed provenance flags — drives the LIVE / DEMO badge.
  final bool myFixMock;
  final bool peerFixMock;

  final String myCallSign;
  final String peerCallSign;

  /// Magnetic azimuth of the device, 0°-360° (0 = pointing north).
  final double headingDegrees;

  /// False when the magnetometer stream is unavailable.
  final bool headingLive;

  /// Haversine great-circle range in metres.
  final double distanceMeters;

  /// Forward azimuth to the peer in degrees.
  final double bearingDegrees;

  /// Dial / grid span chosen so the blip always lands inside the rings.
  final double spanMeters;

  /// Every live peer decoded from the shared radio bus, keyed by call-sign.
  final Map<String, PeerNode> activePeers;

  /// Supporting hint rendered under the telemetry banner.
  final String note;

  bool get hasFixes => myFix != null && peerFix != null;

  bool get peerLocked => peerFix != null;

  bool get anyMock => myFixMock || peerFixMock;

  /// Normalised distance label — `820 M`, `1.7 KM`.
  String get distanceLabel => GeoMath.formatDistance(distanceMeters);

  /// Whole-degree azimuth label — `45°`.
  String get bearingLabel => GeoMath.formatDegrees(bearingDegrees);

  /// 8-point direction word — `NORTH-EAST`.
  String get directionLabel => GeoMath.compassPoint(bearingDegrees);

  /// Hero readout — `1.7 KM • NORTH-EAST (45°)`.
  String get bannerLabel => '$distanceLabel • $directionLabel ($bearingLabel)';

  String get headingLabel => 'Heading ${GeoMath.formatDegrees(headingDegrees)}';

  String get headingStatusLabel =>
      headingLive ? headingLabel : 'Sensor Offline';

  String get spanLabel => 'Span ${GeoMath.formatDistance(spanMeters)}';

  String get rangeRingsLabel =>
      'Rings ${GeoMath.formatDistance(spanMeters / 3)} · '
      '${GeoMath.formatDistance(spanMeters * 2 / 3)}';

  /// 0.05 - 1.0 radial position of the blip inside the dial rings.
  double get blipFraction {
    if (spanMeters <= 0) return 1.0;
    final value = distanceMeters / spanMeters;
    if (value < 0.05) return 0.05;
    if (value > 1.0) return 1.0;
    return value;
  }

  bool get hasLivePeers => activePeers.isNotEmpty;

  int get contactCount => hasLivePeers ? activePeers.length : (peerFix == null ? 0 : 1);

  String get contactCountLabel => contactCount == 1 ? '1 CONTACT' : '$contactCount CONTACTS';

  /// All blips to plot: every live peer, or the offline seed as a fallback.
  List<RadarContact> get contacts {
    final my = myFix;
    if (activePeers.isNotEmpty) {
      final result = activePeers.values.map((peer) {
        if (my == null) {
          return RadarContact(
            callSign: peer.callSign,
            distanceMeters: 0.0,
            bearingDegrees: 0.0,
            isMock: peer.isMock,
          );
        }
        return RadarContact(
          callSign: peer.callSign,
          distanceMeters: GeoMath.distanceMeters(
            my.latitude,
            my.longitude,
            peer.latitude,
            peer.longitude,
          ),
          bearingDegrees: GeoMath.bearingDegrees(
            my.latitude,
            my.longitude,
            peer.latitude,
            peer.longitude,
          ),
          isMock: peer.isMock,
        );
      }).toList()
        ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      return result;
    }

    if (peerFix == null) return const <RadarContact>[];
    return <RadarContact>[
      RadarContact(
        callSign: peerCallSign,
        distanceMeters: distanceMeters,
        bearingDegrees: bearingDegrees,
        isMock: peerFixMock,
      ),
    ];
  }

  RadarState copyWith({
    RadarStatus? status,
    RadarView? view,
    GeoLocationEntity? myFix,
    GeoLocationEntity? peerFix,
    bool? myFixMock,
    bool? peerFixMock,
    String? myCallSign,
    String? peerCallSign,
    double? headingDegrees,
    bool? headingLive,
    double? distanceMeters,
    double? bearingDegrees,
    double? spanMeters,
    Map<String, PeerNode>? activePeers,
    String? note,
  }) {
    return RadarState(
      status: status ?? this.status,
      view: view ?? this.view,
      myFix: myFix ?? this.myFix,
      peerFix: peerFix ?? this.peerFix,
      myFixMock: myFixMock ?? this.myFixMock,
      peerFixMock: peerFixMock ?? this.peerFixMock,
      myCallSign: myCallSign ?? this.myCallSign,
      peerCallSign: peerCallSign ?? this.peerCallSign,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      headingLive: headingLive ?? this.headingLive,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      bearingDegrees: bearingDegrees ?? this.bearingDegrees,
      spanMeters: spanMeters ?? this.spanMeters,
      activePeers: activePeers ?? this.activePeers,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => [
        status,
        view,
        myFix,
        peerFix,
        myFixMock,
        peerFixMock,
        myCallSign,
        peerCallSign,
        headingDegrees,
        headingLive,
        distanceMeters,
        bearingDegrees,
        spanMeters,
        activePeers,
        note,
      ];
}
