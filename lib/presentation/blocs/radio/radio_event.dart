import 'package:equatable/equatable.dart';

abstract class RadioEvent extends Equatable {
  const RadioEvent();

  @override
  List<Object?> get props => [];
}

class RadioInitializeEvent extends RadioEvent {
  const RadioInitializeEvent();
}

class RadioScanPeersEvent extends RadioEvent {
  const RadioScanPeersEvent();
}

class RadioConnectManualEvent extends RadioEvent {
  final String ipAddress;

  const RadioConnectManualEvent(this.ipAddress);

  @override
  List<Object?> get props => [ipAddress];
}

class RadioToggleBadWifiEvent extends RadioEvent {
  final bool enabled;

  const RadioToggleBadWifiEvent(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class RadioToggleThrottleEvent extends RadioEvent {
  final bool enabled;

  const RadioToggleThrottleEvent(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class RadioToggleJammingEvent extends RadioEvent {
  final bool enabled;

  const RadioToggleJammingEvent(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class RadioLinkStatusChangedEvent extends RadioEvent {
  final String status;

  const RadioLinkStatusChangedEvent(this.status);

  @override
  List<Object?> get props => [status];
}

class RadioPeerDiscoveredEvent extends RadioEvent {
  final List<DiscoveredPeer> peers;

  const RadioPeerDiscoveredEvent(this.peers);

  @override
  List<Object?> get props => [peers];
}

class RadioConnectionStateChangedEvent extends RadioEvent {
  final RadioConnectionState state;

  const RadioConnectionStateChangedEvent(this.state);

  @override
  List<Object?> get props => [state];
}

class RadioBandwidthThrottledEvent extends RadioEvent {
  final int bitsPerSecond;

  const RadioBandwidthThrottledEvent(this.bitsPerSecond);

  @override
  List<Object?> get props => [bitsPerSecond];
}

class RadioPacketDroppedEvent extends RadioEvent {
  final int droppedCount;

  const RadioPacketDroppedEvent(this.droppedCount);

  @override
  List<Object?> get props => [droppedCount];
}

class DiscoveredPeer extends Equatable {
  final String callSign;
  final String ipAddress;
  final int signalStrength;
  final String status;

  const DiscoveredPeer({
    required this.callSign,
    required this.ipAddress,
    required this.signalStrength,
    required this.status,
  });

  @override
  List<Object?> get props => [callSign, ipAddress, signalStrength, status];
}

enum RadioConnectionState {
  disconnected,
  connecting,
  connected,
  failed,
  failoverActive,
}