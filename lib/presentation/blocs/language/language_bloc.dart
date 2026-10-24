import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/device_node.dart';
import '../../../services/speech/language_pack_manager.dart';
import '../../../services/speech/stt_service.dart';
import '../../../services/speech/tts_service.dart';
import 'language_event.dart';
import 'language_state.dart';

class LanguageBloc extends Bloc<LanguageEvent, LanguageState> {
  LanguageBloc() : super(const LanguageState()) {
    on<LanguageInitialize>(_onInitialize);
    on<LanguageSelect>(_onSelect);
    on<LanguageTestVoice>(_onTestVoice);
    on<LanguageRefreshMemory>(_onRefreshMemory);
    on<LanguageDownloadPack>(_onDownloadPack);
  }

  static final List<LanguagePack> _defaultPacks = [
    LanguagePack(
      code: 'hi_IN',
      name: 'Hindi',
      script: 'हिन्दी',
      modelType: 'Piper VITS',
      availability: LanguageAvailability.active,
      estimatedSizeMB: 110,
      testPhrase: 'iTantra mein aapka swagat hai',
    ),
    LanguagePack(
      code: 'en_IN',
      name: 'English',
      script: 'English',
      modelType: 'System',
      availability: LanguageAvailability.installed,
      estimatedSizeMB: 0,
      testPhrase: 'Welcome to iTantra',
    ),
    LanguagePack(
      code: 'mr_IN',
      name: 'Marathi',
      script: 'मराठी',
      modelType: 'Piper VITS',
      availability: LanguageAvailability.available,
      estimatedSizeMB: 95,
      testPhrase: 'iTantra मधील आपले स्वागत आहे',
    ),
    LanguagePack(
      code: 'bn_IN',
      name: 'Bengali',
      script: 'বাংলা',
      modelType: 'Piper VITS',
      availability: LanguageAvailability.available,
      estimatedSizeMB: 98,
      testPhrase: 'iTantra-এ আপনাকে স্বাগতম',
    ),
    LanguagePack(
      code: 'ta_IN',
      name: 'Tamil',
      script: 'தமிழ்',
      modelType: 'Piper VITS',
      availability: LanguageAvailability.available,
      estimatedSizeMB: 102,
      testPhrase: 'iTantra-வில் உங்களை வரவேற்கிறோம்',
    ),
    LanguagePack(
      code: 'te_IN',
      name: 'Telugu',
      script: 'తెలుగు',
      modelType: 'Piper VITS',
      availability: LanguageAvailability.available,
      estimatedSizeMB: 97,
      testPhrase: 'iTantraలో మీకు స్వాగతం',
    ),
    LanguagePack(
      code: 'gu_IN',
      name: 'Gujarati',
      script: 'ગુજરાતી',
      modelType: 'Piper VITS',
      availability: LanguageAvailability.available,
      estimatedSizeMB: 93,
      testPhrase: 'iTantra માં તમારું સ્વાગત છે',
    ),
    LanguagePack(
      code: 'pa_IN',
      name: 'Punjabi',
      script: 'ਪੰਜਾਬੀ',
      modelType: 'Piper VITS',
      availability: LanguageAvailability.available,
      estimatedSizeMB: 94,
      testPhrase: 'iTantra ਵਿੱਚ ਤੁਹਾਡਾ ਸੁਆਗਤ ਹੈ',
    ),
    LanguagePack(
      code: 'ml_IN',
      name: 'Malayalam',
      script: 'മലയാളം',
      modelType: 'Piper VITS',
      availability: LanguageAvailability.available,
      estimatedSizeMB: 105,
      testPhrase: 'iTantra-യിൽ നിങ്ങളെ സ്വാगതം ചെയ്യുന്നു',
    ),
    LanguagePack(
      code: 'kn_IN',
      name: 'Kannada',
      script: 'ಕನ್ನಡ',
      modelType: 'Piper VITS',
      availability: LanguageAvailability.available,
      estimatedSizeMB: 96,
      testPhrase: 'iTantra-ಗೆ ನಿಮಗೆ ಸುಸ್ವಾಗತ',
    ),
  ];

