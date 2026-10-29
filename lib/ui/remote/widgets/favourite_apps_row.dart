/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../remote_models.dart';

class FavouriteAppsRow extends StatelessWidget {
  const FavouriteAppsRow({
    super.key,
    required this.apps,
    required this.onOpen,
    required this.onEdit,
  });
  final List<FavouriteApp> apps;
  final ValueChanged<FavouriteApp> onOpen;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Favourite apps',
                style: TextStyle(
                  color: c.onSurfaceStrong,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                onEdit();
              },
              style: TextButton.styleFrom(
                foregroundColor: c.primaryText,
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
              ),
              child: const Text('Edit'),
            ),
          ],
        ),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: apps.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final app = apps[i];
              return SizedBox(
                width: 72,
                child: Semantics(
                  label: app.label,
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onOpen(app);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 54,
                          decoration: BoxDecoration(
                            color: c.appTile,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: c.subtleOutline),
                          ),
                          child: Center(child: app.icon),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          app.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.onSurface, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
