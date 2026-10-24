import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'alert_event.dart';
import 'alert_state.dart';
import '../../../core/constants/protocol_constants.dart';
import '../../../core/network/packet_codec.dart';
import '../../../core/network/quick_ack.dart';
import '../../../core/router/app_router.dart';
import '../../../data/datasources/wifi_udp_datasource.dart';
import '../../../data/datasources/virtual_lora_datasource.dart';
import '../../../presentation/widgets/emergency_dialog.dart';
import '../../../services/audio/audio_player_service.dart';
import '../../../services/speech/tts_service.dart';

/// AlertBloc — Global SOS Emergency Listener.
///
/// Network concept: **Interrupt-Driven Priority Queuing (QoS Level 0)** —
/// Listens on all radio interfaces for MsgType == 0x02 packets.
/// When detected, immediately hijacks the UI via showGeneralDialog()
/// regardless of current screen (Radar, Log, Settings, etc.).
class AlertBloc extends Bloc<AlertEvent, AlertState> {
  AlertBloc({
    required WifiUdpDataSource wifiSource,
    required VirtualLoRaDataSource loraSource,
    required AudioPlayerService audioPlayer,
    required TtsService ttsService,
  })  : _wifiSource = wifiSource,
        _loraSource = loraSource,
        _audioPlayer = audioPlayer,
        _ttsService = ttsService,
        super(const AlertState()) {
    on<AlertPacketReceived>(_onPacketReceived);
    on<AlertAcknowledged>(_onAcknowledged);
    on<AlertDismissed>(_onDismissed);
    on<AlertTestTriggered>(_onTestTriggered);

    _startListening();
  }

  final WifiUdpDataSource _wifiSource;
  final VirtualLoRaDataSource _loraSource;
  final AudioPlayerService _audioPlayer;
  final TtsService _ttsService;

  StreamSubscription<Uint8List>? _wifiSub;
  StreamSubscription<Uint8List>? _loraSub;
  BuildContext? _dialogContext;
  bool _isDialogShowing = false;

  /// Starts listening on both WiFi UDP and Virtual LoRa streams.
  void _startListening() {
    _wifiSub = _wifiSource.incomingPackets.listen(_handleIncomingPacket);
    _loraSub = _loraSource.incomingPackets.listen(_handleIncomingPacket);
  }

  /// Handles raw incoming packet from any radio interface.
  void _handleIncomingPacket(Uint8List frame) {
    // Fast-path: check magic bytes and message type before full decode.
    if (frame.length < ProtocolConstants.minimumFrameBytes) return;
    if (frame[ProtocolConstants.offsetMagic0] != ProtocolConstants.magicByte0) return;
    if (frame[ProtocolConstants.offsetMagic1] != ProtocolConstants.magicByte1) return;

    final msgType = frame[ProtocolConstants.offsetMsgType];
    if (!ProtocolConstants.isPriorityType(msgType)) return;

    // Coordinates and validation.
    final fix = PacketCodec.decodePeerFix(frame);
    final hasFix = fix != null && fix.hasCoordinates;
    final lat = hasFix ? fix.latitude : 0.0;
    final lon = hasFix ? fix.longitude : 0.0;

    // Extract payload (compressed text after GPS block).
    final payloadStart = ProtocolConstants.offsetPayloadStart;
    if (frame.length <= payloadStart + ProtocolConstants.crcBytes) return;

    final compressedPayload = frame.sublist(
      payloadStart,
      frame.length - ProtocolConstants.crcBytes,
    );

    String transcribedText = '';
    try {
      transcribedText = _decompressPayload(compressedPayload);
    } catch (_) {
      transcribedText = 'Emergency voice message received';
    }

    // Determine sender call-sign from sequence or use default.
    final senderCallSign = _extractCallSign(frame);

    // Calculate distance and bearing from our position.
    final distanceMeters = hasFix ? _estimateDistance(lat, lon) : 0.0;
    final bearingDegrees = hasFix ? _estimateBearing(lat, lon) : 0.0;

    add(AlertPacketReceived(
      senderCallSign: senderCallSign,
      distanceMeters: distanceMeters,
      bearingDegrees: bearingDegrees,
      transcribedText: transcribedText,
      latitude: lat,
      longitude: lon,
      timestamp: DateTime.now(),
    ));
  }

