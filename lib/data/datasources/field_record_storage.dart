import 'package:hive/hive.dart';

import '../models/field_record.dart';

/// Persistent store for the dashboard field records.
///
/// Same delayed-tolerant principle as the comms queue: a record survives a
/// power cycle, and the record id is the de-duplication key so a re-written
/// row never duplicates.
class FieldRecordStorage {
  FieldRecordStorage._();

  static const String boxName = 'field_records';

  static Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<Map<dynamic, dynamic>>(boxName);
    }
  }

  static Box<Map<dynamic, dynamic>> get _box => Hive.box(boxName);

  /// Reads every stored record, newest first.
  static List<FieldRecord> readAll() {
    if (!Hive.isBoxOpen(boxName)) return <FieldRecord>[];

    final records = <FieldRecord>[];
    for (final raw in _box.values) {
      try {
        final json = Map<String, dynamic>.from(raw);
        records.add(FieldRecord.fromJson(json));
      } catch (_) {
        continue;
      }
    }

    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  /// Upserts one record.
  static Future<void> write(FieldRecord record) async {
    if (!Hive.isBoxOpen(boxName)) await init();
    await _box.put(record.id, record.toJson());
  }

  /// Removes one record by id.
  static Future<void> delete(String id) async {
    if (!Hive.isBoxOpen(boxName)) await init();
    await _box.delete(id);
  }

  /// Wipes the store — used when the operator resets the dashboard.
  static Future<void> clearAll() async {
    if (!Hive.isBoxOpen(boxName)) return;
    await _box.clear();
  }
}
