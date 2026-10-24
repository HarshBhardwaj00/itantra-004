import 'package:equatable/equatable.dart';

enum TalkStatus {
  /// Engine idle, ready for the next hold.
  idle,

  /// Mic open, PCM streaming (AudioRecording).
  recording,

  /// Silero VAD marked speech start during the hold.
  voiceDetected,

  /// Whisper Tiny is decoding the captured audio.
  transcribing,

  /// Compressed + CRC framed packet pushed to the radio manager.
  packetSent,

  /// Stop-and-wait ARQ window: waiting for peer acknowledgement.
  waitingAck,

  /// Peer acknowledged the frame.
  ackReceived,

  /// Nothing usable was captured.
  error,
}

class TalkState extends Equatable {
  final TalkStatus status;

  /// Final text shown inside the Live Transcription HUD.
  final String transcript;

  /// Live line shown while the mic is open.
  final String liveCaption;

  /// Supporting hint (errors, engine state, packet meta).
  final String note;

  final int packetBytes;
  final int payloadBytes;
  final int latencyMs;
  final int seqNo;

  final bool sosArmed;
  final bool lastPacketWasSos;

  final bool sttReady;
  final bool vadReady;
  final bool ttsReady;

  final int queueCount;
  final String lastMessage;
  final String lastMessageMeta;
  final String? lastAudioPath;
  final bool lastMessageIsVoice;

  const TalkState({
    this.status = TalkStatus.idle,
    this.transcript = '',
    this.liveCaption = '',
    this.note = '',
    this.packetBytes = 0,
    this.payloadBytes = 0,
    this.latencyMs = 0,
    this.seqNo = 0,
    this.sosArmed = false,
    this.lastPacketWasSos = false,
    this.sttReady = false,
    this.vadReady = false,
    this.ttsReady = false,
    this.queueCount = 0,
    this.lastMessage = 'No transmissions yet',
    this.lastMessageMeta = 'Local Mesh · Standby',
    this.lastAudioPath,
    this.lastMessageIsVoice = false,
  });

  bool get isHolding =>
      status == TalkStatus.recording || status == TalkStatus.voiceDetected;

  TalkState copyWith({
    TalkStatus? status,
    String? transcript,
    String? liveCaption,
    String? note,
    int? packetBytes,
    int? payloadBytes,
    int? latencyMs,
    int? seqNo,
    bool? sosArmed,
    bool? lastPacketWasSos,
    bool? sttReady,
    bool? vadReady,
    bool? ttsReady,
    int? queueCount,
    String? lastMessage,
    String? lastMessageMeta,
    String? lastAudioPath,
    bool clearLastAudioPath = false,
    bool? lastMessageIsVoice,
  }) {
    return TalkState(
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      liveCaption: liveCaption ?? this.liveCaption,
      note: note ?? this.note,
      packetBytes: packetBytes ?? this.packetBytes,
      payloadBytes: payloadBytes ?? this.payloadBytes,
      latencyMs: latencyMs ?? this.latencyMs,
      seqNo: seqNo ?? this.seqNo,
      sosArmed: sosArmed ?? this.sosArmed,
      lastPacketWasSos: lastPacketWasSos ?? this.lastPacketWasSos,
      sttReady: sttReady ?? this.sttReady,
      vadReady: vadReady ?? this.vadReady,
      ttsReady: ttsReady ?? this.ttsReady,
      queueCount: queueCount ?? this.queueCount,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageMeta: lastMessageMeta ?? this.lastMessageMeta,
      lastAudioPath: clearLastAudioPath
          ? null
          : (lastAudioPath ?? this.lastAudioPath),
      lastMessageIsVoice: lastMessageIsVoice ?? this.lastMessageIsVoice,
    );
  }

  @override
  List<Object?> get props => [
        status,
        transcript,
        liveCaption,
        note,
        packetBytes,
        payloadBytes,
        latencyMs,
        seqNo,
        sosArmed,
        lastPacketWasSos,
        sttReady,
        vadReady,
        ttsReady,
        queueCount,
        lastMessage,
        lastMessageMeta,
        lastAudioPath,
        lastMessageIsVoice,
      ];
}
