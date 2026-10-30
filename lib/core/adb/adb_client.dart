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

class AdbTransferCancelled implements Exception {}

class CancelToken {
  bool _isCancelled = false;
  final _listeners = <void Function()>{};
  bool get isCancelled => _isCancelled;
  void cancel() {
    if (isCancelled) return;
    _isCancelled = true;
    for (final listener in _listeners.toList()) {
      listener();
    }
    _listeners.clear();
  }

  Future<T> guard<T>(Future<T> future) {
    if (isCancelled) {
      future.ignore();
      return Future.error(AdbTransferCancelled());
    }
    final result = Completer<T>();
    void cancelled() {
      if (!result.isCompleted) result.completeError(AdbTransferCancelled());
    }

    _listeners.add(cancelled);
    future.then(
      (value) {
        _listeners.remove(cancelled);
        if (!result.isCompleted) result.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        _listeners.remove(cancelled);
        if (!result.isCompleted) result.completeError(error, stack);
      },
    );
    return result.future;
  }
}

class AdbFileEntry {
  const AdbFileEntry({
    required this.name,
    required this.mode,
    required this.size,
    required this.modified,
  });
  final String name;
  final int mode, size;
  final DateTime modified;
  bool get isDirectory => (mode & 0xf000) == 0x4000;
  bool get isSymlink => (mode & 0xf000) == 0xa000;
}

class _SyncReader {
  _SyncReader(Stream<List<int>> source) : iterator = StreamIterator(source);
  final StreamIterator<List<int>> iterator;
  final buffer = <int>[];
  Future<Uint8List> read(int length) async {
    while (buffer.length < length) {
      if (!await iterator.moveNext()) throw AdbException('Sync stream closed');
      buffer.addAll(iterator.current);
    }
    final result = Uint8List.fromList(buffer.sublist(0, length));
    buffer.removeRange(0, length);
    return result;
  }

  Future<void> close() => iterator.cancel();
}

class _AdbStream {
  _AdbStream(this.id);
  final int id;
  int? remoteId;
  final opened = Completer<void>();
  Completer<void>? ack;
  Future<void> writes = Future.value();
  final data = StreamController<List<int>>();
  void Function()? cancelTransfer;
}

/// A two-way stream to a device service, such as `localabstract:<name>`.
class AdbSocket {
  AdbSocket._(this._client, this._stream);
  final AdbClient _client;
  final _AdbStream _stream;

  Stream<List<int>> get input => _stream.data.stream;

  Future<void> write(List<int> bytes) => _client._write(_stream, bytes);

  void close() => _client._close(_stream);
}

class AdbClient {
  AdbClient({
    required this.host,
    this.port = 5555,
    required this.key,
    this.socketConnector,
  });
  final String host;
  final int port;
  final AdbKey key;
  final Future<Socket> Function(String host, int port, Duration timeout)?
  socketConnector;
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
  bool _offerPublicKey = true;
  int _generation = 0;

  void _state(AdbConnectionState state) => _states.add(state);
  void _send(String command, int a, int b, [List<int> data = const []]) {
    final socket = _socket;
    if (socket == null) throw AdbException('Socket is closed');
    socket.add(AdbMessage(adbCommand(command), a, b, data).encode());
  }

