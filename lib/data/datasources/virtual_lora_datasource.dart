import 'dart:async';
import 'dart:typed_data';

import 'radio_packet_bus.dart';
import 'wifi_udp_datasource.dart';

class VirtualLoRaDataSource {
  StreamController<String>? _packetController;
  StreamController<bool>? _statusController;
  StreamController<Uint8List>? _incomingPacketsController;
  StreamController<RadioFrame>? _incomingFramesController;
  WifiUdpDataSource? _wifiSource;

  int _bitrateBps = 600;
  bool _isActive = false;
  int _packetsSent = 0;
  int _packetsReceived = 0;
  int _bytesTransferred = 0;

  Stream<String> get packetStream => _packetController?.stream ?? const Stream.empty();
  Stream<bool> get statusStream => _statusController?.stream ?? const Stream.empty();
  Stream<Uint8List> get incomingPackets => _incomingPacketsController?.stream ?? const Stream.empty();

  /// Raw frames tagged with the link origin, consumed by the bus.
  Stream<RadioFrame> get incomingFrames =>
      _incomingFramesController?.stream ?? const Stream.empty();

  VirtualLoRaDataSource() {
    _packetController = StreamController<String>.broadcast();
    _statusController = StreamController<bool>.broadcast();
    _incomingPacketsController = StreamController<Uint8List>.broadcast();
    _incomingFramesController = StreamController<RadioFrame>.broadcast();
  }

  void attachWifi(WifiUdpDataSource wifi) {
    _wifiSource = wifi;
  }

  void activate({int bitrateBps = 600}) {
    _bitrateBps = bitrateBps;
    _isActive = true;
    _packetsSent = 0;
    _packetsReceived = 0;
    _bytesTransferred = 0;
    _statusController?.add(true);
    // Link active in standby for real physical LoRa hardware / USB bridges.
    // Zero mock data injected.
  }

  void deactivate() {
    _isActive = false;
    _statusController?.add(false);
  }

  void sendPacket(String payload) {
    if (!_isActive) return;

    final packet = 'LORA_PKT|$payload|${DateTime.now().millisecondsSinceEpoch}';
    _packetsSent++;
    _bytesTransferred += payload.length;

    final transmissionTimeMs = (payload.length * 8 / _bitrateBps * 1000).round();

    Future.delayed(Duration(milliseconds: transmissionTimeMs), () {
      _packetController?.add('TX: $packet');
    });
  }

  /// Transmits raw binary frame over the simulated/virtual 600 bps LoRa radio link.
  /// Enforces bandwidth throttling to emulate physical LoRa transmission latency (75 B/s).
  Future<void> sendRawFrame(List<int> bytes, {String? targetIp}) async {
    if (!_isActive) activate();

    _packetsSent++;
    _bytesTransferred += bytes.length;

    // Emulate physical LoRa airtime at 600 bps:
    // e.g. 50 bytes * 8 bits = 400 bits / 600 bps ~ 666 ms transmission time
    final transmissionTimeMs =
        ((bytes.length * 8) / _bitrateBps * 1000).round().clamp(60, 1000);
    await Future.delayed(Duration(milliseconds: transmissionTimeMs));

    if (!_isActive) return;
    final frameData = Uint8List.fromList(bytes);

    // Deliver to local radio bus with 'LoRa 600 bps' origin
    final frame = RadioFrame(frameData, origin: 'LoRa 600 bps');
    if (_incomingFramesController != null && !_incomingFramesController!.isClosed) {
      _incomingFramesController!.add(frame);
    }
    if (_incomingPacketsController != null && !_incomingPacketsController!.isClosed) {
      _incomingPacketsController!.add(frameData);
    }

    // Also send over physical fallback network if reachable so peer receives it
    _wifiSource?.sendRawBroadcast(bytes);
  }

  void dispose() {
    deactivate();
    _packetController?.close();
    _statusController?.close();
    _incomingPacketsController?.close();
    _incomingFramesController?.close();
  }

  int get bitrateBps => _bitrateBps;
  bool get isActive => _isActive;
  int get packetsSent => _packetsSent;
  int get packetsReceived => _packetsReceived;
  int get bytesTransferred => _bytesTransferred;
}
