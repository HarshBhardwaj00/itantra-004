import 'package:equatable/equatable.dart';

import '../../../data/models/comms_entry.dart';
import 'comms_log_event.dart';

enum CommsLogStatus {
  initial,
  loading,
  loaded,
  error,
}

class CommsLogState extends Equatable {
  const CommsLogState({
    this.status = CommsLogStatus.initial,
    this.entries = const <CommsEntry>[],
    this.filter = CommsFilter.all,
    this.note = '',
    this.lastClearedCount = 0,
  });

  final CommsLogStatus status;

  /// Full timeline, newest first — straight from the Hive queue.
  final List<CommsEntry> entries;

  final CommsFilter filter;

  /// Short human-readable hint shown under the summary bar.
  final String note;

  /// Count of records removed by the last "Clear Delivered" action.
  final int lastClearedCount;

  int get totalSent => entries.length;

  int get ackCount =>
      entries.where((e) => e.status == PacketStatus.ackDelivered).length;

  int get queuedCount =>
      entries.where((e) => e.status == PacketStatus.queued).length;

  int get sosCount => entries.where((e) => e.isSos).length;

  /// Aggregate bandwidth saved: (raw − framed) / raw across every packet.
  double get bandwidthSavedPercent {
    var raw = 0;
    var sent = 0;
    for (final e in entries) {
      raw += e.originalBytes;
      sent += e.sentBytes;
    }
    if (raw <= 0) return 0.0;
    return ((raw - sent) / raw) * 100.0;
  }

  /// Filtered view handed to the timeline ListView.
  List<CommsEntry> get visibleEntries {
    switch (filter) {
      case CommsFilter.all:
        return entries;
      case CommsFilter.sosOnly:
        return entries.where((e) => e.isSos).toList();
      case CommsFilter.pending:
        return entries
            .where((e) => e.status == PacketStatus.queued)
            .toList();
    }
  }

  CommsLogState copyWith({
    CommsLogStatus? status,
    List<CommsEntry>? entries,
    CommsFilter? filter,
    String? note,
    int? lastClearedCount,
  }) {
    return CommsLogState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      filter: filter ?? this.filter,
      note: note ?? this.note,
      lastClearedCount: lastClearedCount ?? this.lastClearedCount,
    );
  }

  @override
  List<Object?> get props => [
        status,
        entries,
        filter,
        note,
        lastClearedCount,
      ];
}
