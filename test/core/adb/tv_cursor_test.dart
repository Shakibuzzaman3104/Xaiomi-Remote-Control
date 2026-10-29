/**
 * @author Shakib
 * @since 30/10/26
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/adb/adb_client.dart';
import 'package:xiaomi_remote/core/adb/adb_key.dart';
import 'package:xiaomi_remote/core/adb/adb_message.dart';
import 'package:xiaomi_remote/core/adb/tv_cursor.dart';

void main() {
  const service = TvCursorLink.service;

  test('rejects an incompatible handshake and closes its socket', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final closed = Completer<void>();
    Socket? peer;
    final daemon = server.listen((socket) {
      peer = socket;
      final decoder = AdbMessageDecoder();
      void send(String command, int a, int b, [List<int> data = const []]) =>
          socket.add(AdbMessage(adbCommand(command), a, b, data).encode());
      socket.listen((data) {
        for (final message in decoder.add(data)) {
          if (message.command == adbCommand('CNXN')) {
            send('CNXN', 0x01000000, 262144);
          } else if (message.command == adbCommand('OPEN')) {
            send('OKAY', 100, message.arg0);
          } else if (message.command == adbCommand('WRTE')) {
            send('OKAY', 100, message.arg0);
            send('WRTE', 100, message.arg0, utf8.encode('xr_cursor 99\n'));
          } else if (message.command == adbCommand('CLSE')) {
            if (!closed.isCompleted) closed.complete();
          }
        }
      });
    });
    final client = AdbClient(host: '127.0.0.1', port: server.port, key: AdbKey.generate());
    try {
      await client.connect();
      final link = TvCursorLink(client);
      var lost = false;
      link.onLost = (_) => lost = true;
      await expectLater(link.connect(), throwsA(isA<CursorVersionException>()));
      await closed.future.timeout(const Duration(seconds: 2));
      expect(lost, isFalse);
      link.close();
    } finally {
      await client.disconnect();
      peer?.destroy();
      await daemon.cancel();
      await server.close();
    }
  });

  test('closing a link cancels its pending handshake', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final opened = Completer<void>();
    final closed = Completer<void>();
    Socket? peer;
    final daemon = server.listen((socket) {
      peer = socket;
      final decoder = AdbMessageDecoder();
      void send(String command, int a, int b) =>
          socket.add(AdbMessage(adbCommand(command), a, b).encode());
      socket.listen((data) {
        for (final message in decoder.add(data)) {
          if (message.command == adbCommand('CNXN')) {
            send('CNXN', 0x01000000, 262144);
          } else if (message.command == adbCommand('OPEN')) {
            send('OKAY', 100, message.arg0);
          } else if (message.command == adbCommand('WRTE')) {
            if (!opened.isCompleted) opened.complete();
          } else if (message.command == adbCommand('CLSE')) {
            if (!closed.isCompleted) closed.complete();
          }
        }
      });
    });
    final client = AdbClient(host: '127.0.0.1', port: server.port, key: AdbKey.generate());
    try {
      await client.connect();
      final link = TvCursorLink(client);
      final connecting = link.connect();
      final expectation = expectLater(connecting, throwsA(isA<AdbException>()));
      await opened.future;
      link.close();
      await closed.future.timeout(const Duration(seconds: 2));
      await expectation;
    } finally {
      await client.disconnect();
      peer?.destroy();
      await daemon.cancel();
      await server.close();
    }
  });

  test('reads the installed version code', () {
    expect(
      TvCursorLink.parseVersionCode(
        '    versionCode=3 minSdk=24 targetSdk=28',
      ),
      3,
    );
    expect(TvCursorLink.parseVersionCode(''), isNull);
  });

  test('adds the service without dropping other services', () {
    expect(TvCursorLink.withService('null'), service);
    expect(TvCursorLink.withService(''), service);
    expect(
      TvCursorLink.withService('com.other/.Talk'),
      'com.other/.Talk:$service',
    );
    expect(
      TvCursorLink.withService('com.other/.Talk:$service'),
      'com.other/.Talk:$service',
    );
    expect(TvCursorLink.isServiceEnabled('com.other/.Talk'), isFalse);
    expect(
      TvCursorLink.isServiceEnabled(
        'com.diatomicsoft.xiaomiremote.cursor/.CursorService',
      ),
      isTrue,
    );
  });
}
