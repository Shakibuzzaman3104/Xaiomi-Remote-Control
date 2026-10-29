/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/widgets.dart';

enum RemoteButton {
  up,
  down,
  left,
  right,
  ok,
  back,
  home,
  settings,
  volumeUp,
  volumeDown,
  mute,
  playPause,
  rewind,
  fastForward,
  power,
  channelUp,
  channelDown,
  digit0,
  digit1,
  digit2,
  digit3,
  digit4,
  digit5,
  digit6,
  digit7,
  digit8,
  digit9,
}

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
    required this.favourites,
  });
  final String deviceName;
  final bool connected, reconnecting, muted;
  final NowPlaying? nowPlaying;
  final int? volumeLevel;
  final List<FavouriteApp> favourites;
  RemoteViewState copyWith({
    String? deviceName,
    bool? connected,
    bool? reconnecting,
    Object? nowPlaying = _unset,
    Object? volumeLevel = _unset,
    bool? muted,
    List<FavouriteApp>? favourites,
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
    favourites: favourites ?? this.favourites,
  );
}
