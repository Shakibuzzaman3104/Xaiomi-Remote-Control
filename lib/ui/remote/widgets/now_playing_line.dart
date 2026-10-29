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
  const NowPlayingLine({super.key, required this.playing, required this.onTap});
  final NowPlaying playing;
  final VoidCallback onTap;
  String time(Duration d) {
    final s = d.inSeconds.clamp(0, 999999);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final progress = playing.duration.inMilliseconds <= 0
        ? 0.0
        : (playing.position.inMilliseconds / playing.duration.inMilliseconds)
              .clamp(0.0, 1.0);
    return Semantics(
      label: 'Now playing, ${playing.title}',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppHaptics.selection();
          onTap();
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
                    Icon(Icons.play_circle_outline, color: c.primary),
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
                            style: TextStyle(
                              color: c.onSurfaceStrong,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          time(playing.position),
                          style: context.appTextTheme.labelMedium!.copyWith(
                            color: c.primaryText,
                          ),
                        ),
                        Text(
                          ' / ${time(playing.duration)}',
                          style: context.appTextTheme.labelMedium!.copyWith(
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
