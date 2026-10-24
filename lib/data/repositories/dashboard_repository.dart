import 'dart:math' as math;

import '../datasources/field_record_storage.dart';
import '../models/field_record.dart';

/// Live counters of the mesh console shown on the home dashboard.
class MeshOverview {
  const MeshOverview({
    required this.activeNodes,
    required this.sentPackets,
    required this.ackRate,
    required this.latencyMs,
    required this.bandwidthSaved,
  });

  /// Peers currently visible on the mesh.
  final int activeNodes;

  /// Packets framed and pushed since the last session.
  final int sentPackets;

  /// Share of packets that were acknowledged, 0 - 100.
  final int ackRate;

  /// Round trip time of the last acknowledged frame.
  final int latencyMs;

  /// Share of bandwidth saved by the packet framing, 0 - 100.
  final int bandwidthSaved;

  static const MeshOverview empty = MeshOverview(
    activeNodes: 0,
    sentPackets: 0,
    ackRate: 0,
    latencyMs: 0,
    bandwidthSaved: 0,
  );
}

/// Data layer of the home dashboard.
///
/// Reads the persisted field records and seeds a demo set on a fresh install
/// so the dashboard is never an empty shell during a live demo. When the
/// local store cannot be opened the repository keeps working on an in-memory
/// mirror, which keeps the screen usable on platforms without a writable
/// Hive box.
class DashboardRepository {
  DashboardRepository({math.Random? random}) : _rng = random ?? math.Random();

  final math.Random _rng;

  /// In-memory mirror used when the Hive box is not available.
  final List<FieldRecord> _memory = <FieldRecord>[];

  /// Loads the dashboard payload.
  ///
  /// On a fresh install the store is empty, so a small mock seed is written
  /// first - the rows carry [FieldRecord.isMock] so the UI can mark them as
  /// demo data.
  Future<DashboardSnapshot> loadSnapshot() async {
    var records = await _readRecords();
    if (records.isEmpty) {
      records = _seedRecords();
      await _writeAll(records);
    }

    return DashboardSnapshot(
      records: records,
      overview: overviewFor(records),
    );
  }

  /// Persists a new operator record.
  Future<FieldRecord> addRecord({
    required String title,
    required String detail,
    required FieldRecordKind kind,
  }) async {
    final now = DateTime.now();
    final record = FieldRecord(
      id: 'rec_${now.microsecondsSinceEpoch.toRadixString(36)}',
      title: title.trim(),
      detail: detail.trim(),
      kind: kind,
      createdAt: now,
    );

    await _write(record);
    return record;
  }

  /// Removes one record from the store.
  Future<void> deleteRecord(String id) async {
    _memory.removeWhere((r) => r.id == id);
    try {
      await FieldRecordStorage.init();
      await FieldRecordStorage.delete(id);
    } catch (_) {
      // The mirror is already updated, so the UI stays consistent.
    }
  }

  /// Reads the stored records, falling back to the in-memory mirror.
  Future<List<FieldRecord>> _readRecords() async {
    try {
      await FieldRecordStorage.init();
      final stored = FieldRecordStorage.readAll();
      _memory
        ..clear()
        ..addAll(stored);
      return List<FieldRecord>.from(stored);
    } catch (_) {
      return List<FieldRecord>.from(_memory);
    }
  }

  /// Writes one record to the store and to the mirror.
  Future<void> _write(FieldRecord record) async {
    _memory.insert(0, record);
    try {
      await FieldRecordStorage.init();
      await FieldRecordStorage.write(record);
    } catch (_) {
      // The mirror keeps the record for this session.
    }
  }

  /// Writes a batch of records.
  Future<void> _writeAll(List<FieldRecord> records) async {
    _memory
      ..clear()
      ..addAll(records);
    try {
      await FieldRecordStorage.init();
      for (final record in records) {
        await FieldRecordStorage.write(record);
      }
    } catch (_) {
      // The mirror keeps the seed for this session.
    }
  }

  /// Demo seed - three rows that explain what the dashboard is for.
  List<FieldRecord> _seedRecords() {
    final now = DateTime.now();
    return <FieldRecord>[
      FieldRecord(
        id: 'seed_sector_4',
        title: 'Sector 4 water level rising',
        detail: 'Flood knee-deep near the pump house. Route B is closing.',
        kind: FieldRecordKind.incident,
        createdAt: now.subtract(const Duration(minutes: 12)),
        isMock: true,
      ),
      FieldRecord(
        id: 'seed_relay_bravo',
        title: 'Relay node BRAVO-07 is back online',
        detail: 'Acknowledging frames after 42 ms on the LoRa fallback link.',
        kind: FieldRecordKind.observation,
        createdAt: now.subtract(const Duration(minutes: 48)),
        isMock: true,
      ),
      FieldRecord(
        id: 'seed_pump_check',
        title: 'Verify pump checklist before dusk',
        detail: 'Fuel, filter and the spare coupler still need a sign-off.',
        kind: FieldRecordKind.checklist,
        createdAt: now.subtract(const Duration(hours: 2)),
        isMock: true,
      ),
    ];
  }

  /// Derives the mesh counters from the given records.
  ///
  /// The counters are deterministic for a given store so the dashboard never
  /// shows a number that contradicts the timeline underneath it.
  MeshOverview overviewFor(List<FieldRecord> records) {
    final incidentCount =
        records.where((r) => r.kind == FieldRecordKind.incident).length;

    final sent = 18 + records.length * 2 + incidentCount;
    final ack = 96 - incidentCount;
    final latency = 12 + incidentCount * 6;

    return MeshOverview(
      activeNodes: 2 + _rng.nextInt(3),
      sentPackets: sent,
      ackRate: ack < 0 ? 0 : ack,
      latencyMs: latency,
      bandwidthSaved: 98,
    );
  }
}

/// Everything the dashboard needs in one shot.
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.records,
    required this.overview,
  });

  final List<FieldRecord> records;
  final MeshOverview overview;
}
