import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:itantra/data/datasources/radio_packet_bus.dart';
import 'package:itantra/data/datasources/wifi_udp_datasource.dart';
import 'package:itantra/data/models/device_node.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('itantra_net_test_');
    Hive.init(tempDir.path);
    await DeviceNode.init();
  });

  tearDown(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('Computer Network Persistence & Mesh Sync Tests', () {
    test('DeviceNode saves and reloads known peers across restarts', () async {
      final peersToSave = ['192.168.1.105', '192.168.43.12'];
      await DeviceNode.saveKnownPeers(peersToSave);

      final loadedPeers = DeviceNode.loadKnownPeers();
      expect(loadedPeers, containsAll(peersToSave));
      expect(loadedPeers.length, equals(2));
    });

    test('DeviceNode saves and reloads peer directory (CallSign mapping)', () async {
      final dirToSave = {
        '192.168.1.105': 'SCOUT-CHARLIE-33',
        '192.168.43.12': 'RESCUE-ALPHA-01',
      };
      await DeviceNode.savePeerDirectory(dirToSave);

      final loadedDir = DeviceNode.loadPeerDirectory();
      expect(loadedDir['192.168.1.105'], equals('SCOUT-CHARLIE-33'));
      expect(loadedDir['192.168.43.12'], equals('RESCUE-ALPHA-01'));
    });

    test('WifiUdpDataSource initializes with persisted peers from storage', () async {
      // 1. Simulate peers that were paired earlier
      await DeviceNode.saveKnownPeers(['192.168.1.200']);

      // 2. Simulate app restarting fresh
      final wifiSource = WifiUdpDataSource();
      await wifiSource.initialize();

      // 3. Verify knownPeers contains the persisted peer
      expect(wifiSource.knownPeers, contains('192.168.1.200'));

      wifiSource.close();
    });

    test('Receiving ITANTRA_DISCOVERY immediately registers peer and publishes to RadioPacketBus', () async {
      final wifiSource = WifiUdpDataSource();
      await wifiSource.initialize();

      const incomingDiscovery = 'ITANTRA_DISCOVERY|SCOUT-CHARLIE-33|transceiver';
      final packetData = Uint8List.fromList(utf8.encode(incomingDiscovery));

      // Simulate incoming packet from peer 192.168.1.77
      wifiSource.feedPacketForTesting(packetData, origin: '192.168.1.77');

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // 1. Verify peer registered in RadioPacketBus
      final callSign = RadioPacketBus.instance.callSignFor('192.168.1.77');
      expect(callSign, equals('SCOUT-CHARLIE-33'));

      // 2. Verify peer IP is registered in storage
      final loaded = DeviceNode.loadKnownPeers();
      expect(loaded, contains('192.168.1.77'));

      wifiSource.close();
    });

    test('Reinstallation scenario: when storage is wiped, incoming peer packet restores link instantly', () async {
      // 1. Storage is empty (fresh install)
      expect(DeviceNode.loadKnownPeers(), isEmpty);

      final wifiSource = WifiUdpDataSource();
      await wifiSource.initialize();

      // 2. Peer on same Wi-Fi sends a discovery or packet
      const peerMsg = 'ITANTRA_DISCOVERY_REPLY|BASE-DELTA-02|transceiver';
      wifiSource.feedPacketForTesting(
        Uint8List.fromList(utf8.encode(peerMsg)),
        origin: '192.168.1.88',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // 3. The reinstalled node has now locked onto the peer
      final loaded = DeviceNode.loadKnownPeers();
      expect(loaded, contains('192.168.1.88'));
      expect(RadioPacketBus.instance.callSignFor('192.168.1.88'), equals('BASE-DELTA-02'));

      wifiSource.close();
    });
  });
}
