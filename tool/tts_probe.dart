// ignore_for_file: avoid_print
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

Uint8List toWav(Float32List samples, int sampleRate) {
  final dataSize = samples.length * 2;
  final builder = BytesBuilder();

  void writeTag(String tag) => builder.add(tag.codeUnits);
  void writeInt32(int value) {
    builder.add([
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ]);
  }

  void writeInt16(int value) {
    builder.add([value & 0xFF, (value >> 8) & 0xFF]);
  }

  writeTag('RIFF');
  writeInt32(36 + dataSize);
  writeTag('WAVE');
  writeTag('fmt ');
  writeInt32(16);
  writeInt16(1);
  writeInt16(1);
  writeInt32(sampleRate);
  writeInt32(sampleRate * 2);
  writeInt16(2);
  writeInt16(16);
  writeTag('data');
  writeInt32(dataSize);

  int maxScaled = 0;
  for (final sample in samples) {
    final scaled = (sample.clamp(-1.0, 1.0) * 32767).round();
    if (scaled.abs() > maxScaled) maxScaled = scaled.abs();
    writeInt16(scaled);
  }
  print('maxScaled=$maxScaled');
  final out = builder.takeBytes();
  int fileMax = 0;
  for (var i = 44; i < out.length - 1; i += 2) {
    var v = out[i] | (out[i + 1] << 8);
    if (v > 32767) v -= 65536;
    if (v.abs() > fileMax) fileMax = v.abs();
  }
  print('fileMax=$fileMax');
  return out;
}

void main() {
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
      DynamicLibrary.open(onnxPath);
    }
    DynamicLibrary.open('$foundDir\\sherpa-onnx-c-api.dll');
    sherpa_onnx.initBindings(foundDir);
  } else {
    sherpa_onnx.initBindings();
  }

  final base = r'D:\itantra\models';
  final model = '$base\\vits-piper-hi_IN-pratham-medium\\hi_IN-pratham-medium.onnx';
  final tokens = '$base\\vits-piper-hi_IN-pratham-medium\\tokens.txt';
  final dataDir = '$base\\vits-piper-hi_IN-pratham-medium\\espeak-ng-data';

  final tts = sherpa_onnx.OfflineTts(
    sherpa_onnx.OfflineTtsConfig(
      model: sherpa_onnx.OfflineTtsModelConfig(
        vits: sherpa_onnx.OfflineTtsVitsModelConfig(
          model: model,
          tokens: tokens,
          dataDir: dataDir,
        ),
        numThreads: 2,
        provider: 'cpu',
        debug: false,
      ),
    ),
  );

  final text = 'Senhal';
  final audio = tts.generate(text: text, sid: 0, speed: 1.0);
  final samples = audio.samples;
  double maxAbs = 0;
  for (final s in samples) {
    if (s.abs() > maxAbs) maxAbs = s.abs();
  }
  print('count=${samples.length} maxAbs=$maxAbs');
  final bytes = toWav(samples, audio.sampleRate);
  final path = '${Directory.systemTemp.path}\\probe2.wav';
  File(path).writeAsBytesSync(bytes);
  final readBack = File(path).readAsBytesSync();
  int diskMax = 0;
  for (var i = 44; i < readBack.length - 1; i += 2) {
    var v = readBack[i] | (readBack[i + 1] << 8);
    if (v > 32767) v -= 65536;
    if (v.abs() > diskMax) diskMax = v.abs();
  }
  print('wrote $path len=${bytes.length} diskMax=$diskMax');
  tts.free();
}
