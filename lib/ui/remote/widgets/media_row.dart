/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../remote_models.dart';
import 'round_action_button.dart';

class MediaRow extends StatelessWidget {
  const MediaRow({super.key, required this.playing, required this.onButton});
  final bool playing;
  final ValueChanged<RemoteButton> onButton;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      RoundActionButton(
        label: 'Rewind',
        icon: Icons.fast_rewind_rounded,
        showLabel: false,
        onPressed: () => onButton(RemoteButton.rewind),
      ),
      RoundActionButton(
        label: playing ? 'Pause' : 'Play',
        icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        showLabel: false,
        onPressed: () => onButton(RemoteButton.playPause),
      ),
      RoundActionButton(
        label: 'Fast forward',
        icon: Icons.fast_forward_rounded,
        showLabel: false,
        onPressed: () => onButton(RemoteButton.fastForward),
      ),
    ],
  );
}
