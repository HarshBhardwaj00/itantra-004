import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Streams raw 16 kHz / 16-bit / mono PCM audio from the microphone.
/// This is the capture stage of the PTT pipeline feeding VAD + Whisper STT.
class AudioRecorderService {
  static const int sampleRate = 16000;
  static const int bitDepth = 16;
  static const int channels = 1;

  final AudioRecorder _recorder = AudioRecorder();

  Stream<Uint8List>? _activeStream;
  bool _recording = false;

  bool get isRecording => _recording;

  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Starts a live PCM stream. Returns null when the mic is unavailable.
  Future<Stream<Uint8List>?> start() async {
    if (_recording) return _activeStream;

    final allowed = await hasPermission();
    if (!allowed) return null;

    try {
      final supported =
          await _recorder.isEncoderSupported(AudioEncoder.pcm16bits);
      final config = RecordConfig(
        encoder: supported ? AudioEncoder.pcm16bits : AudioEncoder.aacLc,
        sampleRate: sampleRate,
        numChannels: channels,
        bitRate: 256000,
        autoGain: true,
        noiseSuppress: false,
        echoCancel: false,
      );
      _activeStream = await _recorder.startStream(config);
      _recording = true;
      return _activeStream;
    } catch (_) {
      _recording = false;
      _activeStream = null;
      return null;
    }
  }

  Future<void> stop() async {
    try {
      await _recorder.stop();
    } catch (_) {}
    _recording = false;
    _activeStream = null;
  }

  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (_) {}
    _recording = false;
  }
}
