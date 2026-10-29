/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../remote/atv_certificate.dart';
import '../remote/atv_remote.dart';
import '../storage/paired_tv_store.dart';
import 'key_mapping.dart';
import 'remote_button.dart';

enum SessionStatus { connecting, connected, reconnecting, offline }

@immutable
class TvSessionState {
  const TvSessionState({
    required this.status,
    this.atv = const AtvState(),
    this.attempt = 0,
    this.lastError,
  });
  final SessionStatus status;
  final AtvState atv;
  final int attempt;
  final String? lastError;
}

class TvSession {
  TvSession({
    required this.tv,
    AtvRemoteClient Function(PairedTv tv)? clientFactory,
    Duration Function(int attempt)? backoff,
  }) : _factory = clientFactory ?? _defaultClient,
       _backoff = backoff ?? _defaultBackoff;

  final PairedTv tv;
  final AtvRemoteClient Function(PairedTv) _factory;
  final Duration Function(int) _backoff;
  final _states = StreamController<TvSessionState>.broadcast();
  TvSessionState _state = const TvSessionState(
    status: SessionStatus.connecting,
  );
  AtvRemoteClient? _client;
  StreamSubscription<AtvState>? _subscription;
  Timer? _timer;
  bool _disposed = false;
  bool _started = false;
  int _generation = 0;

  static AtvRemoteClient _defaultClient(PairedTv tv) => AtvRemoteClient(
    host: tv.host,
    certificate: AtvCertificate(
      certPem: tv.certPem,
      privateKeyPem: tv.privateKeyPem,
    ),
  );
  static Duration _defaultBackoff(int attempt) =>
      Duration(seconds: attempt >= 5 ? 15 : 1 << (attempt - 1));

  Stream<TvSessionState> get states => _states.stream;
  TvSessionState get state => _state;
  bool get isConnected =>
      !_disposed && _state.status == SessionStatus.connected;

  void _emit(
    SessionStatus status, {
    AtvState? atv,
    int? attempt,
    String? error,
  }) {
    if (_disposed) return;
    _state = TvSessionState(
      status: status,
      atv: atv ?? _state.atv,
      attempt: attempt ?? _state.attempt,
      lastError: error,
    );
    _states.add(_state);
  }

  Future<void> start() async {
    if (_disposed || _started) return;
    _started = true;
    await _connect();
  }

  Future<void> _connect() async {
    if (_disposed) return;
    final generation = ++_generation;
    _emit(
      _state.status == SessionStatus.connecting
          ? SessionStatus.connecting
          : SessionStatus.reconnecting,
      error: _state.lastError,
    );
    try {
      final client = _factory(tv);
      _client = client;
      _subscription = client.states.listen(
        (atv) {
          if (_disposed || generation != _generation) return;
          _emit(_state.status, atv: atv, error: _state.lastError);
        },
        onError: (Object error, StackTrace stack) {
          _failure(generation, error);
        },
        onDone: () {
          _failure(
            generation,
            const AtvConnectionLostException('Connection closed'),
          );
        },
      );
      await client.connect();
      if (_disposed || generation != _generation) return;
      _emit(SessionStatus.connected, atv: client.state, attempt: 0);
    } catch (error) {
      _failure(generation, error);
    }
  }

  void _failure(int generation, Object error) {
    if (_disposed || generation != _generation) return;
    ++_generation;
    final client = _client;
    _client = null;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    if (client != null) unawaited(client.disconnect());
    final attempt = _state.attempt + 1;
    _emit(
      attempt >= 6 ? SessionStatus.offline : SessionStatus.reconnecting,
      atv: _state.atv.copyWith(connected: false),
      attempt: attempt,
      error: '$error',
    );
    if (attempt < 6) {
      _timer = Timer(_backoff(attempt), () {
        unawaited(_connect());
      });
    }
  }

  void retryNow() {
    if (_disposed || isConnected || !_started) return;
    _timer?.cancel();
    ++_generation;
    final client = _client;
    _client = null;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    if (client != null) unawaited(client.disconnect());
    _emit(SessionStatus.reconnecting, attempt: 0);
    unawaited(_connect());
  }

  void _command(void Function(AtvRemoteClient) action) {
    final client = _client;
    if (!isConnected || client == null) return;
    try {
      action(client);
    } on AtvConnectionLostException catch (error) {
      _failure(_generation, error);
    }
  }

  void press(RemoteButton button) =>
      _command((c) => c.sendKey(keyCodeFor(button)));
  void pressDown(RemoteButton button) => _command(
    (c) => c.sendKey(keyCodeFor(button), direction: RemoteDirection.START_LONG),
  );
  void pressUp(RemoteButton button) => _command(
    (c) => c.sendKey(keyCodeFor(button), direction: RemoteDirection.END_LONG),
  );
  void sendText(String text) => _command(
    (c) => unawaited(
      c.replaceText(text).catchError((Object error) {
        if (error is AtvConnectionLostException) _failure(_generation, error);
      }),
    ),
  );

  /// Submits the TV field once pending edits land.
  /// A newline triggers the IME action; KEYCODE_ENTER would press the focused TV key.
  void submitText() => _command(
    (c) => unawaited(
      c.textSettled.then((_) => c.insertText('\n')).catchError((Object error) {
        if (error is AtvConnectionLostException) {
          _failure(_generation, error);
        }
      }),
    ),
  );

  void insertText(String text) => _command((c) => c.insertText(text));
  void launchLink(String url) => _command((c) => c.launchApp(url));
  Future<int> startVoice() async {
    final client = _client;
    if (!isConnected || client == null) return -1;
    try {
      return await client.startVoice();
    } on AtvConnectionLostException catch (error) {
      _failure(_generation, error);
      return -1;
    }
  }

  void sendVoiceChunk(int id, Uint8List data) =>
      _command((c) => c.sendVoiceChunk(id, data));
  void endVoice(int id) => _command((c) => c.endVoice(id));

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _timer?.cancel();
    await _subscription?.cancel();
    await _client?.disconnect();
    await _states.close();
  }
}
