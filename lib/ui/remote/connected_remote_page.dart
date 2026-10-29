/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adb/full_control.dart';
import '../../core/session/providers.dart';
import '../../core/settings/app_preferences.dart';
import '../../core/session/tv_session.dart';
import '../apps/apps_page.dart';
import 'remote_models.dart';
import 'remote_screen.dart';

/// The Remote screen driven by the active TV session.
class ConnectedRemotePage extends ConsumerStatefulWidget {
  const ConnectedRemotePage({
    super.key,
    required this.onSwitchDevice,
    required this.onAppSettings,
    required this.onKeyboard,
    required this.onVoice,
    this.onPairAgain,
  });
  final VoidCallback onSwitchDevice, onAppSettings, onKeyboard, onVoice;
  final VoidCallback? onPairAgain;

  @override
  ConsumerState<ConnectedRemotePage> createState() =>
      _ConnectedRemotePageState();
}

class _ConnectedRemotePageState extends ConsumerState<ConnectedRemotePage>
    with WidgetsBindingObserver {
  Timer? _volumeTimer;
  VolumeControl? _exactVolume;
  int _volumeGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _readVolume();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _volumeTimer?.cancel();
    _volumeGeneration++;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(tvSessionProvider)?.retryNow();
      _readVolume();
    }
  }

  Future<void> _readVolume() async {
    if (ref.read(fullControlProvider).status != FullControlStatus.connected) {
      return;
    }
    final generation = ++_volumeGeneration;
    try {
      final volume = await ref.read(fullControlProvider.notifier).readVolume();
      if (!mounted || generation != _volumeGeneration) return;
      setState(
        () => _exactVolume = volume.fixed || volume.max <= 0
            ? null
            : VolumeControl(index: volume.index, max: volume.max),
      );
    } catch (_) {
      if (mounted && generation == _volumeGeneration) {
        setState(() => _exactVolume = null);
      }
    }
  }

  Future<void> _setVolume(int index) async {
    _volumeTimer?.cancel();
    final generation = ++_volumeGeneration;
    try {
      await ref.read(fullControlProvider.notifier).setVolume(index);
      if (mounted && generation == _volumeGeneration) await _readVolume();
    } catch (_) {
      if (mounted && generation == _volumeGeneration) {
        setState(() => _exactVolume = null);
      }
    }
  }

  void _showApps() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppsPage(
          onAppSettings: widget.onAppSettings,
          onSwitchDevice: widget.onSwitchDevice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(fullControlProvider, (previous, next) {
      if (previous?.status == next.status) return;
      if (next.status == FullControlStatus.connected) {
        _readVolume();
      } else {
        _volumeTimer?.cancel();
        _volumeGeneration++;
        if (_exactVolume != null) setState(() => _exactVolume = null);
      }
    });
    final tv = ref.watch(activeTvProvider);
    final session = ref.watch(tvSessionProvider);
    final sessionState =
        ref.watch(tvSessionStateProvider).asData?.value ??
        const TvSessionState(status: SessionStatus.connecting);
    final atv = sessionState.atv;
    final status = sessionState.status;

    return RemoteScreen(
      swipeSensitivity: ref.watch(appPreferencesProvider).swipeSensitivity,
      state: RemoteViewState(
        deviceName: tv?.name ?? 'No TV',
        connected: status == SessionStatus.connected,
        reconnecting:
            status == SessionStatus.connecting ||
            status == SessionStatus.reconnecting,
        volumeLevel: atv.volumeMax > 0
            ? (atv.volumeLevel * 100 / atv.volumeMax).round()
            : null,
        muted: atv.muted,
        needsPairing: status == SessionStatus.notPaired,
        exactVolume: _exactVolume,
      ),
      onButton: (button) {
        session?.press(button);
        if (button == RemoteButton.volumeUp ||
            button == RemoteButton.volumeDown ||
            button == RemoteButton.mute) {
          _volumeGeneration++;
          _volumeTimer?.cancel();
          _volumeTimer = Timer(const Duration(milliseconds: 400), _readVolume);
        }
      },
      onExactVolumeChanged: _setVolume,
      onSwitchDevice: widget.onSwitchDevice,
      onOpenNowPlaying: () {},
      onApps: _showApps,
      onKeyboard: widget.onKeyboard,
      onVoice: widget.onVoice,
      onRetry: () => session?.retryNow(),
      onPairAgain: widget.onPairAgain,
      onAppSettings: widget.onAppSettings,
      onPointerMove: (_) {},
      onScroll: (_) {},
      onClick: (_) {},
      onAirMouseChanged: (_) {},
      mouseAvailable: false,
    );
  }
}
