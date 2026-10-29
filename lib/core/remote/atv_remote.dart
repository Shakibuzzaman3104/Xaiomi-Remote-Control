/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:protobuf/protobuf.dart';

import 'atv_certificate.dart';
import 'atv_framing.dart';
import 'atv_pairing.dart';
import 'proto/remotemessage.pb.dart';
export 'proto/remotemessage.pbenum.dart' show RemoteKeyCode, RemoteDirection;

/// A snapshot of the remote connection and television state.
@immutable
class AtvState {
  const AtvState({
    this.connected = false,
    this.isOn = false,
    this.currentApp,
    this.volumeLevel = 0,
    this.volumeMax = 0,
    this.muted = false,
    this.supportedFeatures = 0,
    this.imeActive = false,
    this.imeLabel,
    this.imeValue,
    this.deviceModel,
    this.deviceManufacturer,
    this.swVersion,
  });
  final bool connected, isOn, muted, imeActive;
  final String? currentApp,
      imeLabel,
      imeValue,
      deviceModel,
      deviceManufacturer,
      swVersion;
  final int volumeLevel, volumeMax, supportedFeatures;

  AtvState copyWith({
    bool? connected,
    bool? isOn,
    String? currentApp,
    int? volumeLevel,
    int? volumeMax,
    bool? muted,
    int? supportedFeatures,
    bool? imeActive,
    String? imeLabel,
    String? imeValue,
    String? deviceModel,
    String? deviceManufacturer,
    String? swVersion,
  }) => AtvState(
    connected: connected ?? this.connected,
    isOn: isOn ?? this.isOn,
    currentApp: currentApp ?? this.currentApp,
    volumeLevel: volumeLevel ?? this.volumeLevel,
    volumeMax: volumeMax ?? this.volumeMax,
    muted: muted ?? this.muted,
    supportedFeatures: supportedFeatures ?? this.supportedFeatures,
    imeActive: imeActive ?? this.imeActive,
    imeLabel: imeLabel ?? this.imeLabel,
    imeValue: imeValue ?? this.imeValue,
    deviceModel: deviceModel ?? this.deviceModel,
    deviceManufacturer: deviceManufacturer ?? this.deviceManufacturer,
    swVersion: swVersion ?? this.swVersion,
  );
}

/// Reports an unexpected loss of the remote connection.
class AtvConnectionLostException implements Exception {
  const AtvConnectionLostException(this.message);
  final String message;
  @override
  String toString() => 'AtvConnectionLostException: $message';
}

/// The TV closed the connection without a word: it no longer knows this phone.
class AtvNotPairedException extends AtvConnectionLostException {
  const AtvNotPairedException() : super('The TV does not recognise this phone');
}

/// A TLS client for the Android TV Remote Service v2 protocol.
class AtvIdentityChangedException extends AtvConnectionLostException {
  const AtvIdentityChangedException()
    : super("This TV's identity changed. Pair it again.");
}

@visibleForTesting
String verifyTvCertificate(List<int> der, String? expectedFingerprint) {
  final fingerprint = sha256.convert(der).toString();
  if (expectedFingerprint != null && fingerprint != expectedFingerprint) {
    throw const AtvIdentityChangedException();
  }
  return fingerprint;
}

class AtvRemoteClient {
  AtvRemoteClient({
    required this.host,
    required this.certificate,
    this.port = 6466,
    this.silenceTimeout = const Duration(seconds: 16),
    this.tvCertSha256,
    @visibleForTesting this.sendSink,
  });
  final String host;
  final AtvCertificate certificate;
  final int port;
  final Duration silenceTimeout;
  final String? tvCertSha256;
  String? peerCertSha256;
  final void Function(RemoteMessage)? sendSink;
  // VOICE (8) stalls the handshake on the Mi Box S: no set_active, keys ignored.
  static const int features = 1 | 2 | 4 | 32 | 64 | 512;
  final _states = StreamController<AtvState>.broadcast();
  AtvState _state = const AtvState();
  AtvState get state => _state;
  Stream<AtvState> get states => _states.stream;
  SecureSocket? _socket;
  FrameDecoder _decoder = FrameDecoder();
  int _imeCounter = 0, _fieldCounter = 0;
  int? _voiceSession;
  Completer<int>? _voiceBegin;
  final _ready = Completer<void>();
  Timer? _watchdog;
  Future<void> _textQueue = Future.value();
  String? _latestText;
  Completer<void>? _fieldUpdate;
  String? _awaitedValue;
  DateTime _lastReceived = DateTime.now();
  bool _closed = false;
  bool _heardFromTv = false;

