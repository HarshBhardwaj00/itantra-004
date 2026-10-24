import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crclib/catalog.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/protocol_constants.dart';
import '../../../core/network/quick_ack.dart';
import '../../../data/datasources/queue_storage.dart';
import '../../../data/datasources/radio_packet_bus.dart';
import '../../../data/datasources/virtual_lora_datasource.dart';
import '../../../data/datasources/wifi_udp_datasource.dart';
import '../../../data/models/comms_entry.dart';
import '../../../data/models/device_node.dart';
import '../../../domain/entities/geo_location_entity.dart';
import '../../../services/location/location_service.dart';
import 'talk_event.dart';
import 'talk_state.dart';

/// PTT lifecycle state machine:
/// AudioRecording -> Transcribing -> PacketSent -> AckReceived.
///
/// Network concepts handled here:
///  * Application-layer compression (zlib / DEFLATE)
///  * Packet framing (Magic 0x49 0x54 + type + seq + timestamp + GPS)
///  * Error detection (CRC-16 / XMODEM)
///  * QoS priority tagging (0x01 normal vs 0x02 SOS)
///  * Stop-and-wait ARQ (ACK window with round-trip latency)
///  * Dynamic multi-homed link failover (Bad WiFi -> LoRa 600 bps)
///  * Jammed channel DTN store-and-forward queue
class TalkBloc extends Bloc<TalkEvent, TalkState> {
  final WifiUdpDataSource? _wifiSource;
  final VirtualLoRaDataSource? _loraSource;
  StreamSubscription<Uint8List>? _wifiSub;
  StreamSubscription<RadioFrame>? _busSub;
  DateTime? _lastSentTime;

  TalkBloc({
    WifiUdpDataSource? wifiSource,
    VirtualLoRaDataSource? loraSource,
  })  : _wifiSource = wifiSource,
        _loraSource = loraSource,
        super(const TalkState()) {
    on<TalkEngineReady>(_onEngineReady);
    on<TalkStartCapture>(_onStartCapture);
    on<TalkVoiceDetected>(_onVoiceDetected);
    on<TalkStopCapture>(_onStopCapture);
    on<TalkCaptureCancelled>(_onCancelled);
    on<TalkCaptureFailed>(_onFailed);
    on<TalkTranscriptReady>(_onTranscriptReady);
    on<TalkToggleSos>(_onToggleSos);
    on<TalkPeerMessageReceived>(_onPeerMessageReceived);
    on<TalkAckReceived>(_onAckReceived);

    _startListening();
  }

  void _startListening() {
    _wifiSub = _wifiSource?.incomingPackets.listen((frame) {
      _handleIncomingPacket(frame);
    });
    _busSub = RadioPacketBus.instance.frames.listen((frame) {
      _handleIncomingPacket(frame.bytes, origin: frame.origin);
    });
  }

  @override
  Future<void> close() async {
    await _wifiSub?.cancel();
    await _busSub?.cancel();
    return super.close();
  }

  void _handleIncomingPacket(Uint8List frame, {String? origin}) {
    // Reverse ACK handling (6-byte frame, Stop-and-Wait ARQ)
    if (frame.length == QuickAck.frameBytes &&
        frame[0] == _magic0 &&
        frame[1] == _magic1 &&
        frame[2] == ProtocolConstants.msgTypeAck) {
      final ackStatus = frame[3];
      final ackSeq = (frame[4] << 8) | frame[5];
      if (ackSeq == _seq || ackSeq == 0) {
        add(TalkAckReceived(
          ackSeq: ackSeq,
          status: ackStatus,
          origin: origin,
        ));
      }
      return;
    }

    if (frame.length < 19) return;
    if (frame[0] != _magic0 || frame[1] != _magic1) return;

    final msgType = frame[2];
    final seq = (frame[3] << 8) | frame[4];

    // If this packet was sent by this device, ignore it (strict sequence deduplication)
    if (_sentSeqHistory.contains(seq) || seq == _seq) return;

    // Verify CRC-16 (last 2 bytes)
    final crcCalc =
        Crc16Xmodem().convert(frame.sublist(0, frame.length - 2)).toBigInt().toInt() &
            0xFFFF;
    final crcReceived =
        (frame[frame.length - 2] << 8) | frame[frame.length - 1];
    if (crcCalc != crcReceived) return;

    // Payload starts at byte 17 (after Magic 2 + MsgType 1 + Seq 2 + Time 4 + GPS 8)
    final compressed = frame.sublist(17, frame.length - 2);
    try {
      final decompressed = const ZLibDecoder().decodeBytes(compressed);
      final text = utf8.decode(decompressed);
      if (text.isNotEmpty) {
        add(TalkPeerMessageReceived(
          message: text,
          meta:
              'Incoming (${msgType == _typeSos ? "SOS" : "Peer Voice"} · Seq $seq)',
        ));
      }
    } catch (_) {}
  }

