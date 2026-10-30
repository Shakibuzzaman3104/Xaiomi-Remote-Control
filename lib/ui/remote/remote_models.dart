/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:typed_data';

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
    this.appName,
    this.package,
    this.canSeek = false,
    this.speed = 1,
    this.updatedAt,
  });
  final String title;
  final String? subtitle;
  final Duration position;
  final Duration? duration;
  final bool playing;
  final Widget? appIcon;
  final String? appName, package;
  final bool canSeek;
  final double speed;
  final DateTime? updatedAt;

  Duration positionAt(DateTime now) {
    final elapsed = playing && updatedAt != null
        ? now.difference(updatedAt!).inMilliseconds * speed
        : 0.0;
    final milliseconds = (position.inMilliseconds + elapsed).round().clamp(
      0,
      (duration?.inMilliseconds ?? (1 << 40)).clamp(0, 1 << 40),
    );
    return Duration(milliseconds: milliseconds);
  }
}

class AppControlData {
  const AppControlData({required this.package, required this.label, this.icon});
  final String package, label;
  final Uint8List? icon;
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
    this.appControls,
    this.volumeLevel,
    this.exactVolume,
    required this.muted,
    this.needsPairing = false,
    this.attempt = 0,
  });
  final String deviceName;
  final bool connected, reconnecting, muted, needsPairing;
  final NowPlaying? nowPlaying;
  final AppControlData? appControls;
  final int? volumeLevel;
  final int attempt;
  final VolumeControl? exactVolume;
  RemoteViewState copyWith({
    String? deviceName,
    bool? connected,
    bool? reconnecting,
    Object? nowPlaying = _unset,
    Object? appControls = _unset,
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
    appControls: identical(appControls, _unset)
        ? this.appControls
        : appControls as AppControlData?,
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
