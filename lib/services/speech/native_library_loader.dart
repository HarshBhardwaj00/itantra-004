import 'native_library_loader_stub.dart'
    if (dart.library.ffi) 'native_library_loader_real.dart';

/// Preloads a native dynamic library safely across all platforms (Web, Desktop, Mobile).
void preloadDll(String path) {
  preloadNativeLibrary(path);
}

/// Ensures sherpa-onnx bindings and onnxruntime DLLs are cleanly resolved on all platforms.
void ensureSherpaBindingsInitialized() {
  ensureSherpaBindings();
}
