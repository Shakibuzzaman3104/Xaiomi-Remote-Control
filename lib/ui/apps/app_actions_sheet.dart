/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../fade_switcher.dart';
import '../physics.dart';
import '../theme/app_colors.dart';
import 'apps_screen.dart';
import '../theme/app_theme.dart';

class AppActionsSheet extends StatelessWidget {
  const AppActionsSheet({
    super.key,
    required this.app,
    this.sizeLabel,
    this.fullControl = true,
    required this.onOpen,
    required this.onToggleFavourite,
    required this.onForceStop,
    required this.onClearCache,
    required this.onAppInfo,
    required this.onUninstall,
    this.onNeedFullControl,
  });
  final TvAppItem app;
  final String? sizeLabel;
  final bool fullControl;
  final VoidCallback onOpen,
      onToggleFavourite,
      onForceStop,
      onClearCache,
      onAppInfo,
      onUninstall;
  final VoidCallback? onNeedFullControl;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    var actionIndex = 0;
    Widget action(
      String title,
      IconData icon,
      VoidCallback callback, {
      bool requiresControl = false,
      bool danger = false,
    }) {
      final enabled = !requiresControl || fullControl;
      final color = !enabled
          ? c.muted
          : danger
          ? c.danger
          : c.onSurfaceStrong;
      return SpringIn(
        delay: Duration(milliseconds: actionIndex++ * 35),
        child: SpringTapFeedback(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: danger
                  ? c.danger.withValues(alpha: .06)
                  : c.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: enabled ? callback : onNeedFullControl,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: danger
                                ? c.danger.withValues(alpha: .08)
                                : c.surfaceContainerStrong,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: context.appTextTheme.labelLarge!
                                    .copyWith(color: color),
                              ),
                              if (!enabled)
                                Text(
                                  'Needs Full control',
                                  style: context.appTextTheme.labelSmall!
                                      .copyWith(color: c.muted),
                                ),
                            ],
                          ),
                        ),
                        if (!enabled)
                          Icon(Icons.lock_outline, size: 18, color: c.muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 64,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.appTile,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.subtleOutline),
                    ),
                    child: app.icon,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.label,
                          style: context.appTextTheme.titleLarge!.copyWith(
                            color: c.onSurfaceStrong,
                          ),
                        ),
                        Text(
                          sizeLabel == null
                              ? app.package
                              : '${app.package} · $sizeLabel',
                          style: context.appTextTheme.bodySmall!.copyWith(
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              action('Open on TV', Icons.tv_outlined, onOpen),
              action(
                app.isFavourite
                    ? 'Remove from favourites'
                    : 'Add to favourites',
                app.isFavourite ? Icons.star : Icons.star_border,
                onToggleFavourite,
              ),
              action(
                'Force stop',
                Icons.block,
                onForceStop,
                requiresControl: true,
              ),
              action(
                'Clear cache',
                Icons.cleaning_services_outlined,
                onClearCache,
                requiresControl: true,
              ),
              action(
                'App info on TV',
                Icons.info_outline,
                onAppInfo,
                requiresControl: true,
              ),
              action(
                'Uninstall',
                Icons.delete_forever_outlined,
                onUninstall,
                requiresControl: true,
                danger: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
