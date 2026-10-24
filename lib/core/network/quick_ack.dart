import 'dart:typed_data';

import '../constants/protocol_constants.dart';

/// Compact 6-byte reverse-ACK frame used by the Receiver quick replies.
///
/// Layout (kept at exactly six bytes so a reply costs a single tiny UDP
/// datagram on the 600 bps channel):
///
/// ```text
/// [0] 0x49     magic
/// [1] 0x54     magic
/// [2] 0x03     MsgType = ACK
/// [3] status   0x00 Roger · 0x01 Standby
/// [4] seq hi
/// [5] seq lo
/// ```
class QuickAck {
  QuickAck._();

  static const int statusRoger = 0x00;
  static const int statusStandby = 0x01;

  static const int frameBytes = 6;

  /// Builds the six-byte acknowledgment datagram.
  static List<int> build({required int status, int seq = 0}) => <int>[
        ProtocolConstants.magicByte0,
        ProtocolConstants.magicByte1,
        ProtocolConstants.msgTypeAck,
        status & 0xFF,
        (seq >> 8) & 0xFF,
        seq & 0xFF,
      ];

  /// Returns the status byte of a valid ACK frame, or null when the frame
  /// is not one of ours.
  static int? tryParse(Uint8List frame) {
    if (frame.length != frameBytes) return null;
    if (frame[0] != ProtocolConstants.magicByte0) return null;
    if (frame[1] != ProtocolConstants.magicByte1) return null;
    if (frame[2] != ProtocolConstants.msgTypeAck) return null;
    return frame[3];
  }

  static String statusLabel(int status) =>
      status == statusStandby ? 'Standby' : 'Roger';
}
