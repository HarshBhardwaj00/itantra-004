/// Tactical Devanagari Normalizer & Phonetic Transliteration Engine.
///
/// Whisper Tiny INT8 produces Latin/Romanized phonetic approximations when
/// transcribing Hindi speech (e.g. "MADAG BESTO" for "मदद भेजो", "stiti sarmanya"
/// for "स्थिति सामान्य है"). This service normalizes and transliterates
/// Romanized tactical speech into clean Devanagari Hindi.
class HindiTransliterationService {
  HindiTransliterationService._();

  /// Curated tactical & emergency dictionary mapping Whisper phonetic
  /// hallucinations and Hinglish commands directly to standard Devanagari.
  static final Map<String, String> _tacticalPhrases = {
    // Distress & Emergency
    'madag besto': 'मदद भेजो',
    'madag': 'मदद',
    'madad vijay': 'मदद भेजो',
    'madad viz': 'मदद भेजो',
    'madad bhejo': 'मदद भेजो',
    'madad chahiye jaldi': 'मदद चाहिए जल्दी',
    'madad chahiye': 'मदद चाहिए',
    'madad karo': 'मदद करो',
    'madad': 'मदद',
    'jaldi': 'जल्दी',
    'bachao': 'बचाओ',
    'sos': 'आपातकालीन मदद (SOS)',
    'emergency': 'आपातकाल',
    'aapatkal': 'आपातकाल',

    // Tactical & Comms Commands
    'radio check': 'रेडियो चेक',
    'audio check': 'रेडियो चेक',
    'sound check': 'रेडियो चेक',
    'roger': 'रोज़र (स्वीकृत)',
    'copy that': 'कॉपी (स्वीकृत)',
    'copy': 'कॉपी',
    'over': 'ओवर',
    'out': 'आउट',
    'standby': 'स्टैंडबाय (प्रतीक्षा)',
    'affirmative': 'स्वीकृत',
    'negative': 'अस्वीकृत',

    // Combat & Field Status
    'khmla hurai': 'हमला हो रहा है',
    'kamla hurai': 'हमला हो रहा है',
    'hamla ho raha hai': 'हमला हो रहा है',
    'hamla': 'हमला',
    'firing ho rahi hai': 'फायरिंग हो रही है',
    'firing': 'फायरिंग',
    'dushman dikha': 'दुश्मन दिखा',
    'dushman': 'दुश्मन',
    'shatru': 'शत्रु',
    'stiti sarmanya hay': 'स्थिति सामान्य है',
    'stiti sarmanya': 'स्थिति सामान्य है',
    'sthiti samanya hai': 'स्थिति सामान्य है',
    'sthiti samanya': 'स्थिति सामान्य है',
    'sab theek hai': 'सब ठीक है',
    'all clear': 'ऑल क्लियर (सुरक्षित)',
    'surakshit': 'सुरक्षित',
    'khatra': 'खतरा',

    // Movement & Orders
    'sani kagi barho': 'सैनिक आगे बढ़ो',
    'sainik aage badho': 'सैनिक आगे बढ़ो',
    'aage badho': 'आगे बढ़ो',
    'piche hato': 'आगे पीछे हटो',
    'ruko': 'रुको',
    'ruk jao': 'रुक जाओ',
    'chup jao': 'छुप जाओ',
    'position lo': 'पोजीशन लो',
    'morcha sambhalo': 'मोर्चा संभालो',
    'squad leader': 'स्क्वाड लीडर',
    'base commander': 'बेस कमांडर',
    'commander': 'कमांडर',
    'report do': 'रिपोर्ट दो',
    'report': 'रिपोर्ट',
    'location bhejo': 'लोकेशन भेजो',
    'location batao': 'लोकेशन बताओ',
    'location': 'लोकेशन',

    // Greetings & Standard phrases
    'namaste you ke siheen': 'नमस्ते, आप कैसे हैं',
    'namaste aap kaise hain': 'नमस्ते, आप कैसे हैं',
    'namaste': 'नमस्ते',
    'namaskar': 'नमस्कार',
    'kripya suniye': 'कृपया सुनिए',
    'kripya suno': 'कृपया सुनो',
    'sun rahe ho': 'सुन रहे हो',
    'kya hal hai': 'क्या हाल है',
    'theek hai': 'ठीक है',
  };

