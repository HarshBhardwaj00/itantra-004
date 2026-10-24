import 'package:equatable/equatable.dart';

sealed class TalkEvent extends Equatable {
  const TalkEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once VAD / Whisper / Piper models resolve their availability.
final class TalkEngineReady extends TalkEvent {
  final bool sttReady;
  final bool vadReady;
  final bool ttsReady;

  const TalkEngineReady({
    required this.sttReady,
    required this.vadReady,
    required this.ttsReady,
  });

  @override
  List<Object?> get props => [sttReady, vadReady, ttsReady];
}

/// PTT button pressed: 16 kHz PCM capture opens.
final class TalkStartCapture extends TalkEvent {}

/// Silero VAD observed speech while the button is held.
final class TalkVoiceDetected extends TalkEvent {}

/// PTT button released: capture closes, decoding begins.
final class TalkStopCapture extends TalkEvent {}

/// Long-press gesture was cancelled before release.
final class TalkCaptureCancelled extends TalkEvent {}

/// Capture could not be decoded (mic or model issue) with a hint.
final class TalkCaptureFailed extends TalkEvent {
  final String note;

  const TalkCaptureFailed(this.note);

  @override
  List<Object?> get props => [note];
}

/// Offline Whisper produced the final text for this hold, or text typed in composer.
final class TalkTranscriptReady extends TalkEvent {
  final String text;
  final String? audioPath;
  final bool isVoice;

  const TalkTranscriptReady(
    this.text, {
    this.audioPath,
    this.isVoice = false,
  });

  @override
  List<Object?> get props => [text, audioPath, isVoice];
}

/// Arms / disarms the SOS priority flag (0x02) for the next packet.
final class TalkToggleSos extends TalkEvent {}

/// Inbound peer transmission received from radio / alert layer.
final class TalkPeerMessageReceived extends TalkEvent {
  final String message;
  final String meta;

  const TalkPeerMessageReceived({
    required this.message,
    required this.meta,
  });

  @override
  List<Object?> get props => [message, meta];
}

/// Inbound reverse-ACK datagram received from peer receiver (Stop-and-Wait ARQ).
final class TalkAckReceived extends TalkEvent {
  final int ackSeq;
  final int status;
  final String? origin;

  const TalkAckReceived({
    required this.ackSeq,
    required this.status,
    this.origin,
  });

  @override
  List<Object?> get props => [ackSeq, status, origin];
}
