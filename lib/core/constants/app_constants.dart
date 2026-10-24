import 'dart:io';

class AppConstants {
  static const String appName = 'iTantra';
  static const String appVersion = '1.0.0';

  // Base directory where models are located
  static const String defaultDesktopModelsDir = r'D:\itantra\models';

  // Network & Protocol Defaults
  static const int defaultUdpPort = 45454;
  static const int defaultBaudRate = 9600;
  static const int emulatedLoRaBitrateBps = 600;

  // Emergency SOS Defaults
  static const String sosAlertKeyword = 'SOS';
  static const double maxVolumeLevel = 1.0;

  // Active Language (persisted across sessions)
  static String activeLanguageCode = 'hi_IN';
  static String activeLanguageName = 'Hindi';
}

class ModelPaths {
  static String resolvedBaseDir = AppConstants.defaultDesktopModelsDir;

  final String baseDir;

  ModelPaths({String? baseDir})
      : baseDir = baseDir ?? resolvedBaseDir;

  static String _findFirstExisting(List<String> candidates, String defaultPath) {
    for (final path in candidates) {
      if (File(path).existsSync() || Directory(path).existsSync()) {
        return path;
      }
    }
    return defaultPath;
  }

  // VAD Model
  String get vadModelPath => _findFirstExisting([
        '$baseDir${Platform.pathSeparator}silero_vad.onnx',
        '$baseDir${Platform.pathSeparator}vad${Platform.pathSeparator}silero_vad.onnx',
      ], '$baseDir${Platform.pathSeparator}silero_vad.onnx');

  // STT: Whisper Tiny Multilingual (INT8 ONNX)
  String get whisperDir => _findFirstExisting([
        '$baseDir${Platform.pathSeparator}sherpa-onnx-whisper-tiny',
        '$baseDir${Platform.pathSeparator}stt${Platform.pathSeparator}whisper-tiny',
        '$baseDir${Platform.pathSeparator}whisper-tiny',
      ], '$baseDir${Platform.pathSeparator}sherpa-onnx-whisper-tiny');

  String get whisperEncoderPath =>
      '$whisperDir${Platform.pathSeparator}tiny-encoder.int8.onnx';
  String get whisperDecoderPath =>
      '$whisperDir${Platform.pathSeparator}tiny-decoder.int8.onnx';
  String get whisperTokensPath =>
      '$whisperDir${Platform.pathSeparator}tiny-tokens.txt';

  // TTS: Piper Models for Indian Languages
  String get piperHindiDir => _findFirstExisting([
        '$baseDir${Platform.pathSeparator}vits-piper-hi_IN-pratham-medium',
        '$baseDir${Platform.pathSeparator}tts${Platform.pathSeparator}piper-hindi',
        '$baseDir${Platform.pathSeparator}piper-hindi',
      ], '$baseDir${Platform.pathSeparator}vits-piper-hi_IN-pratham-medium');
  String get piperHindiModelPath =>
      '$piperHindiDir${Platform.pathSeparator}hi_IN-pratham-medium.onnx';
  String get piperHindiTokensPath =>
      '$piperHindiDir${Platform.pathSeparator}tokens.txt';
  String get piperHindiDataDir =>
      '$piperHindiDir${Platform.pathSeparator}espeak-ng-data';

  String get piperMarathiDir =>
      '$baseDir${Platform.pathSeparator}vits-piper-mr_IN';
  String get piperMarathiModelPath =>
      '$piperMarathiDir${Platform.pathSeparator}mr_IN.onnx';
  String get piperMarathiTokensPath =>
      '$piperMarathiDir${Platform.pathSeparator}tokens.txt';
  String get piperMarathiDataDir =>
      '$piperMarathiDir${Platform.pathSeparator}espeak-ng-data';

  String get piperBengaliDir =>
      '$baseDir${Platform.pathSeparator}vits-piper-bn_IN';
  String get piperBengaliModelPath =>
      '$piperBengaliDir${Platform.pathSeparator}bn_IN.onnx';
  String get piperBengaliTokensPath =>
      '$piperBengaliDir${Platform.pathSeparator}tokens.txt';
  String get piperBengaliDataDir =>
      '$piperBengaliDir${Platform.pathSeparator}espeak-ng-data';

  String get piperTamilDir =>
      '$baseDir${Platform.pathSeparator}vits-piper-ta_IN';
  String get piperTamilModelPath =>
      '$piperTamilDir${Platform.pathSeparator}ta_IN.onnx';
  String get piperTamilTokensPath =>
      '$piperTamilDir${Platform.pathSeparator}tokens.txt';
  String get piperTamilDataDir =>
      '$piperTamilDir${Platform.pathSeparator}espeak-ng-data';

