import 'dart:async';

import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/haversine.dart';
import '../../../core/network/packet_codec.dart';
import '../../../data/datasources/radio_packet_bus.dart';
import '../../../data/models/device_node.dart';
import '../../../data/models/peer_node.dart';
import '../../../data/repositories/radar_repository.dart';
import '../../../domain/entities/geo_location_entity.dart';
import '../../../services/location/location_service.dart';
import 'radar_event.dart';
import 'radar_state.dart';

/// Screen 3 state machine.
///
/// Purely mathematical / sensor driven — no AI model is involved:
///  * `geolocator`  -> live receiver fix (one-shot + continuous stream)
///  * `RadioPacketBus` -> every peer GPS slot decoded by [PacketCodec]
///  * `GeoMath`     -> Haversine range + forward azimuth per contact
///  * `flutter_compass` -> live magnetometer azimuth for the dial
class RadarBloc extends Bloc<RadarEvent, RadarState> {
  RadarBloc({
    RadarRepository? repository,
    Stream<CompassEvent>? compassEvents,
    Stream<GeoLocationEntity>? positionStream,
    RadioPacketBus? packetBus,
  })  : _repository = repository ?? RadarRepository(),
        _compassEvents = compassEvents,
        _positionStream = positionStream ?? LocationService.positionStream(),
        _packetBus = packetBus ?? RadioPacketBus.instance,
        super(const RadarState()) {
    on<RadarStarted>(_onStarted);
    on<RadarHeadingChanged>(_onHeadingChanged);
    on<RadarSensorLost>(_onSensorLost);
    on<RadarRecenterRequested>(_onRecenter);
    on<RadarViewToggled>(_onViewToggled);
    on<RadarPeerPacketReceived>(_onPeerPacketReceived);
    on<RadarMyPositionChanged>(_onMyPositionChanged);

    // Subscribe immediately so frames that arrive while the screen is closed
    // are still captured, and the receiver fix tracks the device continuously.
    _listenPackets();
    _listenPosition();
  }

  final RadarRepository _repository;
  final Stream<CompassEvent>? _compassEvents;
  final Stream<GeoLocationEntity> _positionStream;
  final RadioPacketBus _packetBus;

  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<GeoLocationEntity>? _positionSubscription;
  StreamSubscription<RadioFrame>? _packetSubscription;
  bool _compassListening = false;
  bool _positionListening = false;
  bool _packetListening = false;

  GeoLocationEntity? _myFix;
  bool _myFixMock = false;
  final Map<String, PeerNode> _peers = <String, PeerNode>{};
  RadarFix? _seedPeer;

  @override
  Future<void> close() async {
    await _compassSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _packetSubscription?.cancel();
    await super.close();
  }

  Future<void> _onStarted(RadarStarted event, Emitter<RadarState> emit) async {
    final node = DeviceNode.load();
    if (node != null && node.callSign.isNotEmpty && state.myCallSign != node.callSign) {
      emit(state.copyWith(myCallSign: node.callSign));
    }

    emit(state.copyWith(
      status: RadarStatus.loading,
      note: 'Locking sender frame',
    ));
    await _refresh(emit);
    _listenCompass();
  }

  Future<void> _onRecenter(
    RadarRecenterRequested event,
    Emitter<RadarState> emit,
  ) async {
    emit(state.copyWith(note: 'Refreshing GPS fix'));
    await _refresh(emit);
    if (emit.isDone) return;
    emit(state.copyWith(note: 'Fix refreshed — range and bearing updated'));
  }

  Future<void> _refresh(Emitter<RadarState> emit) async {
    try {
      final mine = await _repository.myLocation();
      _myFix = mine.location;
      _myFixMock = mine.isMock;
      _seedPeer ??= await _repository.peerLocation();
      if (emit.isDone) return;
      _emitProjection(emit, note: _projectionNote());
    } catch (_) {
      if (emit.isDone) return;
      emit(state.copyWith(
        status: RadarStatus.error,
        note: 'Location services blocked — retry to continue',
      ));
    }
  }

  /// A frame whose GPS slot decoded cleanly landed on the shared bus.
  void _onPeerPacketReceived(
    RadarPeerPacketReceived event,
    Emitter<RadarState> emit,
  ) {
    _peers[event.callSign] = PeerNode(
      callSign: event.callSign,
      latitude: event.latitude,
      longitude: event.longitude,
      lastSeen: DateTime.now(),
    );

    final suffix = _peers.length > 1 ? ' · ${_peers.length} CONTACTS' : '';
    _emitProjection(emit, note: 'Live fix from ${event.callSign}$suffix');
  }

  /// The receiver moved — recompute every contact without touching the rest.
  void _onMyPositionChanged(
    RadarMyPositionChanged event,
    Emitter<RadarState> emit,
  ) {
    _myFix = event.location;
    _myFixMock = false;
    _emitProjection(emit, note: _projectionNote());
  }

