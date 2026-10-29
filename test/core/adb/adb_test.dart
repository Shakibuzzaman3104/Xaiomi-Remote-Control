/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/adb/adb_client.dart';
import 'package:xiaomi_remote/core/adb/adb_commands.dart';
import 'package:xiaomi_remote/core/adb/adb_key.dart';
import 'package:xiaomi_remote/core/adb/adb_message.dart';

void main() {
  test('messages survive split and coalesced chunks', () {
    final first = AdbMessage(adbCommand('WRTE'), 1, 2, [1, 2, 3]);
    final second = AdbMessage(adbCommand('OKAY'), 2, 1);
    final bytes = [...first.encode(), ...second.encode()];
    final decoder = AdbMessageDecoder();
    expect(decoder.add(bytes.sublist(0, 7)), isEmpty);
    expect(decoder.add(bytes.sublist(7, 25)), isEmpty);
    final messages = decoder.add(bytes.sublist(25));
    expect(messages.length, 2);
    expect(messages[0].data, [1, 2, 3]);
    expect(messages[1].command, adbCommand('OKAY'));
  });

  test('Android public key and token signature', () {
    final key = AdbKey.generate();
    final bytes = base64Decode(key.androidPublicKey().split(' ').first);
    final data = ByteData.sublistView(bytes);
    expect(bytes.length, 524);
    expect(data.getUint32(0, Endian.little), 64);
    expect(
      (data.getUint32(4, Endian.little) * data.getUint32(8, Endian.little)) &
          0xffffffff,
      0xffffffff,
    );
    expect(data.getUint32(520, Endian.little), 65537);
    final token = Uint8List.fromList(List.generate(20, (i) => i));
    final signature = key.signToken(token);
    final publicKey = CryptoUtils.rsaPublicKeyFromPem(key.publicKeyPem);
    var value = BigInt.zero;
    for (final b in signature) {
      value = (value << 8) | BigInt.from(b);
    }
    value = value.modPow(publicKey.exponent!, publicKey.modulus!);
    final block = Uint8List(256);
    for (var i = 255; i >= 0; i--) {
      block[i] = (value & BigInt.from(255)).toInt();
      value >>= 8;
    }
    expect(block.sublist(0, 2), [0, 1]);
    expect(block.sublist(2, 220), everyElement(255));
    expect(block[220], 0);
    expect(block.sublist(221), [
      0x30,
      0x21,
      0x30,
      0x09,
      0x06,
      0x05,
      0x2b,
      0x0e,
      0x03,
      0x02,
      0x1a,
      0x05,
      0x00,
      0x04,
      0x14,
      ...token,
    ]);
  });

  test('parses media and audio dumps', () {
    const media = '''
    package=com.google.android.youtube.tv
      state=PlaybackState {state=3, position=1437, buffered position=0, speed=1.0, updated=3619212, actions=379, custom actions=[], active item id=-1, error=null}
      metadata:size=5, description=Me at the zoo, jawed, null
    package=com.netflix.ninja
      metadata:size=0, description=null
''';
    const audio = '''
- STREAM_MUSIC:
   Muted: false
   Min: 0
   Max: 15
   Current: 2 (speaker): 3, 80 (bt_a2dp): 6, 400 (hdmi): 12, 40000000 (default): 3
''';
    final now = AdbCommands.parseNowPlaying(media)!;
    expect(now.package, 'com.google.android.youtube.tv');
    expect(now.title, 'Me at the zoo');
    expect(now.subtitle, 'jawed');
    expect(now.positionMs, 1437);
    expect(now.state, AdbPlaybackState.playing);
    expect(AdbCommands.parseMusicVolume(audio), (12, 15));
  });

  test('detects fixed music volume conservatively', () {
    expect(AdbCommands.parseFixedVolume('mUseFixedVolume=true'), isTrue);
    expect(AdbCommands.parseFixedVolume('mUseFixedVolume=false'), isFalse);
    const fixed =
        'mFixedVolumeDevices=0x400\n- STREAM_MUSIC:\n  Devices: hdmi\n';
    expect(AdbCommands.parseFixedVolume(fixed), isTrue);
    expect(
      AdbCommands.parseFixedVolume(
        fixed.replaceAll('Devices: hdmi', 'Devices: speaker'),
      ),
      isFalse,
    );
    expect(
      AdbCommands.parseFixedVolume(
        fixed.replaceAll('Devices: hdmi', 'Current: 400 (hdmi): 12'),
      ),
      isFalse,
    );
    expect(
      AdbCommands.parseFixedVolume(fixed.replaceAll('0x400', '0x2')),
      isFalse,
    );
  });

  test('probe without public key fails fast on an untrusted key', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    var offeredPublicKey = false;
    server.listen((socket) {
      final decoder = AdbMessageDecoder();
      void send(String command, int a, int b, [List<int> data = const []]) =>
          socket.add(AdbMessage(adbCommand(command), a, b, data).encode());
      socket.listen((data) {
        for (final message in decoder.add(data)) {
          if (message.command == adbCommand('CNXN')) {
            send('AUTH', 1, 0, List.filled(20, 7));
          } else if (message.command == adbCommand('AUTH')) {
            if (message.arg0 == 3) offeredPublicKey = true;
            send('AUTH', 1, 0, List.filled(20, 8));
          }
        }
      }, onError: (_) {});
    });
    final client = AdbClient(
      host: '127.0.0.1',
      port: server.port,
      key: AdbKey.generate(),
    );
    try {
      await expectLater(
        client.connect(
          authTimeout: const Duration(seconds: 5),
          offerPublicKey: false,
        ),
        throwsA(
          isA<AdbException>().having(
            (e) => e.message,
            'message',
            'Key not trusted yet',
          ),
        ),
      );
      expect(offeredPublicKey, isFalse);
    } finally {
      await server.close();
    }
  });

  test('fake daemon connects, handles shell, push and install', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final uploads = <List<int>>[];
    final services = <int, String>{};
    final buffers = <int, List<int>>{};
    final received = <int, List<int>>{};
    final daemon = server.listen((socket) {
      final decoder = AdbMessageDecoder();
      void send(String command, int a, int b, [List<int> data = const []]) =>
          socket.add(AdbMessage(adbCommand(command), a, b, data).encode());
      socket.listen((data) {
        for (final message in decoder.add(data)) {
          final cmd = message.command;
          if (cmd == adbCommand('CNXN')) {
            send('AUTH', 1, 0, List.filled(20, 7));
          } else if (cmd == adbCommand('AUTH')) {
            if (message.arg0 == 2) {
              expect(message.data.length, 256);
              send('AUTH', 1, 0, List.filled(20, 8));
            } else {
              expect(message.arg0, 3);
              expect(
                utf8.decode(message.data),
                endsWith(' xiaomi_remote@phone\u0000'),
              );
              send(
                'CNXN',
                0x01000000,
                262144,
                utf8.encode('device::ro.product.model=Test TV;\u0000'),
              );
            }
          } else if (cmd == adbCommand('OPEN')) {
            final id = message.arg0;
            final service = utf8.decode(message.data).replaceAll('\u0000', '');
            services[id] = service;
            send('OKAY', id + 100, id);
            if (service != 'sync:') {
              final output = service == 'shell:echo hi'
                  ? 'hi\n'
                  : service.startsWith('shell:pm install')
                  ? 'Success\n'
                  : '';
              if (output.isNotEmpty) {
                send('WRTE', id + 100, id, utf8.encode(output));
              }
              send('CLSE', id + 100, id);
            }
          } else if (cmd == adbCommand('WRTE')) {
            final id = message.arg0;
            send('OKAY', id + 100, id);
            final buffer = buffers.putIfAbsent(id, () => <int>[]);
            buffer.addAll(message.data);
            while (buffer.length >= 8) {
              final tag = ascii.decode(buffer.sublist(0, 4));
              final length = ByteData.sublistView(Uint8List.fromList(buffer))
                  .getUint32(4, Endian.little);
              final payloadLength = tag == 'DONE' ? 0 : length;
              if (buffer.length < 8 + payloadLength) break;
              if (tag == 'DATA') {
                received
                    .putIfAbsent(id, () => [])
                    .addAll(buffer.sublist(8, 8 + payloadLength));
              }
              buffer.removeRange(0, 8 + payloadLength);
              if (tag == 'DONE') {
                uploads.add(received[id] ?? []);
                send('WRTE', id + 100, id, [
                  ...ascii.encode('OKAY'),
                  0,
                  0,
                  0,
                  0,
                ]);
              }
            }
          }
        }
      });
    });
    final client = AdbClient(
      host: '127.0.0.1',
      port: server.port,
      key: AdbKey.generate(),
    );
    final states = <AdbConnectionState>[];
    final stateSubscription = client.states.listen(states.add);
    try {
      await client.connect();
      expect(client.deviceModel, 'Test TV');
      expect(states, contains(AdbConnectionState.waitingForApproval));
      expect(
        await Future.wait([client.shell('echo hi'), client.shell('echo hi')]),
        ['hi\n', 'hi\n'],
      );
      final payload = Uint8List.fromList(List.generate(70000, (i) => i & 255));
      var progress = 0;
      await client.push(
        payload,
        '/data/local/tmp/test',
        onProgress: (sent, total) {
          progress = sent;
        },
      );
      expect(progress, payload.length);
      await client.install(Uint8List.fromList([1, 2, 3]));
      expect(uploads[0], payload);
      expect(uploads[1], [1, 2, 3]);
      expect(
        services.values,
        contains('shell:rm -f /data/local/tmp/xr_install.apk'),
      );
    } finally {
      await client.disconnect();
      await stateSubscription.cancel();
      await daemon.cancel();
      await server.close();
    }
  });
}
