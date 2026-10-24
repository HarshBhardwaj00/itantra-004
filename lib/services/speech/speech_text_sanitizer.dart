/// Sanitizes speech-to-text transcriptions, preventing and repairing:
/// 1. Whisper autoregressive hallucination loops (repeated sentences / phrases).
/// 2. Audio silence tail stutter (e.g. "Please, please help me. Please, please help me. Please,").
/// 3. Incomplete trailing dangling prefixes.
/// 4. Consecutive repeated words / stutters.
class SpeechTextSanitizer {
  static const Set<String> _preservedRepetitions = {
    'sos',
    'mayday',
    'roger',
    'copy',
    'break',
  };

  /// Cleans transcription hallucinations, repetitive loops, and stuttering.
  static String sanitize(String input) {
    var text = input.trim();
    if (text.isEmpty) return text;

    // 0. Remove bracket hallucinations and non-speech markers: e.g. [music], (applause), [.
    text = text.replaceAll(RegExp(r'\[[^\]]*\]|\([^\)]*\)|[\[\]\(\)\{\}]'), ' ').trim();
    if (text.isEmpty) return '';

    // Normalize whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    // 1. Remove single-letter hyphenated stutters: e.g. "F-F", "f-f", "A-A", "t-t", "f - f"
    text = text.replaceAll(
      RegExp(r'\b([a-zA-Z\u0900-\u097F])\s*[-–—]\s*(\1)\b', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 2. Remove dangling trailing prefixes (e.g. "Please help me. Please,")
    text = _removeDanglingTrailingPrefix(text);

    // 3. Remove sentence-level loops (e.g. "Please help me. Please help me.")
    text = _deduplicateSentences(text);

    // 4. Remove phrase loops (n-grams from length 8 down to 2)
    text = _deduplicatePhrases(text);

    // 5. Remove consecutive word repeats (e.g. "please please" -> "please")
    text = _deduplicateConsecutiveWords(text);

    // 6. Clean up weird trailing or leading punctuation
    text = text.replaceAll(RegExp(r'^[,\.;:\-\s]+'), '');
    text = text.replaceAll(RegExp(r'[,;:\-\s]+$'), '').trim();

    // If the remaining text is just isolated single consonant or noise fragment, drop it
    final lettersOnly = text.replaceAll(RegExp(r'[^\w\u0900-\u097F]'), '').trim();
    if (lettersOnly.isEmpty) return '';
    // A single consonant in English or Hindi without vowels is noise hallucination (except "a" or "I")
    if (lettersOnly.length == 1 &&
        !RegExp(r'^[aAiI\u0905-\u0914]$').hasMatch(lettersOnly)) {
      return '';
    }

    // Ensure sensible sentence capitalization & punctuation if text is non-empty
    if (text.isNotEmpty) {
      if (!text.endsWith('.') &&
          !text.endsWith('!') &&
          !text.endsWith('?') &&
          !text.endsWith('।')) {
        text = '$text.';
      }
      // Capitalize first character if letter
      text = text[0].toUpperCase() + text.substring(1);
    }

    return text.trim();
  }

  /// If the text ends with an incomplete prefix of what came before:
  /// e.g. "Please, please help me. Please, please help me. Please,"
  /// -> strips trailing "Please,"
  static String _removeDanglingTrailingPrefix(String text) {
    // Split into sentence segments
    final segments = text.split(RegExp(r'(?<=[.!?।])\s+'));
    if (segments.length <= 1) return text;

    final last = segments.last.trim();
    // Check if last segment has no terminal punctuation
    if (!last.endsWith('.') &&
        !last.endsWith('!') &&
        !last.endsWith('?') &&
        !last.endsWith('।')) {
      final cleanLast = _cleanWord(last);
      if (cleanLast.isEmpty) {
        return segments.sublist(0, segments.length - 1).join(' ');
      }
      // Check if last is a prefix of any earlier sentence
      for (var i = 0; i < segments.length - 1; i++) {
        final prevClean = _cleanWord(segments[i]);
        if (prevClean.startsWith(cleanLast)) {
          return segments.sublist(0, segments.length - 1).join(' ');
        }
      }
    }

    return text;
  }

  /// Removes duplicate sentences and clauses.
  static String _deduplicateSentences(String text) {
    // Match sentence chunks
    final sentencePattern = RegExp(r'([^.!?।\n]+[.!?।\n]*)');
    final matches = sentencePattern
        .allMatches(text)
        .map((m) => m.group(0)!.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (matches.length <= 1) return text;

    final cleaned = <String>[];
    for (final s in matches) {
      final norm = _cleanWord(s);
      if (cleaned.isEmpty) {
        cleaned.add(s);
      } else {
        final lastNorm = _cleanWord(cleaned.last);
        if (norm != lastNorm && !lastNorm.startsWith(norm)) {
          cleaned.add(s);
        }
      }
    }

    return cleaned.join(' ');
  }

  /// Removes repeating word n-grams (e.g. "help me please help me please" -> "help me please")
  static String _deduplicatePhrases(String text) {
    final words = text.split(' ');
    if (words.length < 4) return text;

    var resultWords = List<String>.from(words);
    var modified = true;

    while (modified) {
      modified = false;
      final nWords = resultWords.length;
      final maxN = nWords ~/ 2;

      for (var n = maxN; n >= 2; n--) {
        for (var i = 0; i <= resultWords.length - 2 * n; i++) {
          final gram1 = resultWords.sublist(i, i + n).map(_cleanWord).join(' ');
          final gram2 =
              resultWords.sublist(i + n, i + 2 * n).map(_cleanWord).join(' ');

          if (gram1.isNotEmpty && gram1 == gram2) {
            resultWords.removeRange(i + n, i + 2 * n);
            modified = true;
            break;
          }
        }
        if (modified) break;
      }
    }

    return resultWords.join(' ');
  }

  /// Removes consecutive single word repeats like "please please please" -> "please",
  /// while preserving legitimate emergency words like "SOS SOS" or "Mayday Mayday".
  static String _deduplicateConsecutiveWords(String text) {
    final words = text.split(' ');
    if (words.length <= 1) return text;

    final result = <String>[];
    for (var i = 0; i < words.length; i++) {
      final current = words[i];
      final cleanCurrent = _cleanWord(current);
      if (result.isEmpty) {
        result.add(current);
      } else {
        final prev = result.last;
        final cleanPrev = _cleanWord(prev);

        if (cleanCurrent == cleanPrev &&
            cleanCurrent.isNotEmpty &&
            !_preservedRepetitions.contains(cleanCurrent)) {
          // If previous word had a trailing comma before the duplicate, strip it
          result[result.length - 1] = result.last.replaceAll(RegExp(r'[,;]+$'), '');
          // Skip consecutive duplicate word
          continue;
        }
        result.add(current);
      }
    }
    return result.join(' ');
  }

  static String _cleanWord(String w) =>
      w.replaceAll(RegExp(r'[^\w\u0900-\u097F]'), '').toLowerCase().trim();
}
