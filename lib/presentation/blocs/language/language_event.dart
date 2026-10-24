import 'package:equatable/equatable.dart';

sealed class LanguageEvent extends Equatable {
  const LanguageEvent();

  @override
  List<Object?> get props => [];
}

final class LanguageInitialize extends LanguageEvent {
  const LanguageInitialize();
}

final class LanguageSelect extends LanguageEvent {
  final String languageCode;
  final String languageName;
  final String modelType;

  const LanguageSelect({
    required this.languageCode,
    required this.languageName,
    required this.modelType,
  });

  @override
  List<Object?> get props => [languageCode, languageName, modelType];
}

final class LanguageTestVoice extends LanguageEvent {
  final String languageCode;

  const LanguageTestVoice(this.languageCode);

  @override
  List<Object?> get props => [languageCode];
}

final class LanguageRefreshMemory extends LanguageEvent {
  const LanguageRefreshMemory();
}

final class LanguageDownloadPack extends LanguageEvent {
  final String languageCode;

  const LanguageDownloadPack(this.languageCode);

  @override
  List<Object?> get props => [languageCode];
}