// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:itantra/core/constants/app_constants.dart';

void main() {
  test('Verify all offline models exist in D:\\itantra\\models', () {
    final models = ModelPaths();

    print('Checking VAD at: ${models.vadModelPath}');
    expect(models.isVadAvailable, isTrue, reason: 'VAD model should exist');

    print('Checking Whisper Tiny at: ${models.whisperDir}');
    expect(models.isWhisperAvailable, isTrue, reason: 'Whisper models should exist');

    print('Checking Piper Hindi at: ${models.piperHindiDir}');
    expect(models.isPiperHindiAvailable, isTrue, reason: 'Piper Hindi should exist');

    print('Checking Vosk Hindi at: ${models.voskHindiDir}');
    expect(models.isVoskHindiAvailable, isTrue, reason: 'Vosk Hindi should exist');

    print('Checking Vosk English at: ${models.voskEnglishDir}');
    expect(models.isVoskEnglishAvailable, isTrue, reason: 'Vosk English should exist');
  });
}
