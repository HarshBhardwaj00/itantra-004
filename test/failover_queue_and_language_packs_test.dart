import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:itantra/data/datasources/queue_storage.dart';
import 'package:itantra/data/datasources/radio_packet_bus.dart';
import 'package:itantra/data/datasources/virtual_lora_datasource.dart';
import 'package:itantra/data/datasources/wifi_udp_datasource.dart';
import 'package:itantra/data/models/comms_entry.dart';
import 'package:itantra/data/repositories/comms_log_repository.dart';
import 'package:itantra/presentation/blocs/talk/talk_bloc.dart';
import 'package:itantra/presentation/blocs/talk/talk_event.dart';
import 'package:itantra/presentation/blocs/talk/talk_state.dart';
import 'package:itantra/services/speech/language_pack_manager.dart';
import 'package:itantra/services/speech/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late VirtualLoRaDataSource loraSource;
  late WifiUdpDataSource wifiSource;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('itantra_rules_test');
    Hive.init(tempDir.path);
    await QueueStorage.init();
  });

  tearDownAll(() async {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await QueueStorage.clearAll();
    RadioPacketBus.instance.updateLinkState(
      badWifi: false,
      jamming: false,
      linkType: 'WiFi',
    );
    loraSource = VirtualLoRaDataSource();
    wifiSource = WifiUdpDataSource();
  });

  tearDown(() {
    loraSource.dispose();
    wifiSource.close();
  });

  group('Rule: Bad WiFi switches to radio link', () {
    test('PTT transmission routes via LoRa 600 bps when Bad WiFi is active', () async {
      RadioPacketBus.instance.updateLinkState(
        badWifi: true,
        linkType: 'LoRa 600 bps',
      );

      final bloc = TalkBloc(
        wifiSource: wifiSource,
        loraSource: loraSource,
      );

      bloc.add(const TalkTranscriptReady('Team Alpha moving to sector 4', isVoice: false));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<TalkState>((state) {
            return state.status == TalkStatus.packetSent &&
                state.lastMessageMeta.contains('LoRa 600 bps') &&
                state.note.contains('LoRa 600 bps');
          }),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));
      await bloc.close();
    });
  });

  group('Rule: Jammed channel waits in queue and delivers after recovery', () {
    test('PTT packet is parked in queue when jamming is active, and delivered after recovery', () async {
      // 1. Enable jamming
      RadioPacketBus.instance.updateLinkState(
        jamming: true,
      );

      final bloc = TalkBloc(
        wifiSource: wifiSource,
        loraSource: loraSource,
      );

      bloc.add(const TalkTranscriptReady('Urgent supply drop requested', isVoice: false));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<TalkState>((state) {
            return state.lastMessageMeta.contains('Channel Jammed') ||
                state.note.contains('Channel jammed');
          }),
        ),
      );

      // Verify packet is safely stored in QueueStorage as queued
      final queued = QueueStorage.readAll();
      expect(queued.isNotEmpty, isTrue);
      expect(queued.any((e) => e.status == PacketStatus.queued), isTrue);

      // 2. Channel remains jammed: ARQ retry keeps it queued
      final repo = CommsLogRepository();
      final jammedEntry = queued.firstWhere((e) => e.status == PacketStatus.queued);
      final retriedWhileJammed = await repo.transmit(jammedEntry, forceNow: true);
      expect(retriedWhileJammed.status, equals(PacketStatus.queued));
      expect(retriedWhileJammed.retryCount, greaterThan(0));

      // 3. Link recovers! Jamming disabled:
      RadioPacketBus.instance.updateLinkState(
        jamming: false,
      );

      // Transmit after recovery: packet is acknowledged and delivered!
      var delivered = await repo.transmit(retriedWhileJammed, forceNow: true);
      for (var i = 0; i < 5 && delivered.status != PacketStatus.ackDelivered; i++) {
        delivered = await repo.transmit(delivered, forceNow: true);
      }
      expect(delivered.status, equals(PacketStatus.ackDelivered));
      expect(delivered.ackLatencyMs, greaterThan(0));

      await Future.delayed(const Duration(milliseconds: 300));
      await bloc.close();
    });
  });

  group('Rule: Language packs one zip per language, loaded one at a time', () {
    test('LanguagePackManager creates and extracts standalone zip pack', () async {
      final mgr = LanguagePackManager.instance;
      await mgr.initialize();

      // Ensure zip archive can be created
      final ok = await mgr.createPackZip('mr_IN');
      expect(ok, isTrue);
      expect(mgr.hasZipArchive('mr_IN'), isTrue);
      expect(mgr.getZipSizeBytes('mr_IN'), greaterThan(0));

      // Extract pack
      final extracted = await mgr.extractPack('mr_IN');
      expect(extracted, isTrue);
    });

    test('TtsService frees previous model when switching languages (loaded one at a time)', () async {
      final tts = TtsService();

      // Free current model releases memory
      tts.free();
      expect(tts.ready, isFalse);

      // Switching to Hindi initializes only Hindi
      await tts.switchLanguage('hi_IN');
      // If native bindings present or offline, current code is hi_IN
      expect(tts.currentLanguageCode, equals('hi_IN'));

      // Freeing releases it completely
      tts.free();
      expect(tts.ready, isFalse);
    });
  });
}
