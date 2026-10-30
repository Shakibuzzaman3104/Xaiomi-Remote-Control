/**
 * @author Shakib
 * @since 30/10/26
 */
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../remote_models.dart';
import 'now_playing_line.dart';

class SeekBar extends StatefulWidget {
  const SeekBar({super.key, required this.playing, required this.position, required this.onSeekTo});
  final NowPlaying playing;
  final Duration position;
  final ValueChanged<Duration> onSeekTo;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? target;

  @override
  Widget build(BuildContext context) {
    final duration = widget.playing.duration;
    final formatter = NowPlayingLine(playing: widget.playing);
    final max = duration?.inMilliseconds.toDouble() ?? 0;
    final value = (target ?? widget.position.inMilliseconds.toDouble()).clamp(0.0, max > 0 ? max : 0.0);
    final style = context.appTextTheme.labelMedium!.copyWith(
      color: context.colors.muted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      children: [
        if (widget.playing.canSeek && max > 0)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: context.colors.primary,
              thumbColor: context.colors.primary,
              inactiveTrackColor: context.colors.progressTrack,
            ),
            child: Slider(
              value: value,
              max: max,
              onChanged: (v) => setState(() => target = v),
              onChangeEnd: (v) {
                setState(() => target = null);
                widget.onSeekTo(Duration(milliseconds: v.round()));
              },
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatter.time(Duration(milliseconds: max > 0 ? value.round() : widget.position.inMilliseconds)), style: style),
            if (max > 0) Text('−${formatter.time(Duration(milliseconds: (max - value).round()))}', style: style),
          ],
        ),
      ],
    );
  }
}
