/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../../haptics.dart';

import '../../theme/app_colors.dart';

class DisconnectedBanner extends StatelessWidget {
  const DisconnectedBanner({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'TV is asleep or off Wi-Fi. Wake it with the physical remote.',
              style: TextStyle(color: c.onSurface, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              AppHaptics.selection();
              onRetry();
            },
            style: TextButton.styleFrom(foregroundColor: c.primaryText),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
