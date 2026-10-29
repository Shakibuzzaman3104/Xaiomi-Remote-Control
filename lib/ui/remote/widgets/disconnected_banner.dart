/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../../haptics.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

class DisconnectedBanner extends StatelessWidget {
  const DisconnectedBanner({
    super.key,
    required this.onRetry,
    this.onPairAgain,
  });
  final VoidCallback onRetry;
  final VoidCallback? onPairAgain;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pairAgain = onPairAgain;
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined, color: c.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pairAgain != null
                  ? "The TV doesn't recognise this phone any more. Pair it again."
                  : 'TV is asleep or off Wi-Fi. Wake it with the physical remote.',
              style: context.appTextTheme.labelMedium!.copyWith(
                color: c.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              AppHaptics.selection();
              (pairAgain ?? onRetry)();
            },
            style: TextButton.styleFrom(foregroundColor: c.primaryText),
            child: Text(pairAgain != null ? 'Pair again' : 'Retry'),
          ),
        ],
      ),
    );
  }
}
