import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crclib/catalog.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/protocol_constants.dart';
import '../../../core/network/haversine.dart';
import '../../../core/network/quick_ack.dart';
import '../../../data/datasources/radio_packet_bus.dart';
import '../../../data/datasources/wifi_udp_datasource.dart';
import '../../../data/models/device_node.dart';
import '../../../domain/entities/geo_location_entity.dart';
import '../../../services/audio/audio_player_service.dart';
import '../../../services/location/location_service.dart';
import '../../../services/speech/tts_service.dart';
import '../../../services/model/model_path_resolver.dart';
import 'receiver_event.dart';
import 'receiver_state.dart';

void _diag(String msg) {
  try {
    final f = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}itantra_diag.log',
    );
    f.writeAsStringSync('${DateTime.now().toIso8601String()} $msg\n',
        mode: FileMode.append);
  } catch (_) {}
}

/// Screen 6 — Receiver / Base-Station monitor.
///
/// Network pipeline: shared radio bus -> magic byte check -> CRC-16/XMODEM
/// verify -> zlib decompress -> Haversine vector engine -> Piper/system TTS
/// auto-playback. Quick replies go back out as a 6-byte ACK frame on the
/// same UDP socket (port 45454).
class ReceiverBloc extends Bloc<ReceiverEvent, ReceiverState> {
  ReceiverBloc({
    WifiUdpDataSource? wifiSource,
    TtsService? ttsService,
    AudioPlayerService? audioPlayer,
    RadioPacketBus? packetBus,
    Stream<GeoLocationEntity>? positionStream,
  })  : _wifiSource = wifiSource,
        _tts = ttsService ?? TtsService(),
        _player = audioPlayer ?? AudioPlayerService(),
        _packetBus = packetBus ?? RadioPacketBus.instance,
        _positionStream = positionStream ?? LocationService.positionStream(),
        super(const ReceiverState()) {
    _diag('ReceiverBloc constructed');
    on<ReceiverStarted>(_onStarted);
    on<ReceiverFrameReceived>(_onFrameReceived);
    on<ReceiverMyPositionChanged>(_onMyPositionChanged);
    on<ReceiverSpeakRequested>(_onSpeakRequested);
    on<ReceiverPlaybackStopped>(_onPlaybackStopped);
    on<ReceiverAutoPlayToggled>(_onAutoPlayToggled);
    on<ReceiverQuickReply>(_onQuickReply);
    on<ReceiverHistoryCleared>(_onHistoryCleared);

    _listenBus();
    _listenPosition();
  }

  final WifiUdpDataSource? _wifiSource;
  final TtsService _tts;
  final AudioPlayerService _player;
  final RadioPacketBus _packetBus;
  final Stream<GeoLocationEntity> _positionStream;

  StreamSubscription<RadioFrame>? _busSub;
  StreamSubscription<GeoLocationEntity>? _positionSub;

  final Set<String> _seenKeys = <String>{};
  final List<String> _playQueue = <String>[];
  bool _speaking = false;
  bool _stopRequested = false;
  int _ackSeq = 0;

  GeoLocationEntity? _myFix;
  bool _peerFixKnown = false;
  double _peerLatitude = 0.0;
  double _peerLongitude = 0.0;
  String _peerCallSign = '';

  final FlutterTts _flutterTts = FlutterTts();

  @override
  Future<void> close() async {
    _stopRequested = true;
    _playQueue.clear();
    await _busSub?.cancel();
    await _positionSub?.cancel();
    await _player.stop();
    try {
      await _flutterTts.stop();
    } catch (_) {}
    return super.close();
  }

  // ---------------------------------------------------------------------
  // Step 2/3: background UDP listener on the shared cross-platform bus.
  // The WiFi datasource already binds 0.0.0.0:45454 on Windows & Android.
  // ---------------------------------------------------------------------
  void _listenBus() {
    try {
      _busSub = _packetBus.frames.listen(
        (frame) {
          if (isClosed) return;
          add(ReceiverFrameReceived(frame.bytes, origin: frame.origin));
        },
        onError: (Object _) {},
        cancelOnError: false,
      );
    } catch (_) {
      // Bus unavailable — the Started event surfaces the error state.
    }
  }

