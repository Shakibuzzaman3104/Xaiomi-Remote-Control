/**
 * @author Shakib
 * @since 30/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/providers.dart';
import '../../core/session/tv_session.dart';
import '../fade_switcher.dart';
import '../physics.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class TvSwitcherSheet extends ConsumerWidget {
  const TvSwitcherSheet({
    super.key,
    required this.onAddTv,
    required this.onSettings,
  });

  final VoidCallback onAddTv;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final tvs = ref.watch(pairedTvsProvider).asData?.value.tvs ?? [];
    final active = ref.watch(activeTvProvider);
    final status = ref.watch(tvSessionStateProvider).asData?.value.status;
    final statusText = switch (status) {
      SessionStatus.connected => 'Connected',
      SessionStatus.connecting => 'Connecting…',
      SessionStatus.reconnecting => 'Reconnecting…',
      SessionStatus.notPaired => 'Pair again',
      SessionStatus.offline => 'Offline',
      null => 'Connecting…',
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your TVs',
              style: context.appTextTheme.headlineMedium!.copyWith(
                color: c.onSurfaceStrong,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < tvs.length; i++)
                    SpringIn(
                      delay: Duration(milliseconds: (i * 45).clamp(0, 300)),
                      child: SpringTapFeedback(
                        child: Builder(
                          builder: (context) {
                            final tv = tvs[i];
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppShapes.card,
                                ),
                              ),
                              leading: Icon(
                                Icons.tv_outlined,
                                color: c.onSurfaceStrong,
                              ),
                              title: Text(
                                tv.displayName,
                                style: TextStyle(color: c.onSurfaceStrong),
                              ),
                              subtitle: Text(
                                tv.id == active?.id
                                    ? statusText
                                    : (tv.model ?? tv.host),
                                style: TextStyle(color: c.onSurfaceVariant),
                              ),
                              trailing: tv.id == active?.id
                                  ? Icon(Icons.check, color: c.primary)
                                  : null,
                              onTap: () {
                                ref
                                    .read(pairedTvsProvider.notifier)
                                    .select(tv.id);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SpringIn(
              delay: Duration(milliseconds: (tvs.length * 45).clamp(0, 300)),
              child: SpringTapFeedback(
                child: ListTile(
                  leading: Icon(Icons.add, color: c.onSurfaceStrong),
                  title: const Text('Add a TV'),
                  onTap: onAddTv,
                ),
              ),
            ),
            SpringIn(
              delay: Duration(
                milliseconds: ((tvs.length + 1) * 45).clamp(0, 300),
              ),
              child: SpringTapFeedback(
                child: ListTile(
                  leading: Icon(
                    Icons.settings_outlined,
                    color: c.onSurfaceStrong,
                  ),
                  title: const Text('Settings'),
                  onTap: onSettings,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
