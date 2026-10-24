import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;

import 'radio_event.dart';
import 'radio_state.dart';
import '../../../data/datasources/radio_packet_bus.dart';
import '../../../data/datasources/wifi_udp_datasource.dart';
import '../../../data/models/device_node.dart';

class RadioBloc extends Bloc<RadioEvent, RadioState> {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// When provided the bloc reuses the app-wide UDP socket instead of binding
  /// its own (two listeners cannot bind the same port).
  final WifiUdpDataSource? _sharedSource;
  StreamSubscription<Datagram>? _sharedPacketSub;

  String _interfaceName = 'wlan0';
  String _ipAddress = '192.168.43.120';
  int _port = 45454;
  List<DiscoveredPeer> _discoveredPeers = [];
  RadioConnectionState _connectionState = RadioConnectionState.disconnected;
  String _activeLinkType = 'WiFi';
  bool _isBadWifiSimulated = false;
  bool _isThrottled = false;
  bool _isJammingSimulated = false;
  int _throttleBps = 600;
  int _packetsDropped = 0;
  String _lastAction = 'Ready';

  RawDatagramSocket? _udpSocket;
  Timer? _heartbeatTimer;
  Timer? _jammingTimer;
  Timer? _failoverTimer;

  RadioBloc({WifiUdpDataSource? wifiSource})
      : _sharedSource = wifiSource,
        super(RadioInitial()) {
    on<RadioInitializeEvent>(_onInitialize);
    on<RadioScanPeersEvent>(_onScanPeers);
    on<RadioConnectManualEvent>(_onConnectManual);
    on<RadioToggleBadWifiEvent>(_onToggleBadWifi);
    on<RadioToggleThrottleEvent>(_onToggleThrottle);
    on<RadioToggleJammingEvent>(_onToggleJamming);
    on<RadioLinkStatusChangedEvent>(_onLinkStatusChanged);
    on<RadioPeerDiscoveredEvent>(_onPeerDiscovered);
    on<RadioConnectionStateChangedEvent>(_onConnectionStateChanged);
    on<RadioBandwidthThrottledEvent>(_onBandwidthThrottled);
    on<RadioPacketDroppedEvent>(_onPacketDropped);
  }

  Future<void> _onInitialize(
    RadioInitializeEvent event,
    Emitter<RadioState> emit,
  ) async {
    emit(RadioLoading());

    try {
      final wifiName = await _networkInfo.getWifiName();
      final wifiIp = await _networkInfo.getWifiIP();

      if (wifiIp != null) {
        _ipAddress = wifiIp;
      }
      if (wifiName != null) {
        _interfaceName = wifiName;
      }

      if (_sharedSource != null) {
        _ipAddress = _sharedSource.localIp;
        _interfaceName = _sharedSource.interfaceName;
      }

      await _startUdpListener();

      _startHeartbeat();

      emit(_buildLoadedState());
    } catch (e) {
      emit(RadioError('Failed to initialize radio: $e'));
    }
  }

  Future<void> _startUdpListener() async {
    if (_sharedSource != null) {
      _port = _sharedSource.port;
      await _sharedPacketSub?.cancel();
      _sharedPacketSub =
          _sharedSource.packetStream.listen(_handleIncomingPacket);
      return;
    }

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
      developer.log('UDP listener error: $e', name: 'RadioBloc');
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

        RadioPacketBus.instance
            .registerPeer(origin: senderIp, callSign: callSign);

        add(RadioPeerDiscoveredEvent(List.from(_discoveredPeers)));
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
    final message =
        'ITANTRA_DISCOVERY|${DeviceNode.load()?.callSign ?? "UNKNOWN"}|transceiver';

    if (_sharedSource != null) {
      _sharedSource.sendBroadcast(message);
      return;
    }

    if (_udpSocket == null) return;
    final data = message.codeUnits;

    try {
      _udpSocket!.send(data, InternetAddress('255.255.255.255'), _port);
    } catch (e) {
      developer.log('Broadcast error: $e', name: 'RadioBloc');
    }
  }

  Future<void> _onScanPeers(
    RadioScanPeersEvent event,
    Emitter<RadioState> emit,
  ) async {
    _lastAction = 'Scanning for peers...';
    emit(_buildLoadedState());

    _discoveredPeers.clear();
    _sharedSource?.triggerSubnetSweep();
    _sendDiscoveryBroadcast();

    await Future.delayed(const Duration(milliseconds: 800));

    _lastAction = 'Scan complete. ${_discoveredPeers.length} peer(s) found.';
    emit(_buildLoadedState());
  }

  Future<void> _onConnectManual(
    RadioConnectManualEvent event,
    Emitter<RadioState> emit,
  ) async {
    final ip = event.ipAddress.trim();
    if (ip.isEmpty) {
      _lastAction = 'Enter a valid IP address';
      emit(_buildLoadedState());
      return;
    }

    _lastAction = 'Connecting to $ip...';
    _sharedSource?.registerPeerIp(ip);
    emit(_buildLoadedState(copyWithConnectionState: RadioConnectionState.connecting));

    await Future.delayed(const Duration(milliseconds: 1500));

    final exists = _discoveredPeers.any((p) => p.ipAddress == ip);
    if (!exists) {
      _discoveredPeers.add(DiscoveredPeer(
        callSign: 'MANUAL-PEER',
        ipAddress: ip,
        signalStrength: 75,
        status: 'Connected',
      ));
    }

    _connectionState = RadioConnectionState.connected;
    _activeLinkType = 'WiFi (Direct)';
    _lastAction = 'Connected to $ip (Synced & Saved)';
    emit(_buildLoadedState());
  }

