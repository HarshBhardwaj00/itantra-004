/// SpeechModelRegistry — hard guard for the memory contract:
///
/// "One language loaded at a time."
///
/// Only one Piper VITS (TTS) engine may live in RAM at any moment. Every
/// engine creation must register here BEFORE constructing the native model,
/// and must unregister when freed. A second engine trying to register while
/// one is live throws, turning a silent memory leak into a loud failure.
class SpeechModelRegistry {
  SpeechModelRegistry._();
  static final SpeechModelRegistry instance = SpeechModelRegistry._();

  /// Holder id owned by the [TtsService] singleton.
  static const String ttsHolder = 'tts';

  /// Piper slots per process. Whisper STT is excluded: its encoder/decoder
  /// are a single language-agnostic model, so it never competes per language.
  static const int maxConcurrentModels = 1;

  final Map<String, String> _holders = <String, String>{};

  int get liveCount => _holders.length;

  bool get saturated => _holders.length >= maxConcurrentModels;

  /// True when [holder] may create a model right now. A holder replacing
  /// its own registration is always allowed (free-then-load swap).
  bool canRegister(String holder) =>
      !saturated || _holders.containsKey(holder);

  /// Claims the Piper slot. Throws [StateError] when a second engine would
  /// live alongside the first — a one-language-rule violation.
  void register(String holder, String tag) {
    if (saturated && !_holders.containsKey(holder)) {
      throw StateError(
        'One-language-at-a-time violated: "$tag" would load while '
        '[$_holders] is already live',
      );
    }
    _holders[holder] = tag;
  }

  /// Releases the slot. Returns true when this holder actually held one.
  bool unregister(String holder) => _holders.remove(holder) != null;

  /// Test-only: clears all slots without freeing any native memory.
  void reset() => _holders.clear();
}