  Future<void> _onInitialize(
    LanguageInitialize event,
    Emitter<LanguageState> emit,
  ) async {
    emit(state.copyWith(status: LanguageStatus.loading));

    unawaited(LanguagePackManager.instance.initialize());
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final activeCode = AppConstants.activeLanguageCode;
    final initialPacks = _defaultPacks.map((p) {
      final isInstalled = p.code == 'hi_IN' ||
          p.code == 'en_IN' ||
          LanguagePackManager.instance.isExtracted(p.code);

      if (p.code == activeCode) {
        return LanguagePack(
          code: p.code,
          name: p.name,
          script: p.script,
          modelType: p.modelType,
          availability: LanguageAvailability.active,
          estimatedSizeMB: p.estimatedSizeMB,
          testPhrase: p.testPhrase,
        );
      } else if (isInstalled) {
        return LanguagePack(
          code: p.code,
          name: p.name,
          script: p.script,
          modelType: p.modelType,
          availability: LanguageAvailability.installed,
          estimatedSizeMB: p.estimatedSizeMB,
          testPhrase: p.testPhrase,
        );
      }
      return p;
    }).toList();

    final active = initialPacks.firstWhere(
      (p) => p.code == activeCode,
      orElse: () => initialPacks.first,
    );

    emit(state.copyWith(
      status: LanguageStatus.loaded,
      languagePacks: initialPacks,
      activeLanguage: active,
      usedMemoryMB: active.estimatedSizeMB,
    ));
  }

  Future<void> _onDownloadPack(
    LanguageDownloadPack event,
    Emitter<LanguageState> emit,
  ) async {
    await LanguagePackManager.instance.extractPack(event.languageCode);

    final updatedPacks = state.languagePacks.map((p) {
      if (p.code == event.languageCode && p.availability != LanguageAvailability.active) {
        return LanguagePack(
          code: p.code,
          name: p.name,
          script: p.script,
          modelType: p.modelType,
          availability: LanguageAvailability.installed,
          estimatedSizeMB: p.estimatedSizeMB,
          testPhrase: p.testPhrase,
        );
      }
      return p;
    }).toList();

    emit(state.copyWith(languagePacks: updatedPacks));
  }

  Future<void> _onSelect(
    LanguageSelect event,
    Emitter<LanguageState> emit,
  ) async {
    emit(state.copyWith(status: LanguageStatus.switching));

    AppConstants.activeLanguageCode = event.languageCode;
    AppConstants.activeLanguageName = event.languageName;
    unawaited(DeviceNode.saveActiveLanguage(event.languageCode, event.languageName));

    // Pre-warm / switch STT in background for the new language:
    unawaited(SttService.instance.switchLanguage(event.languageCode));

    // Ensure the single zip pack is ready/extracted:
    try {
      await LanguagePackManager.instance.extractPack(event.languageCode);
    } catch (_) {}

    try {
      await TtsService.instance.switchLanguage(event.languageCode);
    } catch (_) {}

    await Future<void>.delayed(const Duration(milliseconds: 250));

    final newActive = state.languagePacks.firstWhere(
      (p) => p.code == event.languageCode,
      orElse: () => LanguagePack(
        code: event.languageCode,
        name: event.languageName,
        script: event.languageName,
        modelType: event.modelType,
        availability: LanguageAvailability.active,
        estimatedSizeMB: 110,
        testPhrase: '',
      ),
    );

    // Rule: loaded one at a time -> only the active pack occupies RAM (e.g. 110 MB)
    final updatedPacks = state.languagePacks.map((p) {
      if (p.code == event.languageCode) {
        return LanguagePack(
          code: p.code,
          name: p.name,
          script: p.script,
          modelType: p.modelType,
          availability: LanguageAvailability.active,
          estimatedSizeMB: p.estimatedSizeMB,
          testPhrase: p.testPhrase,
        );
      } else if (p.availability == LanguageAvailability.active) {
        return LanguagePack(
          code: p.code,
          name: p.name,
          script: p.script,
          modelType: p.modelType,
          availability: LanguageAvailability.installed,
          estimatedSizeMB: p.estimatedSizeMB,
          testPhrase: p.testPhrase,
        );
      }
      return p;
    }).toList();

    emit(state.copyWith(
      status: LanguageStatus.loaded,
      languagePacks: updatedPacks,
      activeLanguage: newActive,
      usedMemoryMB: newActive.estimatedSizeMB,
    ));
  }

  Future<void> _onTestVoice(
    LanguageTestVoice event,
    Emitter<LanguageState> emit,
  ) async {
    emit(state.copyWith(
      isTestingVoice: true,
      testingLanguageCode: event.languageCode,
    ));

    await Future<void>.delayed(const Duration(milliseconds: 1500));

    emit(state.copyWith(
      isTestingVoice: false,
      clearTestingLanguage: true,
    ));
  }

  Future<void> _onRefreshMemory(
    LanguageRefreshMemory event,
    Emitter<LanguageState> emit,
  ) async {
    final active = state.activeLanguage;
    if (active != null) {
      emit(state.copyWith(usedMemoryMB: active.estimatedSizeMB));
    }
  }
}
