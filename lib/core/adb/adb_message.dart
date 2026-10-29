/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:typed_data';

int adbCommand(String value) => value.codeUnits.asMap().entries.fold(
  0,
  (a, e) => a | (e.value << (8 * e.key)),
);

class AdbMessage {
  AdbMessage(this.command, this.arg0, this.arg1, [List<int> data = const []])
    : data = Uint8List.fromList(data);
  final int command, arg0, arg1;
  final Uint8List data;

  Uint8List encode() {
    final result = Uint8List(24 + data.length);
    final header = ByteData.sublistView(result);
    final fields = [
      command,
      arg0,
      arg1,
      data.length,
      data.fold<int>(0, (a, b) => (a + b) & 0xffffffff),
      command ^ 0xffffffff,
    ];
    for (var i = 0; i < fields.length; i++) {
      header.setUint32(i * 4, fields[i], Endian.little);
    }
    result.setRange(24, result.length, data);
    return result;
  }
}

class AdbMessageDecoder {
  Uint8List _buffer = Uint8List(0);
  List<AdbMessage> add(List<int> bytes) {
    _buffer = Uint8List.fromList([..._buffer, ...bytes]);
    final messages = <AdbMessage>[];
    var offset = 0;
    while (_buffer.length - offset >= 24) {
      final header = ByteData.sublistView(_buffer, offset, offset + 24);
      final command = header.getUint32(0, Endian.little);
      final length = header.getUint32(12, Endian.little);
      if (header.getUint32(20, Endian.little) != (command ^ 0xffffffff)) {
        throw const FormatException('Invalid ADB magic');
      }
      if (length > 256 * 1024) {
        throw const FormatException('ADB payload too large');
      }
      if (_buffer.length - offset < 24 + length) break;
      final data = _buffer.sublist(offset + 24, offset + 24 + length);
      if (data.fold<int>(0, (a, b) => (a + b) & 0xffffffff) !=
          header.getUint32(16, Endian.little)) {
        throw const FormatException('Invalid ADB checksum');
      }
      messages.add(
        AdbMessage(
          command,
          header.getUint32(4, Endian.little),
          header.getUint32(8, Endian.little),
          data,
        ),
      );
      offset += 24 + length;
    }
    _buffer = Uint8List.fromList(_buffer.sublist(offset));
    return messages;
  }
}
