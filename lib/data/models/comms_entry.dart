import 'package:equatable/equatable.dart';

/// Delivery lifecycle of a single framed packet in the comms log.
enum PacketStatus {
  /// Peer acknowledged the frame — Stop-and-Wait ARQ window closed.
  ackDelivered,

  /// Link was down — packet is held in the Hive store queue (DTN).
  queued,

  /// CRC-16 checksum failed at the receiver — frame dropped.
  crcDropped,
}

/// One transmission record shown on the Comms Log timeline.
///
/// Each entry carries a unique 2-byte packet sequence number used for
/// deduplication so the same frame is never rendered or delivered twice.
class CommsEntry extends Equatable {
  const CommsEntry({
    required this.seqNo,
    required this.callSign,
    required this.text,
    required this.timestamp,
    required this.status,
    required this.originalBytes,
    required this.sentBytes,
    this.isSos = false,
    this.ackLatencyMs = 0,
    this.retryCount = 0,
    this.retryInSec = 0,
    this.isMock = false,
  });

  /// 2-byte packet sequence number (0x0000 – 0xFFFF).
  final int seqNo;

  /// Sender node call-sign (e.g. RESCUE-ALPHA-01).
  final String callSign;

  /// Transcribed message payload shown on the card.
  final String text;

  final DateTime timestamp;
  final PacketStatus status;

  /// Raw voice capture size before zlib compression.
  final int originalBytes;

  /// Final framed packet size pushed over the radio link.
  final int sentBytes;

  /// QoS flag — true when MsgType == 0x02 (ALERT).
  final bool isSos;

  /// Round-trip ACK latency in milliseconds (0 while pending).
  final int ackLatencyMs;

  /// Number of automatic retransmissions already attempted.
  final int retryCount;

  /// Seconds remaining until the next automatic retry fires.
  final int retryInSec;

  final bool isMock;

  String get seqHex => '0x${seqNo.toRadixString(16).toUpperCase().padLeft(4, '0')}';

  double get savedPercent {
    if (originalBytes <= 0) return 0.0;
    return ((originalBytes - sentBytes) / originalBytes) * 100.0;
  }

  CommsEntry copyWith({
    int? seqNo,
    String? callSign,
    String? text,
    DateTime? timestamp,
    PacketStatus? status,
    int? originalBytes,
    int? sentBytes,
    bool? isSos,
    int? ackLatencyMs,
    int? retryCount,
    int? retryInSec,
    bool? isMock,
  }) {
    return CommsEntry(
      seqNo: seqNo ?? this.seqNo,
      callSign: callSign ?? this.callSign,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      originalBytes: originalBytes ?? this.originalBytes,
      sentBytes: sentBytes ?? this.sentBytes,
      isSos: isSos ?? this.isSos,
      ackLatencyMs: ackLatencyMs ?? this.ackLatencyMs,
      retryCount: retryCount ?? this.retryCount,
      retryInSec: retryInSec ?? this.retryInSec,
      isMock: isMock ?? this.isMock,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'seqNo': seqNo,
      'callSign': callSign,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.name,
      'originalBytes': originalBytes,
      'sentBytes': sentBytes,
      'isSos': isSos,
      'ackLatencyMs': ackLatencyMs,
      'retryCount': retryCount,
      'retryInSec': retryInSec,
      'isMock': isMock,
    };
  }

  factory CommsEntry.fromJson(Map<String, dynamic> json) {
    return CommsEntry(
      seqNo: (json['seqNo'] as num?)?.toInt() ?? 0,
      callSign: json['callSign'] as String? ?? 'UNKNOWN',
      text: json['text'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] as num?)?.toInt() ?? 0,
      ),
      status: PacketStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PacketStatus.queued,
      ),
      originalBytes: (json['originalBytes'] as num?)?.toInt() ?? 0,
      sentBytes: (json['sentBytes'] as num?)?.toInt() ?? 0,
      isSos: json['isSos'] as bool? ?? false,
      ackLatencyMs: (json['ackLatencyMs'] as num?)?.toInt() ?? 0,
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      retryInSec: (json['retryInSec'] as num?)?.toInt() ?? 0,
      isMock: json['isMock'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        seqNo,
        callSign,
        text,
        timestamp,
        status,
        originalBytes,
        sentBytes,
        isSos,
        ackLatencyMs,
        retryCount,
        retryInSec,
        isMock,
      ];
}