  Future<void> connect({
    Duration authTimeout = const Duration(seconds: 60),
    bool offerPublicKey = true,
  }) async {
    if (_socket != null || _handshake != null) {
      throw AdbException('Already connecting or connected');
    }
    _offerPublicKey = offerPublicKey;
    _closing = false;
    _authCount = 0;
    deviceModel = null;
    _state(AdbConnectionState.connecting);
    _handshake = Completer<void>();
    final handshake = _handshake!;
    final generation = ++_generation;
    handshake.future.ignore();
    Socket? socket;
    try {
      socket =
          await (socketConnector?.call(host, port, authTimeout) ??
              Socket.connect(host, port, timeout: authTimeout));
      if (generation != _generation) throw AdbException('Disconnected');
      _socket = socket;
      try {
        socket.setOption(SocketOption.tcpNoDelay, true);
      } catch (_) {}
      final decoder = AdbMessageDecoder();
      _socket!.listen(
        (bytes) {
          if (generation != _generation) return;
          try {
            for (final message in decoder.add(bytes)) {
              _receive(message);
            }
          } catch (e) {
            _fail(AdbException('Invalid ADB response: $e'));
          }
        },
        onError: (Object e) {
          if (generation == _generation) {
            _fail(AdbException('Socket error: $e'));
          }
        },
        onDone: () {
          if (generation == _generation) _fail(AdbException('Socket closed'));
        },
      );
      _send('CNXN', 0x01000000, 256 * 1024, utf8.encode('host::\u0000'));
      await handshake.future.timeout(authTimeout);
      if (generation != _generation) throw AdbException('Disconnected');
    } on TimeoutException {
      if (generation == _generation) {
        _fail(AdbException('Connection timed out'));
      }
      throw AdbException('Connection timed out');
    } catch (e) {
      final error = e is AdbException
          ? e
          : AdbException('Connection failed: $e');
      if (generation == _generation) _fail(error);
      throw error;
    } finally {
      if (generation != _generation || !_connected) socket?.destroy();
      if (identical(_handshake, handshake)) _handshake = null;
    }
  }

