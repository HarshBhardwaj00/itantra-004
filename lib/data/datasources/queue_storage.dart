import 'package:hive/hive.dart';

import '../models/comms_entry.dart';

/// Persistent store-and-forward queue backed by Hive.
///
/// Delay-Tolerant Networking (DTN) concept: unacknowledged packets live in
/// this box so a device power-cycle or link drop never leaks or loses them.
/// Entries are keyed by their 2-byte packet sequence number, which also
/// gives us free deduplication (a re-framed packet overwrites, never
/// duplicates).
class QueueStorage {
  QueueStorage._();

  static const String boxName = 'comms_queue';

  static Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox<Map<dynamic, dynamic>>(boxName)
            .catchError((_) => null as dynamic);
      }
    } catch (_) {}
  }

  static Box<Map<dynamic, dynamic>> get _box => Hive.box(boxName);

  /// Loads every stored packet. A HashSet on seqNo guards against any
  /// duplicate frames that slipped in from a flaky retransmit.
  static List<CommsEntry> readAll() {
    try {
      if (!Hive.isBoxOpen(boxName)) return <CommsEntry>[];

      final seen = <int>{};
      final entries = <CommsEntry>[];

      for (final raw in _box.values) {
        try {
          final json = Map<String, dynamic>.from(raw);
          final entry = CommsEntry.fromJson(json);
          if (seen.add(entry.seqNo)) {
            entries.add(entry);
          }
        } catch (_) {
          continue;
        }
      }

      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return entries;
    } catch (_) {
      return <CommsEntry>[];
    }
  }

  /// FIFO-safe upsert: the 2-byte seq number is the dedupe key.
  static Future<void> write(CommsEntry entry) async {
    try {
      if (!Hive.isBoxOpen(boxName)) await init();
      if (Hive.isBoxOpen(boxName)) {
        await _box.put(entry.seqNo, entry.toJson());
      }
    } catch (_) {}
  }

  static Future<void> writeAll(List<CommsEntry> entries) async {
    try {
      if (!Hive.isBoxOpen(boxName)) await init();
      if (Hive.isBoxOpen(boxName)) {
        final map = <dynamic, Map<dynamic, dynamic>>{
          for (final e in entries) e.seqNo: e.toJson(),
        };
        await _box.putAll(map);
      }
    } catch (_) {}
  }

  /// Removes only acknowledged packets — queued frames stay safe.
  static Future<int> clearDelivered() async {
    if (!Hive.isBoxOpen(boxName)) return 0;

    final doomed = <dynamic>[];
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw == null) continue;
      final status = raw['status'] as String? ?? '';
      if (status == PacketStatus.ackDelivered.name) {
        doomed.add(key);
      }
    }
    await _box.deleteAll(doomed);
    return doomed.length;
  }

  static Future<void> clearAll() async {
    if (!Hive.isBoxOpen(boxName)) return;
    await _box.clear();
  }
}
