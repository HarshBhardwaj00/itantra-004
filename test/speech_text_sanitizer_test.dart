// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:itantra/services/speech/speech_text_sanitizer.dart';

void main() {
  test('Sanitize user case: Please, please help me. Please, please help me. Please,', () {
    const input = 'Please, please help me. Please, please help me. Please,';
    final output = SpeechTextSanitizer.sanitize(input);
    print('Input:  "$input"');
    print('Output: "$output"');
    expect(output, equals('Please help me.'));
  });

  test('Sanitize repeated sentence: Help me. Help me. Help me.', () {
    const input = 'Help me. Help me. Help me.';
    final output = SpeechTextSanitizer.sanitize(input);
    print('Output: "$output"');
    expect(output, equals('Help me.'));
  });

  test('Sanitize word stutter: please please help help me', () {
    const input = 'please please help help me';
    final output = SpeechTextSanitizer.sanitize(input);
    print('Output: "$output"');
    expect(output, equals('Please help me.'));
  });

  test('Preserve emergency repeat: SOS SOS', () {
    const input = 'SOS SOS need backup';
    final output = SpeechTextSanitizer.sanitize(input);
    print('Output: "$output"');
    expect(output, equals('SOS SOS need backup.'));
  });

  test('Sanitize Hindi duplicate: मदद करो मदद करो', () {
    const input = 'मदद करो मदद करो';
    final output = SpeechTextSanitizer.sanitize(input);
    print('Output: "$output"');
    expect(output, equals('मदद करो.'));
  });

  test('Sanitize Whisper stutter hallucination: F-F. -> drops garbage to empty', () {
    expect(SpeechTextSanitizer.sanitize('F-F.'), equals(''));
    expect(SpeechTextSanitizer.sanitize('f-f'), equals(''));
    expect(SpeechTextSanitizer.sanitize('f - f'), equals(''));
    expect(SpeechTextSanitizer.sanitize('A-A.'), equals(''));
    expect(SpeechTextSanitizer.sanitize('t-t.'), equals(''));
  });

  test('Sanitize bracket hallucinations: [music], [inaudible], [.', () {
    expect(SpeechTextSanitizer.sanitize('[music]'), equals(''));
    expect(SpeechTextSanitizer.sanitize('(inaudible)'), equals(''));
    expect(SpeechTextSanitizer.sanitize('[.'), equals(''));
    expect(SpeechTextSanitizer.sanitize('(.'), equals(''));
  });

  test('Sanitize orphaned single consonants', () {
    expect(SpeechTextSanitizer.sanitize('F.'), equals(''));
    expect(SpeechTextSanitizer.sanitize('b.'), equals(''));
    expect(SpeechTextSanitizer.sanitize('k'), equals(''));
  });
}
