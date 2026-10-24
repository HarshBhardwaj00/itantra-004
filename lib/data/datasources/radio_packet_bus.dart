import 'dart:async';
import 'dart:typed_data';

import '../models/device_node.dart';

/// A raw protocol frame tagged with the interface it arrived on.
class RadioFrame {
  const RadioFrame(this.bytes, {this.origin});

  /// The complete binary frame (magic header + GPS slot + payload + CRC).
  final Uint8List bytes;

  /// Sender hint used to keep multi-peer blips stable — a UDP source IP
  /// (`192.168.x.y`) or a link label (`LoRa`, `10.42.0.11`, ...).
  final String? origin;
}

/// Central fan-in for every radio interface and mesh link manager.
///
/// `WifiUdpDataSource` and `VirtualLoRaDataSource` both publish their raw
/// inbound frames here, while `RadarBloc` (and any future consumer such as
/// a mesh logger) subscribes exactly once. Transports never talk to the
/// radar directly, so a packet that lands while the radar screen is closed
/// is still captured and projected as soon as the screen opens.
class RadioPacketBus {
  RadioPacketBus._() {
    _loadDirectory();
  }

  void _loadDirectory() {
    try {
      final saved = DeviceNode.loadPeerDirectory();
      _directory.addAll(saved);
    } catch (_) {}
  }

  static final RadioPacketBus instance = RadioPacketBus._();

  final StreamController<RadioFrame> _controller =
      StreamController<RadioFrame>.broadcast();
  final List<StreamSubscription<RadioFrame>> _sources =
      <StreamSubscription<RadioFrame>>[];

  /// Origin -> call-sign map learned from `ITANTRA_DISCOVERY` broadcasts.
  final Map<String, String> _directory = <String, String>{};

  /// Live hardware & link simulation states
  bool isBadWifi = false;
  bool isJamming = false;
  int throttleBps = 600;
  String activeLinkType = 'WiFi';

  final StreamController<String> _linkStateController =
      StreamController<String>.broadcast();

  /// Emits link type changes (e.g. 'WiFi', 'LoRa 600 bps').
  Stream<String> get linkStateStream => _linkStateController.stream;

  void updateLinkState({
    bool? badWifi,
    bool? jamming,
    int? throttle,
    String? linkType,
  }) {
    if (badWifi != null) isBadWifi = badWifi;
    if (jamming != null) isJamming = jamming;
    if (throttle != null) throttleBps = throttle;
    if (linkType != null) activeLinkType = linkType;
    if (!_linkStateController.isClosed) {
      _linkStateController.add(activeLinkType);
    }
  }

  /// Every frame received from any attached interface.
  Stream<RadioFrame> get frames => _controller.stream;

  /// Fans a transport stream into the bus.
  void attach(Stream<RadioFrame> source) {
    final subscription = source.listen(
      publish,
      onError: (Object _) {},
    );
    _sources.add(subscription);
  }

  /// Publishes a single frame to every subscriber.
  void publish(RadioFrame frame) {
    if (_controller.isClosed) return;
    _controller.add(frame);
  }

  /// Remembers which call-sign sits behind an origin (from radio discovery).
  void registerPeer({required String origin, required String callSign}) {
    if (origin.isEmpty || callSign.isEmpty) return;
    _directory[origin] = callSign;
    DeviceNode.savePeerDirectory(_directory);
  }

  /// Resolves a stable call-sign for a frame origin.
  ///
  /// Falls back to a deterministic name derived from the origin so that
  /// different senders never collapse onto a single blip.
  String callSignFor(String? origin) {
    if (origin == null || origin.isEmpty) return 'PEER-LINK';
    final known = _directory[origin];
    if (known != null && known.isNotEmpty) return known;
    return _deriveCallSign(origin);
  }

  static String _deriveCallSign(String origin) {
    final octets = origin.split('.');
    if (octets.length == 4) {
      return 'PEER-${octets[2]}-${octets[3]}';
    }
    final cleaned =
        origin.replaceAll(RegExp('[^A-Za-z0-9]+'), '-').toUpperCase();
    return cleaned.isEmpty ? 'PEER-LINK' : 'PEER-$cleaned';
  }

  /// Tear-down hook used by tests; the live app never calls this.
  Future<void> dispose() async {
    for (final subscription in _sources) {
      await subscription.cancel();
    }
    _sources.clear();
    await _controller.close();
    await _linkStateController.close();
  }
}
