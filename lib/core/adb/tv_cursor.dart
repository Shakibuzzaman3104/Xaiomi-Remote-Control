/**
 * @author Shakib
 * @since 30/10/26
 */
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adb_client.dart';
import 'full_control.dart';

class CursorVersionException implements Exception {}

enum TvCursorStatus { unavailable, needsSetup, settingUp, connecting, ready }

class TvCursorState {
  const TvCursorState({this.status = TvCursorStatus.unavailable, this.error});
  final TvCursorStatus status;
  final String? error;
}

/// Talks to the pointer app on the TV through an ADB abstract socket.
class TvCursorLink {
  TvCursorLink(this._client);
  static const package = 'com.diatomicsoft.xiaomiremote.cursor';
  static const service = '$package/$package.CursorService';
  static const socketName = 'xr_cursor';
  static const version = 1;

  final AdbClient _client;
  AdbSocket? _socket;
  final _queue = <String>[];
  double _moveX = 0, _moveY = 0, _scroll = 0;
  bool _sending = false;
  bool _closed = false;
  bool _ready = false;
  Future<void>? _connecting;
  void Function(Object error)? onLost;
  bool get isReady => _ready && !_closed && _socket != null;

  static int? parseVersionCode(String dumpsysPackage) => int.tryParse(
    RegExp(r'versionCode=(\d+)').firstMatch(dumpsysPackage)?.group(1) ?? '',
  );

  static bool isServiceEnabled(String enabledServices) => enabledServices
      .split(':')
      .map((s) => s.trim())
      .any((s) => s == service || s == '$package/.CursorService');

  static String withService(String enabledServices) {
    final current = enabledServices.trim();
    if (current.isEmpty || current == 'null') return service;
    if (isServiceEnabled(current)) return current;
    return '$current:$service';
  }

  Future<int?> installedVersion() async => parseVersionCode(
    await _client.shell('dumpsys package $package | grep -m1 versionCode'),
  );

  Future<bool> serviceEnabled() async => isServiceEnabled(
    await _client.shell('settings get secure enabled_accessibility_services'),
  );

  Future<void> install(Uint8List apk, {bool force = false}) async {
    final installed = await installedVersion();
    _checkOpen();
    if (force || installed != version) await _client.install(apk);
    _checkOpen();
    final enabled = await serviceEnabled();
    _checkOpen();
    if (!enabled) {
      final current = await _client.shell(
        'settings get secure enabled_accessibility_services',
      );
      _checkOpen();
      await _client.shell(
        "settings put secure enabled_accessibility_services '${withService(current)}'",
      );
      _checkOpen();
    }
    await _client.shell('settings put secure accessibility_enabled 1');
    _checkOpen();
  }

  /// Opens the socket, retrying while the service starts.
  Future<void> connect({Duration timeout = const Duration(seconds: 8)}) {
    if (_closed) return Future.error(AdbException('TV cursor closed'));
    return _connecting ??= _connect(timeout)
        .whenComplete(() => _connecting = null);
  }

  void _checkOpen() {
    if (_closed) throw AdbException('TV cursor closed');
  }

  Future<void> _connect(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      try {
        await _handshake();
        _checkOpen();
        return;
      } catch (error) {
        if (error is CursorVersionException || _closed) rethrow;
        lastError = error;
        _socket?.close();
        _socket = null;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        _checkOpen();
      }
    }
    throw AdbException('TV cursor did not answer: $lastError');
  }

  Future<void> _handshake() async {
    final socket = await _client.openSocket('localabstract:$socketName');
    if (_closed) {
      socket.close();
      _checkOpen();
    }
    final reply = Completer<String>();
    reply.future.ignore();
    final buffer = StringBuffer();
    socket.input.listen(
      (bytes) {
        buffer.write(utf8.decode(bytes, allowMalformed: true));
        final text = buffer.toString();
        if (!reply.isCompleted && text.contains('\n')) {
          reply.complete(text.substring(0, text.indexOf('\n')));
        }
      },
      onError: (Object error) {
        if (!reply.isCompleted) reply.completeError(error);
        _lost(socket, error);
      },
      onDone: () {
        if (!reply.isCompleted) {
          reply.completeError(AdbException('TV cursor closed the socket'));
        }
        _lost(socket, AdbException('TV cursor closed the socket'));
      },
      cancelOnError: true,
    );
    _socket = socket;
    try {
      await socket.write(utf8.encode('v\n'));
      _checkOpen();
      final line = await reply.future.timeout(const Duration(seconds: 2));
      _checkOpen();
      final match = RegExp(r'^xr_cursor (\d+)$').firstMatch(line);
      if (match == null) {
        throw AdbException('Unexpected TV cursor reply: $line');
      }
      if (int.tryParse(match.group(1)!) != version) {
        throw CursorVersionException();
      }
      if (_socket != socket) throw AdbException('TV cursor closed the socket');
      _ready = true;
    } catch (_) {
      if (_socket == socket) _socket = null;
      socket.close();
      rethrow;
    }
  }

  void _lost(AdbSocket? socket, Object error) {
    if (socket == null || _socket != socket) return;
    _socket = null;
    socket.close();
    final wasReady = _ready;
    _ready = false;
    if (wasReady && !_closed) onLost?.call(error);
  }

  /// Moves by phone pixels, with acceleration for fast swipes.
  void move(Offset delta) {
    final gain = (2.4 + delta.distance * 0.18).clamp(2.4, 7.0);
    _moveX += delta.dx * gain;
    _moveY += delta.dy * gain;
    _pump();
  }

  /// Moves by TV pixels, without acceleration.
  void moveExact(Offset pixels) {
    _moveX += pixels.dx;
    _moveY += pixels.dy;
    _pump();
  }

  void scroll(double dy) {
    _scroll += dy * 3;
    _pump();
  }

  void tap() => _command('c');
  void longPress() => _command('l');
  void back() => _command('b');
  void hide() => _command('h');

  void _command(String line) {
    _flushMove();
    _queue.add(line);
    _pump();
  }

  void _flushMove() {
    final dx = _moveX.truncate(), dy = _moveY.truncate();
    if (dx == 0 && dy == 0) return;
    _moveX -= dx;
    _moveY -= dy;
    _queue.add('m $dx $dy');
  }

  String? _nextLine() {
    if (_queue.isNotEmpty) return _queue.removeAt(0);
    _flushMove();
    if (_queue.isNotEmpty) return _queue.removeAt(0);
    final scroll = _scroll.truncate();
    if (scroll.abs() >= 2) {
      _scroll -= scroll;
      return 's ${scroll.clamp(-1080, 1080)}';
    }
    return null;
  }

  Future<void> _pump() async {
    if (_sending || _socket == null) return;
    _sending = true;
    try {
      for (var line = _nextLine(); line != null; line = _nextLine()) {
        final socket = _socket;
        if (socket == null) break;
        await socket.write(utf8.encode('$line\n'));
      }
    } catch (error) {
      _lost(_socket, error);
    } finally {
      _sending = false;
    }
  }

  void close() {
    _closed = true;
    _ready = false;
    final socket = _socket;
    _socket = null;
    socket?.close();
  }
}

