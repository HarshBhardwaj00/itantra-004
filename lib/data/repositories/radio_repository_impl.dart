import 'dart:io';
import 'dart:async';
import 'package:network_info_plus/network_info_plus.dart';

abstract class RadioRepository {
  Future<void> initialize();
  Future<void> scanPeers();
  Future<bool> connectToPeer(String ipAddress);
  Future<void> simulateBadWifi(bool enabled);
  Future<void> setBandwidthThrottle(int bps);
  Future<void> simulateJamming(bool enabled);
  void dispose();
}

class RadioRepositoryImpl implements RadioRepository {
  final NetworkInfo _networkInfo = NetworkInfo();
  RawDatagramSocket? _udpSocket;
  Timer? _heartbeatTimer;
  Timer? _jammingTimer;

  String _interfaceName = 'wlan0';
  String _ipAddress = '192.168.43.120';
  final int _port = 45454;
  final List<DiscoveredPeer> _discoveredPeers = [];
  RadioConnectionState _connectionState = RadioConnectionState.disconnected;
  String _activeLinkType = 'WiFi';
  bool _isBadWifiSimulated = false;
  bool _isThrottled = false;
  bool _isJammingSimulated = false;
  int _throttleBps = 600;
  int _packetsDropped = 0;

  StreamController<RadioStateUpdate>? _stateController;

  Stream<RadioStateUpdate> get stateStream => _stateController?.stream ?? const Stream.empty();

  RadioRepositoryImpl() {
    _stateController = StreamController<RadioStateUpdate>.broadcast();
  }

  @override
  Future<void> initialize() async {
    try {
      final wifiName = await _networkInfo.getWifiName();
      final wifiIp = await _networkInfo.getWifiIP();

      if (wifiIp != null) {
        _ipAddress = wifiIp;
      }
      if (wifiName != null) {
        _interfaceName = wifiName;
      }

      await _startUdpListener();
      _startHeartbeat();

      _notifyState();
    } catch (e) {
      // Radio init error
    }
  }

  Future<void> _startUdpListener() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _port,
      );

      _udpSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            _handleIncomingPacket(datagram);
          }
        }
      });

      _udpSocket!.broadcastEnabled = true;
    } catch (e) {
      // UDP listener error
    }
  }

  void _handleIncomingPacket(Datagram datagram) {
    final data = String.fromCharCodes(datagram.data);
    final senderIp = datagram.address.address;

    if (data.startsWith('ITANTRA_DISCOVERY')) {
      final parts = data.split('|');
      if (parts.length >= 3) {
        final callSign = parts[1];
        final signalStrength = _calculateSignalStrength(datagram.address);

        final existingIndex = _discoveredPeers.indexWhere((p) => p.ipAddress == senderIp);
        final peer = DiscoveredPeer(
          callSign: callSign,
          ipAddress: senderIp,
          signalStrength: signalStrength,
          status: 'Online',
        );

        if (existingIndex >= 0) {
          _discoveredPeers[existingIndex] = peer;
        } else {
          _discoveredPeers.add(peer);
        }

        _notifyState();
      }
    }
  }

  int _calculateSignalStrength(InternetAddress address) {
    final hash = address.address.hashCode.abs();
    return 60 + (hash % 40);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _sendDiscoveryBroadcast();
    });
  }

  void _sendDiscoveryBroadcast() {
    if (_udpSocket == null) return;

    final message = 'ITANTRA_DISCOVERY|iTantra-Node|transceiver';
    final data = message.codeUnits;

    try {
      _udpSocket!.send(data, InternetAddress('255.255.255.255'), _port);
    } catch (e) {
      // Broadcast error logged
    }
  }

  @override
  Future<void> scanPeers() async {
    _discoveredPeers.clear();
    _sendDiscoveryBroadcast();

    await Future.delayed(const Duration(milliseconds: 800));

    _notifyState();
  }

  @override
  Future<bool> connectToPeer(String ipAddress) async {
    _connectionState = RadioConnectionState.connecting;
    _notifyState();

    await Future.delayed(const Duration(milliseconds: 1500));

    final exists = _discoveredPeers.any((p) => p.ipAddress == ipAddress);
    if (!exists) {
      _discoveredPeers.add(DiscoveredPeer(
        callSign: 'MANUAL-PEER',
        ipAddress: ipAddress,
        signalStrength: 75,
        status: 'Connected',
      ));
    }

    _connectionState = RadioConnectionState.connected;
    _activeLinkType = 'WiFi (Direct)';
    _notifyState();
    return true;
  }

  @override
  Future<void> simulateBadWifi(bool enabled) async {
    _isBadWifiSimulated = enabled;

    if (enabled) {
      _connectionState = RadioConnectionState.failoverActive;
      _activeLinkType = 'LoRa 600 bps';
      _notifyState();

      _udpSocket?.close();
      _udpSocket = null;

      await Future.delayed(const Duration(milliseconds: 500));

      _connectionState = RadioConnectionState.connected;
      _notifyState();
    } else {
      _connectionState = RadioConnectionState.connecting;
      _activeLinkType = 'WiFi (Restoring)';
      _notifyState();

      await _startUdpListener();
      _startHeartbeat();

      await Future.delayed(const Duration(milliseconds: 800));

      _connectionState = RadioConnectionState.connected;
      _activeLinkType = 'WiFi';
      _notifyState();
    }
  }

  @override
  Future<void> setBandwidthThrottle(int bps) async {
    _throttleBps = bps;
    _isThrottled = bps > 0;
    _notifyState();
  }

  @override
  Future<void> simulateJamming(bool enabled) async {
    _isJammingSimulated = enabled;
    _packetsDropped = 0;

    if (enabled) {
      _jammingTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
        _packetsDropped++;
        _notifyState();
      });
    } else {
      _jammingTimer?.cancel();
    }

    _notifyState();
  }

  void _notifyState() {
    _stateController?.add(RadioStateUpdate(
      interfaceName: _interfaceName,
      ipAddress: _ipAddress,
      port: _port,
      discoveredPeers: List.from(_discoveredPeers),
      connectionState: _connectionState,
      activeLinkType: _activeLinkType,
      isBadWifiSimulated: _isBadWifiSimulated,
      isThrottled: _isThrottled,
      isJammingSimulated: _isJammingSimulated,
      throttleBps: _throttleBps,
      packetsDropped: _packetsDropped,
    ));
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _jammingTimer?.cancel();
    _udpSocket?.close();
    _stateController?.close();
  }
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