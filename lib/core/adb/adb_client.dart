/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'adb_key.dart';
import 'adb_message.dart';

enum AdbConnectionState {
  disconnected,
  connecting,
  waitingForApproval,
  connected,
  failed,
}

class AdbException implements Exception {
  AdbException(this.message);
  final String message;
  @override
  String toString() => 'AdbException: $message';
}

class _AdbStream {
  _AdbStream(this.id);
  final int id;
  int? remoteId;
  final opened = Completer<void>();
  Completer<void>? ack;
  final data = StreamController<List<int>>();
}

class AdbClient {
  AdbClient({required this.host, this.port = 5555, required this.key});
  final String host;
  final int port;
  final AdbKey key;
  final _states = StreamController<AdbConnectionState>.broadcast();
  Stream<AdbConnectionState> get states => _states.stream;
  String? deviceModel;
  Socket? _socket;
  final _streams = <int, _AdbStream>{};
  Completer<void>? _handshake;
  int _nextId = 1;
  int _authCount = 0;
  int _maxData = 256 * 1024;
  bool _connected = false;
  bool _closing = false;

  void _state(AdbConnectionState state) => _states.add(state);
  void _send(String command, int a, int b, [List<int> data = const []]) {
    final socket = _socket;
    if (socket == null) throw AdbException('Socket is closed');
    socket.add(AdbMessage(adbCommand(command), a, b, data).encode());
  }

  Future<void> connect({
    Duration authTimeout = const Duration(seconds: 60),
  }) async {
    if (_socket != null || _handshake != null) {
      throw AdbException('Already connecting or connected');
    }
    _closing = false;
    _authCount = 0;
    deviceModel = null;
    _state(AdbConnectionState.connecting);
    _handshake = Completer<void>();
    _handshake!.future.ignore();
    try {
      _socket = await Socket.connect(host, port, timeout: authTimeout);
      final decoder = AdbMessageDecoder();
      _socket!.listen(
        (bytes) {
          try {
            for (final message in decoder.add(bytes)) {
              _receive(message);
            }
          } catch (e) {
            _fail(AdbException('Invalid ADB response: $e'));
          }
        },
        onError: (Object e) => _fail(AdbException('Socket error: $e')),
        onDone: () => _fail(AdbException('Socket closed')),
      );
      _send('CNXN', 0x01000000, 256 * 1024, utf8.encode('host::\u0000'));
      await _handshake!.future.timeout(authTimeout);
    } on TimeoutException {
      _fail(AdbException('Connection timed out'));
      throw AdbException('Connection timed out');
    } catch (e) {
      final error = e is AdbException
          ? e
          : AdbException('Connection failed: $e');
      _fail(error);
      throw error;
    } finally {
      _handshake = null;
    }
  }

  void _receive(AdbMessage m) {
    if (m.command == adbCommand('AUTH')) {
      if (m.arg0 != 1 || m.data.length != 20) {
        throw AdbException('Invalid authentication token');
      }
      if (_authCount++ == 0) {
        _send('AUTH', 2, 0, key.signToken(m.data));
      } else if (_authCount == 2) {
        _state(AdbConnectionState.waitingForApproval);
        _send('AUTH', 3, 0, utf8.encode(key.androidPublicKey()));
      } else {
        throw AdbException('Authentication rejected');
      }
      return;
    }
    if (m.command == adbCommand('CNXN')) {
      _maxData = m.arg1.clamp(1, 256 * 1024);
      final banner = utf8.decode(m.data, allowMalformed: true);
      deviceModel = RegExp(r'(?:^|[;:])ro\.product\.model=([^;\x00]*)')
          .firstMatch(banner)
          ?.group(1);
      _connected = true;
      _state(AdbConnectionState.connected);
      if (_handshake != null && !_handshake!.isCompleted) {
        _handshake!.complete();
      }
      return;
    }
    final stream = _streams[m.arg1];
    if (stream == null) return;
    if (m.command == adbCommand('OKAY')) {
      if (stream.remoteId != null && stream.remoteId != m.arg0) {
        throw AdbException('Invalid stream ID');
      }
      stream.remoteId = m.arg0;
      if (!stream.opened.isCompleted) {
        stream.opened.complete();
      } else if (stream.ack != null && !stream.ack!.isCompleted) {
        stream.ack!.complete();
      }
    } else if (m.command == adbCommand('WRTE')) {
      if (stream.remoteId != m.arg0) throw AdbException('Invalid stream ID');
      stream.data.add(m.data);
      _send('OKAY', stream.id, m.arg0);
    } else if (m.command == adbCommand('CLSE')) {
      if (!stream.opened.isCompleted) {
        stream.opened.completeError(AdbException('Stream closed before OKAY'));
      }
      if (stream.ack != null && !stream.ack!.isCompleted) {
        stream.ack!.completeError(AdbException('Stream closed during write'));
      }
      if (stream.remoteId != null) _send('CLSE', stream.id, m.arg0);
      _streams.remove(stream.id);
      stream.data.close();
    }
  }

  void _fail(AdbException error) {
    if (_closing) return;
    _closing = true;
    _connected = false;
    _socket?.destroy();
    _socket = null;
    if (_handshake != null && !_handshake!.isCompleted) {
      _handshake!.completeError(error);
    }
    for (final stream in _streams.values) {
      if (!stream.opened.isCompleted) {
        stream.opened.completeError(error);
      }
      if (stream.ack != null && !stream.ack!.isCompleted) {
        stream.ack!.completeError(error);
      }
      stream.data.addError(error);
      stream.data.close();
    }
    _streams.clear();
    _state(AdbConnectionState.failed);
  }

