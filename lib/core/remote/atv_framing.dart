/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:typed_data';

/// Prefixes a protobuf payload with its varint length.
Uint8List frame(Uint8List payload) {
  var length = payload.length;
  final prefix = <int>[];
  do {
    var byte = length & 0x7f;
    length >>= 7;
    if (length != 0) byte |= 0x80;
    prefix.add(byte);
  } while (length != 0);
  return Uint8List.fromList([...prefix, ...payload]);
}

/// Decodes varint-delimited messages from arbitrary stream chunks.
class FrameDecoder {
  final List<int> _buffer = [];

  List<Uint8List> add(List<int> chunk) {
    _buffer.addAll(chunk);
    final messages = <Uint8List>[];
    while (_buffer.isNotEmpty) {
      var length = 0;
      var pos = 0;
      var complete = false;
      while (pos < _buffer.length) {
        final byte = _buffer[pos];
        if (pos == 9 && byte > 1) {
          _buffer.clear();
          throw const FormatException('Invalid frame length');
        }
        length |= (byte & 0x7f) << (7 * pos);
        pos++;
        if (byte & 0x80 == 0) {
          complete = true;
          break;
        }
        if (pos == 10) {
          _buffer.clear();
          throw const FormatException('Invalid frame length');
        }
      }
      if (!complete || _buffer.length - pos < length) break;
      messages.add(Uint8List.fromList(_buffer.sublist(pos, pos + length)));
      _buffer.removeRange(0, pos + length);
    }
    return messages;
  }
}