  void _receive(AdbMessage m) {
    if (m.command == adbCommand('AUTH')) {
      if (m.arg0 != 1 || m.data.length != 20) {
        throw AdbException('Invalid authentication token');
      }
      if (_authCount++ == 0) {
        _send('AUTH', 2, 0, key.signToken(m.data));
      } else if (_authCount == 2 && !_offerPublicKey) {
        _fail(AdbException('Key not trusted yet'));
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
      if (stream.remoteId != null && stream.remoteId != m.arg0) {
        throw AdbException('Invalid stream ID');
      }
      if (!stream.opened.isCompleted) {
        stream.opened.completeError(AdbException('Stream closed before OKAY'));
      }
      if (stream.ack != null && !stream.ack!.isCompleted) {
        stream.ack!.completeError(AdbException('Stream closed during write'));
      }
      if (stream.remoteId != null) _send('CLSE', stream.id, m.arg0);
      _streams.remove(stream.id);
      stream.cancelTransfer?.call();
      stream.cancelTransfer = null;
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
    _handshake = null;
    for (final stream in _streams.values) {
      stream.cancelTransfer?.call();
      stream.cancelTransfer = null;
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

  Future<_AdbStream> _open(String service, {CancelToken? cancel}) async {
    if (!_connected) throw AdbException('Not connected');
    if (cancel?.isCancelled ?? false) throw AdbTransferCancelled();
    final stream = _AdbStream(_nextId++);
    _streams[stream.id] = stream;
    if (cancel != null) {
      void close() => _close(stream);
      cancel._listeners.add(close);
      stream.cancelTransfer = () => cancel._listeners.remove(close);
    }
    _send('OPEN', stream.id, 0, utf8.encode('$service\u0000'));
    try {
      await _guard(
        stream.opened.future,
        cancel,
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      _close(stream);
      throw AdbException('Stream open timed out');
    } catch (_) {
      _close(stream);
      if (cancel?.isCancelled ?? false) throw AdbTransferCancelled();
      rethrow;
    }
    return stream;
  }

  void _close(_AdbStream stream) {
    stream.cancelTransfer?.call();
    stream.cancelTransfer = null;
    if (_streams.remove(stream.id) == null) return;
    final error = AdbException('Stream closed');
    if (!stream.opened.isCompleted) stream.opened.completeError(error);
    if (stream.ack != null && !stream.ack!.isCompleted) {
      stream.ack!.completeError(error);
    }
    if (_socket != null) _send('CLSE', stream.id, stream.remoteId ?? 0);
    stream.data.close();
  }

  Future<void> _write(_AdbStream stream, List<int> bytes) {
    final result = stream.writes.then((_) => _writeNow(stream, bytes));
    stream.writes = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _writeNow(_AdbStream stream, List<int> bytes) async {
    if (!_streams.containsKey(stream.id)) throw AdbException('Stream closed');
    for (var offset = 0; offset < bytes.length; offset += _maxData) {
      if (!_streams.containsKey(stream.id)) throw AdbException('Stream closed');
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
        _close(stream);
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

  Future<AdbSocket> openSocket(String service) async =>
      AdbSocket._(this, await _open(service));

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

  void _checkPath(String path) {
    if (path.contains('\u0000')) throw AdbException('Invalid remote path');
  }

  Future<T> _guard<T>(Future<T> future, CancelToken? cancel) =>
      cancel == null ? future : cancel.guard(future);

  Future<_AdbStream> _openTransfer(CancelToken? cancel) =>
      _open('sync:', cancel: cancel);

  Future<void> push(
    Uint8List bytes,
    String remotePath, {
    void Function(int sent, int total)? onProgress,
  }) => pushStream(
    Stream.value(bytes),
    bytes.length,
    remotePath,
    onProgress: onProgress,
  );

  Future<void> pushStream(
    Stream<List<int>> data,
    int length,
    String remotePath, {
    int mode = 0x1a4,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancel,
  }) async {
    _checkPath(remotePath);
    if (length < 0) throw AdbException('Invalid transfer length');
    if (cancel?.isCancelled ?? false) throw AdbTransferCancelled();
    final stream = await _openTransfer(cancel);
    final reader = _SyncReader(stream.data.stream);
    final input = StreamIterator(data);
    try {
      final path = utf8.encode('$remotePath,${0x8000 | mode}');
      await _guard(
        _write(stream, _syncPacket('SEND', path.length, path)),
        cancel,
      );
      var sent = 0, queued = 0;
      final pending = BytesBuilder(copy: false);
      // Fills each ADB packet with several sync chunks so a round trip carries up to maxData.
      Future<void> flush() async {
        if (pending.isEmpty) return;
        await _guard(_write(stream, pending.takeBytes()), cancel);
        sent = queued;
        onProgress?.call(sent, length);
      }

      while (await _guard(input.moveNext(), cancel)) {
        final bytes = input.current;
        for (var offset = 0; offset < bytes.length; offset += 65528) {
          final end = (offset + 65528).clamp(0, bytes.length);
          if (queued + end - offset > length) {
            throw AdbException('Transfer length mismatch');
          }
          if (pending.length + 8 + end - offset > _maxData) await flush();
          pending.add(
            _syncPacket('DATA', end - offset, bytes.sublist(offset, end)),
          );
          queued += end - offset;
        }
      }
      if (queued != length) throw AdbException('Transfer length mismatch');
      pending.add(
        _syncPacket('DONE', DateTime.now().millisecondsSinceEpoch ~/ 1000),
      );
      await flush();
      final header = await _guard(
        reader.read(8).timeout(const Duration(seconds: 15)),
        cancel,
      );
      final id = ascii.decode(header.sublist(0, 4), allowInvalid: true);
      final size = ByteData.sublistView(header).getUint32(4, Endian.little);
      if (id == 'FAIL') {
        throw AdbException(
          utf8.decode(
            await _guard(reader.read(size), cancel),
            allowMalformed: true,
          ),
        );
      }
      if (id != 'OKAY') throw AdbException('Invalid sync response');
      if (cancel?.isCancelled ?? false) throw AdbTransferCancelled();
    } on TimeoutException {
      throw AdbException('Sync timed out');
    } catch (_) {
      if (cancel?.isCancelled ?? false) throw AdbTransferCancelled();
      rethrow;
    } finally {
      _close(stream);
      await reader.close();
      if (cancel?.isCancelled ?? false) {
        input.cancel().ignore();
      } else {
        await input.cancel();
      }
    }
  }

  Future<({int mode, int size, DateTime modified})?> stat(String path) =>
      _stat(path, null);

  Future<({int mode, int size, DateTime modified})?> _stat(
    String path,
    CancelToken? cancel,
  ) async {
    _checkPath(path);
    final stream = await _openTransfer(cancel);
    final reader = _SyncReader(stream.data.stream);
    try {
      final name = utf8.encode(path);
      await _guard(
        _write(stream, _syncPacket('STAT', name.length, name)),
        cancel,
      );
      final first = await _guard(reader.read(8), cancel);
      final id = ascii.decode(first.sublist(0, 4), allowInvalid: true);
      if (id == 'FAIL') {
        final length = ByteData.sublistView(first).getUint32(4, Endian.little);
        throw AdbException(
          utf8.decode(
            await _guard(reader.read(length), cancel),
            allowMalformed: true,
          ),
        );
      }
      if (id != 'STAT') throw AdbException('Invalid sync response');
      final header = Uint8List.fromList([
        ...first,
        ...await _guard(reader.read(8), cancel),
      ]);
      final fields = ByteData.sublistView(header);
      final mode = fields.getUint32(4, Endian.little);
      if (mode == 0) return null;
      return (
        mode: mode,
        size: fields.getUint32(8, Endian.little),
        modified: DateTime.fromMillisecondsSinceEpoch(
          fields.getUint32(12, Endian.little) * 1000,
        ),
      );
    } catch (_) {
      if (cancel?.isCancelled ?? false) throw AdbTransferCancelled();
      rethrow;
    } finally {
      _close(stream);
      await reader.close();
    }
  }

  Future<List<AdbFileEntry>> list(String path) async {
    _checkPath(path);
    final stream = await _open('sync:');
    final reader = _SyncReader(stream.data.stream);
    try {
      final name = utf8.encode(path);
      await _write(stream, _syncPacket('LIST', name.length, name));
      final entries = <AdbFileEntry>[];
      while (true) {
        final first = await reader.read(8);
        final id = ascii.decode(first.sublist(0, 4), allowInvalid: true);
        if (id == 'FAIL') {
          final length = ByteData.sublistView(first)
              .getUint32(4, Endian.little);
          throw AdbException(
            utf8.decode(await reader.read(length), allowMalformed: true),
          );
        }
        if (id != 'DONE' && id != 'DENT') {
          throw AdbException('Invalid sync response');
        }
        final header = Uint8List.fromList([...first, ...await reader.read(12)]);
        if (id == 'DONE') return entries;
        final fields = ByteData.sublistView(header);
        final entryName = utf8.decode(
          await reader.read(fields.getUint32(16, Endian.little)),
          allowMalformed: true,
        );
        if (entryName == '.' || entryName == '..') continue;
        entries.add(
          AdbFileEntry(
            name: entryName,
            mode: fields.getUint32(4, Endian.little),
            size: fields.getUint32(8, Endian.little),
            modified: DateTime.fromMillisecondsSinceEpoch(
              fields.getUint32(12, Endian.little) * 1000,
            ),
          ),
        );
      }
    } finally {
      _close(stream);
      await reader.close();
    }
  }

  Stream<List<int>> pull(
    String remotePath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancel,
  }) async* {
    _checkPath(remotePath);
    if (cancel?.isCancelled ?? false) throw AdbTransferCancelled();
    final info = await _stat(remotePath, cancel);
    final stream = await _openTransfer(cancel);
    final reader = _SyncReader(stream.data.stream);
    try {
      final path = utf8.encode(remotePath);
      await _guard(
        _write(stream, _syncPacket('RECV', path.length, path)),
        cancel,
      );
      var received = 0;
      while (true) {
        final header = await _guard(reader.read(8), cancel);
        final id = ascii.decode(header.sublist(0, 4), allowInvalid: true);
        final length = ByteData.sublistView(header).getUint32(4, Endian.little);
        if (id == 'DONE') return;
        if (id == 'FAIL') {
          throw AdbException(
            utf8.decode(
              await _guard(reader.read(length), cancel),
              allowMalformed: true,
            ),
          );
        }
        if (id != 'DATA' || length > 65536) {
          throw AdbException('Invalid sync response');
        }
        final bytes = await _guard(reader.read(length), cancel);
        received += bytes.length;
        onProgress?.call(received, info?.size ?? 0);
        if (cancel?.isCancelled ?? false) throw AdbTransferCancelled();
        yield bytes;
      }
    } catch (_) {
      if (cancel?.isCancelled ?? false) throw AdbTransferCancelled();
      rethrow;
    } finally {
      _close(stream);
      await reader.close();
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
    ++_generation;
    _closing = true;
    _connected = false;
    final error = AdbException('Disconnected');
    if (_handshake != null && !_handshake!.isCompleted) {
      _handshake!.completeError(error);
    }
    _handshake = null;
    for (final stream in _streams.values) {
      stream.cancelTransfer?.call();
      stream.cancelTransfer = null;
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
