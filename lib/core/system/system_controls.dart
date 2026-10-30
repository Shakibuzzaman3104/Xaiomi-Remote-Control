/**
 * @author Shakib
 * @since 30/10/26
 */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/providers.dart';
import '../session/remote_button.dart';
import '../session/tv_session.dart';
import '../settings/app_preferences.dart';

final systemControlsProvider = Provider<SystemControls>((ref) {
  final controls = SystemControls(ref);
  ref.onDispose(controls.dispose);
  return controls;
});

class SystemControls {
  SystemControls(this._ref) {
    if (!_supported) return;
    _channel.setMethodCallHandler(_handleCall);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    _ref.listen(tvSessionStateProvider, (_, _) => _sync());
    _ref.listen(activeTvProvider, (previous, next) {
      if (previous?.id != next?.id) _suppressed = false;
      _sync();
    });
    _ref.listen(appPreferencesProvider, (_, _) => _sync());
    nowPlayingTitle.addListener(_sync);
    nowPlayingActive.addListener(_sync);
    _sync();
  }

  final Ref _ref;
  static const _channel = MethodChannel('xr/system_controls');
  final ValueNotifier<String?> nowPlayingTitle = ValueNotifier(null);
  final ValueNotifier<bool> nowPlayingActive = ValueNotifier(false);
  AppLifecycleListener? _lifecycle;
  bool _suppressed = false;
  bool _serviceStarted = false;
  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> requestPermission() async {
    if (_supported) await _invoke('requestPermission');
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // The platform channel is unavailable in widget tests.
    } on PlatformException {
      // The activity or foreground service may no longer be available.
    }
  }

  Future<void> _handleCall(MethodCall call) async {
    if (call.method == 'press') {
      final name = call.arguments;
      for (final button in RemoteButton.values) {
        if (button.name == name) {
          _ref.read(tvSessionProvider)?.press(button);
          break;
        }
      }
    } else if (call.method == 'stopped') {
      _suppressed = true;
      _serviceStarted = false;
    }
  }

  void _onLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _suppressed = false;
      _sync();
    }
  }

  void _sync() {
    if (!_supported) return;
    final status = _ref.read(tvSessionStateProvider).asData?.value.status;
    final connected = status == SessionStatus.connected;
    unawaited(_invoke('setConnected', connected));
    final enabled = _ref.read(appPreferencesProvider).controlsInNotification;
    final terminal = status == null || status == SessionStatus.offline ||
        status == SessionStatus.notPaired;
    if (!enabled || terminal || _suppressed) {
      if (_serviceStarted) {
        _serviceStarted = false;
        unawaited(_invoke('stopNotification'));
      }
    } else if (connected || _serviceStarted) {
      _serviceStarted = true;
      unawaited(_invoke('updateNotification', {
        'tvName': _ref.read(activeTvProvider)?.displayName ?? 'TV',
        'title': nowPlayingTitle.value,
        'playing': nowPlayingActive.value,
        'enabled': enabled,
      }));
    }
  }

  void dispose() {
    if (_supported) {
      _lifecycle?.dispose();
      _channel.setMethodCallHandler(null);
      if (_serviceStarted) unawaited(_invoke('stopNotification'));
      unawaited(_invoke('setConnected', false));
    }
    nowPlayingTitle.dispose();
    nowPlayingActive.dispose();
  }
}