  /// Individual tactical words dictionary for token-level lookup.
  static final Map<String, String> _wordDict = {
    'madad': 'मदद',
    'madag': 'मदद',
    'bhejo': 'भेजो',
    'besto': 'भेजो',
    'vijay': 'भेजो',
    'viz': 'भेजो',
    'chahiye': 'चाहिए',
    'bachao': 'बचाओ',
    'hamla': 'हमला',
    'khmla': 'हमला',
    'dushman': 'दुश्मन',
    'shatru': 'शत्रु',
    'khatra': 'खतरा',
    'suraksha': 'सुरक्षा',
    'surakshit': 'सुरक्षित',
    'sainik': 'सैनिक',
    'sani': 'सैनिक',
    'jawano': 'जवानों',
    'jawan': 'जवान',
    'aage': 'आगे',
    'kagi': 'आगे',
    'badho': 'बढ़ो',
    'barho': 'बढ़ो',
    'piche': 'पीछे',
    'hato': 'हटो',
    'ruko': 'रुको',
    'morcha': 'मोर्चा',
    'radio': 'रेडियो',
    'check': 'चेक',
    'roger': 'रोज़र',
    'copy': 'कॉपी',
    'over': 'ओवर',
    'out': 'आउट',
    'location': 'लोकेशन',
    'report': 'रिपोर्ट',
    'position': 'पोजीशन',
    'base': 'बेस',
    'alpha': 'अल्फा',
    'bravo': 'ब्रावो',
    'charlie': 'चार्ली',
    'delta': 'डेल्टा',
    'echo': 'इको',
    'leader': 'लीडर',
    'commander': 'कमांडर',
    'namaste': 'नमस्ते',
    'namaskar': 'नमस्कार',
    'kripya': 'कृपया',
    'theek': 'ठीक',
    'hai': 'है',
    'hain': 'हैं',
    'ho': 'हो',
    'kya': 'क्या',
    'kaun': 'कौन',
    'kaha': 'कहाँ',
    'kab': 'कब',
    'kyun': 'क्यों',
    'kaise': 'कैसे',
    'sab': 'सब',
    'hum': 'हम',
    'main': 'मैं',
    'aap': 'आप',
    'tum': 'तुम',
    'yeh': 'यह',
    'woh': 'वह',
    'yahan': 'यहाँ',
    'wahan': 'वहाँ',
    'aur': 'और',
    'par': 'पर',
    'se': 'से',
    'ko': 'को',
    'ka': 'का',
    'ke': 'के',
    'ki': 'की',
    'mein': 'में',
    'nahi': 'नहीं',
    'haan': 'हाँ',
  };

  /// Multi-character consonant digraphs in Latin.
  static final List<MapEntry<String, String>> _consonantRules = [
    MapEntry('ksha', 'क्ष'),
    MapEntry('gya', 'ज्ञ'),
    MapEntry('tra', 'त्र'),
    MapEntry('shh', 'ष'),
    MapEntry('chh', 'छ'),
    MapEntry('kh', 'ख'),
    MapEntry('gh', 'घ'),
    MapEntry('ch', 'च'),
    MapEntry('jh', 'झ'),
    MapEntry('th', 'थ'),
    MapEntry('dh', 'ध'),
    MapEntry('ph', 'फ'),
    MapEntry('bh', 'भ'),
    MapEntry('sh', 'श'),
    MapEntry('k', 'क'),
    MapEntry('g', 'ग'),
    MapEntry('j', 'ज'),
    MapEntry('t', 'त'),
    MapEntry('d', 'द'),
    MapEntry('n', 'न'),
    MapEntry('p', 'प'),
    MapEntry('b', 'ब'),
    MapEntry('m', 'म'),
    MapEntry('y', 'य'),
    MapEntry('r', 'र'),
    MapEntry('l', 'ल'),
    MapEntry('v', 'व'),
    MapEntry('w', 'व'),
    MapEntry('s', 'स'),
    MapEntry('h', 'ह'),
    MapEntry('z', 'ज़'),
    MapEntry('f', 'फ़'),
  ];

