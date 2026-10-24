import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:itantra/services/speech/tts_service.dart';

void main() {
  test('Test synthesizeToFile with unique timestamp filename', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tts = TtsService();
    final ok = await tts.init(languageCode: 'hi_IN');
    expect(ok, isTrue);

    // Run synthesis 3 times in a row!
    for (var i = 0; i < 3; i++) {
      final wav = await tts.synthesizeToFile('मदद भेjo $i');
      expect(wav, isNotNull);
      expect(File(wav!).existsSync(), isTrue);
    }
  });
}
