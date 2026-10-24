import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';

class ModelPathResolver {
  static bool _initialized = false;
  static bool _isCopying = false;
  static double copyProgress = 0.0;

  static bool get isInitialized => _initialized;
  static bool get isCopying => _isCopying;

  /// Ensures models directory is discovered and ready on all platforms.
  static Future<void> ensureInitialized() async {
    if (_initialized) return;

    // 1. Check if the desktop directory exists and contains the VAD model
    try {
      final desktopDir = Directory(AppConstants.defaultDesktopModelsDir);
      if (desktopDir.existsSync()) {
        final vadFile = File('${AppConstants.defaultDesktopModelsDir}${Platform.pathSeparator}silero_vad.onnx');
        if (vadFile.existsSync()) {
          ModelPaths.resolvedBaseDir = AppConstants.defaultDesktopModelsDir;
          _initialized = true;
          return;
        }
      }
    } catch (_) {}

    // 2. On Mobile (Android/iOS) or other platforms, use internal app storage
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory('${docDir.path}${Platform.pathSeparator}models');
      if (!targetDir.existsSync()) {
        await targetDir.create(recursive: true);
      }

      ModelPaths.resolvedBaseDir = targetDir.path;

      // Check if models are already copied
      final vadCopied = File('${targetDir.path}${Platform.pathSeparator}vad${Platform.pathSeparator}silero_vad.onnx').existsSync() ||
          File('${targetDir.path}${Platform.pathSeparator}silero_vad.onnx').existsSync();
      final whisperCopied = File('${targetDir.path}${Platform.pathSeparator}stt${Platform.pathSeparator}whisper-tiny${Platform.pathSeparator}tiny-decoder.int8.onnx').existsSync() ||
          File('${targetDir.path}${Platform.pathSeparator}sherpa-onnx-whisper-tiny${Platform.pathSeparator}tiny-decoder.int8.onnx').existsSync();
      final piperCopied = File('${targetDir.path}${Platform.pathSeparator}tts${Platform.pathSeparator}piper-hindi${Platform.pathSeparator}hi_IN-pratham-medium.onnx').existsSync() ||
          File('${targetDir.path}${Platform.pathSeparator}vits-piper-hi_IN-pratham-medium${Platform.pathSeparator}hi_IN-pratham-medium.onnx').existsSync();

      if (!vadCopied || !whisperCopied || !piperCopied) {
        _isCopying = true;
        await _copyModelsFromAssets(targetDir);
        _isCopying = false;
      }

      _initialized = true;
    } catch (_) {
      // Fallback to desktop path if platform channels fail in testing
      ModelPaths.resolvedBaseDir = AppConstants.defaultDesktopModelsDir;
      _initialized = true;
    }
  }

  static Future<void> _copyModelsFromAssets(Directory targetDir) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final modelAssets = manifest
          .listAssets()
          .where((key) => key.startsWith('assets/models/'))
          .toList();

      final total = modelAssets.length;
      if (total == 0) return;

      int copied = 0;
      for (final assetKey in modelAssets) {
        final relativePath = assetKey.substring('assets/models/'.length);
        if (relativePath.isEmpty || relativePath.toLowerCase().endsWith('readme.md')) {
          continue;
        }

        final destFile = File('${targetDir.path}${Platform.pathSeparator}$relativePath');
        if (!destFile.existsSync()) {
          await destFile.parent.create(recursive: true);
          final byteData = await rootBundle.load(assetKey);
          await destFile.writeAsBytes(
            byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
            flush: true,
          );
        }
        copied++;
        copyProgress = copied / total;
      }
    } catch (_) {}
  }
}
