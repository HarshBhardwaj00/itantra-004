// ignore_for_file: avoid_print
import 'dart:typed_data';

void main() {
  final builder = BytesBuilder();
  void writeInt16(int value) {
    builder.add([value & 0xFF, (value >> 8) & 0xFF]);
  }

  writeInt16(23634);
  writeInt16(-3);
  writeInt16(32767);
  writeInt16(-32768);
  final bytes = builder.takeBytes();
  print(bytes);
}
