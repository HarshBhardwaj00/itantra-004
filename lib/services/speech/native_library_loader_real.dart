import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

bool _bindingsInitialized = false;

/// Native (Windows/Android/Desktop) implementation using dart:ffi DynamicLibrary.
void preloadNativeLibrary(String path) {
  try {
    DynamicLibrary.open(path);
  } catch (_) {
    // Gracefully ignore if already loaded or not found
  }
}

/// Ensures sherpa-onnx bindings and onnxruntime DLLs are cleanly resolved on Windows/Desktop.
void ensureSherpaBindings() {
  if (kIsWeb || _bindingsInitialized) return;
  try {
    if (Platform.isWindows) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final candidateDirs = [
        exeDir,
        r'D:\itantra\build\windows\x64\runner\Debug',
        r'D:\itantra\build\windows\x64\runner\Release',
        Directory.current.path,
      ];
      String? foundDir;
      for (final dir in candidateDirs) {
        if (File('$dir\\sherpa-onnx-c-api.dll').existsSync()) {
          foundDir = dir;
          break;
        }
      }
      if (foundDir != null) {
        final onnxPath = '$foundDir\\onnxruntime.dll';
        if (File(onnxPath).existsSync()) {
          preloadNativeLibrary(onnxPath);
        }
        preloadNativeLibrary('$foundDir\\sherpa-onnx-c-api.dll');
        sherpa_onnx.initBindings(foundDir);
        _bindingsInitialized = true;
        return;
      }
    }
    sherpa_onnx.initBindings();
    _bindingsInitialized = true;
  } catch (_) {}
}