  void _listenPosition() {
    try {
      _positionSub = _positionStream.listen(
        (fix) {
          if (isClosed) return;
          add(ReceiverMyPositionChanged(fix));
        },
        onError: (Object _) {},
        cancelOnError: false,
      );
    } catch (_) {
      // Continuous fix unavailable — one-shot refresh still works.
    }
  }

  Future<void> _onStarted(
    ReceiverStarted event,
    Emitter<ReceiverState> emit,
  ) async {
    _diag('_onStarted begin');
    emit(state.copyWith(
      status: ReceiverStatus.loading,
      note: 'Binding UDP socket and locking GPS fix',
    ));

    final node = DeviceNode.load();
    final callSign = (node != null && node.callSign.isNotEmpty)
        ? node.callSign
        : state.myCallSign;

    try {
      final fix = await LocationService.current();
      if (emit.isDone) return;
      if (fix.hasFix) {
        _myFix = fix;
      }

      _busSub ??= _packetBus.frames.listen(
        (frame) {
          if (isClosed) return;
          add(ReceiverFrameReceived(frame.bytes, origin: frame.origin));
        },
        onError: (Object _) {},
        cancelOnError: false,
      );

      _projectVector();
      _wifiSource?.sendDiscoveryHeartbeat();
      await ModelPathResolver.ensureInitialized();
      if (!_tts.ready) {
        await _tts.init(languageCode: AppConstants.activeLanguageCode);
      }

      _diag('_onStarted done fix=${_myFix != null}');

      emit(state.copyWith(
        status: ReceiverStatus.loaded,
        listening: true,
        myCallSign: callSign,
        myFix: _myFix,
        clearMyFix: _myFix == null,
        vectorLocked: _peerFixKnown && _myFix != null,
        distanceMeters: _distanceCache,
        bearingDegrees: _bearingCache,
        peerCallSign: _peerCallSign,
        peerLatitude: _peerLatitude,
        peerLongitude: _peerLongitude,
        note: _myFix == null
            ? 'Listening — GPS fix pending for range math'
            : 'Listening for tactical frames',
      ));
    } catch (e) {
      _diag('_onStarted ERROR $e');
      if (emit.isDone) return;
      emit(state.copyWith(
        status: ReceiverStatus.error,
        listening: false,
        note: 'Radio bus unavailable — retry to reopen the socket',
      ));
    }
  }

