/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../remote_models.dart';

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
          HapticFeedback.selectionClick();
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
                          style: TextStyle(color: c.primaryText, fontSize: 12),
                        ),
                        Text(
                          ' / ${time(playing.duration)}',
                          style: TextStyle(color: c.muted, fontSize: 12),
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
