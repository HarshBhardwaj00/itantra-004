import 'dart:math' as math;

import '../datasources/queue_storage.dart';
import '../datasources/radio_packet_bus.dart';
import '../models/comms_entry.dart';

/// Data layer for Screen 4. Reads/writes the Hive store-and-forward queue
/// and simulates the Stop-and-Wait ARQ transmit window against the radio
/// link. Mock seed data keeps the timeline demo-ready on a fresh install.
class CommsLogRepository {
  CommsLogRepository({math.Random? random}) : _rng = random ?? math.Random();

  final math.Random _rng;

  int _nextSeq = 0x04D0;

  /// Loads the persistent queue.
  Future<List<CommsEntry>> loadEntries() async {
    await QueueStorage.init();

    final stored = QueueStorage.readAll();
    return stored;
  }

  /// Frames a new message packet and pushes it through the transmit window.
  ///
  /// Network concepts: zlib-style payload estimate, 2-byte sequence ID,
  /// Stop-and-Wait ACK latency. When [forceNow] is true the ARQ backoff
  /// timer is bypassed (used by "Force Retry Now").
  Future<CommsEntry> enqueue({
    required String text,
    required String callSign,
    bool isSos = false,
  }) async {
    await QueueStorage.init();

    final seq = _nextSeq & 0xFFFF;
    _nextSeq = (_nextSeq + 1) & 0xFFFF;

    final rawBytes = 16000 * 2 * (1 + text.length ~/ 14);
    final framedBytes = 28 + (text.length ~/ 3);

    final entry = CommsEntry(
      seqNo: seq,
      callSign: callSign,
      text: text.trim(),
      timestamp: DateTime.now(),
      status: PacketStatus.queued,
      originalBytes: rawBytes,
      sentBytes: framedBytes,
      isSos: isSos,
      retryCount: 0,
      retryInSec: 4,
    );

    await QueueStorage.write(entry);
    return entry;
  }

  /// Attempts one transmit of [entry]. Returns the updated record.
  ///
  /// [forceNow] skips the backoff window and pushes immediately.
  /// When channel is jammed, packets strictly wait in queue and are delivered after recovery.
  Future<CommsEntry> transmit(CommsEntry entry, {bool forceNow = false}) async {
    await QueueStorage.init();

    if (!forceNow && entry.retryInSec > 0) {
      return entry.copyWith(retryInSec: entry.retryInSec - 1);
    }

    final isJamming = RadioPacketBus.instance.isJamming;

    if (isJamming) {
      // Jammed channel: packets wait in queue and retry
      final updated = entry.copyWith(
        status: PacketStatus.queued,
        retryCount: entry.retryCount + 1,
        retryInSec: math.min(3 + entry.retryCount, 12),
      );
      await QueueStorage.write(updated);
      return updated;
    }

    final successRoll = entry.isSos ? 0.95 : 0.85;
    final ok = _rng.nextDouble() < successRoll;

    final updated = ok
        ? entry.copyWith(
            status: PacketStatus.ackDelivered,
            ackLatencyMs: 8 + _rng.nextInt(24),
            retryInSec: 0,
          )
        : entry.copyWith(
            retryCount: entry.retryCount + 1,
            retryInSec: math.min(4 + entry.retryCount * 2, 20),
          );

    await QueueStorage.write(updated);
    return updated;
  }

  /// Purges acknowledged frames only — the DTN queue is never touched.
  Future<int> clearDelivered() => QueueStorage.clearDelivered();

  /// Rebuilds one queued entry after an external force-retry signal.
  Future<CommsEntry> forceRetry(CommsEntry entry) => transmit(entry, forceNow: true);
}