  // ---------------------------------------------------------------------
  // Step 3: magic bytes -> CRC-16 -> zlib decompress -> replay queue.
  // ---------------------------------------------------------------------
  void _onFrameReceived(
    ReceiverFrameReceived event,
    Emitter<ReceiverState> emit,
  ) {
    final frame = event.bytes;
    final seen = state.framesSeen + 1;
    _diag('frame len=${frame.length} origin=${event.origin} '
        'autoPlay=${state.autoPlay}');

    if (frame.length < ProtocolConstants.minimumFrameBytes ||
        frame[ProtocolConstants.offsetMagic0] !=
            ProtocolConstants.magicByte0 ||
        frame[ProtocolConstants.offsetMagic1] !=
            ProtocolConstants.magicByte1) {
      _diag('frame dropped: too short/bad magic');
      emit(state.copyWith(framesSeen: seen));
      return;
    }

    // Filter out plain-text ASCII discovery packets ('ITANTRA_DISCOVERY...')
    // so they are never treated as binary radio frames or counted as CRC drops.
    if (frame.length >= 17 && frame[2] == 0x41) {
      return;
    }

    final msgType = frame[ProtocolConstants.offsetMsgType];

    // Our own quick-ACKs and keep-alives are not voice traffic.
    if (msgType == ProtocolConstants.msgTypeAck ||
        msgType == ProtocolConstants.msgTypeHeartbeat) {
      _diag('frame dropped: ack/heartbeat msgType=$msgType');
      emit(state.copyWith(framesSeen: seen));
      return;
    }

    // CRC-16/XMODEM tail verification.
    final crcCalc = Crc16Xmodem()
            .convert(frame.sublist(0, frame.length - ProtocolConstants.crcBytes))
            .toBigInt()
            .toInt() &
        0xFFFF;
    final crcReceived = (frame[frame.length - 2] << 8) | frame[frame.length - 1];
    if (crcCalc != crcReceived) {
      _diag('frame dropped: CRC mismatch calc=$crcCalc recv=$crcReceived');
      emit(state.copyWith(
        framesSeen: seen,
        framesDropped: state.framesDropped + 1,
        note: 'CRC mismatch — frame dropped',
      ));
      return;
    }

    final seq =
        (frame[ProtocolConstants.offsetSeqHi] << 8) | frame[ProtocolConstants.offsetSeqLo];

    final timestamp = (frame[ProtocolConstants.offsetTimestampStart] << 24) |
        (frame[ProtocolConstants.offsetTimestampStart + 1] << 16) |
        (frame[ProtocolConstants.offsetTimestampStart + 2] << 8) |
        frame[ProtocolConstants.offsetTimestampStart + 3];

    // Deduplication by origin + sequence id + timestamp.
    // Retransmissions of the same packet share seq + timestamp -> deduplicated & reverse ACK re-sent.
    // New transmissions after app restart or language switch have a new timestamp -> accepted cleanly!
    final key = '${event.origin ?? 'link'}|$seq|$timestamp|$msgType';
    if (_seenKeys.contains(key)) {
      // Re-send ACK in case the sender retransmitted due to ACK loss on the network
      final isSos = msgType == ProtocolConstants.msgTypeAlert;
      final ackFrame = Uint8List.fromList(QuickAck.build(
        status: isSos ? ProtocolConstants.statusAlertAcknowledged : QuickAck.statusRoger,
        seq: seq,
      ));
      try {
        if (event.origin != null && event.origin!.isNotEmpty) {
          _wifiSource?.sendRawUnicast(ackFrame, event.origin!);
        }
        _wifiSource?.sendRawBroadcast(ackFrame);
      } catch (_) {}
      emit(state.copyWith(framesSeen: seen));
      return;
    }
    _seenKeys.add(key);
    if (_seenKeys.length > 300) _seenKeys.remove(_seenKeys.first);

    // Drop loopback frames from localhost / self
    if (event.origin == '127.0.0.1' || event.origin == 'localhost') {
      emit(state.copyWith(framesSeen: seen));
      return;
    }

    // IEEE-754 GPS slot straight out of the header.
    final data = ByteData.sublistView(frame);
    final latitude = data.getFloat32(ProtocolConstants.offsetGpsStart, Endian.big);
    final longitude =
        data.getFloat32(ProtocolConstants.offsetGpsStart + 4, Endian.big);
    final hasPeerFix = !latitude.isNaN &&
        !longitude.isNaN &&
        latitude >= -90.0 &&
        latitude <= 90.0 &&
        longitude >= -180.0 &&
        longitude <= 180.0 &&
        !(latitude == 0.0 && longitude == 0.0);

    // zlib decompression of the text payload.
    String text = '';
    var decompressed = false;
    final payloadStart = ProtocolConstants.offsetPayloadStart;
    if (frame.length > payloadStart + ProtocolConstants.crcBytes) {
      try {
        final raw = const ZLibDecoder().decodeBytes(
          frame.sublist(payloadStart, frame.length - ProtocolConstants.crcBytes),
        );
        text = utf8.decode(raw).trim();
        decompressed = text.isNotEmpty;
      } catch (_) {
        decompressed = false;
      }
    }
    if (text.isEmpty) {
      text = msgType == ProtocolConstants.msgTypeAlert
          ? 'SOS voice frame — Seq $seq'
          : 'Voice frame — Seq $seq';
    }

    final isSos = msgType == ProtocolConstants.msgTypeAlert;
    final callSign = _packetBus.callSignFor(event.origin);

    // Drop frames originating strictly from this device's own local loopback
    final isSelfOrigin = event.origin != null &&
        (_wifiSource?.localIp == event.origin ||
            event.origin == '127.0.0.1' ||
            event.origin == 'localhost');
    if (isSelfOrigin &&
        state.myCallSign.isNotEmpty &&
        callSign.toUpperCase() == state.myCallSign.toUpperCase()) {
      emit(state.copyWith(framesSeen: seen));
      return;
    }

    double? distance;
    double? bearing;
    if (hasPeerFix) {
      _peerFixKnown = true;
      _peerLatitude = latitude;
      _peerLongitude = longitude;
      _peerCallSign = callSign;
      _projectVector();
      distance = _distanceCache;
      bearing = _bearingCache;
    }

    final message = ReceivedMessage(
      id: '$key-${DateTime.now().microsecondsSinceEpoch}',
      callSign: callSign,
      text: text,
      seq: seq,
      msgType: msgType,
      isSos: isSos,
      hasPeerFix: hasPeerFix,
      peerLatitude: latitude,
      peerLongitude: longitude,
      distanceMeters: distance,
      bearingDegrees: bearing,
      receivedAt: DateTime.now(),
      origin: event.origin,
    );

    final nextMessages = <ReceivedMessage>[message, ...state.messages];
    if (nextMessages.length > 60) nextMessages.removeLast();

    // Automatic Stop-and-Wait ARQ Reverse ACK on CRC Pass (Slide 1: "Validate (CRC pass -> ACK, Invalid -> drop)")
    final ackFrame = Uint8List.fromList(QuickAck.build(
      status: isSos ? ProtocolConstants.statusAlertAcknowledged : QuickAck.statusRoger,
      seq: seq,
    ));
    try {
      if (event.origin != null && event.origin!.isNotEmpty) {
        _wifiSource?.sendRawUnicast(ackFrame, event.origin!);
      }
      _wifiSource?.sendRawBroadcast(ackFrame);
    } catch (_) {}

    emit(state.copyWith(
      status: ReceiverStatus.loaded,
      listening: true,
      messages: List<ReceivedMessage>.unmodifiable(nextMessages),
      framesSeen: seen,
      framesAccepted: state.framesAccepted + 1,
      vectorLocked: _peerFixKnown && _myFix != null,
      distanceMeters: _distanceCache,
      bearingDegrees: _bearingCache,
      peerCallSign: _peerCallSign,
      peerLatitude: _peerLatitude,
      peerLongitude: _peerLongitude,
      note: decompressed
          ? (isSos ? 'SOS packet decoded and queued' : 'Packet decoded and queued')
          : 'Frame framed without payload — placeholder queued',
    ));

    if (state.autoPlay) {
      _diag('autoPlay -> ReceiverSpeakRequested id=${message.id}');
      add(ReceiverSpeakRequested(message.id));
    } else {
      _diag('autoPlay off, skipping speak');
    }
  }

