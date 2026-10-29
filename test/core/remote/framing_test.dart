/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/remote/atv_framing.dart';

void main() {
  test('round trip', () {
    final payload = Uint8List.fromList(List.generate(300, (i) => i % 256));
    expect(FrameDecoder().add(frame(payload)), [payload]);
  });
  test('split varint and payload', () {
    final payload = Uint8List.fromList(List.generate(300, (i) => i % 256));
    final bytes = frame(payload);
    final decoder = FrameDecoder();
    expect(decoder.add(bytes.sublist(0, 1)), isEmpty);
    expect(decoder.add(bytes.sublist(1, 12)), isEmpty);
    expect(decoder.add(bytes.sublist(12)), [payload]);
  });
  test('coalesced frames', () {
    final a = Uint8List.fromList([1, 2]);
    final b = Uint8List.fromList([3]);
    expect(FrameDecoder().add([...frame(a), ...frame(b)]), [a, b]);
  });
}
