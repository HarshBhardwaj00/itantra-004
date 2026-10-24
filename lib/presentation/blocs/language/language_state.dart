import 'package:equatable/equatable.dart';

enum LanguageStatus {
  initial,
  loading,
  loaded,
  switching,
  testing,
  error,
}

enum LanguageAvailability {
  active,
  installed,
  available,
}

class LanguagePack extends Equatable {
  final String code;
  final String name;
  final String script;
  final String modelType;
  final LanguageAvailability availability;
  final int estimatedSizeMB;
  final String testPhrase;

  const LanguagePack({
    required this.code,
    required this.name,
    required this.script,
    required this.modelType,
    required this.availability,
    required this.estimatedSizeMB,
    required this.testPhrase,
  });

  @override
  List<Object?> get props => [
        code,
        name,
        script,
        modelType,
        availability,
        estimatedSizeMB,
        testPhrase,
      ];
}

class LanguageState extends Equatable {
  final LanguageStatus status;
  final List<LanguagePack> languagePacks;
  final LanguagePack? activeLanguage;
  final int usedMemoryMB;
  final int totalMemoryMB;
  final String? errorMessage;
  final bool isTestingVoice;
  final String? testingLanguageCode;

  const LanguageState({
    this.status = LanguageStatus.initial,
    this.languagePacks = const [],
    this.activeLanguage,
    this.usedMemoryMB = 110,
    this.totalMemoryMB = 2048,
    this.errorMessage,
    this.isTestingVoice = false,
    this.testingLanguageCode,
  });

  /// Short RAM read-out — the full sentence lives in [memoryStatus], so the
  /// gauge never has to render a long monospace string.
  String get memoryLabel => '$usedMemoryMB MB of ${totalMemoryMB ~/ 1024} GB';

  /// Health of the current model footprint.
  String get memoryStatus {
    if (usedMemoryMB <= totalMemoryMB * 0.6) return 'Optimal';
    if (usedMemoryMB <= totalMemoryMB * 0.85) return 'Moderate';
    return 'High';
  }

  double get memoryRatio => usedMemoryMB / totalMemoryMB;

  LanguageState copyWith({
    LanguageStatus? status,
    List<LanguagePack>? languagePacks,
    LanguagePack? activeLanguage,
    int? usedMemoryMB,
    int? totalMemoryMB,
    String? errorMessage,
    bool? isTestingVoice,
    String? testingLanguageCode,
    bool clearTestingLanguage = false,
  }) {
    return LanguageState(
      status: status ?? this.status,
      languagePacks: languagePacks ?? this.languagePacks,
      activeLanguage: activeLanguage ?? this.activeLanguage,
      usedMemoryMB: usedMemoryMB ?? this.usedMemoryMB,
      totalMemoryMB: totalMemoryMB ?? this.totalMemoryMB,
      errorMessage: errorMessage ?? this.errorMessage,
      isTestingVoice: isTestingVoice ?? this.isTestingVoice,
      testingLanguageCode: clearTestingLanguage ? null : (testingLanguageCode ?? this.testingLanguageCode),
    );
  }

  @override
  List<Object?> get props => [
        status,
        languagePacks,
        activeLanguage,
        usedMemoryMB,
        totalMemoryMB,
        errorMessage,
        isTestingVoice,
        testingLanguageCode,
      ];
}