  /// Shows the emergency dialog globally using showGeneralDialog.
  void _showEmergencyDialog(BuildContext context, AlertState alertState) {
    if (_isDialogShowing) return;

    _isDialogShowing = true;
    _dialogContext = context;

    // Force audio to max volume and start TTS announcement.
    _startEmergencyAudio(alertState);

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      barrierLabel: 'Emergency SOS Alert',
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          EmergencyDialog(alertState: alertState),
    ).then((_) {
      _isDialogShowing = false;
      _dialogContext = null;
      _stopEmergencyAudio();
    });
  }

  /// Starts TTS announcement at maximum volume (siren disabled).
  Future<void> _startEmergencyAudio(AlertState alertState) async {
    try {
      // Speak the alert via Piper TTS.
      final ttsPath = await _ttsService.synthesizeToFile(alertState.ttsAnnouncement);
      if (ttsPath != null) {
        await _audioPlayer.playFile(ttsPath);
      }
    } catch (_) {
      // Audio errors should not crash the emergency flow.
    }
  }

  /// Stops all emergency audio.
  Future<void> _stopEmergencyAudio() async {
    await _audioPlayer.stop();
  }

  /// Sends ACK packet back to sender (STATUS = ALERT_ACKNOWLEDGED).
  Future<void> _sendAckPacket(AlertState alertState) async {
    try {
      final ackFrame = QuickAck.build(status: ProtocolConstants.statusAlertAcknowledged);
      _wifiSource.sendRawBroadcast(ackFrame);
      debugPrint('Sent ALERT_ACKNOWLEDGED to ${alertState.senderCallSign}');
    } catch (_) {
      // ACK failure should not block UI dismissal.
    }
  }

  // ---------------------------------------------------------------------
  // Event handlers
  // ---------------------------------------------------------------------

  Future<void> _onPacketReceived(
    AlertPacketReceived event,
    Emitter<AlertState> emit,
  ) async {
    // Update state with alert data.
    emit(state.copyWith(
      isAlertActive: true,
      senderCallSign: event.senderCallSign,
      distanceMeters: event.distanceMeters,
      bearingDegrees: event.bearingDegrees,
      transcribedText: event.transcribedText,
      latitude: event.latitude,
      longitude: event.longitude,
      receivedAt: event.timestamp ?? DateTime.now(),
      isAcknowledged: false,
    ));

    // Show dialog on the root navigator (global overlay).
    if (_dialogContext != null) {
      _showEmergencyDialog(_dialogContext!, state);
    }
  }

  Future<void> _onAcknowledged(
    AlertAcknowledged event,
    Emitter<AlertState> emit,
  ) async {
    // Stop audio, send ACK, dismiss dialog, navigate to Radar.
    await _stopEmergencyAudio();
    await _sendAckPacket(state);

    emit(state.copyWith(isAcknowledged: true, isAlertActive: false));

    // Pop the dialog.
    if (_dialogContext != null && _dialogContext!.mounted) {
      Navigator.of(_dialogContext!).pop();
    }

    // Navigate to Radar screen (Screen 3) for immediate rescue guidance.
    // The hub stays underneath so the tactical dock can return to it.
    if (_dialogContext != null && _dialogContext!.mounted) {
      Navigator.of(_dialogContext!).pushNamed(AppRouter.radar);
    }
  }

  void _onDismissed(AlertDismissed event, Emitter<AlertState> emit) {
    emit(state.copyWith(isAlertActive: false, isAcknowledged: false));
    if (_dialogContext != null && _dialogContext!.mounted) {
      Navigator.of(_dialogContext!).pop();
    }
  }

  void _onTestTriggered(AlertTestTriggered event, Emitter<AlertState> emit) {
    // Simulate a test alert for development.
    add(AlertPacketReceived(
      senderCallSign: 'TEST-BASE',
      distanceMeters: 850.0,
      bearingDegrees: 135.0,
      transcribedText: 'Test emergency alert — flood water rising, team stranded at sector 4',
      latitude: 28.6139,
      longitude: 77.2090,
      timestamp: DateTime.now(),
    ));
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  String _decompressPayload(Uint8List compressed) {
    try {
      final raw = const ZLibDecoder().decodeBytes(compressed);
      final text = utf8.decode(raw).trim();
      return text.isNotEmpty ? text : 'Emergency voice message';
    } catch (_) {
      return 'Emergency voice message';
    }
  }

  String _extractCallSign(Uint8List frame) {
    // Extract from sequence or payload. Simplified for scaffold.
    final seqHi = frame[ProtocolConstants.offsetSeqHi];
    return 'RESCUE-TEAM-${String.fromCharCode(65 + (seqHi % 26))}';
  }

  double _estimateDistance(double lat, double lon) {
    // Placeholder: in production use Haversine from current GPS.
    return 850.0;
  }

  double _estimateBearing(double lat, double lon) {
    // Placeholder: in production use azimuth math from current GPS.
    return 135.0;
  }

  /// Call this from the root widget to provide context for global dialog.
  void setDialogContext(BuildContext context) {
    _dialogContext = context;
  }

  @override
  Future<void> close() {
    _wifiSub?.cancel();
    _loraSub?.cancel();
    _stopEmergencyAudio();
    return super.close();
  }
}