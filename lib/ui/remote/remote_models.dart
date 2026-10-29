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
    required this.duration,
    required this.playing,
    this.appIcon,
  });
  final String title;
  final Duration position, duration;
  final bool playing;
  final Widget? appIcon;
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

const _unset = Object();

class RemoteViewState {
  const RemoteViewState({
    required this.deviceName,
    required this.connected,
    required this.reconnecting,
    this.nowPlaying,
    this.volumeLevel,
    required this.muted,
  });
  final String deviceName;
  final bool connected, reconnecting, muted;
  final NowPlaying? nowPlaying;
  final int? volumeLevel;
  RemoteViewState copyWith({
    String? deviceName,
    bool? connected,
    bool? reconnecting,
    Object? nowPlaying = _unset,
    Object? volumeLevel = _unset,
    bool? muted,
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
    muted: muted ?? this.muted,
  );
}
