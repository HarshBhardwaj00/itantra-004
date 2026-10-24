import 'package:equatable/equatable.dart';

/// Events for the AlertBloc — handles incoming SOS packets and UI lifecycle.
abstract class AlertEvent extends Equatable {
  const AlertEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when a raw packet with MsgType == 0x02 (ALERT) is received.
class AlertPacketReceived extends AlertEvent {
  const AlertPacketReceived({
    required this.senderCallSign,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.transcribedText,
    required this.latitude,
    required this.longitude,
    this.timestamp,
  });

  final String senderCallSign;
  final double distanceMeters;
  final double bearingDegrees;
  final String transcribedText;
  final double latitude;
  final double longitude;
  final DateTime? timestamp;

  @override
  List<Object?> get props => [
        senderCallSign,
        distanceMeters,
        bearingDegrees,
        transcribedText,
        latitude,
        longitude,
        timestamp,
      ];
}

/// Fired when user completes the "Slide to Acknowledge" gesture.
class AlertAcknowledged extends AlertEvent {
  const AlertAcknowledged();

  @override
  List<Object?> get props => [];
}

/// Fired when the emergency dialog should be dismissed programmatically.
class AlertDismissed extends AlertEvent {
  const AlertDismissed();

  @override
  List<Object?> get props => [];
}

/// Fired to test the emergency dialog without network packet (debug/dev).
class AlertTestTriggered extends AlertEvent {
  const AlertTestTriggered();

  @override
  List<Object?> get props => [];
}