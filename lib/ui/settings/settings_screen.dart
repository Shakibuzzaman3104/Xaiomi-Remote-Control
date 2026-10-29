/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/providers.dart';
import '../theme/app_colors.dart';
import '../theme/theme_mode_provider.dart';

/// Paired TVs and appearance.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.onAddTv});
  final VoidCallback onAddTv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final paired = ref.watch(pairedTvsProvider).asData?.value;
    final themeMode = ref.watch(themeModeProvider);
    final sectionStyle = Theme.of(context).textTheme.titleSmall
        ?.copyWith(color: colors.primaryText, fontWeight: FontWeight.w700);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(title: Text('Devices', style: sectionStyle)),
          for (final tv in paired?.tvs ?? const [])
            ListTile(
              leading: const Icon(Icons.tv_outlined),
              title: Text(tv.name),
              subtitle: Text(tv.host),
              trailing: tv.id == paired?.lastUsedId
                  ? Icon(Icons.check_circle, color: colors.connected)
                  : IconButton(
                      tooltip: 'Remove ${tv.name}',
                      icon: Icon(Icons.delete_outline, color: colors.danger),
                      onPressed: () =>
                          ref.read(pairedTvsProvider.notifier).remove(tv.id),
                    ),
              onTap: () => ref.read(pairedTvsProvider.notifier).select(tv.id),
            ),
          ListTile(
            leading: Icon(Icons.add, color: colors.primaryText),
            title: const Text('Add a TV'),
            onTap: onAddTv,
          ),
          const Divider(),
          ListTile(title: Text('Appearance', style: sectionStyle)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ref.read(themeModeProvider.notifier).select(selection.first),
            ),
          ),
        ],
      ),
    );
  }
}
