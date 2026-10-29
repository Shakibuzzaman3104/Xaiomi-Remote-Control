/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../../haptics.dart';

import '../../theme/app_colors.dart';
import '../remote_models.dart';
import '../../theme/app_theme.dart';

class NowPlayingLine extends StatelessWidget {
  const NowPlayingLine({super.key, required this.playing, this.onTap});
  final NowPlaying playing;
  final VoidCallback? onTap;
  String time(Duration d) {
    final s = d.inSeconds.clamp(0, 999999);
    final seconds = (s % 60).toString().padLeft(2, '0');
    if (s >= 3600) {
      return '${s ~/ 3600}:${((s ~/ 60) % 60).toString().padLeft(2, '0')}:$seconds';
    }
    return '${s ~/ 60}:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final duration = playing.duration;
    final hasDuration = duration != null && duration.inMilliseconds > 0;
    final progress = hasDuration
        ? (playing.position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final subtitle = playing.subtitle;
    final tap = onTap;
    return Semantics(
      label:
          '${playing.playing ? 'Playing' : 'Paused'}, ${playing.title}'
          '${subtitle == null || subtitle.isEmpty ? '' : ', $subtitle'}',
      button: tap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap == null
            ? null
            : () {
                AppHaptics.selection();
                tap();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child:
                    playing.appIcon ??
                    Icon(
                      playing.playing
                          ? Icons.play_circle_outline
                          : Icons.pause_circle_outline,
                      color: c.primary,
                    ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            playing.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.appTextTheme.titleSmall!.copyWith(
                              color: c.onSurfaceStrong,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          time(playing.position),
                          style: context.appTextTheme.labelMedium!.copyWith(
                            color: c.primaryText,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (hasDuration)
                          Text(
                            ' / ${time(duration)}',
                            style: context.appTextTheme.labelMedium!.copyWith(
                              color: c.muted,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appTextTheme.labelMedium!.copyWith(
                            color: c.muted,
                          ),
                        ),
                      ),
                    if (hasDuration) ...[
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: c.progressTrack,
                          color: c.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
