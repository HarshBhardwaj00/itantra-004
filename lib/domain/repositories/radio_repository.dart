import 'dart:async';

abstract class RadioRepository {
  Future<void> initialize();
  Future<void> scanPeers();
  Future<bool> connectToPeer(String ipAddress);
  Future<void> simulateBadWifi(bool enabled);
  Future<void> setBandwidthThrottle(int bps);
  Future<void> simulateJamming(bool enabled);
  Stream<RadioStateUpdate> get stateStream;
  void dispose();
}

class DiscoveredPeer {
  final String callSign;
  final String ipAddress;
  final int signalStrength;
  final String status;

  DiscoveredPeer({
    required this.callSign,
    required this.ipAddress,
    required this.signalStrength,
    required this.status,
  });
}

enum RadioConnectionState {
  disconnected,
  connecting,
  connected,
  failed,
  failoverActive,
}

class RadioStateUpdate {
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

  RadioStateUpdate({
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
  });
}