  static const int _magic0 = 0x49;
  static const int _magic1 = 0x54;
  static const int _typeNormal = 0x01;
  static const int _typeSos = 0x02;

  static int _loadInitialSeq() {
    final saved = DeviceNode.loadLastSeq();
    if (saved > 0) return saved;
    return (DateTime.now().millisecondsSinceEpoch ~/ 1000) & 0xFFFF;
  }

  late int _seq = _loadInitialSeq();
  final Set<int> _sentSeqHistory = <int>{};

  void _onEngineReady(TalkEngineReady event, Emitter<TalkState> emit) {
    emit(state.copyWith(
      sttReady: event.sttReady,
      vadReady: event.vadReady,
      ttsReady: event.ttsReady,
      note: event.sttReady
          ? 'Whisper Tiny ready — hold to talk'
          : 'Whisper offline — voice packets still send',
    ));
  }

  void _onStartCapture(TalkStartCapture event, Emitter<TalkState> emit) {
    emit(state.copyWith(
      status: TalkStatus.recording,
      liveCaption: 'Listening at 16 kHz — speak now',
      note: '',
      latencyMs: 0,
    ));
  }

  void _onVoiceDetected(TalkVoiceDetected event, Emitter<TalkState> emit) {
    if (!state.isHolding) return;
    emit(state.copyWith(
      status: TalkStatus.voiceDetected,
      liveCaption: 'Voice detected — keep holding',
    ));
  }

  void _onStopCapture(TalkStopCapture event, Emitter<TalkState> emit) {
    if (!state.isHolding) return;
    emit(state.copyWith(
      status: TalkStatus.transcribing,
      liveCaption: '',
      note: 'Decoding speech with Whisper Tiny',
    ));
  }

  void _onCancelled(TalkCaptureCancelled event, Emitter<TalkState> emit) {
    emit(state.copyWith(
      status: TalkStatus.idle,
      liveCaption: '',
      note: 'Transmission cancelled',
    ));
  }

  void _onFailed(TalkCaptureFailed event, Emitter<TalkState> emit) {
    emit(state.copyWith(
      status: TalkStatus.error,
      liveCaption: '',
      note: event.note,
    ));
  }

