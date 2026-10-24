import 'package:equatable/equatable.dart';

import '../../../core/network/haversine.dart';
import '../../../domain/entities/geo_location_entity.dart';

/// One fully decoded inbound transmission kept in the replay queue.
class ReceivedMessage extends Equatable {
  const ReceivedMessage({
    required this.id,
    required this.callSign,
    required this.text,
    required this.seq,
    required this.msgType,
    required this.receivedAt,
    this.isSos = false,
    this.hasPeerFix = false,
    this.peerLatitude = 0.0,
    this.peerLongitude = 0.0,
    this.distanceMeters,
    this.bearingDegrees,
    this.origin,
  });

  final String id;
  final String callSign;
  final String text;
  final int seq;
  final int msgType;
  final DateTime receivedAt;
  final bool isSos;
  final bool hasPeerFix;
  final double peerLatitude;
  final double peerLongitude;

  /// Snapshot of the Haversine range at receive time (null without a fix).
  final double? distanceMeters;

  /// Snapshot of the forward azimuth at receive time.
  final double? bearingDegrees;

  final String? origin;

  bool get hasVector => distanceMeters != null && bearingDegrees != null;

  String? get distanceLabel =>
      distanceMeters == null ? null : GeoMath.formatDistance(distanceMeters!);

  String? get directionLabel =>
      bearingDegrees == null ? null : GeoMath.compassPoint(bearingDegrees!);

  @override
  List<Object?> get props => [
        id,
        callSign,
        text,
        seq,
        msgType,
        receivedAt,
        isSos,
        hasPeerFix,
        peerLatitude,
        peerLongitude,
        distanceMeters,
        bearingDegrees,
        origin,
      ];
}

/// 4-state network lifecycle for the receiver screen.
enum ReceiverStatus {
  /// Bloc created, listener not attached yet.
  initial,

  /// UDP bind + GPS fix in progress (skeleton pulse).
  loading,

  /// Listener live — frames decode and land in the replay queue.
  loaded,

  /// Socket or bus unavailable (retryable).
  error,
}

class ReceiverState extends Equatable {
  const ReceiverState({
    this.status = ReceiverStatus.initial,
    this.listening = false,
    this.autoPlay = true,
    this.playingId,
    this.messages = const <ReceivedMessage>[],
    this.myFix,
    this.framesSeen = 0,
    this.framesAccepted = 0,
    this.framesDropped = 0,
    this.myCallSign = 'BASE-STATION-01',
    this.vectorLocked = false,
    this.distanceMeters = 0.0,
    this.bearingDegrees = 0.0,
    this.peerCallSign = '',
    this.peerLatitude = 0.0,
    this.peerLongitude = 0.0,
    this.lastAckLabel = '',
    this.note = '',
  });

  final ReceiverStatus status;
  final bool listening;
  final bool autoPlay;
  final String? playingId;
  final List<ReceivedMessage> messages;
  final GeoLocationEntity? myFix;

  final int framesSeen;
  final int framesAccepted;
  final int framesDropped;

  final String myCallSign;

  /// True when a peer GPS slot decoded and our own fix can range it.
  final bool vectorLocked;
  final double distanceMeters;
  final double bearingDegrees;
  final String peerCallSign;
  final double peerLatitude;
  final double peerLongitude;

  final String lastAckLabel;
  final String note;

  bool get isPlaying => playingId != null;

  int get peerCount {
    final calls = <String>{};
    for (final message in messages) {
      if (message.origin != null && message.origin!.isNotEmpty) {
        calls.add(message.origin!);
      }
    }
    return calls.isEmpty ? (vectorLocked ? 1 : 0) : calls.length;
  }

  String get distanceLabel => GeoMath.formatDistance(distanceMeters);

  String get bearingLabel => GeoMath.formatDegrees(bearingDegrees);

  String get directionLabel => GeoMath.compassPoint(bearingDegrees);

  String get bannerLabel => vectorLocked
      ? '$distanceLabel · $directionLabel ($bearingLabel)'
      : 'Awaiting GPS lock';

  String get listeningLabel => listening ? 'Listening' : 'Standby';

  String get autoPlayLabel => autoPlay ? 'On' : 'Off';

  int get queueCount => messages.length;

  ReceiverState copyWith({
    ReceiverStatus? status,
    bool? listening,
    bool? autoPlay,
    String? playingId,
    List<ReceivedMessage>? messages,
    GeoLocationEntity? myFix,
    bool clearMyFix = false,
    bool clearPlayingId = false,
    int? framesSeen,
    int? framesAccepted,
    int? framesDropped,
    String? myCallSign,
    bool? vectorLocked,
    double? distanceMeters,
    double? bearingDegrees,
    String? peerCallSign,
    double? peerLatitude,
    double? peerLongitude,
    String? lastAckLabel,
    String? note,
  }) {
    return ReceiverState(
      status: status ?? this.status,
      listening: listening ?? this.listening,
      autoPlay: autoPlay ?? this.autoPlay,
      playingId: clearPlayingId ? null : (playingId ?? this.playingId),
      messages: messages ?? this.messages,
      myFix: clearMyFix ? null : (myFix ?? this.myFix),
      framesSeen: framesSeen ?? this.framesSeen,
      framesAccepted: framesAccepted ?? this.framesAccepted,
      framesDropped: framesDropped ?? this.framesDropped,
      myCallSign: myCallSign ?? this.myCallSign,
      vectorLocked: vectorLocked ?? this.vectorLocked,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      bearingDegrees: bearingDegrees ?? this.bearingDegrees,
      peerCallSign: peerCallSign ?? this.peerCallSign,
      peerLatitude: peerLatitude ?? this.peerLatitude,
      peerLongitude: peerLongitude ?? this.peerLongitude,
      lastAckLabel: lastAckLabel ?? this.lastAckLabel,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => [
        status,
        listening,
        autoPlay,
        playingId,
        messages,
        myFix,
        framesSeen,
        framesAccepted,
        framesDropped,
        myCallSign,
        vectorLocked,
        distanceMeters,
        bearingDegrees,
        peerCallSign,
        peerLatitude,
        peerLongitude,
        lastAckLabel,
        note,
      ];
}
