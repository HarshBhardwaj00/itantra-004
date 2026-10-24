import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crclib/catalog.dart';
import '../models/device_node.dart';
import 'radio_packet_bus.dart';

class WifiUdpDataSource {
  RawDatagramSocket? _socket;
  final int _port = 45454;
  String _localIp = '127.0.0.1';
  String _interfaceName = 'wlan0';
  final Set<String> _localIps = <String>{'127.0.0.1', 'localhost'};
  final List<String> _broadcastAddresses = <String>['255.255.255.255'];
  final Set<String> _knownPeers = <String>{};
  final Set<int> _recentSentHashes = <int>{};

  Timer? _beaconTimer;
  Timer? _watchdogTimer;
  int _beaconTicks = 0;

  StreamController<Datagram>? _packetController;
  StreamController<bool>? _connectionController;
  StreamController<Uint8List>? _incomingPacketsController;
  StreamController<RadioFrame>? _incomingFramesController;

  Stream<Datagram> get packetStream =>
      _packetController?.stream ?? const Stream.empty();
  Stream<bool> get connectionStream =>
      _connectionController?.stream ?? const Stream.empty();
  Stream<Uint8List> get incomingPackets =>
      _incomingPacketsController?.stream ?? const Stream.empty();

  /// Raw frames tagged with the sender IP, consumed by the shared bus.
  Stream<RadioFrame> get incomingFrames =>
      _incomingFramesController?.stream ?? const Stream.empty();

  WifiUdpDataSource() {
    _packetController = StreamController<Datagram>.broadcast();
    _connectionController = StreamController<bool>.broadcast();
    _incomingPacketsController = StreamController<Uint8List>.broadcast();
    _incomingFramesController = StreamController<RadioFrame>.broadcast();
  }

  Future<void> initialize() async {
    await _discoverInterfaces();
    _loadPersistedPeers();
    await _bindSocket();
    _startPeriodicBeacon();
    _startWatchdog();

    // Fast-path immediate discovery sweep on startup so nodes on the same Wi-Fi find each other in <100ms
    sendDiscoveryHeartbeat();
    _sendDiscoveryBeacon();
    triggerSubnetSweep();
  }

  void _loadPersistedPeers() {
    try {
      final loaded = DeviceNode.loadKnownPeers();
      for (final ip in loaded) {
        if (ip.isNotEmpty && ip != _localIp && ip != '127.0.0.1' && !_localIps.contains(ip)) {
          _knownPeers.add(ip);
        }
      }
    } catch (_) {}
  }

  void _persistPeers() {
    try {
      final valid = _knownPeers
          .where((ip) =>
              ip.isNotEmpty &&
              ip != _localIp &&
              ip != '127.0.0.1' &&
              !ip.endsWith('.255') &&
              ip != '255.255.255.255' &&
              !_localIps.contains(ip))
          .toList();
      DeviceNode.saveKnownPeers(valid);
    } catch (_) {}
  }

  void _registerAndPersistPeer(String ip) {
    if (ip.isEmpty ||
        _localIps.contains(ip) ||
        ip == _localIp ||
        ip == '127.0.0.1' ||
        ip.endsWith('.255') ||
        ip == '255.255.255.255') {
      return;
    }
    if (!_knownPeers.contains(ip)) {
      _knownPeers.add(ip);
      _persistPeers();
    }
  }

  String _myCallSign() {
    try {
      return DeviceNode.load()?.callSign ?? 'ITANTRA-NODE';
    } catch (_) {
      return 'ITANTRA-NODE';
    }
  }