  // ---------------------------------------------------------------------
  // Step 4: Haversine range + forward bearing between the two fixes.
  // ---------------------------------------------------------------------
  double _distanceCache = 0.0;
  double _bearingCache = 0.0;

  void _projectVector() {
    final my = _myFix;
    if (my == null || !_peerFixKnown) return;
    _distanceCache = GeoMath.distanceMeters(
      my.latitude,
      my.longitude,
      _peerLatitude,
      _peerLongitude,
    );
    _bearingCache = GeoMath.bearingDegrees(
      my.latitude,
      my.longitude,
      _peerLatitude,
      _peerLongitude,
    );
  }

  void _onMyPositionChanged(
    ReceiverMyPositionChanged event,
    Emitter<ReceiverState> emit,
  ) {
    _myFix = event.fix;
    _projectVector();
    emit(state.copyWith(
      myFix: event.fix,
      vectorLocked: _peerFixKnown,
      distanceMeters: _distanceCache,
      bearingDegrees: _bearingCache,
    ));
  }

  // ---------------------------------------------------------------------
  // Step 5: auto-playback + replay queue via Piper (fallback: system TTS).
  // ---------------------------------------------------------------------
  Future<void> _onSpeakRequested(
    ReceiverSpeakRequested event,
    Emitter<ReceiverState> emit,
  ) async {
    _diag('_onSpeakRequested id=${event.messageId} speaking=$_speaking '
        'queueLen=${_playQueue.length}');
    _playQueue.add(event.messageId);
    if (_speaking) return;

    _speaking = true;
    _stopRequested = false;
    try {
      while (_playQueue.isNotEmpty && !_stopRequested) {
        final id = _playQueue.removeAt(0);
        ReceivedMessage? target;
        for (final message in state.messages) {
          if (message.id == id) {
            target = message;
            break;
          }
        }
        if (target == null) continue;

        emit(state.copyWith(
          playingId: target.id,
          note: 'Speaking incoming message',
        ));
        await _speakText(target.text);
        if (isClosed) return;
      }
    } catch (e, st) {
      _diag('Error in _onSpeakRequested: $e\n$st');
    } finally {
      _speaking = false;
      if (!isClosed) {
        emit(state.copyWith(clearPlayingId: true, note: ''));
      }
    }
  }

