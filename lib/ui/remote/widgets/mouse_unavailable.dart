/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../remote_models.dart';

/// Shown in Mouse mode until the TV pointer is ready.
class MouseUnavailable extends StatelessWidget {
  const MouseUnavailable({
    super.key,
    required this.prompt,
    required this.onUseSwipe,
  });
  final MouseSetupPrompt prompt;
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
                prompt.title,
                textAlign: TextAlign.center,
                style: context.appTextTheme.titleMedium!.copyWith(
                  color: c.onSurfaceStrong,
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  prompt.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: prompt.isError ? c.danger : c.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (prompt.busy)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              else if (prompt.actionLabel != null && prompt.onAction != null)
                FilledButton(
                  onPressed: prompt.onAction,
                  child: Text(prompt.actionLabel!),
                ),
              const SizedBox(height: 4),
              TextButton(onPressed: onUseSwipe, child: const Text('Use Swipe')),
            ],
          ),
        ),
      ),
    );
  }
}
