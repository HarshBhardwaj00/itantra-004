import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../core/constants/app_constants.dart';
import '../audio/audio_player_service.dart';
import '../model/model_path_resolver.dart';
import 'hindi_transliteration_service.dart';
import 'language_pack_manager.dart';
import 'native_library_loader.dart';
import 'speech_model_registry.dart';

void _diag(String msg) {
  try {
    final f = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}itantra_diag.log',
    );
    f.writeAsStringSync('${DateTime.now().toIso8601String()} $msg\n',
        mode: FileMode.append);
  } catch (_) {}
}

/// Offline Piper (VITS) multi-language text-to-speech.
/// Supports dynamic model switching for Indian languages and English.
///
/// Memory contract — one Piper model in RAM at a time, process-wide:
/// [TtsService] is a singleton ([instance]); every `TtsService()` call
/// resolves to the same engine, and language switches always release the
/// previous model before the next one is constructed.
class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  factory TtsService() => instance;

  sherpa_onnx.OfflineTts? _tts;
  String _currentLanguageCode = 'hi_IN';
  bool _ready = false;

  bool get ready => _ready;
  String get currentLanguageCode => _currentLanguageCode;

  /// Live Piper engines across the whole process (0 or 1).
  int get liveModelCount => SpeechModelRegistry.instance.liveCount;

  static void _ensureBindings() {
    ensureSherpaBindingsInitialized();
  }

  Future<bool> init({String languageCode = 'hi_IN'}) async {
    final ok = await _loadModel(languageCode);
    if (!ok && languageCode != 'hi_IN') {
      // Ensure the bundled offline Hindi Piper model is loaded as resilient fallback
      return _loadModel('hi_IN');
    }
    return ok;
  }

  Future<bool> switchLanguage(String languageCode) async {
    if (languageCode == _currentLanguageCode && _ready) return true;

    final paths = ModelPaths();
    if (paths.isPiperAvailable(languageCode)) {
      _freeCurrentModel();
      return _loadModel(languageCode);
    }
    // If target language has no offline Piper model (e.g. English),
    // retain the Hindi Piper model so offline fallback stays armed.
    if (!_ready) {
      await _loadModel('hi_IN');
    }
    _currentLanguageCode = languageCode;
    return true;
  }

  Future<bool> _loadModel(String languageCode) async {
    if (kIsWeb) return false;
    try {
      // Free-before-load: never hold two Piper engines simultaneously.
      _freeCurrentModel();

      final registry = SpeechModelRegistry.instance;
      if (!registry.canRegister(SpeechModelRegistry.ttsHolder)) {
        _diag('tts.load blocked by one-language registry: ${registry.liveCount} live');
        return false;
      }

      final paths = ModelPaths();
      if (!paths.isPiperAvailable(languageCode)) {
        if (LanguagePackManager.instance.hasZipArchive(languageCode)) {
          await LanguagePackManager.instance.extractPack(languageCode);
        }
      }
      if (!paths.isPiperAvailable(languageCode)) return false;

      _ensureBindings();

      _tts = sherpa_onnx.OfflineTts(
        sherpa_onnx.OfflineTtsConfig(
          model: sherpa_onnx.OfflineTtsModelConfig(
            vits: sherpa_onnx.OfflineTtsVitsModelConfig(
              model: paths.getPiperModelPath(languageCode),
              tokens: paths.getPiperTokensPath(languageCode),
              dataDir: paths.getPiperDataDir(languageCode),
            ),
            numThreads: 2,
            provider: 'cpu',
            debug: false,
          ),
        ),
      );

      _currentLanguageCode = languageCode;
      _ready = true;
      SpeechModelRegistry.instance.register(
        SpeechModelRegistry.ttsHolder,
        'piper:$languageCode',
      );
      return true;
    } catch (_) {
      _ready = false;
      _tts = null;
      return false;
    }
  }

  /// Synthesizes [text] into a temp WAV file, returns its path or null.
  Future<String?> synthesizeToFile(String text) async {
    final tts = _tts;
    if (tts == null || text.trim().isEmpty) return null;

    try {
      _diag('tts.generate start for "$text"');
      final audio = tts.generate(text: text, sid: 0, speed: 1.0);
      _diag('tts.generate done samples=${audio.samples.length}');
      if (audio.samples.isEmpty) return null;

      String tempDirPath = '';
      try {
        tempDirPath = (await getTemporaryDirectory()).path;
      } catch (_) {}
      if (tempDirPath.isEmpty) {
        tempDirPath = Directory.systemTemp.path;
      }
      if (tempDirPath.isEmpty) {
        tempDirPath = '.';
      }
      final sep = Platform.pathSeparator;
      final ts = DateTime.now().microsecondsSinceEpoch;
      final path = '$tempDirPath${sep}itantra_replay_${_currentLanguageCode}_$ts.wav';
      File(path).writeAsBytesSync(_toWav(audio.samples, audio.sampleRate));
      _diag('tts.generate file written: $path size=${File(path).lengthSync()}');
      return path;
    } catch (_) {
      return null;
    }
  }

  Uint8List _toWav(Float32List samples, int sampleRate) {
    final dataSize = samples.length * 2;
    final builder = BytesBuilder();

    void writeTag(String tag) => builder.add(tag.codeUnits);
    void writeInt32(int value) {
      builder.add([
        value & 0xFF,
        (value >> 8) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 24) & 0xFF,
      ]);
    }

    void writeInt16(int value) {
      builder.add([value & 0xFF, (value >> 8) & 0xFF]);
    }

    writeTag('RIFF');
    writeInt32(36 + dataSize);
    writeTag('WAVE');
    writeTag('fmt ');
    writeInt32(16);
    writeInt16(1);
    writeInt16(1);
    writeInt32(sampleRate);
    writeInt32(sampleRate * 2);
    writeInt16(2);
    writeInt16(16);
    writeTag('data');
    writeInt32(dataSize);

    for (final sample in samples) {
      final scaled = (sample.clamp(-1.0, 1.0) * 32767).round();
      writeInt16(scaled);
    }

    return builder.takeBytes();
  }

  bool _flutterTtsInitialized = false;

  /// Idempotent setup for platform native TTS (volume, rate, iOS session).
  Future<void> ensureFlutterTtsInitialized(FlutterTts flutterTts) async {
    if (_flutterTtsInitialized) return;
    try {
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.awaitSpeakCompletion(true);
      if (Platform.isIOS) {
        await flutterTts.setSharedInstance(true);
        await flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          ],
        );
      }
      _flutterTtsInitialized = true;
      _diag('ensureFlutterTtsInitialized OK');
    } catch (e, st) {
      _diag('ensureFlutterTtsInitialized ERROR: $e\n$st');
    }
  }

  /// Synthesizes and speaks [text] with tactical fidelity and resilience.
  ///
  /// For Hindi / Indic languages:
  ///   1. Transliterates Romanized / Hinglish text to Devanagari if needed.
  ///   2. Synthesizes offline using neural Piper VITS model (`hi_IN-pratham-medium.onnx`).
  ///   3. Plays through [player] (AudioPlayerService) and awaits completion.
  ///   4. Gracefully falls back to system TTS (`FlutterTts`) if Piper is unavailable.
  ///
  /// For English:
  ///   1. Uses high-clarity native system TTS (`FlutterTts`) with `en-IN` / `en-US`.
  ///   2. Falls back to Piper if system TTS throws.
  ///
  /// Returns true if playback succeeded, or false if stopped/failed.
  Future<bool> speakText({
    required String text,
    required AudioPlayerService player,
    required FlutterTts flutterTts,
    bool Function()? isStopRequested,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || (isStopRequested?.call() ?? false)) return false;

    try {
      _diag('speakText start "$cleanText" ready=$ready');
      await ModelPathResolver.ensureInitialized();
      if (isStopRequested?.call() ?? false) return false;

      final isDevanagari = HindiTransliterationService.hasDevanagari(cleanText);
      final isHindi = isDevanagari || AppConstants.activeLanguageCode.startsWith('hi');

      // Strategy 1: If Hindi text or Hindi mode, prioritize Piper Offline Hindi Neural TTS
      if (isHindi) {
        if (!ready) {
          try {
            await init(languageCode: 'hi_IN')
                .timeout(const Duration(milliseconds: 2000), onTimeout: () => false);
          } catch (_) {}
        }
        if (ready && !(isStopRequested?.call() ?? false)) {
          String piperInput = cleanText;
          if (!isDevanagari) {
            final transliterated =
                HindiTransliterationService.toHindiDevanagari(cleanText);
            if (HindiTransliterationService.hasDevanagari(transliterated)) {
              piperInput = transliterated;
            }
          }

          _diag('calling synthesizeToFile "$piperInput"');
          final path = await synthesizeToFile(piperInput);
          _diag('after synthesizeToFile path=$path stopRequested=${isStopRequested?.call()}');
          if (isStopRequested?.call() ?? false) return false;
          if (path != null) {
            final played = await player.playFileAndWait(path);
            if (played || (isStopRequested?.call() ?? false)) {
              _diag('Piper Hindi playback complete');
              return true;
            }
            _diag('Piper audio playback failed, falling back to FlutterTts');
          }
        }
        // Fallback to System TTS for Hindi
        if (!(isStopRequested?.call() ?? false)) {
          _diag('falling back to FlutterTts for Hindi');
          final ok = await _speakWithFlutterTts(cleanText, flutterTts, isStopRequested);
          return ok;
        }
      } else {
        // Strategy 2: English or non-Hindi
        // Primary: Native System TTS (Google TTS / Apple Speech / Windows SAPI) for clear English
        _diag('speaking English via FlutterTts: "$cleanText"');
        bool systemTtsOk = false;
        try {
          systemTtsOk = await _speakWithFlutterTts(cleanText, flutterTts, isStopRequested);
          _diag('FlutterTts speak result: $systemTtsOk');
        } catch (e) {
          systemTtsOk = false;
          _diag('FlutterTts threw error: $e');
        }

        // Secondary fallback to Piper if system TTS failed or threw
        if (!systemTtsOk && !(isStopRequested?.call() ?? false)) {
          _diag('FlutterTts failed, falling back to Piper neural TTS for English');
          if (!ready) {
            try {
              await init(languageCode: 'hi_IN')
                  .timeout(const Duration(milliseconds: 2000), onTimeout: () => false);
            } catch (_) {}
          }
          if (ready && !(isStopRequested?.call() ?? false)) {
            final transliterated = HindiTransliterationService.toHindiDevanagari(cleanText);
            _diag('calling synthesizeToFile with transliterated English: "$transliterated"');
            final path = await synthesizeToFile(transliterated);
            if (path != null && !(isStopRequested?.call() ?? false)) {
              final played = await player.playFileAndWait(path);
              return played;
            }
          }
        }
        return systemTtsOk;
      }
    } catch (e, st) {
      _diag('ERROR in speakText: $e\n$st');
      if (!(isStopRequested?.call() ?? false)) {
        try {
          return await _speakWithFlutterTts(cleanText, flutterTts, isStopRequested);
        } catch (_) {}
      }
    }
    return false;
  }

  /// Safely checks if a language is available without crashing on platforms
  /// where [flutterTts.isLanguageAvailable] is omitted (e.g. Windows desktop).
  Future<bool> _isLanguageAvailableSafe(FlutterTts flutterTts, String lang) async {
    try {
      final avail = await flutterTts.isLanguageAvailable(lang);
      return _isLangSupported(avail);
    } catch (_) {
      try {
        final langs = await flutterTts.getLanguages;
        if (langs is List && langs.isNotEmpty) {
          final target = lang.toLowerCase().replaceAll('_', '-');
          for (final l in langs) {
            final candidate = l.toString().toLowerCase().replaceAll('_', '-');
            if (candidate == target || candidate.startsWith(target.split('-').first)) {
              return true;
            }
          }
        }
      } catch (_) {}
      return true;
    }
  }

  Future<bool> _speakWithFlutterTts(
    String text,
    FlutterTts flutterTts,
    bool Function()? isStopRequested,
  ) async {
    if (isStopRequested?.call() ?? false) return false;
    await ensureFlutterTtsInitialized(flutterTts);
    if (isStopRequested?.call() ?? false) return false;

    final isDevanagari = HindiTransliterationService.hasDevanagari(text);
    final activeCode = AppConstants.activeLanguageCode.toLowerCase().replaceAll('_', '-');
    final isHindi = isDevanagari || activeCode.startsWith('hi');
    String langToUse = 'en-US';
    String textToSpeak = text;

    try {
      if (isHindi) {
        if (!isDevanagari) {
          textToSpeak = HindiTransliterationService.toHindiDevanagari(text);
        }
        langToUse = 'hi-IN';
        final hiAvail = await _isLanguageAvailableSafe(flutterTts, 'hi-IN');
        if (!hiAvail) {
          final hiShort = await _isLanguageAvailableSafe(flutterTts, 'hi');
          langToUse = hiShort ? 'hi' : 'en-US';
        }
      } else if (activeCode.startsWith('en')) {
        // English
        final inAvail = await _isLanguageAvailableSafe(flutterTts, 'en-IN');
        if (inAvail) {
          langToUse = 'en-IN';
        } else {
          final usAvail = await _isLanguageAvailableSafe(flutterTts, 'en-US');
          langToUse = usAvail ? 'en-US' : 'en';
        }
      } else {
        // Regional Indian languages (mr_IN, ta_IN, te_IN, bn_IN, gu_IN, kn_IN, ml_IN, pa_IN)
        final fullLang = activeCode;
        final shortLang = activeCode.split('-').first;
        if (await _isLanguageAvailableSafe(flutterTts, fullLang)) {
          langToUse = fullLang;
        } else if (await _isLanguageAvailableSafe(flutterTts, shortLang)) {
          langToUse = shortLang;
        } else {
          final hiAvail = await _isLanguageAvailableSafe(flutterTts, 'hi-IN');
          langToUse = hiAvail ? 'hi-IN' : 'en-IN';
        }
      }

      try {
        await flutterTts.setLanguage(langToUse);
        await flutterTts.setVolume(1.0);
        await flutterTts.setPitch(1.0);
        await flutterTts.setSpeechRate(Platform.isWindows ? 0.5 : 0.5);
      } catch (e) {
        _diag('FlutterTts setting properties note: $e');
      }

      final completer = Completer<void>();
      flutterTts.setCompletionHandler(() {
        _diag('FlutterTts completion handler fired');
        if (!completer.isCompleted) completer.complete();
      });
      flutterTts.setErrorHandler((msg) {
        _diag('FlutterTts error: $msg');
        if (!completer.isCompleted) completer.complete();
      });
      flutterTts.setCancelHandler(() {
        _diag('FlutterTts cancel handler fired');
        if (!completer.isCompleted) completer.complete();
      });

      _diag('FlutterTts speak dispatched ($langToUse: "$textToSpeak")');
      final dynamic result = await flutterTts.speak(textToSpeak);
      _diag('FlutterTts speak call result=$result');

      final numResult = result is num ? result : (result == true ? 1 : 0);
      if (numResult == 0) {
        _diag('FlutterTts speak call returned 0 (failed)');
        return false;
      }

      // If speak() already awaited speech completion via awaitSpeakCompletion,
      // complete completer immediately so we don't hang on timeout.
      if (!completer.isCompleted) {
        completer.complete();
      }

      final timeoutSec = (textToSpeak.length / 4).clamp(3.0, 20.0).round();
      await completer.future.timeout(
        Duration(seconds: timeoutSec),
        onTimeout: () => _diag('FlutterTts completion timed out / continued'),
      );
      return true;
    } catch (e, st) {
      _diag('Error in _speakWithFlutterTts: $e\n$st');
      return false;
    }
  }

  bool _isLangSupported(dynamic res) {
    if (res == null) return false;
    if (res is bool) return res;
    if (res is num) return res == 1;
    if (res is String) return res == '1' || res.toLowerCase() == 'true';
    return false;
  }

  /// Cancels any active playback on both the audio player and native TTS.
  Future<void> stopPlayback({
    required AudioPlayerService player,
    required FlutterTts flutterTts,
  }) async {
    try {
      await player.stop();
    } catch (_) {}
    try {
      await flutterTts.stop();
    } catch (_) {}
  }

  void _freeCurrentModel() {
    try {
      _tts?.free();
    } catch (_) {}
    if (_tts != null) {
      SpeechModelRegistry.instance.unregister(SpeechModelRegistry.ttsHolder);
    }
    _tts = null;
    _ready = false;
  }

  void free() {
    _freeCurrentModel();
    _currentLanguageCode = 'hi_IN';
  }
}
