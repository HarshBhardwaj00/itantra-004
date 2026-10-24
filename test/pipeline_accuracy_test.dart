// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:itantra/services/speech/native_library_loader.dart';
import 'package:itantra/services/speech/speech_text_sanitizer.dart';
import 'package:itantra/services/speech/stt_service.dart';
import 'package:itantra/services/speech/vad_detector.dart';

Float32List readWav(String path) {
  final bytes = File(path).readAsBytesSync();
  final pcmBytes = bytes.sublist(44);
  final count = pcmBytes.length ~/ 2;
  final samples = Float32List(count);
  for (var i = 0; i < count; i++) {
    final low = pcmBytes[i * 2] & 0xFF;
    final high = pcmBytes[i * 2 + 1];
    var val = (high << 8) | low;
    if (val >= 0x8000) val -= 0x10000;
    samples[i] = val / 32768.0;
  }
  return samples;
}

void main() {
  test('Complete Pipeline Accuracy: VAD Trimming + Whisper STT + Sanitizer', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    ensureSherpaBindingsInitialized();

    final vad = VadDetector();
    final vadOk = await vad.init();
    expect(vadOk, isTrue, reason: 'Silero VAD should initialize successfully');

    final stt = SttService();
    final sttOk = await stt.init(languageCode: 'en_IN');
    expect(sttOk, isTrue, reason: 'Whisper STT should initialize successfully');

    // 1. Test live speech onset detection
    final rawSpeech = readWav(r'D:\itantra\models\sherpa-onnx-whisper-tiny\test_wavs\0.wav');
    
    // Simulate real-time streaming chunks of 100ms (1600 samples)
    final chunkSpeech = Float32List(1600);
    chunkSpeech.setRange(0, 1600, rawSpeech.sublist(8000, 9600)); // middle of speech
    final voiceSeen = vad.push(chunkSpeech);
    expect(voiceSeen, isTrue, reason: 'Live voice energy/speech should be detected instantaneously');

    // 2. Simulate user holding PTT, speaking short phrase, then holding for 2.5 seconds of silence
    final shortUtterance = Float32List(24000); // 1.5s speech
    shortUtterance.setRange(0, 24000, rawSpeech);

    final capturedWithLongSilence = Float32List(24000 + 40000); // 1.5s speech + 2.5s silence
    capturedWithLongSilence.setRange(0, 24000, shortUtterance);

    print('Captured audio total length: ${capturedWithLongSilence.length / 16000}s');

    // Run VAD silence trimming
    final trimmed = vad.trimSilence(capturedWithLongSilence);
    print('Trimmed audio length: ${trimmed.length / 16000}s');

    // The trimmed audio should be substantially shorter than the total audio (silence removed)
    expect(trimmed.length, lessThan(capturedWithLongSilence.length));

    // Transcribe with Whisper
    final transcript = stt.transcribe(trimmed);
    print('Final clean transcript: "$transcript"');

    expect(transcript, isNotNull);
    expect(transcript!.isNotEmpty, isTrue);

    // Verify there are no repetition loops
    expect(transcript.contains('After early nightfall, After early'), isFalse);

    // 3. Test exact user bug string with sanitizer
    const userBugString = 'Please, please help me. Please, please help me. Please,';
    final sanitized = SpeechTextSanitizer.sanitize(userBugString);
    print('User bug string: "$userBugString" -> Sanitized: "$sanitized"');
    expect(sanitized, equals('Please help me.'));

    // 4. Test fast speech transcription (1.5x speed)
    final newLen = (rawSpeech.length / 1.5).floor();
    final fast15 = Float32List(newLen);
    for (var i = 0; i < newLen; i++) {
      fast15[i] = rawSpeech[(i * 1.5).floor()];
    }
    final fastTrimmed = vad.trimSilence(fast15);
    final fastTranscript = stt.transcribe(fastTrimmed);
    print('Fast speech 1.5x transcript: "$fastTranscript"');
    expect(fastTranscript, isNotNull);
    expect(fastTranscript!.toLowerCase().contains('nightfall'), isTrue);

    // 5. Test elimination of stutter hallucination: F-F. -> drops garbage to empty
    expect(SpeechTextSanitizer.sanitize('F-F.'), equals(''));

    vad.free();
    stt.free();
  });
}