  void _update(AtvState value) {
    _state = value;
    if (!_states.isClosed) _states.add(value);
  }

  Future<void> connect() async {
    if (_closed || _socket != null) {
      throw StateError('Client is closed or already connected');
    }
    try {
      final SecureSocket socket;
      var mismatch = false;
      try {
        socket = await SecureSocket.connect(
          host,
          port,
          context: atvSecurityContext(certificate),
          onBadCertificate: (cert) {
            try {
              verifyTvCertificate(cert.der, tvCertSha256);
              return true;
            } on AtvIdentityChangedException {
              mismatch = true;
              return false;
            }
          },
        );
      } on TlsException catch (_) {
        if (mismatch) throw const AtvIdentityChangedException();
        rethrow;
      } on SocketException catch (e) {
        if (mismatch) throw const AtvIdentityChangedException();
        if (_isReset(e)) throw const AtvNotPairedException();
        rethrow;
      }
      final peer = socket.peerCertificate;
      if (peer == null) {
        socket.destroy();
        throw const AtvConnectionLostException('Server certificate is missing');
      }
      try {
        peerCertSha256 = verifyTvCertificate(peer.der, tvCertSha256);
      } on AtvIdentityChangedException {
        socket.destroy();
        rethrow;
      }
      if (_closed) {
        socket.destroy();
        throw StateError('Client is closed');
      }
      _socket = socket;
      _decoder = FrameDecoder();
      _update(_state.copyWith(connected: true));
      socket.listen(
        (data) {
          _heardFromTv = true;
          _lastReceived = DateTime.now();
          try {
            for (final bytes in _decoder.add(data)) {
              RemoteMessage message;
              try {
                message = RemoteMessage.fromBuffer(bytes);
              } on InvalidProtocolBufferException {
                continue;
              }
              handleMessage(message);
            }
          } catch (e) {
            _lost(e);
          }
        },
        onError: (Object error) => _lost(
          !_heardFromTv && error is SocketException && _isReset(error)
              ? const AtvNotPairedException()
              : error,
        ),
        onDone: () => _lost(
          _heardFromTv ? 'Connection closed' : const AtvNotPairedException(),
        ),
      );
      _watchdog = Timer.periodic(const Duration(seconds: 4), (_) {
        if (DateTime.now().difference(_lastReceived) > silenceTimeout) {
          _lost('No ping from the TV for ${silenceTimeout.inSeconds} s');
        }
      });
      await _ready.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw const AtvConnectionLostException(
          'TV did not activate the remote session',
        ),
      );
    } catch (e) {
      if (!_closed) _lost(e);
      rethrow;
    }
  }

  static bool _isReset(SocketException e) =>
      const {54, 104}.contains(e.osError?.errorCode) ||
      e.message.toLowerCase().contains('reset');

  Future<void> disconnect() async {
    if (_closed) return;
    _closed = true;
    _watchdog?.cancel();
    _socket?.destroy();
    _socket = null;
    final pending = _voiceBegin;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(
        const AtvConnectionLostException('Connection closed'),
      );
    }
    _abortFieldWait(const AtvConnectionLostException('Connection closed'));
    _update(_state.copyWith(connected: false, imeActive: false));
    await _states.close();
  }

  void _lost(Object error) {
    if (_closed) return;
    _closed = true;
    _watchdog?.cancel();
    _socket?.destroy();
    _socket = null;
    final exception = error is AtvConnectionLostException
        ? error
        : AtvConnectionLostException('$error');
    final pending = _voiceBegin;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(exception);
    }
    _abortFieldWait(exception);
    _update(_state.copyWith(connected: false, imeActive: false));
    _states.addError(exception);
    _states.close();
  }

  void _send(RemoteMessage message) {
    if (sendSink != null) {
      sendSink!(message);
      return;
    }
    final socket = _socket;
    if (_closed || socket == null) {
      throw const AtvConnectionLostException('Connection closed');
    }
    socket.add(frame(Uint8List.fromList(message.writeToBuffer())));
  }

  @visibleForTesting
  void handleMessage(RemoteMessage message) {
    if (message.hasRemoteConfigure()) {
      final cfg = message.remoteConfigure;
      final active = features & cfg.code1;
      _update(
        _state.copyWith(
          supportedFeatures: active,
          deviceModel: cfg.deviceInfo.model,
          deviceManufacturer: cfg.deviceInfo.vendor,
          swVersion: cfg.deviceInfo.appVersion,
        ),
      );
      _send(
        RemoteMessage(
          remoteConfigure: RemoteConfigure(
            code1: active,
            deviceInfo: RemoteDeviceInfo(
              unknown1: 1,
              unknown2: '1',
              packageName: 'xiaomi_remote',
              appVersion: '1.0.0',
            ),
          ),
        ),
      );
    } else if (message.hasRemoteSetActive()) {
      if (!_ready.isCompleted) _ready.complete();
      _send(
        RemoteMessage(
          remoteSetActive: RemoteSetActive(active: _state.supportedFeatures),
        ),
      );
    } else if (message.hasRemotePingRequest()) {
      _send(
        RemoteMessage(
          remotePingResponse: RemotePingResponse(
            val1: message.remotePingRequest.val1,
          ),
        ),
      );
    } else if (message.hasRemoteImeKeyInject()) {
      final ime = message.remoteImeKeyInject;
      _imeCounter = ime.appInfo.counter;
      if (ime.hasTextFieldStatus()) {
        _fieldCounter = ime.textFieldStatus.counterField;
        _update(
          _state.copyWith(
            currentApp: ime.appInfo.appPackage,
            imeActive: true,
            imeLabel: ime.appInfo.label,
            imeValue: ime.textFieldStatus.value,
          ),
        );
      } else {
        _update(
          _state.copyWith(
            currentApp: ime.appInfo.appPackage,
            imeActive: false,
            imeLabel: ime.appInfo.label,
          ),
        );
      }
      _completeFieldUpdate();
    } else if (message.hasRemoteImeShowRequest()) {
      final field = message.remoteImeShowRequest.remoteTextFieldStatus;
      _fieldCounter = field.counterField;
      _update(_state.copyWith(imeActive: true, imeValue: field.value));
      _completeFieldUpdate();
    } else if (message.hasRemoteSetVolumeLevel()) {
      final volume = message.remoteSetVolumeLevel;
      _update(
        _state.copyWith(
          volumeLevel: volume.volumeLevel,
          volumeMax: volume.volumeMax,
          muted: volume.volumeMuted,
        ),
      );
    } else if (message.hasRemoteStart()) {
      _update(_state.copyWith(isOn: message.remoteStart.started));
    } else if (message.hasRemoteVoiceBegin()) {
      final pending = _voiceBegin;
      if (pending != null && !pending.isCompleted) {
        pending.complete(message.remoteVoiceBegin.sessionId);
      }
    }
  }

  void _abortFieldWait(AtvConnectionLostException exception) {
    final update = _fieldUpdate;
    if (update != null && !update.isCompleted) update.completeError(exception);
  }

  void _completeFieldUpdate() {
    final update = _fieldUpdate;
    if (update == null || update.isCompleted) return;
    final awaited = _awaitedValue;
    if (awaited == null || _state.imeValue == awaited) update.complete();
  }

  void sendKey(
    RemoteKeyCode code, {
    RemoteDirection direction = RemoteDirection.SHORT,
  }) => _send(
    RemoteMessage(
      remoteKeyInject: RemoteKeyInject(keyCode: code, direction: direction),
    ),
  );

  /// Makes the focused TV field read [text], sending only the difference.
  Future<void> replaceText(String text) {
    _latestText = text;
    return _textQueue = _textQueue.then((_) => _applyText(text));
  }

  /// Completes once every queued text edit has reached the TV.
  Future<void> get textSettled => _textQueue;

  Future<void> _applyText(String text) async {
    if (text != _latestText || (_closed && sendSink == null)) return;
    final current = (_state.imeValue ?? '').runes.toList();
    final target = text.runes.toList();
    var common = 0;
    while (common < current.length &&
        common < target.length &&
        current[common] == target[common]) {
      common++;
    }
    final deletes = current.length - common;
    final suffix = String.fromCharCodes(target.skip(common));
    if (deletes > 0) {
      for (var i = 0; i < deletes; i++) {
        sendKey(RemoteKeyCode.KEYCODE_DEL);
      }
      await _awaitFieldValue(String.fromCharCodes(target.take(common)));
    }
    if (suffix.isNotEmpty) {
      insertText(suffix);
      await _awaitFieldValue(text);
    }
  }

  Future<void> _awaitFieldValue(String value) async {
    if (sendSink != null) {
      _update(_state.copyWith(imeValue: value));
      return;
    }
    final update = _fieldUpdate = Completer<void>();
    _awaitedValue = value;
    await update.future.timeout(
      const Duration(milliseconds: 1500),
      onTimeout: () => _update(_state.copyWith(imeValue: value)),
    );
    _awaitedValue = null;
  }

  /// Inserts [text] at the TV field's cursor.
  void insertText(String text) {
    if (text.isEmpty) throw ArgumentError('Text cannot be empty');
    final position = text.length - 1;
    _send(
      RemoteMessage(
        remoteImeBatchEdit: RemoteImeBatchEdit(
          imeCounter: _imeCounter,
          fieldCounter: _fieldCounter,
          editInfo: [
            RemoteEditInfo(
              insert: 1,
              textFieldStatus: RemoteImeObject(
                start: position,
                end: position,
                value: text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void launchApp(String appLink) => _send(
    RemoteMessage(
      remoteAppLinkLaunchRequest: RemoteAppLinkLaunchRequest(appLink: appLink),
    ),
  );

  Future<int> startVoice() async {
    if (_voiceBegin != null || _voiceSession != null) {
      throw StateError('Voice session already in progress');
    }
    final pending = Completer<int>();
    _voiceBegin = pending;
    try {
      sendKey(RemoteKeyCode.KEYCODE_SEARCH);
      final session = await pending.future.timeout(const Duration(seconds: 2));
      _send(
        RemoteMessage(remoteVoiceBegin: RemoteVoiceBegin(sessionId: session)),
      );
      _voiceSession = session;
      return session;
    } finally {
      _voiceBegin = null;
    }
  }

  void sendVoiceChunk(int sessionId, Uint8List pcm16Mono8k) {
    for (var offset = 0; offset < pcm16Mono8k.length; offset += 20 * 1024) {
      final end = (offset + 20 * 1024).clamp(0, pcm16Mono8k.length);
      final length = end - offset;
      final samples = Uint8List(length < 8 * 1024 ? 8 * 1024 : length);
      samples.setRange(0, length, pcm16Mono8k, offset);
      _send(
        RemoteMessage(
          remoteVoicePayload: RemoteVoicePayload(
            sessionId: sessionId,
            samples: samples,
          ),
        ),
      );
    }
  }

  void endVoice(int sessionId) {
    _send(RemoteMessage(remoteVoiceEnd: RemoteVoiceEnd(sessionId: sessionId)));
    if (_voiceSession == sessionId) _voiceSession = null;
  }
}
