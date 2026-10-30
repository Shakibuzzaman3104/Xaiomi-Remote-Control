/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adb/full_control.dart';
import '../../core/session/providers.dart';
import '../../core/session/tv_session.dart';
import '../../core/settings/app_preferences.dart';
import '../../core/system/system_controls.dart';
import '../motion.dart';
import '../theme/theme_mode_provider.dart';
import 'settings_view.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({
    super.key,
    required this.onAddTv,
    required this.onOpenFullControl,
    required this.onBack,
  });
  final VoidCallback onAddTv, onOpenFullControl, onBack;

  Future<void> _choose<T>(
    BuildContext context,
    String title,
    T selected,
    Map<T, String> choices,
    ValueChanged<T> onSelected,
  ) => showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: sheetAnimation(context),
    builder: (sheetContext) => SafeArea(
      child: RadioGroup<T>(
        groupValue: selected,
        onChanged: (value) {
          if (value == null) return;
          onSelected(value);
          Navigator.pop(sheetContext);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
            ),
            for (final entry in choices.entries)
              RadioListTile<T>(title: Text(entry.value), value: entry.key),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paired = ref.watch(pairedTvsProvider).asData?.value;
    final active = ref.watch(activeTvProvider);
    final connected =
        ref.watch(tvSessionStateProvider).asData?.value.status ==
        SessionStatus.connected;
    final prefs = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);
    final theme = ref.watch(themeModeProvider);

    return SettingsView(
      onBack: onBack,
      devices: [
        for (final tv in paired?.tvs ?? const [])
          SettingsDevice(
            id: tv.id,
            name: tv.displayName,
            subtitle: tv.host,
            isActive: tv.id == active?.id && connected,
          ),
      ],
      onSelectDevice: (id) => ref.read(pairedTvsProvider.notifier).select(id),
      onRemoveDevice: (id) async {
        String? removedName;
        for (final item in paired?.tvs ?? const []) {
          if (item.id == id) removedName = item.displayName;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Remove ${removedName ?? 'this TV'}?'),
            content: const Text("You'll need to pair it again to use it."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        final navigator = Navigator.of(context);
        final remaining = [
          for (final item in paired?.tvs ?? const [])
            if (item.id != id) item,
        ];
        final removingLast = remaining.isEmpty;
        if (id == active?.id && remaining.isNotEmpty) {
          await ref.read(pairedTvsProvider.notifier).select(remaining.first.id);
        }
        await ref.read(pairedTvsProvider.notifier).remove(id);
        if (removingLast && navigator.mounted) {
          navigator.popUntil((route) => route.isFirst);
        }
      },
      onAddTv: onAddTv,
      hapticsEnabled: prefs.haptics,
      onHapticsChanged: notifier.setHaptics,
      volumeKeysEnabled: prefs.volumeKeysControlTv,
      onVolumeKeysChanged: notifier.setVolumeKeysControlTv,
      controlsInNotification: prefs.controlsInNotification,
      onControlsInNotificationChanged: (value) {
        if (value) ref.read(systemControlsProvider).requestPermission();
        notifier.setControlsInNotification(value);
      },
      swipeSensitivity: prefs.swipeSensitivity,
      onSwipeSensitivityChanged: notifier.setSwipeSensitivity,
      micButtonLabel: prefs.micButton == VoiceTargetPreference.askAssistant
          ? 'Search YouTube'
          : 'Type into field',
      onMicButtonTap: () => _choose(context, 'Mic button', prefs.micButton, {
        VoiceTargetPreference.askAssistant: 'Search YouTube',
        VoiceTargetPreference.typeIntoField: 'Type into field',
      }, notifier.setMicButton),
      speechLanguageLabel: prefs.speechLocale == 'bn_BD' ? 'বাংলা' : 'English',
      onSpeechLanguageTap: () => _choose(
        context,
        'Speech language',
        prefs.speechLocale,
        {'en_US': 'English (US)', 'bn_BD': 'বাংলা'},
        notifier.setSpeechLocale,
      ),
      adbConnected:
          ref.watch(fullControlProvider).status == FullControlStatus.connected,
      onNetworkDebuggingTap: onOpenFullControl,
      onTurnOffFullControl: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Turn off Full control?'),
            content: const Text(
              "Apps, mouse and exact volume will stop working until you set it up again.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Turn off'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await ref.read(fullControlProvider.notifier).disconnect();
        }
      },
      themeLabel: switch (theme) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      },
      onThemeTap: () => _choose(context, 'Theme', theme, {
        ThemeMode.system: 'System',
        ThemeMode.light: 'Light',
        ThemeMode.dark: 'Dark',
      }, ref.read(themeModeProvider.notifier).select),
      appVersion: '1.0.0',
      onAboutTap: () => showAboutDialog(
        context: context,
        applicationName: 'Xiaomi Remote',
        applicationVersion: '1.0.0',
      ),
    );
  }
}