  /// Vowel letters (initial vs dependent matra).
  static final List<MapEntry<String, (String, String)>> _vowelRules = [
    MapEntry('aa', ('आ', 'ा')),
    MapEntry('ee', ('ई', 'ी')),
    MapEntry('oo', ('ऊ', 'ू')),
    MapEntry('ai', ('ऐ', 'ै')),
    MapEntry('au', ('औ', 'ौ')),
    MapEntry('a', ('अ', '')),
    MapEntry('i', ('इ', 'ि')),
    MapEntry('u', ('उ', 'ु')),
    MapEntry('e', ('ए', 'े')),
    MapEntry('o', ('ओ', 'ो')),
  ];

  /// Checks if the text already contains Devanagari Unicode characters (U+0900 - U+097F).
  static bool hasDevanagari(String text) {
    for (final unit in text.codeUnits) {
      if (unit >= 0x0900 && unit <= 0x097F) {
        return true;
      }
    }
    return false;
  }

  /// Converts a Romanized/Latin speech transcript into clean Devanagari Hindi.
  static String toHindiDevanagari(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return raw;

    // If it already has Devanagari script, keep it as-is!
    if (hasDevanagari(raw)) return raw;

    final lower = raw.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    // 1. Direct tactical phrase match
    if (_tacticalPhrases.containsKey(lower)) {
      return _tacticalPhrases[lower]!;
    }

    // 2. Sub-phrase tactical check (longest match first)
    String working = lower;
    for (final entry in _tacticalPhrases.entries) {
      if (entry.key.contains(' ') && working.contains(entry.key)) {
        working = working.replaceAll(entry.key, entry.value);
      }
    }
    if (hasDevanagari(working)) {
      return _finalizeTransliteration(working);
    }

    // 3. Word-by-word dictionary and phonetic conversion
    final tokens = lower.split(' ');
    final resultWords = <String>[];

    for (final token in tokens) {
      final clean = token.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (clean.isEmpty) {
        resultWords.add(token);
        continue;
      }

      if (_wordDict.containsKey(clean)) {
        resultWords.add(_wordDict[clean]!);
      } else {
        resultWords.add(_transliterateWord(clean));
      }
    }

    return resultWords.join(' ');
  }

  /// Transliterates a single roman word into Devanagari phonetically.
  static String _transliterateWord(String word) {
    if (word.isEmpty) return word;
    final buffer = StringBuffer();
    int idx = 0;
    bool lastWasConsonant = false;

    while (idx < word.length) {
      // Check for consonants
      String? matchedConsonant;
      int matchLen = 0;

      for (final rule in _consonantRules) {
        if (word.startsWith(rule.key, idx)) {
          matchedConsonant = rule.value;
          matchLen = rule.key.length;
          break;
        }
      }

      if (matchedConsonant != null) {
        if (lastWasConsonant) {
          // Half consonant (virama) in cluster
          buffer.write('्');
        }
        buffer.write(matchedConsonant);
        lastWasConsonant = true;
        idx += matchLen;
        continue;
      }

      // Check for vowels
      (String, String)? matchedVowel;
      int vLen = 0;

      for (final vRule in _vowelRules) {
        if (word.startsWith(vRule.key, idx)) {
          matchedVowel = vRule.value;
          vLen = vRule.key.length;
          break;
        }
      }

      if (matchedVowel != null) {
        if (lastWasConsonant) {
          // Dependent matra
          buffer.write(matchedVowel.$2);
        } else {
          // Independent vowel
          buffer.write(matchedVowel.$1);
        }
        lastWasConsonant = false;
        idx += vLen;
        continue;
      }

      // Fallback: character pass-through (digits, punctuation)
      buffer.write(word[idx]);
      lastWasConsonant = false;
      idx++;
    }

    return buffer.toString();
  }

  static String _finalizeTransliteration(String input) {
    final tokens = input.split(' ');
    final out = <String>[];
    for (final t in tokens) {
      if (hasDevanagari(t)) {
        out.add(t);
      } else if (_wordDict.containsKey(t.toLowerCase())) {
        out.add(_wordDict[t.toLowerCase()]!);
      } else {
        out.add(_transliterateWord(t.toLowerCase()));
      }
    }
    return out.join(' ');
  }
}
