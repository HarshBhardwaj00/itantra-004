import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/comms_entry.dart';
import '../../../data/repositories/comms_log_repository.dart';
import '../../../data/models/device_node.dart';
import 'comms_log_event.dart';
import 'comms_log_state.dart';

/// Screen 4 lifecycle:
///   Initial -> Loading (skeleton) -> Loaded (timeline) -> Error (retryable)
///
/// Computer-network responsibilities owned here:
///  * Stop-and-Wait ARQ — a 1 s tick drives the per-packet backoff timer;
///    the moment a window opens the oldest queued frame is retransmitted
///    in FIFO order.
///  * DTN / Store-and-Forward — every state change is flushed to Hive so a
///    power cycle never loses an unacknowledged packet.
///  * Deduplication — the 2-byte sequence number is the storage key, so a
///    flaky retransmit overwrites instead of duplicating.
class CommsLogBloc extends Bloc<CommsLogEvent, CommsLogState> {
  CommsLogBloc({CommsLogRepository? repository})
      : _repo = repository ?? CommsLogRepository(),
        super(const CommsLogState()) {
    on<CommsLogFetch>(_onFetch);
    on<CommsLogFilterChanged>(_onFilterChanged);
    on<CommsLogForceRetry>(_onForceRetry);
    on<CommsLogQueueTick>(_onQueueTick);
    on<CommsLogClearDelivered>(_onClearDelivered);
    on<CommsLogSendText>(_onSendText);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed) add(const CommsLogQueueTick());
    });
  }

  final CommsLogRepository _repo;
  Timer? _ticker;

  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }

  Future<void> _onFetch(
    CommsLogFetch event,
    Emitter<CommsLogState> emit,
  ) async {
    emit(state.copyWith(status: CommsLogStatus.loading, note: ''));
    try {
      final entries = await _repo.loadEntries();
      if (emit.isDone) return;
      emit(state.copyWith(
        status: CommsLogStatus.loaded,
        entries: entries,
        note: _queueNote(entries),
      ));
    } catch (_) {
      if (emit.isDone) return;
      emit(state.copyWith(
        status: CommsLogStatus.error,
        note: 'Local store unavailable',
      ));
    }
  }

  void _onFilterChanged(
    CommsLogFilterChanged event,
    Emitter<CommsLogState> emit,
  ) {
    emit(state.copyWith(filter: event.filter));
  }

  Future<void> _onForceRetry(
    CommsLogForceRetry event,
    Emitter<CommsLogState> emit,
  ) async {
    final index =
        state.entries.indexWhere((e) => e.seqNo == event.seqNo);
    if (index < 0) return;
    final target = state.entries[index];
    if (target.status != PacketStatus.queued) return;

    final updated = await _repo.forceRetry(target);
    if (emit.isDone) return;

    final entries = List<CommsEntry>.from(state.entries);
    entries[index] = updated;
    emit(state.copyWith(
      entries: entries,
      note: updated.status == PacketStatus.ackDelivered
          ? 'Forced push succeeded — ACK in ${updated.ackLatencyMs} ms'
          : 'Link still down — packet requeued',
    ));
  }

  /// ARQ driver: decrement every visible backoff counter once per second.
  /// FIFO rule — only the oldest queued packet may open the window.
  Future<void> _onQueueTick(
    CommsLogQueueTick event,
    Emitter<CommsLogState> emit,
  ) async {
    if (state.status != CommsLogStatus.loaded) return;
    if (state.queuedCount == 0) return;

    final entries = List<CommsEntry>.from(state.entries);

    final queuedIndexes = <int>[];
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].status == PacketStatus.queued) queuedIndexes.add(i);
    }
    queuedIndexes.sort((a, b) =>
        entries[a].timestamp.compareTo(entries[b].timestamp));

    var changed = false;

    for (final i in queuedIndexes) {
      final entry = entries[i];
      final updated = await _repo.transmit(entry);
      if (emit.isDone) return;
      entries[i] = updated;
      changed = true;
      // Stop-and-Wait: only one packet per window — first in wins the
      // slot, the rest keep counting down.
      if (updated.status == PacketStatus.ackDelivered) break;
    }

    if (!changed) return;
    emit(state.copyWith(entries: entries, note: _queueNote(entries)));
  }

  Future<void> _onClearDelivered(
    CommsLogClearDelivered event,
    Emitter<CommsLogState> emit,
  ) async {
    final removed = await _repo.clearDelivered();
    if (emit.isDone) return;

    final entries = QueueStorageBridge.readAfterClear(state.entries, removed);
    emit(state.copyWith(
      entries: entries,
      lastClearedCount: removed,
      note: removed == 0
          ? 'Nothing delivered yet — queue untouched'
          : '$removed delivered packet${removed == 1 ? '' : 's'} removed',
    ));
  }

  Future<void> _onSendText(
    CommsLogSendText event,
    Emitter<CommsLogState> emit,
  ) async {
    final text = event.text.trim();
    if (text.isEmpty) return;

    final node = DeviceNode.load();
    final callSign =
        (node?.callSign.isNotEmpty ?? false) ? node!.callSign : 'RESCUE-ALPHA-01';

    final entry = await _repo.enqueue(
      text: text,
      callSign: callSign,
      isSos: event.isSos,
    );
    if (emit.isDone) return;

    final transmitted = await _repo.transmit(entry, forceNow: true);
    if (emit.isDone) return;

    final entries = List<CommsEntry>.from(state.entries)
      ..insert(0, transmitted);
    emit(state.copyWith(
      entries: entries,
      note: transmitted.status == PacketStatus.ackDelivered
          ? 'Packet framed and delivered'
          : 'Link down — packet parked in queue',
    ));
  }

  String _queueNote(List<CommsEntry> entries) {
    final queued =
        entries.where((e) => e.status == PacketStatus.queued).length;
    if (queued == 0) return 'All packets acknowledged';
    return 'Store-and-forward holding $queued packet${queued == 1 ? '' : 's'}';
  }
}

/// Small helper that keeps the "clear delivered" handler pure: instead of
/// re-querying Hive we filter the in-memory list, which already matches
/// what the repository just deleted.
class QueueStorageBridge {
  QueueStorageBridge._();

  static List<CommsEntry> readAfterClear(
    List<CommsEntry> current,
    int removedCount,
  ) {
    if (removedCount == 0) return current;
    return current
        .where((e) => e.status != PacketStatus.ackDelivered)
        .toList();
  }
}