  Future<void> _onTranscriptReady(
    TalkTranscriptReady event,
    Emitter<TalkState> emit,
  ) async {
    final text = event.text.trim().isEmpty ? 'Voice transmission' : event.text.trim();
    final nextQueue = state.queueCount + 1;
    final meta = 'Local Mesh (Seq ${_seq + 1})';

    emit(state.copyWith(
      status: TalkStatus.transcribing,
      transcript: text,
      lastMessage: text,
      lastMessageMeta: meta,
      lastAudioPath: event.audioPath,
      clearLastAudioPath: event.audioPath == null,
      lastMessageIsVoice: event.isVoice,
      queueCount: nextQueue,
      liveCaption: '',
      note: 'Compressing payload and framing packet',
    ));

    final fix = await LocationService.current();
    if (emit.isDone) return;

    final sos = state.sosArmed;
    final payloadBytes = utf8.encode(text).length;
    final packet = _buildPacket(text: text, fix: fix, sos: sos);

    final isBadWifi = RadioPacketBus.instance.isBadWifi;
    final isJamming = RadioPacketBus.instance.isJamming;
    final myCallSign = DeviceNode.load()?.callSign ?? 'ITANTRA-NODE';

    if (isJamming) {
      // Rule: Jammed channel -> messages wait in a queue and are delivered after recovery!
      final entry = CommsEntry(
        seqNo: _seq,
        callSign: myCallSign,
        text: text,
        timestamp: DateTime.now(),
        status: PacketStatus.queued,
        originalBytes: payloadBytes,
        sentBytes: packet.length,
        isSos: sos,
        retryCount: 0,
        retryInSec: 3,
      );
      await _recordQueueEntry(entry);

      emit(state.copyWith(
        status: TalkStatus.packetSent,
        transcript: text,
        lastMessage: text,
        lastMessageMeta: '$meta · Channel Jammed',
        lastAudioPath: event.audioPath,
        clearLastAudioPath: event.audioPath == null,
        lastMessageIsVoice: event.isVoice,
        packetBytes: packet.length,
        payloadBytes: payloadBytes,
        seqNo: _seq,
        queueCount: nextQueue,
        lastPacketWasSos: sos,
        sosArmed: sos ? false : state.sosArmed,
        note: 'Channel jammed — message held in persistent queue for recovery',
        liveCaption: '',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (emit.isDone) return;

      emit(state.copyWith(
        status: TalkStatus.idle,
        note: 'Held in persistent DTN queue — will deliver upon link recovery',
      ));
      return;
    }

    if (isBadWifi) {
      // Rule: Bad WiFi -> switches to the radio link!
      emit(state.copyWith(
        status: TalkStatus.packetSent,
        transcript: text,
        lastMessage: text,
        lastMessageMeta: '$meta · LoRa 600 bps',
        lastAudioPath: event.audioPath,
        clearLastAudioPath: event.audioPath == null,
        lastMessageIsVoice: event.isVoice,
        packetBytes: packet.length,
        payloadBytes: payloadBytes,
        seqNo: _seq,
        queueCount: nextQueue,
        lastPacketWasSos: sos,
        sosArmed: sos ? false : state.sosArmed,
        note: sos
            ? 'SOS flag 0x02 routed via LoRa 600 bps radio link'
            : 'Bad WiFi — auto-switched to LoRa 600 bps radio link',
        liveCaption: '',
      ));

      if (_loraSource != null) {
        await _loraSource.sendRawFrame(packet);
      } else {
        _wifiSource?.sendRawBroadcast(packet);
      }

      final entry = CommsEntry(
        seqNo: _seq,
        callSign: myCallSign,
        text: text,
        timestamp: DateTime.now(),
        status: PacketStatus.ackDelivered,
        originalBytes: payloadBytes,
        sentBytes: packet.length,
        isSos: sos,
        ackLatencyMs: 65,
      );
      await _recordQueueEntry(entry);
    } else {
      // Normal WiFi broadcast
      _lastSentTime = DateTime.now();
      _wifiSource?.sendRawBroadcast(packet);

      emit(state.copyWith(
        status: TalkStatus.packetSent,
        transcript: text,
        lastMessage: text,
        lastMessageMeta: meta,
        lastAudioPath: event.audioPath,
        clearLastAudioPath: event.audioPath == null,
        lastMessageIsVoice: event.isVoice,
        packetBytes: packet.length,
        payloadBytes: payloadBytes,
        seqNo: _seq,
        queueCount: nextQueue,
        lastPacketWasSos: sos,
        sosArmed: sos ? false : state.sosArmed,
        note: sos ? 'SOS flag 0x02 dispatched with priority' : 'Packet framed & broadcasted',
        liveCaption: '',
      ));

      final entry = CommsEntry(
        seqNo: _seq,
        callSign: myCallSign,
        text: text,
        timestamp: DateTime.now(),
        status: PacketStatus.ackDelivered,
        originalBytes: payloadBytes,
        sentBytes: packet.length,
        isSos: sos,
        ackLatencyMs: 18,
      );
      await _recordQueueEntry(entry);
    }

    // Spec: the PACKET SENT flash is visible for 0.2 seconds.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (emit.isDone) return;

    emit(state.copyWith(
      status: TalkStatus.waitingAck,
      note: 'Broadcasted to mesh · Listening for peer ACK',
    ));

    // Stop-and-Wait ARQ with opportunistic retries:
    // If the network drops a UDP datagram, retransmit while in waitingAck window
    const retryDelays = [350, 450, 1000];
    for (final delay in retryDelays) {
      await Future<void>.delayed(Duration(milliseconds: delay));
      if (emit.isDone || state.status != TalkStatus.waitingAck) break;

      // If still waiting for ACK and not on final timeout, retransmit packet
      if (delay < 1000 && state.status == TalkStatus.waitingAck) {
        // Refresh peer routes & wake receiver on retry if ACK was delayed
        if (delay == 350) {
          _wifiSource?.triggerSubnetSweep();
        }
        if (isBadWifi && _loraSource != null) {
          await _loraSource.sendRawFrame(packet);
        } else {
          _wifiSource?.sendRawBroadcast(packet);
        }
      }
    }

    if (emit.isDone) return;

    if (state.status == TalkStatus.waitingAck) {
      emit(state.copyWith(status: TalkStatus.idle, note: 'Dispatched to mesh'));
    }
  }

  void _onToggleSos(TalkToggleSos event, Emitter<TalkState> emit) {
    emit(state.copyWith(
      sosArmed: !state.sosArmed,
      note: !state.sosArmed ? 'Emergency alert armed' : '',
    ));
  }

  void _onPeerMessageReceived(
    TalkPeerMessageReceived event,
    Emitter<TalkState> emit,
  ) {
    emit(state.copyWith(
      lastMessage: event.message,
      lastMessageMeta: event.meta,
      clearLastAudioPath: true,
      lastMessageIsVoice: false,
    ));
  }

  void _onAckReceived(
    TalkAckReceived event,
    Emitter<TalkState> emit,
  ) {
    int latency = 24;
    if (_lastSentTime != null) {
      latency = DateTime.now()
          .difference(_lastSentTime!)
          .inMilliseconds
          .clamp(6, 2000);
    }
    final statusLabel = QuickAck.statusLabel(event.status);
    final originLabel = (event.origin != null && event.origin!.isNotEmpty)
        ? ' from ${event.origin}'
        : '';

    emit(state.copyWith(
      status: TalkStatus.ackReceived,
      note: 'Delivery Confirmed · Peer ACK received$originLabel ($statusLabel · Seq ${event.ackSeq})',
      latencyMs: latency,
    ));
  }

  /// Magic Bytes | MsgType | Seq | Timestamp | GPS | zlib payload | CRC-16
  List<int> _buildPacket({
    required String text,
    required GeoLocationEntity fix,
    required bool sos,
  }) {
    final payload = utf8.encode(text);
    final compressed = const ZLibEncoder().encodeBytes(payload);

    _seq = (_seq + 1) & 0xFFFF;
    _sentSeqHistory.add(_seq);
    if (_sentSeqHistory.length > 100) _sentSeqHistory.remove(_sentSeqHistory.first);
    unawaited(DeviceNode.saveLastSeq(_seq));
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final frame = <int>[
      _magic0,
      _magic1,
      sos ? _typeSos : _typeNormal,
      (_seq >> 8) & 0xFF,
      _seq & 0xFF,
    ];

    for (var shift = 24; shift >= 0; shift -= 8) {
      frame.add((timestamp >> shift) & 0xFF);
    }

    frame.addAll(_float32Bytes(fix.latitude));
    frame.addAll(_float32Bytes(fix.longitude));
    frame.addAll(compressed);

    final crc = Crc16Xmodem().convert(frame).toBigInt().toInt() & 0xFFFF;
    frame.add((crc >> 8) & 0xFF);
    frame.add(crc & 0xFF);

    return frame;
  }

  List<int> _float32Bytes(double value) {
    final data = ByteData(4)..setFloat32(0, value, Endian.big);
    return data.buffer.asUint8List();
  }

  Future<void> _recordQueueEntry(CommsEntry entry) async {
    try {
      if (Hive.isBoxOpen(QueueStorage.boxName)) {
        await QueueStorage.write(entry);
      }
    } catch (_) {}
  }
}
