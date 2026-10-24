import 'package:flutter_test/flutter_test.dart';
import 'package:itantra/services/speech/hindi_transliteration_service.dart';

void main() {
  group('HindiTransliterationService Tests', () {
    test('transliterates MADAG BESTO (Whisper distress hallucination) to मदद भेजो', () {
      expect(HindiTransliterationService.toHindiDevanagari('MADAG BESTO'), 'मदद भेजो');
      expect(HindiTransliterationService.toHindiDevanagari('madag besto'), 'मदद भेजो');
      expect(HindiTransliterationService.toHindiDevanagari('madad vijay'), 'मदद भेजो');
      expect(HindiTransliterationService.toHindiDevanagari('madad bhejo'), 'मदद भेजो');
    });

    test('transliterates tactical military and comms commands to Devanagari', () {
      expect(HindiTransliterationService.toHindiDevanagari('RADIO CHECK'), 'रेडियो चेक');
      expect(HindiTransliterationService.toHindiDevanagari('stiti sarmanya hay'), 'स्थिति सामान्य है');
      expect(HindiTransliterationService.toHindiDevanagari('khmla hurai'), 'हमला हो रहा है');
      expect(HindiTransliterationService.toHindiDevanagari('sani kagi barho'), 'सैनिक आगे बढ़ो');
      expect(HindiTransliterationService.toHindiDevanagari('aage badho'), 'आगे बढ़ो');
      expect(HindiTransliterationService.toHindiDevanagari('roger'), 'रोज़र (स्वीकृत)');
    });

    test('preserves existing Devanagari script without modification', () {
      expect(HindiTransliterationService.toHindiDevanagari('मदद भेजो'), 'मदद भेजो');
      expect(HindiTransliterationService.toHindiDevanagari('रेडियो चेक'), 'रेडियो चेक');
      expect(HindiTransliterationService.toHindiDevanagari('नमस्ते'), 'नमस्ते');
    });

    test('transliterates arbitrary romanized words using phonetic rules', () {
      final res = HindiTransliterationService.toHindiDevanagari('kripya suno');
      expect(res, 'कृपया सुनो');
    });

    test('handles empty or whitespace strings safely', () {
      expect(HindiTransliterationService.toHindiDevanagari(''), '');
      expect(HindiTransliterationService.toHindiDevanagari('   '), '');
    });
  });
}
