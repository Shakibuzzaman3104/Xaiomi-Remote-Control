/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Shown in Mouse mode until the TV pointer is available.
class MouseUnavailable extends StatelessWidget {
  const MouseUnavailable({super.key, required this.onUseSwipe});
  final VoidCallback onUseSwipe;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.dpadOutline),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 240,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mouse_outlined, size: 40, color: c.primary),
              const SizedBox(height: 16),
              Text(
                'Mouse pointer is coming soon',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: c.onSurfaceStrong,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Swipe works on every TV screen in the meantime.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onUseSwipe,
                child: const Text('Use Swipe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
