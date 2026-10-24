import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../core/constants/app_constants.dart';
import 'native_library_loader.dart';

/// Real-time Voice Activity Detection using Silero VAD + acoustic energy.
///
/// Responsibilities:
/// 1. Instant (<30ms) speech onset detection so the PTT HUD glows green immediately.
/// 2. Post-capture speech isolation (stripping leading and trailing silence),
///    preventing Whisper from entering silence-induced repetition hallucination loops.
class VadDetector {
  sherpa_onnx.VoiceActivityDetector? _vad;
  bool _ready = false;

  static const int windowSize = 512;
  static const int sampleRate = 16000;

  final List<double> _sampleBuffer = <double>[];
  bool _isVoiceActive = false;

  bool get ready => _ready;
  bool get isVoiceActive => _isVoiceActive;

  Future<bool> init() async {
    try {
      final paths = ModelPaths();
      if (!paths.isVadAvailable) return false;

      ensureSherpaBindingsInitialized();

      _vad = sherpa_onnx.VoiceActivityDetector(
        config: sherpa_onnx.VadModelConfig(
          sileroVad: sherpa_onnx.SileroVadModelConfig(
            model: paths.vadModelPath,
            threshold: 0.5,
            minSilenceDuration: 0.35,
            minSpeechDuration: 0.08, // Captures fast speech onset and short commands
            windowSize: windowSize,
          ),
          sampleRate: sampleRate,
          numThreads: 1,
          provider: 'cpu',
          debug: false,
        ),
        bufferSizeInSeconds: 30.0,
      );

      _ready = true;
      return true;
    } catch (_) {
      _ready = false;
      _vad = null;
      return false;
    }
  }

  /// Pushes one incoming PCM chunk during recording.
  /// Returns true while voice/speech is detected.
  bool push(Float32List samples) {
    if (samples.isEmpty) return false;

    // 1. Instant acoustic energy calculation
    var sumSquares = 0.0;
    var maxVal = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final abs = samples[i].abs();
      if (abs > maxVal) maxVal = abs;
      sumSquares += samples[i] * samples[i];
    }
    final rms = math.sqrt(sumSquares / samples.length);

    // Voice threshold: quiet room is RMS < 0.005. Speech onset is RMS >= 0.010.
    final bool energyDetected = (rms >= 0.010 && maxVal >= 0.025);

    // 2. Feed Silero VAD in exact 512-sample windows
    final vad = _vad;
    bool sileroDetected = false;
    if (vad != null) {
      for (var i = 0; i < samples.length; i++) {
        _sampleBuffer.add(samples[i]);
      }
      while (_sampleBuffer.length >= windowSize) {
        final window = Float32List.fromList(_sampleBuffer.sublist(0, windowSize));
        _sampleBuffer.removeRange(0, windowSize);
        try {
          vad.acceptWaveform(window);
          if (vad.isDetected()) {
            sileroDetected = true;
          }
        } catch (_) {}
      }
    }

    _isVoiceActive = energyDetected || sileroDetected;
    return _isVoiceActive;
  }

  /// Extracts trimmed speech segments from all captured audio samples.
  /// Removes leading and trailing silence, completely eliminating the
  /// silence-induced repetition loops in Whisper.
  Float32List trimSilence(Float32List allSamples) {
    if (allSamples.isEmpty) return allSamples;

    final vad = _vad;
    if (vad != null) {
      try {
        vad.reset();
        // Stream in 512-sample windows
        for (var i = 0; i < allSamples.length; i += windowSize) {
          final end = (i + windowSize < allSamples.length)
              ? i + windowSize
              : allSamples.length;
          final chunk = Float32List(end - i);
          chunk.setRange(0, end - i, allSamples.sublist(i, end));
          vad.acceptWaveform(chunk);
        }
        vad.flush();

        final segments = <sherpa_onnx.SpeechSegment>[];
        while (!vad.isEmpty()) {
          final seg = vad.front();
          if (seg.samples.isNotEmpty) {
            segments.add(seg);
          }
          vad.pop();
        }

        if (segments.isNotEmpty) {
          // If speech segments were detected, keep a comfortable 300ms padding margin (4800 samples)
          // to protect boundary phonemes and plosives during fast speech.
          const int paddingSamples = 4800; // 300ms @ 16kHz
          final firstStart = math.max(0, segments.first.start - paddingSamples);
          final lastSeg = segments.last;
          final lastEnd = math.min(
            allSamples.length,
            lastSeg.start + lastSeg.samples.length + paddingSamples,
          );

          if (lastEnd > firstStart) {
            final trimmed = Float32List(lastEnd - firstStart);
            trimmed.setRange(0, lastEnd - firstStart, allSamples.sublist(firstStart, lastEnd));
            return trimmed;
          }
        }
      } catch (_) {}
    }

    // Fallback: Energy-based trimming
    return _energyTrim(allSamples);
  }

  /// Energy-based fallback silence trimmer.
  static Float32List _energyTrim(Float32List samples) {
    if (samples.length < 1600) return samples;

    const frameSize = 320; // 20ms frames
    int startIdx = 0;
    for (var i = 0; i <= samples.length - frameSize; i += frameSize) {
      var sumSquares = 0.0;
      for (var j = 0; j < frameSize; j++) {
        final val = samples[i + j];
        sumSquares += val * val;
      }
      final rms = math.sqrt(sumSquares / frameSize);
      if (rms >= 0.007) {
        startIdx = math.max(0, i - frameSize * 10); // 200ms pre-roll
        break;
      }
    }

    int endIdx = samples.length;
    for (var i = samples.length - frameSize; i >= startIdx; i -= frameSize) {
      var sumSquares = 0.0;
      for (var j = 0; j < frameSize; j++) {
        final val = samples[i + j];
        sumSquares += val * val;
      }
      final rms = math.sqrt(sumSquares / frameSize);
      if (rms >= 0.007) {
        endIdx = math.min(samples.length, i + frameSize * 10); // 200ms post-roll
        break;
      }
    }

    if (endIdx > startIdx && (endIdx - startIdx) >= 1600) {
      final trimmed = Float32List(endIdx - startIdx);
      trimmed.setRange(0, endIdx - startIdx, samples.sublist(startIdx, endIdx));
      return trimmed;
    }

    return samples;
  }

  void reset() {
    _sampleBuffer.clear();
    _isVoiceActive = false;
    try {
      _vad?.reset();
    } catch (_) {}
  }

  void free() {
    reset();
    try {
      _vad?.free();
    } catch (_) {}
    _vad = null;
    _ready = false;
  }
}
