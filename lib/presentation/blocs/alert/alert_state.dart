import 'package:equatable/equatable.dart';

/// Immutable state for the AlertBloc.
///
/// Network concept: **Interrupt-Driven Priority Queuing (QoS Level 0)** —
/// The bloc holds the emergency payload and triggers a global modal
/// that preempts all normal application flow.
class AlertState extends Equatable {
  const AlertState({
    this.isAlertActive = false,
    this.senderCallSign = '',
    this.distanceMeters = 0.0,
    this.bearingDegrees = 0.0,
    this.transcribedText = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.receivedAt,
    this.isAcknowledged = false,
  });

  /// Whether an emergency alert is currently being displayed.
  final bool isAlertActive;

  /// Call-sign of the sending node (e.g., "RESCUE-TEAM-B").
  final String senderCallSign;

  /// Distance to sender in meters.
  final double distanceMeters;

  /// Bearing to sender in degrees (0 = North, clockwise).
  final double bearingDegrees;

  /// Transcribed voice message from the sender.
  final String transcribedText;

  /// Sender latitude (degrees).
  final double latitude;

  /// Sender longitude (degrees).
  final double longitude;

  /// When the alert packet was received.
  final DateTime? receivedAt;

  /// Whether the user has acknowledged the alert via slider.
  final bool isAcknowledged;

  /// Formatted distance label (e.g., "850m" or "1.2 km").
  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()}m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// Formatted bearing label (e.g., "South-East (135°)").
  String get bearingLabel {
    const directions = [
      'North',
      'North-East',
      'East',
      'South-East',
      'South',
      'South-West',
      'West',
      'North-West',
    ];
    final index = ((bearingDegrees + 22.5) / 45).floor() % 8;
    return '${directions[index]} (${bearingDegrees.round()}\u00B0)';
  }

  /// TTS announcement text.
  String get ttsAnnouncement =>
      'Emergency SOS Alert from $senderCallSign: $distanceLabel $bearingLabel!';

  @override
  List<Object?> get props => [
        isAlertActive,
        senderCallSign,
        distanceMeters,
        bearingDegrees,
        transcribedText,
        latitude,
        longitude,
        receivedAt,
        isAcknowledged,
      ];

  AlertState copyWith({
    bool? isAlertActive,
    String? senderCallSign,
    double? distanceMeters,
    double? bearingDegrees,
    String? transcribedText,
    double? latitude,
    double? longitude,
    DateTime? receivedAt,
    bool? isAcknowledged,
  }) {
    return AlertState(
      isAlertActive: isAlertActive ?? this.isAlertActive,
      senderCallSign: senderCallSign ?? this.senderCallSign,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      bearingDegrees: bearingDegrees ?? this.bearingDegrees,
      transcribedText: transcribedText ?? this.transcribedText,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      receivedAt: receivedAt ?? this.receivedAt,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
    );
  }
}