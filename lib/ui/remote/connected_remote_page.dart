/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/adb/adb_commands.dart';
import '../../core/adb/full_control.dart';
import '../../core/adb/tv_cursor.dart';
import '../../core/session/providers.dart';
import '../../core/settings/app_preferences.dart';
import '../../core/session/tv_session.dart';
import '../apps/apps_page.dart';
import '../onboarding/unlock_page.dart';
import '../motion.dart';
import '../theme/app_theme.dart';
import 'remote_models.dart';
import 'remote_screen.dart';
import 'widgets/now_playing_line.dart';

/// The Remote screen driven by the active TV session.
class ConnectedRemotePage extends ConsumerStatefulWidget {
  const ConnectedRemotePage({
    super.key,
    required this.onSwitchDevice,
    required this.onAppSettings,
    required this.onKeyboard,
    required this.onVoice,
    this.onPairAgain,
    this.hardwareVolume,
  });
  final VoidCallback onSwitchDevice, onAppSettings, onKeyboard, onVoice;
  final VoidCallback? onPairAgain;
  final ValueNotifier<RemoteButton?>? hardwareVolume;

  @override
  ConsumerState<ConnectedRemotePage> createState() =>
      _ConnectedRemotePageState();
}

class _ConnectedRemotePageState extends ConsumerState<ConnectedRemotePage>
    with WidgetsBindingObserver {
  static const _nowPlayingInterval = Duration(seconds: 2);
  static const _airPixelsPerRadian = 2600.0;
  static const _airDeadZone = 0.03;

  Timer? _volumeTimer, _nowPlayingTimer, _nowPlayingRefresh;
  VolumeControl? _exactVolume;
  int _volumeGeneration = 0;
  bool? _adbMuted;
  bool _assumedMuted = false;
  AdbNowPlaying? _nowPlaying;
  int _nowPlayingGeneration = 0;
  int? _readingGeneration;
  Object? _activeTv;
  bool _routeVisible = true;
  bool _airWanted = false;
  StreamSubscription<GyroscopeEvent>? _gyro;
  DateTime? _lastGyro;

  bool get _fullControl =>
      ref.read(fullControlProvider).status == FullControlStatus.connected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.hardwareVolume?.addListener(_hardwareVolumeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _readVolume();
      _startNowPlaying();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.hardwareVolume?.removeListener(_hardwareVolumeChanged);
    _volumeTimer?.cancel();
    _stopNowPlaying();
    _stopAirMouse();
    _volumeGeneration++;
    super.dispose();
  }

  void _hardwareVolumeChanged() {
    final button = widget.hardwareVolume?.value;
    if (button == null) return;
    setState(() {
      if (button == RemoteButton.mute) {
        _assumedMuted = !_assumedMuted;
      } else {
        _assumedMuted = false;
        _adbMuted = false;
      }
    });
    _volumeTimer?.cancel();
    _volumeGeneration++;
    _volumeTimer = Timer(const Duration(milliseconds: 400), _readVolume);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(tvSessionProvider)?.retryNow();
      ref.read(fullControlProvider.notifier).reconnectIfEnabled();
      _readVolume();
      _startNowPlaying();
      if (_airWanted) _startAirMouse();
    } else if (state == AppLifecycleState.paused) {
      _stopNowPlaying();
      _stopAirMouse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRouteVisibility();
  }

  void _syncRouteVisibility() {
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    if (_routeVisible == visible) return;
    _routeVisible = visible;
    if (visible) {
      _startNowPlaying();
      if (_airWanted) _startAirMouse();
    } else {
      _stopNowPlaying();
      _stopAirMouse();
    }
  }

  void _setAirMouse(bool enabled) {
    _airWanted = enabled;
    enabled ? _startAirMouse() : _stopAirMouse();
  }

  void _startAirMouse() {
    if (_gyro != null || !_routeVisible) return;
    _lastGyro = null;
    _gyro = gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval)
        .listen(_moveWithGyro, onError: (_) => _stopAirMouse());
  }

  void _stopAirMouse() {
    _gyro?.cancel();
    _gyro = null;
  }

  void _moveWithGyro(GyroscopeEvent event) {
    _syncRouteVisibility();
    if (!_routeVisible) return;
    final last = _lastGyro;
    _lastGyro = event.timestamp;
    if (last == null) return;
    final seconds = (event.timestamp.difference(last).inMicroseconds / 1e6)
        .clamp(0.0, 0.05);
    double rate(double value) => value.abs() < _airDeadZone ? 0 : value;
    final yaw = rate(event.z), pitch = rate(event.x);
    if (yaw == 0 && pitch == 0) return;
    ref
        .read(tvCursorProvider.notifier)
        .moveExact(Offset(-yaw, -pitch) * seconds * _airPixelsPerRadian);
  }

  void _startNowPlaying() {
    if (!_fullControl || !_routeVisible || _nowPlayingTimer != null) return;
    _readNowPlaying();
    _nowPlayingTimer = Timer.periodic(_nowPlayingInterval, (_) {
      _syncRouteVisibility();
      if (_routeVisible) _readNowPlaying();
    });
  }

  void _stopNowPlaying() {
    _nowPlayingTimer?.cancel();
    _nowPlayingRefresh?.cancel();
    _nowPlayingTimer = null;
  }

  void _refreshNowPlayingSoon() {
    if (!_fullControl) return;
    _nowPlayingRefresh?.cancel();
    _nowPlayingRefresh = Timer(
      const Duration(milliseconds: 600),
      _readNowPlaying,
    );
  }

  Future<void> _readNowPlaying() async {
    final generation = _nowPlayingGeneration;
    if (_readingGeneration == generation || !_fullControl || !_routeVisible) {
      return;
    }
    _readingGeneration = generation;
    try {
      final now = await ref.read(fullControlProvider.notifier).readNowPlaying();
      if (mounted && generation == _nowPlayingGeneration && _fullControl) {
        setState(() => _nowPlaying = now);
      }
    } catch (_) {
      if (mounted &&
          generation == _nowPlayingGeneration &&
          _nowPlaying != null) {
        setState(() => _nowPlaying = null);
      }
    } finally {
      if (_readingGeneration == generation) _readingGeneration = null;
    }
  }

  NowPlaying? _buildNowPlaying(List<TvApp> apps) {
    final now = _nowPlaying;
    if (now == null) return null;
    final app = apps.where((a) => a.package == now.package).firstOrNull;
    final appName = app?.label ?? now.package;
    final icon = app?.iconPng;
    return NowPlaying(
      title: now.title.isNotEmpty ? now.title : appName,
      subtitle: now.title.isEmpty
          ? null
          : [
              if (now.subtitle.isNotEmpty) now.subtitle,
              if (app != null) app.label,
            ].join(' · '),
      position: Duration(milliseconds: now.positionMs.clamp(0, 1 << 40)),
      duration: now.durationMs == null
          ? null
          : Duration(milliseconds: now.durationMs!),
      playing: now.state == AdbPlaybackState.playing,
      appIcon: icon == null
          ? null
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                icon,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
    );
  }

  void _openFullControl() =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const UnlockPage()));

  MouseSetupPrompt _mouseSetupPrompt(TvCursorState cursor) {
    final setUp = ref.read(tvCursorProvider.notifier).setUp;
    return switch (cursor.status) {
      TvCursorStatus.unavailable => MouseSetupPrompt(
        title: 'Mouse needs Full control',
        message: 'Turn on Full control to use a pointer on the TV.',
        actionLabel: 'Set up Full control',
        onAction: _openFullControl,
      ),
      TvCursorStatus.needsSetup => MouseSetupPrompt(
        title: 'Add a pointer to your TV',
        message: cursor.error ?? 'This installs a small pointer app on the TV and turns it on as an accessibility service.',
        actionLabel: cursor.error == null ? 'Set up pointer' : 'Try again',
        onAction: setUp,
        isError: cursor.error != null,
      ),
      TvCursorStatus.settingUp => const MouseSetupPrompt(
        title: 'Setting up the pointer',
        message: 'Installing the pointer app on the TV…',
        busy: true,
      ),
      TvCursorStatus.connecting ||
      TvCursorStatus.ready => const MouseSetupPrompt(
        title: 'Connecting to the pointer',
        message: 'Reaching the pointer app on the TV…',
        busy: true,
      ),
    };
  }

  Future<void> _openTvSettings() async {
    if (_fullControl) {
      try {
        await ref.read(fullControlProvider.notifier).openTvSettings();
        return;
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Opening TV settings needs Full control.'),
          action: SnackBarAction(label: 'Set up', onPressed: _openFullControl),
        ),
      );
  }

  Future<void> _readVolume() async {
    if (ref.read(fullControlProvider).status != FullControlStatus.connected) {
      return;
    }
    final generation = ++_volumeGeneration;
    try {
      final volume = await ref.read(fullControlProvider.notifier).readVolume();
      if (!mounted || generation != _volumeGeneration) return;
      setState(() {
        _adbMuted = volume.muted;
        _assumedMuted = volume.muted;
        _exactVolume = volume.fixed || volume.max <= 0
            ? null
            : VolumeControl(index: volume.index, max: volume.max);
      });
    } catch (_) {
      if (mounted && generation == _volumeGeneration) {
        setState(() {
          _exactVolume = null;
          _adbMuted = null;
        });
      }
    }
  }

  Future<void> _setVolume(int index) async {
    _volumeTimer?.cancel();
    if (_exactVolume != null) {
      setState(() {
        _exactVolume = VolumeControl(index: index, max: _exactVolume!.max);
        _assumedMuted = false;
        _adbMuted = false;
      });
    }
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
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const AppsPage()));
  }

  void _openNowPlaying(NowPlaying playing) {
    final package = _nowPlaying?.package;
    final apps = ref.read(fullControlProvider).apps;
    final app = apps.where((item) => item.package == package).firstOrNull;
    final formatter = NowPlayingLine(playing: playing);
    showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: sheetAnimation(context),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(playing.title, style: context.appTextTheme.titleLarge),
              if (playing.subtitle?.isNotEmpty ?? false)
                Text(playing.subtitle!, style: context.appTextTheme.bodyMedium),
              if (app != null)
                Text(app.label, style: context.appTextTheme.bodyMedium),
              const SizedBox(height: 12),
              Text(
                '${formatter.time(playing.position)}${playing.duration == null ? '' : ' / ${formatter.time(playing.duration!)}'}',
                style: context.appTextTheme.labelMedium!.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: 'Rewind',
                    onPressed: () =>
                        ref.read(tvSessionProvider)?.press(RemoteButton.rewind),
                    icon: const Icon(Icons.fast_rewind_rounded),
                  ),
                  IconButton(
                    tooltip: 'Play-Pause',
                    onPressed: () => ref
                        .read(tvSessionProvider)
                        ?.press(RemoteButton.playPause),
                    icon: Icon(
                      playing.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fast-forward',
                    onPressed: () => ref
                        .read(tvSessionProvider)
                        ?.press(RemoteButton.fastForward),
                    icon: const Icon(Icons.fast_forward_rounded),
                  ),
                ],
              ),
              if (package != null && package.isNotEmpty)
                FilledButton.tonal(
                  onPressed: () {
                    ref.read(fullControlProvider.notifier).launch(package);
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('Open app'),
                ),
            ],
          ),
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
        _startNowPlaying();
      } else {
        _nowPlayingGeneration++;
        _volumeTimer?.cancel();
        _stopNowPlaying();
        _volumeGeneration++;
        setState(() {
          _exactVolume = null;
          _adbMuted = null;
          _nowPlaying = null;
        });
      }
    });
    final tv = ref.watch(activeTvProvider);
    if (_activeTv != tv) {
      _activeTv = tv;
      _nowPlayingGeneration++;
      _nowPlaying = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _readNowPlaying();
      });
    }
    final session = ref.watch(tvSessionProvider);
    final sessionState =
        ref.watch(tvSessionStateProvider).asData?.value ??
        const TvSessionState(status: SessionStatus.connecting);
    final atv = sessionState.atv;
    final cursor = ref.read(tvCursorProvider.notifier);
    final cursorState = ref.watch(tvCursorProvider);
    final status = sessionState.status;

    return RemoteScreen(
      initialMode:
          RemoteMode.values
              .where(
                (mode) =>
                    mode.name == ref.watch(appPreferencesProvider).remoteMode,
              )
              .firstOrNull ??
          RemoteMode.dpad,
      onModeChanged: (mode) {
        ref.read(appPreferencesProvider.notifier).setRemoteMode(mode.name);
        if (mode != RemoteMode.mouse) {
          _setAirMouse(false);
          cursor.hide();
        }
      },
      swipeSensitivity: ref.watch(appPreferencesProvider).swipeSensitivity,
      state: RemoteViewState(
        deviceName: tv?.displayName ?? 'No TV',
        connected: status == SessionStatus.connected,
        reconnecting:
            status == SessionStatus.connecting ||
            status == SessionStatus.reconnecting,
        volumeLevel: atv.volumeMax > 0
            ? (atv.volumeLevel * 100 / atv.volumeMax).round()
            : null,
        muted: _adbMuted ?? (atv.volumeMax > 0 ? atv.muted : _assumedMuted),
        needsPairing: status == SessionStatus.notPaired,
        attempt: sessionState.attempt,
        exactVolume: _exactVolume,
        nowPlaying: _buildNowPlaying(ref.watch(fullControlProvider).apps),
      ),
      onButton: (button) {
        if (button == RemoteButton.settings) {
          _openTvSettings();
          return;
        }
        session?.press(button);
        switch (button) {
          case RemoteButton.mute:
            setState(() => _assumedMuted = !_assumedMuted);
          case RemoteButton.volumeUp || RemoteButton.volumeDown:
            if (_assumedMuted || _adbMuted == true) {
              setState(() {
                _assumedMuted = false;
                _adbMuted = false;
              });
            }
          case RemoteButton.playPause ||
              RemoteButton.rewind ||
              RemoteButton.fastForward:
            _refreshNowPlayingSoon();
          default:
        }
        if (button == RemoteButton.volumeUp ||
            button == RemoteButton.volumeDown ||
            button == RemoteButton.mute) {
          _volumeGeneration++;
          _volumeTimer?.cancel();
          _volumeTimer = Timer(const Duration(milliseconds: 400), _readVolume);
        }
      },
      onButtonDown: (button) => session?.pressDown(button),
      onButtonUp: (button) => session?.pressUp(button),
      onExactVolumeChanged: _setVolume,
      onOpenNowPlaying: _nowPlaying == null
          ? null
          : () {
              final playing = _buildNowPlaying(
                ref.read(fullControlProvider).apps,
              );
              if (playing != null) _openNowPlaying(playing);
            },
      onSwitchDevice: widget.onSwitchDevice,
      onApps: _showApps,
      onKeyboard: widget.onKeyboard,
      onVoice: widget.onVoice,
      onRetry: () => session?.retryNow(),
      onPairAgain: widget.onPairAgain,
      onAppSettings: widget.onAppSettings,
      onPointerMove: cursor.move,
      onScroll: cursor.scroll,
      onClick: (right) => right ? cursor.back() : cursor.tap(),
      onAirMouseChanged: _setAirMouse,
      onPointerLongPress: cursor.longPress,
      mouseAvailable: cursorState.status == TvCursorStatus.ready,
      mouseSetup: _mouseSetupPrompt(cursorState),
    );
  }
}