  void _emitProjection(Emitter<RadarState> emit, {String? note}) {
    final my = _myFix;
    final peers = Map<String, PeerNode>.unmodifiable(_peers);
    final primary = _selectPrimary(my);

    GeoLocationEntity? peerFix;
    var peerMock = true;
    var peerCallSign = state.peerCallSign;
    var distance = 0.0;
    var bearing = 0.0;

    if (primary != null) {
      peerFix = GeoLocationEntity(
        latitude: primary.latitude,
        longitude: primary.longitude,
        accuracyMeters: RadarRepository.seedPeerAccuracy,
        capturedAt: primary.lastSeen,
      );
      peerMock = primary.isMock;
      peerCallSign = primary.callSign;
      if (my != null) {
        distance = GeoMath.distanceMeters(
          my.latitude, my.longitude, primary.latitude, primary.longitude);
        bearing = GeoMath.bearingDegrees(
          my.latitude, my.longitude, primary.latitude, primary.longitude);
      }
    } else {
      final seed = _seedPeer;
      if (seed != null) {
        peerFix = seed.location;
        peerMock = seed.isMock;
        if (my != null) {
          distance = GeoMath.distanceMeters(
            my.latitude, my.longitude, seed.location.latitude,
            seed.location.longitude);
          bearing = GeoMath.bearingDegrees(
            my.latitude, my.longitude, seed.location.latitude,
            seed.location.longitude);
        }
      }
    }

    emit(state.copyWith(
      status: my != null ? RadarStatus.loaded : state.status,
      myFix: my,
      myFixMock: _myFixMock,
      peerFix: peerFix,
      peerFixMock: peerMock,
      peerCallSign: peerCallSign,
      distanceMeters: distance,
      bearingDegrees: bearing,
      spanMeters: _selectSpan(distance),
      activePeers: peers,
      note: note,
    ));
  }

  PeerNode? _selectPrimary(GeoLocationEntity? my) {
    PeerNode? primary;
    for (final peer in _peers.values) {
      if (primary == null) {
        primary = peer;
        continue;
      }
      if (my == null) {
        if (peer.lastSeen.isAfter(primary.lastSeen)) primary = peer;
        continue;
      }
      final candidate = GeoMath.distanceMeters(
        my.latitude, my.longitude, peer.latitude, peer.longitude);
      final current = GeoMath.distanceMeters(
        my.latitude, my.longitude, primary.latitude, primary.longitude);
      if (candidate < current) primary = peer;
    }
    return primary;
  }

  String _projectionNote() {
    if (_peers.isNotEmpty) {
      return _peers.length == 1
          ? 'Live peer frame decoded from the radio bus'
          : '${_peers.length} live peers decoded from the radio bus';
    }
    if (_seedPeer?.isMock == true) {
      return 'Sender frame from offline seed — decoder path identical';
    }
    return 'Sender frame decoded from the live packet';
  }

  void _onHeadingChanged(
    RadarHeadingChanged event,
    Emitter<RadarState> emit,
  ) {
    emit(state.copyWith(
      headingDegrees: GeoMath.normalize(event.headingDegrees),
      headingLive: event.live,
      note: state.headingLive ? null : '',
    ));
  }

  void _onSensorLost(RadarSensorLost event, Emitter<RadarState> emit) {
    if (!state.headingLive && state.note == event.reason) return;
    emit(state.copyWith(headingLive: false, note: event.reason));
  }

  void _onViewToggled(RadarViewToggled event, Emitter<RadarState> emit) {
    final next =
        state.view == RadarView.compass ? RadarView.grid : RadarView.compass;
    emit(state.copyWith(
      view: next,
      note: next == RadarView.grid
          ? 'Offline vector plot — north-up, no internet used'
          : 'Rotating dial — magnetometer driven',
    ));
  }

  void _listenPackets() {
    if (_packetListening) return;
    _packetListening = true;

    try {
      _packetSubscription = _packetBus.frames.listen(
        (frame) {
          if (isClosed) return;
          final fix = PacketCodec.decodePeerFix(frame.bytes);
          if (fix == null) return;
          add(RadarPeerPacketReceived(
            callSign: _packetBus.callSignFor(frame.origin),
            latitude: fix.latitude,
            longitude: fix.longitude,
          ));
        },
        onError: (Object _) {},
        cancelOnError: false,
      );
    } catch (_) {
      // Bus unavailable — radar still runs on the one-shot GPS path.
    }
  }

  void _listenPosition() {
    if (_positionListening) return;
    _positionListening = true;

    try {
      _positionSubscription = _positionStream.listen(
        (fix) {
          if (isClosed) return;
          add(RadarMyPositionChanged(fix));
        },
        onError: (Object _) {},
        cancelOnError: false,
      );
    } catch (_) {
      // Continuous fix unavailable — fall back to manual refresh.
    }
  }

  void _listenCompass() {
    if (_compassListening) return;
    _compassListening = true;

    final stream = _compassEvents ?? FlutterCompass.events;
    if (stream == null) {
      add(const RadarSensorLost(
        reason: 'Magnetometer unavailable — dial holds North',
      ));
      return;
    }

    try {
      _compassSubscription = stream.listen(
        (event) {
          if (isClosed) return;
          final heading = event.heading;
          if (heading == null || heading.isNaN) {
            add(const RadarSensorLost(
              reason: 'No heading data — dial holds North',
            ));
            return;
          }
          add(RadarHeadingChanged(heading));
        },
        onError: (Object _) {
          if (isClosed) return;
          add(const RadarSensorLost(
            reason: 'Magnetometer unavailable — dial holds North',
          ));
        },
        cancelOnError: false,
      );
    } catch (_) {
      add(const RadarSensorLost(
        reason: 'Magnetometer unavailable — dial holds North',
      ));
    }
  }

  /// Dial spans are picked from a ladder whose thirds are round numbers,
  /// so the in-dial ring labels always read `1 KM · 2 KM` (never `0.7`).
  static double _selectSpan(double distanceMeters) {
    const ladder = <double>[
      300.0,
      600.0,
      900.0,
      1500.0,
      3000.0,
      6000.0,
      9000.0,
      15000.0,
      30000.0,
    ];
    for (final step in ladder) {
      if (distanceMeters <= step * 0.85) return step;
    }
    return ladder.last;
  }
}
