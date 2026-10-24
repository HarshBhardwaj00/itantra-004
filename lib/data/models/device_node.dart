import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

enum DeviceRole {
  transceiver,
  sender,
  receiver,
}

class DeviceNode {
  final String callSign;
  final String nodeId;
  final DeviceRole role;

  const DeviceNode({
    required this.callSign,
    required this.nodeId,
    required this.role,
  });

  factory DeviceNode.generate({DeviceRole role = DeviceRole.transceiver}) {
    const uuid = Uuid();
    final hash = uuid.v4().replaceAll('-', '').substring(0, 8).toUpperCase();

    const teams = ['RESCUE', 'BASE', 'SCOUT', 'CMD'];
    const names = ['ALPHA', 'BRAVO', 'CHARLIE', 'DELTA', 'ECHO', 'FOXTROT'];

    final teamIdx = int.parse(hash.substring(0, 2), radix: 16) % teams.length;
    final nameIdx = int.parse(hash.substring(2, 4), radix: 16) % names.length;
    final numVal = (int.parse(hash.substring(4, 6), radix: 16) % 99) + 1;

    return DeviceNode(
      callSign: '${teams[teamIdx]}-${names[nameIdx]}-${numVal.toString().padLeft(2, '0')}',
      nodeId: hash,
      role: role,
    );
  }

  DeviceNode copyWith({String? callSign, String? nodeId, DeviceRole? role}) {
    return DeviceNode(
      callSign: callSign ?? this.callSign,
      nodeId: nodeId ?? this.nodeId,
      role: role ?? this.role,
    );
  }

  static const String boxName = 'device_profile';

  static Future<void> init() async {
    await Hive.openBox(boxName);
  }

  Future<void> save() async {
    final box = Hive.box(boxName);
    await box.put('callSign', callSign);
    await box.put('nodeId', nodeId);
    await box.put('role', role.name);
  }

  static DeviceNode? load() {
    if (!Hive.isBoxOpen(boxName)) return null;
    final box = Hive.box(boxName);
    final callSign = box.get('callSign') as String?;
    if (callSign == null || callSign.isEmpty) return null;

    final roleStr = box.get('role', defaultValue: 'transceiver') as String;
    return DeviceNode(
      callSign: callSign,
      nodeId: box.get('nodeId', defaultValue: '') as String,
      role: DeviceRole.values.firstWhere(
        (r) => r.name == roleStr,
        orElse: () => DeviceRole.transceiver,
      ),
    );
  }

  static bool get isConfigured {
    if (!Hive.isBoxOpen(boxName)) return false;
    final callSign = Hive.box(boxName).get('callSign') as String?;
    return callSign != null && callSign.isNotEmpty;
  }

  /// Provisions the device profile when it does not exist yet.
  ///
  /// There is no setup screen anymore, so the very first launch generates a
  /// call-sign and persists it. Every later boot reuses the stored profile,
  /// which keeps the mesh identity stable: the discovery heartbeat, the peer
  /// directory and the comms log all key off this call-sign.
  static Future<DeviceNode> ensureProfile() async {
    final existing = load();
    if (existing != null) return existing;

    final generated = DeviceNode.generate();
    await generated.save();
    return generated;
  }

  static Future<void> saveActiveLanguage(String code, String name) async {
    if (!Hive.isBoxOpen(boxName)) return;
    try {
      final box = Hive.box(boxName);
      await box.put('active_language_code', code);
      await box.put('active_language_name', name);
    } catch (_) {}
  }

  static (String, String)? loadActiveLanguage() {
    if (!Hive.isBoxOpen(boxName)) return null;
    final box = Hive.box(boxName);
    final code = box.get('active_language_code') as String?;
    final name = box.get('active_language_name') as String?;
    if (code != null && name != null && code.isNotEmpty) {
      return (code, name);
    }
    return null;
  }

  /// Persists discovered / paired peer IP addresses across restarts.
  static Future<void> saveKnownPeers(List<String> peers) async {
    if (!Hive.isBoxOpen(boxName)) return;
    try {
      final box = Hive.box(boxName);
      await box.put('known_peers', peers);
    } catch (_) {}
  }

  /// Loads previously discovered / paired peer IP addresses.
  static List<String> loadKnownPeers() {
    if (!Hive.isBoxOpen(boxName)) return [];
    try {
      final box = Hive.box(boxName);
      final raw = box.get('known_peers');
      if (raw is List) {
        return raw.map((e) => e.toString()).where((ip) => ip.isNotEmpty).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Persists origin IP -> callSign mappings.
  static Future<void> savePeerDirectory(Map<String, String> directory) async {
    if (!Hive.isBoxOpen(boxName)) return;
    try {
      final box = Hive.box(boxName);
      await box.put('peer_directory', directory);
    } catch (_) {}
  }

  /// Loads origin IP -> callSign directory.
  static Map<String, String> loadPeerDirectory() {
    if (!Hive.isBoxOpen(boxName)) return {};
    try {
      final box = Hive.box(boxName);
      final raw = box.get('peer_directory');
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  /// Persists the last used sequence number across app restarts.
  static Future<void> saveLastSeq(int seq) async {
    if (!Hive.isBoxOpen(boxName)) return;
    try {
      final box = Hive.box(boxName);
      await box.put('last_seq', seq);
    } catch (_) {}
  }

  /// Loads the last used sequence number across app restarts.
  static int loadLastSeq() {
    if (!Hive.isBoxOpen(boxName)) return 0;
    try {
      final box = Hive.box(boxName);
      return (box.get('last_seq', defaultValue: 0) as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