  String get piperTeluguDir =>
      '$baseDir${Platform.pathSeparator}vits-piper-te_IN';
  String get piperTeluguModelPath =>
      '$piperTeluguDir${Platform.pathSeparator}te_IN.onnx';
  String get piperTeluguTokensPath =>
      '$piperTeluguDir${Platform.pathSeparator}tokens.txt';
  String get piperTeluguDataDir =>
      '$piperTeluguDir${Platform.pathSeparator}espeak-ng-data';

  String get piperGujaratiDir =>
      '$baseDir${Platform.pathSeparator}vits-piper-gu_IN';
  String get piperGujaratiModelPath =>
      '$piperGujaratiDir${Platform.pathSeparator}gu_IN.onnx';
  String get piperGujaratiTokensPath =>
      '$piperGujaratiDir${Platform.pathSeparator}tokens.txt';
  String get piperGujaratiDataDir =>
      '$piperGujaratiDir${Platform.pathSeparator}espeak-ng-data';

  String get piperPunjabiDir =>
      '$baseDir${Platform.pathSeparator}vits-piper-pa_IN';
  String get piperPunjabiModelPath =>
      '$piperPunjabiDir${Platform.pathSeparator}pa_IN.onnx';
  String get piperPunjabiTokensPath =>
      '$piperPunjabiDir${Platform.pathSeparator}tokens.txt';
  String get piperPunjabiDataDir =>
      '$piperPunjabiDir${Platform.pathSeparator}espeak-ng-data';

  String get piperMalayalamDir =>
      '$baseDir${Platform.pathSeparator}vits-piper-ml_IN';
  String get piperMalayalamModelPath =>
      '$piperMalayalamDir${Platform.pathSeparator}ml_IN.onnx';
  String get piperMalayalamTokensPath =>
      '$piperMalayalamDir${Platform.pathSeparator}tokens.txt';
  String get piperMalayalamDataDir =>
      '$piperMalayalamDir${Platform.pathSeparator}espeak-ng-data';

  String get piperKannadaDir =>
      '$baseDir${Platform.pathSeparator}vits-piper-kn_IN';
  String get piperKannadaModelPath =>
      '$piperKannadaDir${Platform.pathSeparator}kn_IN.onnx';
  String get piperKannadaTokensPath =>
      '$piperKannadaDir${Platform.pathSeparator}tokens.txt';
  String get piperKannadaDataDir =>
      '$piperKannadaDir${Platform.pathSeparator}espeak-ng-data';

  // STT: Vosk Models
  String get voskHindiDir => _findFirstExisting([
        '$baseDir${Platform.pathSeparator}vosk-model-small-hi-0.22',
        '$baseDir${Platform.pathSeparator}stt${Platform.pathSeparator}vosk-model-small-hi-0.22',
      ], '$baseDir${Platform.pathSeparator}vosk-model-small-hi-0.22');
  String get voskEnglishDir => _findFirstExisting([
        '$baseDir${Platform.pathSeparator}vosk-model-small-en-in-0.4',
        '$baseDir${Platform.pathSeparator}stt${Platform.pathSeparator}vosk-model-small-en-in-0.4',
      ], '$baseDir${Platform.pathSeparator}vosk-model-small-en-in-0.4');
  String get voskMarathiDir =>
      '$baseDir${Platform.pathSeparator}vosk-model-small-mr-0.4';
  String get voskBengaliDir =>
      '$baseDir${Platform.pathSeparator}vosk-model-small-bn-0.4';
  String get voskTamilDir =>
      '$baseDir${Platform.pathSeparator}vosk-model-small-ta-0.4';
  String get voskTeluguDir =>
      '$baseDir${Platform.pathSeparator}vosk-model-small-te-0.4';
  String get voskGujaratiDir =>
      '$baseDir${Platform.pathSeparator}vosk-model-small-gu-0.4';
  String get voskPunjabiDir =>
      '$baseDir${Platform.pathSeparator}vosk-model-small-pa-0.4';
  String get voskMalayalamDir =>
      '$baseDir${Platform.pathSeparator}vosk-model-small-ml-0.4';
  String get voskKannadaDir =>
      '$baseDir${Platform.pathSeparator}vosk-model-small-kn-0.4';

  bool get isVadAvailable => File(vadModelPath).existsSync();
  bool get isWhisperAvailable =>
      File(whisperEncoderPath).existsSync() &&
      File(whisperDecoderPath).existsSync() &&
      File(whisperTokensPath).existsSync();
  bool get isPiperHindiAvailable =>
      File(piperHindiModelPath).existsSync() &&
      File(piperHindiTokensPath).existsSync() &&
      Directory(piperHindiDataDir).existsSync();

