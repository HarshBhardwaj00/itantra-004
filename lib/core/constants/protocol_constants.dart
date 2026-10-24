/// iTantra Tactical Protocol Constants
///
/// Network concept: **Packet Framing & QoS Priority Tagging** —
/// Message types define how the binary frame is routed and prioritized
/// across the mesh. Emergency (0x02) preempts Normal (0x01) traffic.
class ProtocolConstants {
  ProtocolConstants._();

  /// Frame magic bytes identifying an iTantra packet.
  static const int magicByte0 = 0x49; // 'I'
  static const int magicByte1 = 0x54; // 'T'

  /// Message type field values (1 byte).
  static const int msgTypeNormal = 0x01; // Standard voice/text packet
  static const int msgTypeAlert = 0x02; // SOS Emergency Alert (QoS Level 0)
  static const int msgTypeAck = 0x03; // Acknowledgment packet
  static const int msgTypeHeartbeat = 0x04; // Keep-alive / presence
  static const int msgTypeConfig = 0x05; // Radio config / channel change

  /// Status codes for ACK payloads (1 byte).
  static const int statusOk = 0x00;
  static const int statusAlertAcknowledged = 0x10; // Explicit SOS ACK
  static const int statusCrcError = 0xFF;

  /// Frame layout offsets (bytes from start of frame).
  static const int offsetMagic0 = 0;
  static const int offsetMagic1 = 1;
  static const int offsetMsgType = 2;
  static const int offsetSeqHi = 3;
  static const int offsetSeqLo = 4;
  static const int offsetTimestampStart = 5; // 4 bytes: 5,6,7,8
  static const int offsetGpsStart = 9; // 8 bytes: lat(4) + lon(4)
  static const int offsetPayloadStart = 17; // Variable: compressed payload
  static const int crcBytes = 2;

  /// Minimum valid frame size (header + GPS + CRC).
  static const int minimumFrameBytes = offsetGpsStart + 8 + crcBytes;

  /// Maximum payload size after zlib compression (fits in 600 bps slot).
  static const int maxCompressedPayloadBytes = 56;

  /// UDP broadcast discovery port.
  static const int discoveryPort = 45454;

  /// Protocol version byte (reserved for future use).
  static const int protocolVersion = 0x01;

  /// Returns human-readable name for a message type.
  static String msgTypeName(int type) {
    switch (type) {
      case msgTypeNormal:
        return 'NORMAL';
      case msgTypeAlert:
        return 'SOS_ALERT';
      case msgTypeAck:
        return 'ACK';
      case msgTypeHeartbeat:
        return 'HEARTBEAT';
      case msgTypeConfig:
        return 'CONFIG';
      default:
        return 'UNKNOWN(0x${type.toRadixString(16).toUpperCase().padLeft(2, '0')})';
    }
  }

  /// Returns true if the message type requires priority interrupt handling.
  static bool isPriorityType(int type) => type == msgTypeAlert;

  /// Returns true if the message type is an acknowledgment.
  static bool isAckType(int type) => type == msgTypeAck;
}