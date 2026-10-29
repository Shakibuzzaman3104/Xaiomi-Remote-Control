/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../remote/remote_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Favourite apps first, then everything else installed on the TV.
class AppsSheet extends StatelessWidget {
  const AppsSheet({
    super.key,
    required this.favourites,
    required this.onOpen,
    this.note,
  });
  final List<FavouriteApp> favourites;
  final ValueChanged<FavouriteApp> onOpen;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppShapes.screenPadding,
          0,
          AppShapes.screenPadding,
          16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Favourite apps',
              style: TextStyle(
                color: c.onSurfaceStrong,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
              children: [
                for (final app in favourites)
                  _AppTile(app: app, onOpen: onOpen),
              ],
            ),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(note!, style: TextStyle(color: c.muted, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.app, required this.onOpen});
  final FavouriteApp app;
  final ValueChanged<FavouriteApp> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: app.label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShapes.card),
        onTap: () {
          HapticFeedback.selectionClick();
          onOpen(app);
        },
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1.3,
              child: Container(
                decoration: BoxDecoration(
                  color: c.appTile,
                  borderRadius: BorderRadius.circular(AppShapes.card),
                  border: Border.all(color: c.subtleOutline),
                ),
                child: Center(child: app.icon),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              app.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.onSurface, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
