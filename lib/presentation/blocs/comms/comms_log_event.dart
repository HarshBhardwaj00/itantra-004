import 'package:equatable/equatable.dart';

sealed class CommsLogEvent extends Equatable {
  const CommsLogEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once on screen bootstrap — loads the Hive store-and-forward queue.
final class CommsLogFetch extends CommsLogEvent {
  const CommsLogFetch();
}

/// User picked a timeline filter pill.
final class CommsLogFilterChanged extends CommsLogEvent {
  final CommsFilter filter;

  const CommsLogFilterChanged(this.filter);

  @override
  List<Object?> get props => [filter];
}

/// "Force Retry Now" on a queued card — bypasses the ARQ backoff timer.
final class CommsLogForceRetry extends CommsLogEvent {
  final int seqNo;

  const CommsLogForceRetry(this.seqNo);

  @override
  List<Object?> get props => [seqNo];
}

/// Periodic 1 s tick that decrements backoff timers and flushes the queue
/// in FIFO order the moment a retry window opens.
final class CommsLogQueueTick extends CommsLogEvent {
  const CommsLogQueueTick();
}

/// "Clear Delivered History" — deletes ACKed frames, keeps the queue.
final class CommsLogClearDelivered extends CommsLogEvent {
  const CommsLogClearDelivered();
}

/// User composed a new text packet from the bottom-sheet form.
final class CommsLogSendText extends CommsLogEvent {
  final String text;
  final bool isSos;

  const CommsLogSendText({required this.text, this.isSos = false});

  @override
  List<Object?> get props => [text, isSos];
}

/// Timeline filter segment: All · Emergency SOS Only · Pending Queue.
enum CommsFilter {
  all,
  sosOnly,
  pending,
}
