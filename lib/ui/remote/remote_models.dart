/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/widgets.dart';

export '../../core/session/remote_button.dart';

enum RemoteMode { dpad, swipe, mouse, numpad }

class NowPlaying {
  const NowPlaying({
    required this.title,
    required this.position,
    this.duration,
    required this.playing,
    this.subtitle,
    this.appIcon,
  });
  final String title;
  final String? subtitle;
  final Duration position;
  final Duration? duration;
  final bool playing;
  final Widget? appIcon;
}

class MouseSetupPrompt {
  const MouseSetupPrompt({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.busy = false,
    this.isError = false,
  });
  final String title, message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool busy, isError;
}

class FavouriteApp {
  const FavouriteApp({
    required this.id,
    required this.label,
    required this.icon,
  });
  final String id, label;
  final Widget icon;
}

@immutable
class VolumeControl {
  const VolumeControl({required this.index, required this.max});
  final int index, max;
}

const _unset = Object();

class RemoteViewState {
  const RemoteViewState({
    required this.deviceName,
    required this.connected,
    required this.reconnecting,
    this.nowPlaying,
    this.volumeLevel,
    this.exactVolume,
    required this.muted,
    this.needsPairing = false,
    this.attempt = 0,
  });
  final String deviceName;
  final bool connected, reconnecting, muted, needsPairing;
  final NowPlaying? nowPlaying;
  final int? volumeLevel;
  final int attempt;
  final VolumeControl? exactVolume;
  RemoteViewState copyWith({
    String? deviceName,
    bool? connected,
    bool? reconnecting,
    Object? nowPlaying = _unset,
    Object? volumeLevel = _unset,
    Object? exactVolume = _unset,
    bool? muted,
    bool? needsPairing,
    int? attempt,
  }) => RemoteViewState(
    deviceName: deviceName ?? this.deviceName,
    connected: connected ?? this.connected,
    reconnecting: reconnecting ?? this.reconnecting,
    nowPlaying: identical(nowPlaying, _unset)
        ? this.nowPlaying
        : nowPlaying as NowPlaying?,
    volumeLevel: identical(volumeLevel, _unset)
        ? this.volumeLevel
        : volumeLevel as int?,
    exactVolume: identical(exactVolume, _unset)
        ? this.exactVolume
        : exactVolume as VolumeControl?,
    muted: muted ?? this.muted,
    needsPairing: needsPairing ?? this.needsPairing,
    attempt: attempt ?? this.attempt,
  );
}