final tvCursorProvider = NotifierProvider<TvCursor, TvCursorState>(
  TvCursor.new,
);

class TvCursor extends Notifier<TvCursorState> {
  TvCursorLink? _link;
  int _generation = 0;
  Future<void>? _reconnecting;
  bool _needsUpdate = false;

  @override
  TvCursorState build() {
    final connected =
        ref.watch(fullControlProvider.select((s) => s.status)) ==
        FullControlStatus.connected;
    final generation = ++_generation;
    _reconnecting = null;
    ref.onDispose(() {
      ++_generation;
      _link?.close();
      _link = null;
    });
    if (!connected) return const TvCursorState();
    unawaited(_reconnectIfSetUp(generation));
    return const TvCursorState(status: TvCursorStatus.connecting);
  }

  TvCursorLink _newLink() {
    _link?.close();
    final link = TvCursorLink(
      ref.read(fullControlProvider.notifier).connectedClient,
    );
    link.onLost = (_) {
      if (_link == link) {
        state = const TvCursorState(status: TvCursorStatus.connecting);
        final pending = _reconnecting;
        if (pending == null) {
          unawaited(_reconnectIfSetUp(_generation));
        } else {
          unawaited(
            pending.whenComplete(() {
              if (_link == link && state.status == TvCursorStatus.connecting) {
                _reconnecting = null;
                unawaited(_reconnectIfSetUp(_generation));
              }
            }),
          );
        }
      }
    };
    return _link = link;
  }

  Future<void> _reconnectIfSetUp(int generation) {
    if (_reconnecting != null) return _reconnecting!;
    final future = _doReconnect(generation);
    _reconnecting = future;
    return future.whenComplete(() {
      if (identical(_reconnecting, future)) _reconnecting = null;
    });
  }

  Future<void> _doReconnect(int generation) async {
    try {
      final link = _newLink();
      final installed = await link.installedVersion();
      if (generation != _generation) {
        link.close();
        return;
      }
      final current =
          installed != null &&
          installed == TvCursorLink.version &&
          await link.serviceEnabled();
      if (generation != _generation) {
        link.close();
        return;
      }
      if (!current) {
        _needsUpdate = installed != null && installed != TvCursorLink.version;
        state = const TvCursorState(status: TvCursorStatus.needsSetup);
        return;
      }
      await link.connect();
      if (generation == _generation && link.isReady) {
        _needsUpdate = false;
        state = const TvCursorState(status: TvCursorStatus.ready);
      }
    } catch (error) {
      if (generation == _generation) {
        _needsUpdate = error is CursorVersionException;
        state = TvCursorState(
          status: TvCursorStatus.needsSetup,
          error: error is CursorVersionException
              ? 'The TV pointer needs an update. Set it up again.'
              : "Couldn't reach the TV pointer. Set it up again.",
        );
      }
    }
  }

  /// Installs and enables the pointer app on the TV, then connects.
  Future<void> setUp() async {
    final generation = ++_generation;
    _link?.close();
    state = const TvCursorState(status: TvCursorStatus.settingUp);
    try {
      final data = await rootBundle.load('assets/tv_cursor.apk');
      if (generation != _generation) return;
      final link = _newLink();
      await link.install(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        force: _needsUpdate,
      );
      if (generation != _generation) {
        link.close();
        return;
      }
      await link.connect();
      if (generation == _generation && link.isReady) {
        _needsUpdate = false;
        state = const TvCursorState(status: TvCursorStatus.ready);
      }
    } catch (error) {
      if (generation == _generation) {
        if (error is CursorVersionException) _needsUpdate = true;
        state = TvCursorState(
          status: TvCursorStatus.needsSetup,
          error: error is CursorVersionException
              ? 'The TV pointer needs an update. Set it up again.'
              : "Couldn't set up the TV pointer. Try again.",
        );
      }
    }
  }

  TvCursorLink? get _ready =>
      state.status == TvCursorStatus.ready ? _link : null;

  void move(Offset delta) => _ready?.move(delta);
  void moveExact(Offset pixels) => _ready?.moveExact(pixels);
  void scroll(double dy) => _ready?.scroll(dy);
  void tap() => _ready?.tap();
  void back() => _ready?.back();
  void longPress() => _ready?.longPress();
  void hide() => _ready?.hide();
}