  bool isPiperAvailable(String languageCode) {
    switch (languageCode) {
      case 'hi_IN':
      case 'hi':
        return isPiperHindiAvailable;
      case 'en_IN':
      case 'en':
        return false; // English uses native system TTS (FlutterTts)
      case 'mr_IN':
        return File(piperMarathiModelPath).existsSync() &&
            File(piperMarathiTokensPath).existsSync() &&
            Directory(piperMarathiDataDir).existsSync();
      case 'bn_IN':
        return File(piperBengaliModelPath).existsSync() &&
            File(piperBengaliTokensPath).existsSync() &&
            Directory(piperBengaliDataDir).existsSync();
      case 'ta_IN':
        return File(piperTamilModelPath).existsSync() &&
            File(piperTamilTokensPath).existsSync() &&
            Directory(piperTamilDataDir).existsSync();
      case 'te_IN':
        return File(piperTeluguModelPath).existsSync() &&
            File(piperTeluguTokensPath).existsSync() &&
            Directory(piperTeluguDataDir).existsSync();
      case 'gu_IN':
        return File(piperGujaratiModelPath).existsSync() &&
            File(piperGujaratiTokensPath).existsSync() &&
            Directory(piperGujaratiDataDir).existsSync();
      case 'pa_IN':
        return File(piperPunjabiModelPath).existsSync() &&
            File(piperPunjabiTokensPath).existsSync() &&
            Directory(piperPunjabiDataDir).existsSync();
      case 'ml_IN':
        return File(piperMalayalamModelPath).existsSync() &&
            File(piperMalayalamTokensPath).existsSync() &&
            Directory(piperMalayalamDataDir).existsSync();
      case 'kn_IN':
        return File(piperKannadaModelPath).existsSync() &&
            File(piperKannadaTokensPath).existsSync() &&
            Directory(piperKannadaDataDir).existsSync();
      default:
        return false;
    }
  }

  String getPiperModelPath(String languageCode) {
    switch (languageCode) {
      case 'hi_IN':
      case 'hi':
        return piperHindiModelPath;
      case 'mr_IN':
        return piperMarathiModelPath;
      case 'bn_IN':
        return piperBengaliModelPath;
      case 'ta_IN':
        return piperTamilModelPath;
      case 'te_IN':
        return piperTeluguModelPath;
      case 'gu_IN':
        return piperGujaratiModelPath;
      case 'pa_IN':
        return piperPunjabiModelPath;
      case 'ml_IN':
        return piperMalayalamModelPath;
      case 'kn_IN':
        return piperKannadaModelPath;
      default:
        return piperHindiModelPath;
    }
  }

  String getPiperTokensPath(String languageCode) {
    switch (languageCode) {
      case 'hi_IN':
      case 'hi':
        return piperHindiTokensPath;
      case 'mr_IN':
        return piperMarathiTokensPath;
      case 'bn_IN':
        return piperBengaliTokensPath;
      case 'ta_IN':
        return piperTamilTokensPath;
      case 'te_IN':
        return piperTeluguTokensPath;
      case 'gu_IN':
        return piperGujaratiTokensPath;
      case 'pa_IN':
        return piperPunjabiTokensPath;
      case 'ml_IN':
        return piperMalayalamTokensPath;
      case 'kn_IN':
        return piperKannadaTokensPath;
      default:
        return piperHindiTokensPath;
    }
  }

  String getPiperDataDir(String languageCode) {
    switch (languageCode) {
      case 'hi_IN':
      case 'hi':
        return piperHindiDataDir;
      case 'mr_IN':
        return piperMarathiDataDir;
      case 'bn_IN':
        return piperBengaliDataDir;
      case 'ta_IN':
        return piperTamilDataDir;
      case 'te_IN':
        return piperTeluguDataDir;
      case 'gu_IN':
        return piperGujaratiDataDir;
      case 'pa_IN':
        return piperPunjabiDataDir;
      case 'ml_IN':
        return piperMalayalamDataDir;
      case 'kn_IN':
        return piperKannadaDataDir;
      default:
        return piperHindiDataDir;
    }
  }

  bool get isVoskHindiAvailable => Directory(voskHindiDir).existsSync();
  bool get isVoskEnglishAvailable => Directory(voskEnglishDir).existsSync();
  bool get isVoskMarathiAvailable => Directory(voskMarathiDir).existsSync();
  bool get isVoskBengaliAvailable => Directory(voskBengaliDir).existsSync();
  bool get isVoskTamilAvailable => Directory(voskTamilDir).existsSync();
  bool get isVoskTeluguAvailable => Directory(voskTeluguDir).existsSync();
  bool get isVoskGujaratiAvailable => Directory(voskGujaratiDir).existsSync();
  bool get isVoskPunjabiAvailable => Directory(voskPunjabiDir).existsSync();
  bool get isVoskMalayalamAvailable => Directory(voskMalayalamDir).existsSync();
  bool get isVoskKannadaAvailable => Directory(voskKannadaDir).existsSync();
}