  Future<void> _onPlaybackStopped(
    ReceiverPlaybackStopped event,
    Emitter<ReceiverState> emit,
  ) async {
    _diag('_onPlaybackStopped received');
    _playQueue.clear();
    _stopRequested = true;
    emit(state.copyWith(clearPlayingId: true, note: 'Playback stopped'));
    _diag('_onPlaybackStopped done, clearPlayingId emitted');
    await _tts.stopPlayback(player: _player, flutterTts: _flutterTts);
  }

  void _onAutoPlayToggled(
    ReceiverAutoPlayToggled event,
    Emitter<ReceiverState> emit,
  ) {
    final next = !state.autoPlay;
    if (!next) {
      _playQueue.clear();
      unawaited(_tts.stopPlayback(player: _player, flutterTts: _flutterTts));
    }
    emit(state.copyWith(
      autoPlay: next,
      clearPlayingId: !next,
      note: next ? 'Auto-play armed' : 'Auto-play off — manual replay only',
    ));
  }

  Future<void> _speakText(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || _stopRequested) return;

    try {
      await _tts.speakText(
        text: cleanText,
        player: _player,
        flutterTts: _flutterTts,
        isStopRequested: () => _stopRequested || isClosed,
      );
    } catch (e, st) {
      _diag('ERROR in _speakText: $e\n$st');
    }
  }

  // ---------------------------------------------------------------------
  // Step 6: quick-response reverse ACK (6 bytes back over UDP 45454).
  // ---------------------------------------------------------------------
  Future<void> _onQuickReply(
    ReceiverQuickReply event,
    Emitter<ReceiverState> emit,
  ) async {
    final status = event.kind == QuickReplyKind.roger
        ? QuickAck.statusRoger
        : QuickAck.statusStandby;
    final label = QuickAck.statusLabel(status);

    _ackSeq = (_ackSeq + 1) & 0xFFFF;
    final frame = QuickAck.build(status: status, seq: _ackSeq);

    var sent = false;
    try {
      _wifiSource?.sendRawBroadcast(frame);
      sent = _wifiSource != null;
    } catch (_) {
      sent = false;
    }

    emit(state.copyWith(
      lastAckLabel: sent ? '$label · 6 B ACK sent' : '$label · radio offline',
      note: sent
          ? 'Reverse ACK frame dispatched'
          : 'No active socket for ACK',
    ));
  }

  void _onHistoryCleared(
    ReceiverHistoryCleared event,
    Emitter<ReceiverState> emit,
  ) {
    _playQueue.clear();
    unawaited(_player.stop());
    emit(state.copyWith(
      messages: const <ReceivedMessage>[],
      clearPlayingId: true,
      note: 'Replay queue cleared',
    ));
  }
}