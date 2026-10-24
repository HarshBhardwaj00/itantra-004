import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:itantra/services/speech/language_pack_manager.dart';
import 'package:itantra/services/speech/speech_model_registry.dart';
import 'package:itantra/services/speech/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Rule: one Piper model in RAM at a time', () {
    setUp(() {
      SpeechModelRegistry.instance.reset();
    });

    test('TtsService is a process-wide singleton', () {
      expect(identical(TtsService(), TtsService()), isTrue);
      expect(identical(TtsService(), TtsService.instance), isTrue);
    });

    test('registry admits a single engine and refuses a second', () {
      final registry = SpeechModelRegistry.instance;
      expect(SpeechModelRegistry.maxConcurrentModels, 1);

      registry.register(SpeechModelRegistry.ttsHolder, 'piper:hi_IN');
      expect(registry.liveCount, 1);
      expect(registry.saturated, isTrue);

      // A second live engine is the exact memory violation the rule bans.
      expect(
        () => registry.register('tts-ghost', 'piper:mr_IN'),
        throwsStateError,
      );

      // Re-register by the SAME holder is allowed (free-then-load swap).
      expect(
        () => registry.register(SpeechModelRegistry.ttsHolder, 'piper:ta_IN'),
        returnsNormally,
      );

      expect(registry.unregister(SpeechModelRegistry.ttsHolder), isTrue);
      expect(registry.saturated, isFalse);
      expect(registry.unregister(SpeechModelRegistry.ttsHolder), isFalse);
    });

    test('switchLanguage never leaves two engines live', () async {
      final tts = TtsService();

      tts.free();
      expect(tts.ready, isFalse);
      expect(SpeechModelRegistry.instance.liveCount, 0);

      // Test sandbox has no native Piper models, so loads fail gracefully —
      // but the invariant must hold through every attempt.
      await tts.switchLanguage('mr_IN');
      expect(SpeechModelRegistry.instance.liveCount, lessThanOrEqualTo(1));

      await tts.switchLanguage('ta_IN');
      expect(SpeechModelRegistry.instance.liveCount, lessThanOrEqualTo(1));

      tts.free();
      expect(tts.ready, isFalse);
      expect(SpeechModelRegistry.instance.liveCount, 0);
    });
  });

  group('Rule: one zip per language on disk', () {
    test('enforceOneZipPerLanguage keeps the largest pack per language',
        () async {
      final mgr = LanguagePackManager.instance;
      await mgr.initialize();

      final dir = Directory(mgr.packsDirectory);
      final sep = Platform.pathSeparator;

      // Same language in two archives — the big one must survive.
      final big = File('${dir.path}$sep${'mr_in_dedupe'}.zip')
        ..writeAsBytesSync(List.filled(64, 1));
      final dup = File('${dir.path}$sep${'mr_in_dedupe.backup'}.zip')
        ..writeAsBytesSync(List.filled(16, 2));
      // A unique language must be left untouched.
      final kn = File('${dir.path}$sep${'kn_in_dedupe'}.zip')
        ..writeAsBytesSync(List.filled(24, 3));

      final deleted = await mgr.enforceOneZipPerLanguage();

      expect(deleted, greaterThanOrEqualTo(1));
      expect(big.existsSync(), isTrue);
      expect(dup.existsSync(), isFalse);
      expect(kn.existsSync(), isTrue);

      big.deleteSync();
      kn.deleteSync();
    });

    test('pack key normalization treats variant zips as one language', () {
      expect(LanguagePackManager.normalizePackKey('hi_IN.zip'), 'hi_in');
      expect(LanguagePackManager.normalizePackKey('hi_IN.backup.zip'), 'hi_in');
      expect(
        LanguagePackManager.normalizePackKey('hi_IN.zip'),
        LanguagePackManager.normalizePackKey('hi_IN.backup.zip'),
      );
      expect(LanguagePackManager.normalizePackKey('kn_in.zip'), 'kn_in');
    });
  });
}
