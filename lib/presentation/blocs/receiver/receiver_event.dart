import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../domain/entities/geo_location_entity.dart';

sealed class ReceiverEvent extends Equatable {
  const ReceiverEvent();

  @override
  List<Object?> get props => [];
}

/// Screen opened / retried: attach the UDP listener and lock a GPS fix.
final class ReceiverStarted extends ReceiverEvent {
  const ReceiverStarted();
}

/// A raw radio frame (WiFi UDP or virtual LoRa) landed on the shared bus.
final class ReceiverFrameReceived extends ReceiverEvent {
  const ReceiverFrameReceived(this.bytes, {this.origin});

  final Uint8List bytes;
  final String? origin;

  @override
  List<Object?> get props => [bytes, origin];
}

/// Continuous receiver GPS stream pushed a fresh own-position fix.
final class ReceiverMyPositionChanged extends ReceiverEvent {
  const ReceiverMyPositionChanged(this.fix);

  final GeoLocationEntity fix;

  @override
  List<Object?> get props => [fix];
}

/// Replay a specific message from the local audio queue.
final class ReceiverSpeakRequested extends ReceiverEvent {
  const ReceiverSpeakRequested(this.messageId);

  final String messageId;

  @override
  List<Object?> get props => [messageId];
}

/// Stop the current TTS playback and flush the replay queue.
final class ReceiverPlaybackStopped extends ReceiverEvent {
  const ReceiverPlaybackStopped();
}

/// Toggle automatic speaker playback of every freshly decoded message.
final class ReceiverAutoPlayToggled extends ReceiverEvent {
  const ReceiverAutoPlayToggled();
}

/// Quick-response kinds mapped to the 6-byte reverse-ACK frame.
enum QuickReplyKind {
  roger,
  standby,
}

/// "Roger" / "Standby" tapped: transmit the 6-byte ACK back to the sender.
final class ReceiverQuickReply extends ReceiverEvent {
  const ReceiverQuickReply(this.kind);

  final QuickReplyKind kind;

  @override
  List<Object?> get props => [kind];
}

/// Wipe the local replay queue (keeps the socket listener running).
final class ReceiverHistoryCleared extends ReceiverEvent {
  const ReceiverHistoryCleared();
}
