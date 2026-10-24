import 'package:equatable/equatable.dart';

import 'radio_event.dart';

abstract class RadioState extends Equatable {
  const RadioState();

  @override
  List<Object?> get props => [];
}

class RadioInitial extends RadioState {}

class RadioLoading extends RadioState {}

class RadioLoaded extends RadioState {
  final String interfaceName;
  final String ipAddress;
  final int port;
  final List<DiscoveredPeer> discoveredPeers;
  final RadioConnectionState connectionState;
  final String activeLinkType;
  final bool isBadWifiSimulated;
  final bool isThrottled;
  final bool isJammingSimulated;
  final int throttleBps;
  final int packetsDropped;
  final String lastAction;

  const RadioLoaded({
    required this.interfaceName,
    required this.ipAddress,
    required this.port,
    required this.discoveredPeers,
    required this.connectionState,
    required this.activeLinkType,
    required this.isBadWifiSimulated,
    required this.isThrottled,
    required this.isJammingSimulated,
    required this.throttleBps,
    required this.packetsDropped,
    required this.lastAction,
  });

  RadioLoaded copyWith({
    String? interfaceName,
    String? ipAddress,
    int? port,
    List<DiscoveredPeer>? discoveredPeers,
    RadioConnectionState? connectionState,
    String? activeLinkType,
    bool? isBadWifiSimulated,
    bool? isThrottled,
    bool? isJammingSimulated,
    int? throttleBps,
    int? packetsDropped,
    String? lastAction,
  }) {
    return RadioLoaded(
      interfaceName: interfaceName ?? this.interfaceName,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      discoveredPeers: discoveredPeers ?? this.discoveredPeers,
      connectionState: connectionState ?? this.connectionState,
      activeLinkType: activeLinkType ?? this.activeLinkType,
      isBadWifiSimulated: isBadWifiSimulated ?? this.isBadWifiSimulated,
      isThrottled: isThrottled ?? this.isThrottled,
      isJammingSimulated: isJammingSimulated ?? this.isJammingSimulated,
      throttleBps: throttleBps ?? this.throttleBps,
      packetsDropped: packetsDropped ?? this.packetsDropped,
      lastAction: lastAction ?? this.lastAction,
    );
  }

  @override
  List<Object?> get props => [
        interfaceName,
        ipAddress,
        port,
        discoveredPeers,
        connectionState,
        activeLinkType,
        isBadWifiSimulated,
        isThrottled,
        isJammingSimulated,
        throttleBps,
        packetsDropped,
        lastAction,
      ];
}

class RadioError extends RadioState {
  final String message;

  const RadioError(this.message);

  @override
  List<Object?> get props => [message];
}