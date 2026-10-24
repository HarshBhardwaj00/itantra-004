import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:itantra/data/datasources/field_record_storage.dart';
import 'package:itantra/data/models/field_record.dart';
import 'package:itantra/data/repositories/dashboard_repository.dart';

void main() {
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('itantra_dashboard_repo');
    Hive.init(dir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('a fresh install is seeded with demo records', () async {
    await FieldRecordStorage.init();
    await FieldRecordStorage.clearAll();

    final repository = DashboardRepository();
    final snapshot = await repository.loadSnapshot();

    expect(snapshot.records, isNotEmpty);
    expect(snapshot.records.every((r) => r.isMock), isTrue);
    expect(snapshot.records.first.kind, isA<FieldRecordKind>());
    expect(snapshot.overview.activeNodes, greaterThan(0));
  });

  test('a record survives a reload and can be removed again', () async {
    await FieldRecordStorage.init();
    await FieldRecordStorage.clearAll();

    final repository = DashboardRepository();
    final record = await repository.addRecord(
      title: 'Bridge at sector 4 is blocked',
      detail: 'Debris across the ramp.',
      kind: FieldRecordKind.incident,
    );

    final stored = FieldRecordStorage.readAll();
    expect(stored.any((r) => r.id == record.id), isTrue);
    expect(stored.first.title, 'Bridge at sector 4 is blocked');

    // A second load picks the record up from the store.
    final snapshot = await repository.loadSnapshot();
    expect(snapshot.records.any((r) => r.id == record.id), isTrue);

    await repository.deleteRecord(record.id);
    expect(
      FieldRecordStorage.readAll().any((r) => r.id == record.id),
      isFalse,
    );
  });

  test('the record kind survives the serialisation round trip', () async {
    await FieldRecordStorage.init();
    await FieldRecordStorage.clearAll();

    final repository = DashboardRepository();
    final record = await repository.addRecord(
      title: 'Relay node BRAVO-07 is back online',
      detail: 'Acknowledging frames after 42 ms.',
      kind: FieldRecordKind.observation,
    );

    final json = record.toJson();
    final decoded = FieldRecord.fromJson(json);

    expect(decoded.kind, FieldRecordKind.observation);
    expect(decoded.kind.label, 'Observation');
    expect(decoded.title, record.title);
  });
}
