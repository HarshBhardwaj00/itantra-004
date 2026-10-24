import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../core/constants/app_constants.dart';
import 'hindi_transliteration_service.dart';
import 'native_library_loader.dart';
import 'speech_text_sanitizer.dart';

/// On-device Whisper Tiny INT8 speech-to-text.
/// Fed with 16 kHz float PCM captured during a PTT hold.
class SttService {
  SttService._internal();
  static final SttService instance = SttService._internal();
  factory SttService() => instance;

  sherpa_onnx.OfflineRecognizer? _recognizer;
  bool _ready = false;

  String _currentLanguageCode = 'hi_IN';

  bool get ready => _ready;
  String get currentLanguageCode => _currentLanguageCode;

  Future<bool> init({String languageCode = 'hi_IN'}) async {
    return _loadModel(languageCode);
  }

  Future<bool> switchLanguage(String languageCode) async {
    if (languageCode == _currentLanguageCode && _ready) return true;
    _freeCurrentModel();
    return _loadModel(languageCode);
  }

  Future<bool> _loadModel(String languageCode) async {
    try {
      final paths = ModelPaths();
      if (!paths.isWhisperAvailable) return false;

      ensureSherpaBindingsInitialized();

      // Extract ISO 639-1 code: 'hi_IN' -> 'hi', 'en_IN' -> 'en', etc.
      final lang = languageCode.split('_').first.toLowerCase();

      _recognizer = sherpa_onnx.OfflineRecognizer(
        sherpa_onnx.OfflineRecognizerConfig(
          model: sherpa_onnx.OfflineModelConfig(
            tokens: paths.whisperTokensPath,
            numThreads: 2,
            provider: 'cpu',
            debug: false,
            modelType: 'whisper',
            whisper: sherpa_onnx.OfflineWhisperModelConfig(
              encoder: paths.whisperEncoderPath,
              decoder: paths.whisperDecoderPath,
              language: lang,
              task: 'transcribe',
              tailPaddings: -1, // Crucial: -1 disables artificial 300-frame tail padding
            ),
          ),
          decodingMethod: 'greedy_search',
        ),
      );

      _currentLanguageCode = languageCode;
      _ready = true;
      return true;
    } catch (_) {
      _ready = false;
      _recognizer = null;
      return false;
    }
  }

  /// Returns transcribed text, or null when decoding fails / no speech.
  String? transcribe(Float32List samples) {
    final recognizer = _recognizer;
    if (recognizer == null || samples.isEmpty) return null;

    // Check audio energy floor: if the audio is essentially silence / hiss
    var maxVal = 0.0;
    var sumSquares = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final abs = samples[i].abs();
      if (abs > maxVal) maxVal = abs;
      sumSquares += samples[i] * samples[i];
    }
    final rms = math.sqrt(sumSquares / samples.length);

    if (maxVal < 0.008 || rms < 0.0025) {
      // Audio is pure silence or negligible noise floor
      return null;
    }

    // Peak amplitude normalization:
    // Whisper performs best when peak audio is scaled to ~0.85 (-1.4 dB FS).
    // Ensure all valid speech (even quiet utterances) is scaled cleanly.
    Float32List normalizedSamples = samples;
    if (maxVal > 0.005 && maxVal < 0.82) {
      final scale = 0.85 / maxVal;
      normalizedSamples = Float32List(samples.length);
      for (var i = 0; i < samples.length; i++) {
        normalizedSamples[i] = (samples[i] * scale).clamp(-1.0, 1.0);
      }
    }

    // Minimum receptive field: Whisper requires at least 1.0s (16,000 samples)
    // of temporal context. Symmetrically pad short/fast speech to prevent edge
    // stutter hallucinations (e.g. "F-F." or "[.").
    Float32List audioToFeed = normalizedSamples;
    const int minWhisperSamples = 16000;
    if (normalizedSamples.length < minWhisperSamples) {
      final padTotal = minWhisperSamples - normalizedSamples.length;
      final padHead = padTotal ~/ 4; // 25% head margin, 75% tail margin
      final padded = Float32List(minWhisperSamples);
      padded.setRange(padHead, padHead + normalizedSamples.length, normalizedSamples);
      audioToFeed = padded;
    }

    sherpa_onnx.OfflineStream? stream;
    try {
      stream = recognizer.createStream();
      stream.acceptWaveform(samples: audioToFeed, sampleRate: 16000);
      recognizer.decode(stream);
      var text = recognizer.getResult(stream).text.trim();
      if (text.isEmpty) return null;

      // 1. Sanitize text: Eliminate repetition loops, dangling stutters & duplicate phrases
      text = SpeechTextSanitizer.sanitize(text);

      // 2. If active language is Hindi, normalize Romanized / distorted Whisper text into clean Devanagari
      if (_currentLanguageCode.startsWith('hi')) {
        text = HindiTransliterationService.toHindiDevanagari(text);
      }

      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    } finally {
      try {
        stream?.free();
      } catch (_) {}
    }
  }

  void _freeCurrentModel() {
    try {
      _recognizer?.free();
    } catch (_) {}
    _recognizer = null;
    _ready = false;
  }

  void free() {
    _freeCurrentModel();
    _currentLanguageCode = 'hi_IN';
  }
}
