/**
 * @author Shakib
 * @since 30/10/26
 */
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BluetoothRemoteState {
  const BluetoothRemoteState({
    this.supported = false,
    this.permissionGranted = false,
    this.registered = false,
    this.hostName,
    this.hostAddress,
    this.connected = false,
    this.busy = false,
    this.error,
  });
  final bool supported, permissionGranted, registered, connected, busy;
  final String? hostName, hostAddress, error;

  BluetoothRemoteState copyWith({
    bool? supported, bool? permissionGranted, bool? registered,
    String? hostName, String? hostAddress, bool clearHost = false,
    bool? connected, bool? busy, String? error, bool clearError = false,
  }) => BluetoothRemoteState(
    supported: supported ?? this.supported,
    permissionGranted: permissionGranted ?? this.permissionGranted,
    registered: registered ?? this.registered,
    hostName: clearHost ? null : hostName ?? this.hostName,
    hostAddress: clearHost ? null : hostAddress ?? this.hostAddress,
    connected: connected ?? this.connected,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
  );
}

final bluetoothRemoteProvider =
    NotifierProvider<BluetoothRemote, BluetoothRemoteState>(BluetoothRemote.new);

class BluetoothRemote extends Notifier<BluetoothRemoteState> {
  static const _channel = MethodChannel('xr/bluetooth_remote');
  bool get _android => defaultTargetPlatform == TargetPlatform.android && !kIsWeb;

  @override
  BluetoothRemoteState build() {
    if (_android) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onState' && call.arguments is Map) {
          _applyState(Map<Object?, Object?>.from(call.arguments as Map));
        }
      });
      ref.onDispose(() { _channel.setMethodCallHandler(null); });
      Future.microtask(refresh);
    }
    return const BluetoothRemoteState();
  }

  void _applyState(Map<Object?, Object?> map) {
    state = state.copyWith(
      supported: map['supported'] == true,
      permissionGranted: map['permissionGranted'] == true,
      registered: map['registered'] == true,
      hostName: map['hostName'] as String?,
      hostAddress: map['hostAddress'] as String?,
      clearHost: map['hostAddress'] == null,
      connected: map['connected'] == true,
    );
  }

  String _message(String code) => switch (code) {
    'permission' => 'Allow Nearby devices so the phone can act as a Bluetooth remote.',
    'not_paired' => 'Pair the TV first.',
    'timeout' => "The TV didn't answer over Bluetooth. Make sure it's plugged in and nearby.",
    _ => 'Bluetooth remote is unavailable on this phone.',
  };

  Future<void> refresh() async {
    if (!_android) return;
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>('getState');
      if (map != null) _applyState(map);
    } on MissingPluginException {
      state = const BluetoothRemoteState();
    } on PlatformException catch (e) {
      state = state.copyWith(error: _message(e.code));
    }
  }

  Future<bool> _run(String method, [Map<String, Object?>? arguments]) async {
    if (!_android || state.busy) return false;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final result = await _channel.invokeMethod<bool>(method, arguments) ?? false;
      if (!result) {
        state = state.copyWith(error: _message(method == 'requestPermission' ? 'permission' : 'timeout'));
      }
      return result;
    } on MissingPluginException {
      state = state.copyWith(supported: false);
      return false;
    } on PlatformException catch (e) {
      state = state.copyWith(error: _message(e.code));
      return false;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<bool> requestPermission() async {
    final ok = await _run('requestPermission');
    await refresh();
    return ok;
  }

  Future<bool> startPairing() async {
    if (!state.permissionGranted && !await requestPermission()) return false;
    return _run('startPairing');
  }

  Future<bool> wake() async {
    if (!state.permissionGranted && !await requestPermission()) return false;
    return _run('wake');
  }
  Future<bool> sendKey(String name) => _run('sendKey', {'name': name});
  Future<bool> forget() => _run('forget');
}
