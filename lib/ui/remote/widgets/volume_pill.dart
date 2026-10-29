/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../remote_models.dart';
import 'round_action_button.dart';

class VolumePill extends StatelessWidget {
  const VolumePill({
    super.key,
    required this.level,
    required this.muted,
    required this.onButton,
  });
  final int? level;
  final bool muted;
  final ValueChanged<RemoteButton> onButton;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: c.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                RoundActionButton(
                  label: 'Volume down',
                  icon: Icons.remove,
                  onPressed: () => onButton(RemoteButton.volumeDown),
                  showLabel: false,
                  repeat: true,
                  strong: true,
                  size: 48,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      level == null ? 'Volume' : 'Volume $level',
                      style: TextStyle(
                        color: c.onSurfaceStrong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                RoundActionButton(
                  label: 'Volume up',
                  icon: Icons.add,
                  onPressed: () => onButton(RemoteButton.volumeUp),
                  showLabel: false,
                  repeat: true,
                  strong: true,
                  size: 48,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        RoundActionButton(
          label: 'Mute',
          icon: Icons.volume_off_outlined,
          selected: muted,
          onPressed: () => onButton(RemoteButton.mute),
        ),
      ],
    );
  }
}