  /// Discovers local network interfaces using pure cross-platform dart:io.
  /// Prioritizes Wi-Fi / WLAN and local LAN interfaces over cellular / mobile data
  /// (rmnet, ccmni, pdp) so dual-connected devices (5G + Wi-Fi) always bind the correct LAN.
  Future<void> _discoverInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      NetworkInterface? selectedIface;

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        for (final addr in iface.addresses) {
          _localIps.add(addr.address);
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final subnetBcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
              if (!_broadcastAddresses.contains(subnetBcast)) {
                _broadcastAddresses.add(subnetBcast);
              }
            }
          }
        }

        final isWifi = name.contains('wlan') ||
            name.contains('wi-fi') ||
            name.contains('wifi') ||
            name.contains('wl') ||
            name.contains('ap') ||
            name.contains('softap') ||
            name.contains('tether') ||
            name.contains('hotspot');
        final isEth = name.contains('eth') ||
            name.contains('en') ||
            name.contains('ethernet');
        final isCellular = name.contains('rmnet') ||
            name.contains('ccmni') ||
            name.contains('pdp') ||
            name.contains('cellular') ||
            name.contains('dummy');

        if (selectedIface == null) {
          if (!isCellular) selectedIface = iface;
        } else {
          final currentName = selectedIface.name.toLowerCase();
          final currentIsWifi = currentName.contains('wlan') ||
              currentName.contains('wi-fi') ||
              currentName.contains('wifi') ||
              currentName.contains('wl');
          if (!currentIsWifi && isWifi) {
            selectedIface = iface;
          } else if (!currentIsWifi && isEth && !currentName.contains('eth')) {
            selectedIface = iface;
          }
        }
      }

      if (selectedIface != null) {
        _interfaceName = selectedIface.name;
        for (final addr in selectedIface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            _localIp = addr.address;
            break;
          }
        }
      } else if (interfaces.isNotEmpty) {
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
              _interfaceName = iface.name;
              _localIp = addr.address;
              break;
            }
          }
          if (_localIp != '127.0.0.1') break;
        }
      }
    } catch (_) {}

    if (!_broadcastAddresses.contains('255.255.255.255')) {
      _broadcastAddresses.add('255.255.255.255');
    }
  }

  int _computeFrameHash(List<int> bytes) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < bytes.length; i++) {
      hash ^= bytes[i];
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  Future<void> _bindSocket() async {
    try {
      if (_socket != null) {
        try {
          _socket!.close();
        } catch (_) {}
        _socket = null;
      }

      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _port,
        reuseAddress: true,
        reusePort: false,
      );
      _socket!.broadcastEnabled = true;

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            _processIncomingDatagram(
              datagram.data,
              datagram.address.address,
              rawDatagram: datagram,
            );
          }
        }
      });

      _connectionController?.add(true);
    } catch (e) {
      _connectionController?.add(false);
    }
  }

  void _startPeriodicBeacon() {
    _beaconTimer?.cancel();
    _beaconTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _beaconTicks++;
      sendDiscoveryHeartbeat();
      _sendDiscoveryBeacon();

      // Opportunistic subnet sweep on startup and periodic maintenance
      if (_beaconTicks == 1 || _beaconTicks == 4 || _beaconTicks % 10 == 0) {
        triggerSubnetSweep();
      }
    });
  }

  void _sendDiscoveryBeacon() {
    final msg = 'ITANTRA_DISCOVERY|${_myCallSign()}|transceiver';
    sendBroadcast(msg);
  }

  /// Sweeps the local /24 subnet with lightweight unicast discovery pings.
  /// Overcomes router AP-isolation and broadcast packet dropping, allowing
  /// reinstalled or restarted devices on the same Wi-Fi to find each other instantly!
  void triggerSubnetSweep() {
    if (_socket == null) return;
    final msg = 'ITANTRA_DISCOVERY|${_myCallSign()}|transceiver';
    final data = utf8.encode(msg);

    final subnetsToSweep = <String>{};
    for (final ip in _localIps) {
      if (ip == '127.0.0.1' || ip == 'localhost') continue;
      final parts = ip.split('.');
      if (parts.length == 4) {
        subnetsToSweep.add('${parts[0]}.${parts[1]}.${parts[2]}.');
      }
    }
    if (subnetsToSweep.isEmpty && _localIp != '127.0.0.1') {
      final parts = _localIp.split('.');
      if (parts.length == 4) {
        subnetsToSweep.add('${parts[0]}.${parts[1]}.${parts[2]}.');
      }
    }

    // Scan all valid hosts on every discovered LAN/Wi-Fi subnet (1 to 254)
    for (final prefix in subnetsToSweep) {
      for (var host = 1; host <= 254; host++) {
        final ip = '$prefix$host';
        if (_localIps.contains(ip)) continue;
        try {
          _socket!.send(data, InternetAddress(ip), _port);
        } catch (_) {}
      }
    }
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      await _checkNetworkHealth();
    });
  }

  Future<void> _checkNetworkHealth() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      String? activeIp;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            activeIp = addr.address;
            break;
          }
        }
        if (activeIp != null) break;
      }

      final ipChanged = activeIp != null && activeIp != _localIp && activeIp != '127.0.0.1';
      final socketDead = _socket == null;

      if (ipChanged || socketDead) {
        await _discoverInterfaces();
        await _bindSocket();
        _sendDiscoveryBeacon();
        triggerSubnetSweep();
      }
    } catch (_) {}
  }

  void _processIncomingDatagram(
    Uint8List data,
    String senderIp, {
    Datagram? rawDatagram,
  }) {
    final isSelfIp = _localIps.contains(senderIp) ||
        senderIp == _localIp ||
        senderIp == '127.0.0.1';

    // Filter out loopback echoes: drop if from our own IP address
    final hash = _computeFrameHash(data);
    if (isSelfIp || (_localIps.contains(senderIp) && _recentSentHashes.contains(hash))) {
      return;
    }

    _registerAndPersistPeer(senderIp);

    // Handle discovery handshake and automatic discovery response
    if (data.isNotEmpty) {
      try {
        final text = utf8.decode(data, allowMalformed: true);
        if (text.startsWith('ITANTRA_DISCOVERY')) {
          // Mutual sync handshake: if peer sent discovery request, reply with unicast
          if (!text.startsWith('ITANTRA_DISCOVERY_REPLY')) {
            final reply = 'ITANTRA_DISCOVERY_REPLY|${_myCallSign()}|transceiver';
            sendUnicast(reply, senderIp);
          }
          final parts = text.split('|');
          if (parts.length >= 2) {
            RadioPacketBus.instance.registerPeer(
              origin: senderIp,
              callSign: parts[1],
            );
          }
          // Discovery frames are node-presence handshakes, not binary radio frames.
          // Return early so they are not pushed to the radio frame queue or checked for CRC.
          return;
        }
      } catch (_) {}
    }

    if (rawDatagram != null) {
      _packetController?.add(rawDatagram);
    }
    _incomingPacketsController?.add(data);
    _incomingFramesController?.add(
      RadioFrame(data, origin: senderIp),
    );
  }

  void feedPacketForTesting(Uint8List packet,
      {String origin = '192.168.1.100'}) {
    _processIncomingDatagram(packet, origin);
  }

  void sendBroadcast(String message) {
    if (_socket == null) return;
    final data = utf8.encode(message);
    final hash = _computeFrameHash(data);
    _recentSentHashes.add(hash);
    if (_recentSentHashes.length > 100) _recentSentHashes.remove(_recentSentHashes.first);

    final targets = <String>{
      ..._broadcastAddresses,
      '255.255.255.255',
      ..._knownPeers,
    };
    for (final target in targets) {
      try {
        _socket!.send(data, InternetAddress(target), _port);
      } catch (_) {}
    }
  }

  void sendRawBroadcast(List<int> bytes) {
    if (_socket == null) return;
    final hash = _computeFrameHash(bytes);
    _recentSentHashes.add(hash);
    if (_recentSentHashes.length > 100) _recentSentHashes.remove(_recentSentHashes.first);

    // If known peers is empty, sweep subnet to immediately wake peers
    if (_knownPeers.isEmpty) {
      triggerSubnetSweep();
    }

    final targets = <String>{
      ..._broadcastAddresses,
      '255.255.255.255',
      ..._knownPeers,
    };
    for (final target in targets) {
      try {
        _socket!.send(bytes, InternetAddress(target), _port);
      } catch (_) {}
    }
  }

  void sendRawUnicast(List<int> bytes, String targetIp) {
    if (_socket == null || targetIp.isEmpty) return;
    try {
      _socket!.send(bytes, InternetAddress(targetIp), _port);
    } catch (_) {}
  }

  void sendUnicast(String message, String targetIp) {
    if (_socket == null || targetIp.isEmpty) return;
    final data = utf8.encode(message);
    try {
      _socket!.send(data, InternetAddress(targetIp), _port);
    } catch (_) {}
  }

  /// Sends a discovery heartbeat to register presence and peer IPs.
  void sendDiscoveryHeartbeat() {
    if (_socket == null) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final frame = <int>[
      0x49, 0x54, // Magic IT
      0x04,       // msgTypeHeartbeat
      0x00, 0x01, // Seq 1
      (now >> 24) & 0xFF,
      (now >> 16) & 0xFF,
      (now >> 8) & 0xFF,
      now & 0xFF,
      0x00, 0x00, 0x00, 0x00, // Lat
      0x00, 0x00, 0x00, 0x00, // Lon
    ];
    final crc = Crc16Xmodem().convert(frame).toBigInt().toInt() & 0xFFFF;
    frame.add((crc >> 8) & 0xFF);
    frame.add(crc & 0xFF);
    sendRawBroadcast(frame);
  }

  void registerPeerIp(String ip) {
    if (ip.isNotEmpty && ip != _localIp && ip != '127.0.0.1') {
      _registerAndPersistPeer(ip);
      if (_socket != null) {
        sendUnicast('ITANTRA_DISCOVERY|${_myCallSign()}|transceiver', ip);
      }
    }
  }

  void close() {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _socket?.close();
    _socket = null;
    _packetController?.close();
    _connectionController?.close();
    _incomingPacketsController?.close();
    _incomingFramesController?.close();
  }

  String get localIp => _localIp;
  String get interfaceName => _interfaceName;
  int get port => _port;
  List<String> get broadcastAddresses => List.unmodifiable(_broadcastAddresses);
  Set<String> get knownPeers => Set.unmodifiable(_knownPeers);
}