  Future<void> _onToggleBadWifi(
    RadioToggleBadWifiEvent event,
    Emitter<RadioState> emit,
  ) async {
    _isBadWifiSimulated = event.enabled;
    RadioPacketBus.instance.updateLinkState(
      badWifi: event.enabled,
      linkType: event.enabled ? 'LoRa 600 bps' : 'WiFi',
    );

    if (event.enabled) {
      _lastAction = 'Simulating WiFi failure...';
      _connectionState = RadioConnectionState.failoverActive;
      _activeLinkType = 'LoRa 600 bps';
      emit(_buildLoadedState());

      _sharedPacketSub?.cancel();
      _sharedPacketSub = null;
      _udpSocket?.close();
      _udpSocket = null;

      _failoverTimer = Timer(const Duration(milliseconds: 500), () {
        _lastAction = 'Auto-switched to LoRa 600 bps';
        _connectionState = RadioConnectionState.connected;
        emit(_buildLoadedState());
      });
    } else {
      _lastAction = 'Restoring WiFi link...';
      _connectionState = RadioConnectionState.connecting;
      _activeLinkType = 'WiFi (Restoring)';
      emit(_buildLoadedState());

      await _startUdpListener();
      _startHeartbeat();

      await Future.delayed(const Duration(milliseconds: 800));

      _connectionState = RadioConnectionState.connected;
      _activeLinkType = 'WiFi';
      _lastAction = 'WiFi link restored';
      emit(_buildLoadedState());
    }
  }

  Future<void> _onToggleThrottle(
    RadioToggleThrottleEvent event,
    Emitter<RadioState> emit,
  ) async {
    _isThrottled = event.enabled;
    RadioPacketBus.instance.updateLinkState(
      throttle: event.enabled ? 600 : 0,
    );

    if (event.enabled) {
      _throttleBps = 600;
      _lastAction = 'Bandwidth throttled to 600 bps (75 B/s)';
    } else {
      _throttleBps = 0;
      _lastAction = 'Bandwidth throttling disabled';
    }

    add(RadioBandwidthThrottledEvent(_throttleBps));
    emit(_buildLoadedState());
  }

  Future<void> _onToggleJamming(
    RadioToggleJammingEvent event,
    Emitter<RadioState> emit,
  ) async {
    _isJammingSimulated = event.enabled;
    _packetsDropped = 0;
    RadioPacketBus.instance.updateLinkState(
      jamming: event.enabled,
    );

    if (event.enabled) {
      _lastAction = 'Channel jamming active - 50% ACK drop';
      _jammingTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
        _packetsDropped++;
        add(RadioPacketDroppedEvent(_packetsDropped));
      });
    } else {
      _lastAction = 'Channel jamming disabled';
      _jammingTimer?.cancel();
    }

    emit(_buildLoadedState());
  }

  void _onLinkStatusChanged(
    RadioLinkStatusChangedEvent event,
    Emitter<RadioState> emit,
  ) {
    _lastAction = event.status;
    emit(_buildLoadedState());
  }

  void _onPeerDiscovered(
    RadioPeerDiscoveredEvent event,
    Emitter<RadioState> emit,
  ) {
    _discoveredPeers = event.peers;
    emit(_buildLoadedState());
  }

  void _onConnectionStateChanged(
    RadioConnectionStateChangedEvent event,
    Emitter<RadioState> emit,
  ) {
    _connectionState = event.state;
    emit(_buildLoadedState());
  }

  void _onBandwidthThrottled(
    RadioBandwidthThrottledEvent event,
    Emitter<RadioState> emit,
  ) {
    _throttleBps = event.bitsPerSecond;
    emit(_buildLoadedState());
  }

  void _onPacketDropped(
    RadioPacketDroppedEvent event,
    Emitter<RadioState> emit,
  ) {
    _packetsDropped = event.droppedCount;
    emit(_buildLoadedState());
  }

  RadioLoaded _buildLoadedState({
    RadioConnectionState? copyWithConnectionState,
  }) {
    return RadioLoaded(
      interfaceName: _interfaceName,
      ipAddress: _ipAddress,
      port: _port,
      discoveredPeers: List.from(_discoveredPeers),
      connectionState: copyWithConnectionState ?? _connectionState,
      activeLinkType: _activeLinkType,
      isBadWifiSimulated: _isBadWifiSimulated,
      isThrottled: _isThrottled,
      isJammingSimulated: _isJammingSimulated,
      throttleBps: _throttleBps,
      packetsDropped: _packetsDropped,
      lastAction: _lastAction,
    );
  }

  @override
  Future<void> close() {
    _heartbeatTimer?.cancel();
    _jammingTimer?.cancel();
    _failoverTimer?.cancel();
    _sharedPacketSub?.cancel();
    _udpSocket?.close();
    return super.close();
  }
}
