/**
 * @author Shakib
 * @since 30/10/26
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/adb/adb_client.dart';
import 'package:xiaomi_remote/core/adb/adb_key.dart';
import 'package:xiaomi_remote/core/adb/adb_message.dart';
import 'package:xiaomi_remote/core/adb/tv_files.dart';

Uint8List packet(String id, List<int> fields, [List<int> data = const []]) {
  final bytes = Uint8List(4 + fields.length * 4 + data.length);
  bytes.setRange(0, 4, ascii.encode(id));
  final view = ByteData.sublistView(bytes);
  for (var i = 0; i < fields.length; i++) {
    view.setUint32(4 + i * 4, fields[i], Endian.little);
  }
  bytes.setRange(4 + fields.length * 4, bytes.length, data);
  return bytes;
}

class FakeDaemon {
  FakeDaemon(this.server);
  final ServerSocket server;
  final files = <String, List<int>>{};
  final sentModes = <String, int>{};
  final commands = <String>[];
  final shellResponses = <String, String>{};
  final sockets = <Socket>[];
  late final StreamSubscription<Socket> subscription;

  void start() {
    subscription = server.listen((socket) {
      sockets.add(socket);
      final decoder = AdbMessageDecoder();
      final paths = <int, String>{};
      final buffers = <int, List<int>>{};
      void send(String command, int a, int b, [List<int> data = const []]) => socket.add(AdbMessage(adbCommand(command), a, b, data).encode());
      void reply(int id, List<int> data) {
        for (var i = 0; i < data.length; i += 7) {
          send('WRTE', 100, id, data.sublist(i, (i + 7).clamp(0, data.length)));
        }
      }
      socket.listen((bytes) {
        for (final message in decoder.add(bytes)) {
          final id = message.arg0;
          if (message.command == adbCommand('CNXN')) {
            send('CNXN', 0x01000000, 262144);
          } else if (message.command == adbCommand('OPEN')) {
            final service = utf8.decode(message.data).replaceAll('\u0000', '');
            send('OKAY', 100, id);
            if (service.startsWith('shell:')) {
              final command = service.substring(6);
              commands.add(command);
              final output = shellResponses[command];
              if (output != null) send('WRTE', 100, id, utf8.encode(output));
              send('CLSE', 100, id);
            }
          } else if (message.command == adbCommand('WRTE')) {
            send('OKAY', 100, id);
            final buffer = buffers.putIfAbsent(id, () => []);
            buffer.addAll(message.data);
            while (buffer.length >= 8) {
              final header = Uint8List.fromList(buffer.sublist(0, 8));
              final command = ascii.decode(header.sublist(0, 4));
              final length = ByteData.sublistView(header).getUint32(4, Endian.little);
              final payloadLength = command == 'DONE' ? 0 : length;
              if (buffer.length < 8 + payloadLength) break;
              final payload = buffer.sublist(8, 8 + payloadLength);
              buffer.removeRange(0, 8 + payloadLength);
              if (command == 'SEND') {
                final specification = utf8.decode(payload);
                final separator = specification.lastIndexOf(',');
                final path = specification.substring(0, separator);
                paths[id] = path;
                sentModes[path] = int.parse(specification.substring(separator + 1));
                files[path] = [];
              } else if (command == 'DATA') {
                files[paths[id]]!.addAll(payload);
              } else if (command == 'DONE') {
                reply(id, packet('OKAY', [0]));
              } else if (command == 'STAT') {
                final file = files[utf8.decode(payload)];
                reply(id, packet('STAT', [file == null ? 0 : 0x81a4, file?.length ?? 0, 123]));
              } else if (command == 'LIST') {
                final output = <int>[];
                for (final name in ['.', '..', 'image.png', '.hidden', 'folder', 'link']) {
                  final encoded = utf8.encode(name);
                  final mode = name == 'folder' ? 0x41ed : name == 'link' ? 0xa1ff : 0x81a4;
                  output.addAll(packet('DENT', [mode, 5, 123, encoded.length], encoded));
                }
                output.addAll(packet('DONE', [0, 0, 0, 0]));
                reply(id, output);
              } else if (command == 'RECV') {
                final file = files[utf8.decode(payload)];
                if (file == null) {
                  final error = utf8.encode('missing file');
                  reply(id, packet('FAIL', [error.length], error));
                } else {
                  final output = <int>[];
                  for (var i = 0; i < file.length; i += 137) {
                    final chunk = file.sublist(i, (i + 137).clamp(0, file.length));
                    output.addAll(packet('DATA', [chunk.length], chunk));
                  }
                  output.addAll(packet('DONE', [0]));
                  reply(id, output);
                }
              }
            }
          }
        }
      });
    });
  }

  Future<void> close() async {
    for (final socket in sockets) { socket.destroy(); }
    await subscription.cancel();
    await server.close();
  }
}

void main() {
  late FakeDaemon daemon;
  late AdbClient client;
  setUp(() async {
    daemon = FakeDaemon(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0))..start();
    client = AdbClient(host: '127.0.0.1', port: daemon.server.port, key: AdbKey.generate());
    await client.connect();
  });
  tearDown(() async { await client.disconnect(); await daemon.close(); });

  test('streamed push and split pull round trip', () async {
    final bytes = List<int>.generate(600000, (i) => i % 256);
    final progress = <int>[];
    await client.pushStream(Stream.value(bytes), bytes.length, '/file',
        mode: 0x180, onProgress: (sent, _) => progress.add(sent));
    expect(daemon.sentModes['/file'], 0x8180);
    expect(progress, [262112, 524224, 600000]);
    final output = <int>[];
    await for (final chunk in client.pull('/file')) { output.addAll(chunk); }
    expect(output, bytes);
  });

  test('list parses split entries and skips dot entries', () async {
    final entries = await client.list('/sdcard');
    expect(entries.map((e) => e.name), ['image.png', '.hidden', 'folder', 'link']);
    expect(entries[2].isDirectory, isTrue);
    expect(entries.last.isSymlink, isTrue);
    expect(entries.first.size, 5);
    final visible = await TvFiles(client).listFolder('/sdcard');
    expect(visible.map((e) => e.name), ['folder', 'image.png', 'link']);
  });

  test('pull reports failure and cancellation', () async {
    await expectLater(client.pull('/missing').drain<void>(), throwsA(isA<AdbException>().having((e) => e.message, 'message', 'missing file')));
    final token = CancelToken()..cancel();
    await expectLater(client.pull('/missing', cancel: token).drain<void>(), throwsA(isA<AdbTransferCancelled>()));
  });

  test('cancelling an active upload closes the transfer', () async {
    final token = CancelToken();
    final data = List<int>.filled(600000, 42);
    await expectLater(
      client.pushStream(Stream.value(data), data.length, '/cancelled',
          cancel: token, onProgress: (_, _) => token.cancel()),
      throwsA(isA<AdbTransferCancelled>()),
    );
    expect(daemon.files['/cancelled']!.length, 262112);
  });

  test('cancellation does not wait for a stalled input source', () async {
    final listening = Completer<void>();
    final sourceClosed = Completer<void>();
    final source = StreamController<List<int>>(
      onListen: () => listening.complete(),
      onCancel: () => sourceClosed.future,
    );
    final token = CancelToken();
    final upload = client.pushStream(source.stream, 1, '/stalled', cancel: token);
    final result = expectLater(upload, throwsA(isA<AdbTransferCancelled>()));
    await listening.future;
    token.cancel();
    try {
      await result.timeout(const Duration(seconds: 2));
    } finally {
      sourceClosed.complete();
    }
  });

  test('file actions select names, quote MIME and reject unsafe delete', () async {
    final files = TvFiles(client);
    daemon.files['${TvFiles.sendFolder}/photo.jpg'] = [1];
    final path = await files.sendFile('photo.jpg', Stream.value([2]), 1);
    expect(path, '${TvFiles.sendFolder}/photo (2).jpg');
    await files.openOnTv(path);
    expect(daemon.commands.last, contains('image/jpeg'));
    await expectLater(files.delete('/sdcard/../data/file'), throwsA(isA<AdbException>()));
    await expectLater(files.delete('/data/file'), throwsA(isA<AdbException>()));
  });

  test('storage, clipboard, URL and TV APK use shell safely', () async {
    daemon.shellResponses['df -k /sdcard'] = 'Filesystem 1K-blocks Used Available Use% Mounted on\n/data 100 60 40 60% /sdcard\n';
    final files = TvFiles(client, ensureHelper: () async {}, helperCommand: 'helper');
    expect(await files.storage(), (free: 40960, total: 102400));
    final encoded = base64Encode(utf8.encode('Hello, TV!'));
    daemon.shellResponses["helper clipboard-set '$encoded'"] = 'ok\n';
    await files.sendText('Hello, TV!');
    await files.openText('https://example.com/a?b=1');
    expect(daemon.commands.last, contains("'https://example.com/a?b=1'"));
    await expectLater(files.openText('plain text'), throwsA(isA<AdbException>()));
    daemon.shellResponses["pm install -r -g '/sdcard/app.apk'"] = 'Failure [bad package]';
    await expectLater(files.installTvApk('/sdcard/app.apk'), throwsA(isA<AdbException>().having((e) => e.message, 'message', 'Failure [bad package]')));
  });
}