  Future<_AdbStream> _open(String service) async {
    if (!_connected) throw AdbException('Not connected');
    final stream = _AdbStream(_nextId++);
    _streams[stream.id] = stream;
    _send('OPEN', stream.id, 0, utf8.encode('$service\u0000'));
    try {
      await stream.opened.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      _close(stream);
      throw AdbException('Stream open timed out');
    }
    return stream;
  }

  void _close(_AdbStream stream) {
    if (_streams.remove(stream.id) == null) return;
    if (_socket != null) _send('CLSE', stream.id, stream.remoteId ?? 0);
    stream.data.close();
  }

  Future<void> _write(_AdbStream stream, List<int> bytes) async {
    for (var offset = 0; offset < bytes.length; offset += _maxData) {
      stream.ack = Completer<void>();
      _send(
        'WRTE',
        stream.id,
        stream.remoteId!,
        bytes.sublist(offset, (offset + _maxData).clamp(0, bytes.length)),
      );
      try {
        await stream.ack!.future.timeout(const Duration(seconds: 15));
      } on TimeoutException {
        throw AdbException('Stream write timed out');
      } finally {
        stream.ack = null;
      }
    }
  }

  Stream<List<int>> _readService(String service) async* {
    final stream = await _open(service);
    try {
      yield* stream.data.stream;
    } finally {
      _close(stream);
    }
  }

  Stream<List<int>> shellStream(String command) =>
      _readService('shell:$command');
  Future<Uint8List> _collect(
    Stream<List<int>> source,
    Duration timeout,
    String operation,
  ) async {
    final bytes = BytesBuilder(copy: false);
    final done = Completer<void>();
    final subscription = source.listen(
      bytes.add,
      onError: (Object error, StackTrace stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
    );
    try {
      await done.future.timeout(timeout);
      return bytes.takeBytes();
    } on TimeoutException {
      throw AdbException('$operation timed out');
    } finally {
      await subscription.cancel();
    }
  }

  Future<String> shell(
    String command, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return utf8.decode(
      await _collect(shellStream(command), timeout, 'Shell'),
      allowMalformed: true,
    );
  }

  Future<Uint8List> exec(String command) async {
    return _collect(
      _readService('exec:$command'),
      const Duration(seconds: 15),
      'Exec',
    );
  }

  Uint8List _syncPacket(String id, int value, [List<int> payload = const []]) {
    final result = Uint8List(8 + payload.length);
    result.setRange(0, 4, ascii.encode(id));
    ByteData.sublistView(result).setUint32(4, value, Endian.little);
    result.setRange(8, result.length, payload);
    return result;
  }

  Future<void> push(
    Uint8List bytes,
    String remotePath, {
    void Function(int sent, int total)? onProgress,
  }) async {
    if (remotePath.contains('\u0000')) {
      throw AdbException('Invalid remote path');
    }
    final stream = await _open('sync:');
    final response = <int>[];
    final completed = Completer<void>();
    completed.future.ignore();
    final subscription = stream.data.stream.listen(
      (data) {
        response.addAll(data);
        if (response.length >= 8) {
          final length = ByteData.sublistView(Uint8List.fromList(response))
              .getUint32(4, Endian.little);
          final id = ascii.decode(
            response.take(4).toList(),
            allowInvalid: true,
          );
          if ((id == 'OKAY' ||
                  (id == 'FAIL' && response.length >= 8 + length)) &&
              !completed.isCompleted) {
            if (id == 'FAIL') {
              completed.completeError(
                AdbException(
                  utf8.decode(
                    response.sublist(8, 8 + length),
                    allowMalformed: true,
                  ),
                ),
              );
            } else {
              completed.complete();
            }
          }
        }
      },
      onError: (Object e) {
        if (!completed.isCompleted) completed.completeError(e);
      },
      onDone: () {
        if (!completed.isCompleted) {
          completed.completeError(AdbException('Sync stream closed'));
        }
      },
    );
    try {
      final path = utf8.encode('$remotePath,33188');
      await _write(stream, _syncPacket('SEND', path.length, path));
      for (var offset = 0; offset < bytes.length; offset += 65536) {
        final end = (offset + 65536).clamp(0, bytes.length);
        await _write(
          stream,
          _syncPacket('DATA', end - offset, bytes.sublist(offset, end)),
        );
        onProgress?.call(end, bytes.length);
      }
      await _write(
        stream,
        _syncPacket('DONE', DateTime.now().millisecondsSinceEpoch ~/ 1000),
      );
      try {
        await completed.future.timeout(const Duration(seconds: 15));
      } on TimeoutException {
        throw AdbException('Sync timed out');
      }
    } finally {
      await subscription.cancel();
      _close(stream);
    }
  }

  Future<void> install(
    Uint8List apk, {
    void Function(int sent, int total)? onProgress,
  }) async {
    const path = '/data/local/tmp/xr_install.apk';
    await push(apk, path, onProgress: onProgress);
    try {
      final output = await shell('pm install -r $path');
      if (!output.contains('Success')) throw AdbException(output.trim());
    } finally {
      await shell('rm -f $path');
    }
  }

  Future<void> disconnect() async {
    _closing = true;
    _connected = false;
    final error = AdbException('Disconnected');
    if (_handshake != null && !_handshake!.isCompleted) {
      _handshake!.completeError(error);
    }
    for (final stream in _streams.values) {
      if (!stream.opened.isCompleted) stream.opened.completeError(error);
      if (stream.ack != null && !stream.ack!.isCompleted) {
        stream.ack!.completeError(error);
      }
      stream.data.addError(error);
      stream.data.close();
    }
    _streams.clear();
    _socket?.destroy();
    _socket = null;
    _state(AdbConnectionState.disconnected);
  }
}
