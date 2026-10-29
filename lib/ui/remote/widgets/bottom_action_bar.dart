/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import 'round_action_button.dart';

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.onKeyboard,
    required this.onVoice,
    required this.onPower,
  });
  final VoidCallback onKeyboard, onVoice, onPower;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      RoundActionButton(
        label: 'Keyboard',
        icon: Icons.keyboard_outlined,
        onPressed: onKeyboard,
      ),
      RoundActionButton(
        label: 'Voice',
        icon: Icons.mic_none,
        selected: true,
        size: 72,
        onPressed: onVoice,
      ),
      RoundActionButton(
        label: 'Power',
        icon: Icons.power_settings_new,
        onPressed: onPower,
      ),
    ],
  );
}
