/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SettingsDevice {
  const SettingsDevice({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.isActive,
  });
  final String id, name, subtitle;
  final bool isActive;
}

class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.devices,
    required this.onSelectDevice,
    required this.onRemoveDevice,
    required this.onAddTv,
    required this.hapticsEnabled,
    required this.onHapticsChanged,
    required this.volumeKeysEnabled,
    required this.onVolumeKeysChanged,
    required this.swipeSensitivity,
    required this.onSwipeSensitivityChanged,
    required this.micButtonLabel,
    required this.onMicButtonTap,
    required this.speechLanguageLabel,
    required this.onSpeechLanguageTap,
    required this.adbConnected,
    required this.onNetworkDebuggingTap,
    required this.themeLabel,
    required this.onThemeTap,
    required this.appVersion,
    required this.onAboutTap,
    this.onTurnOffFullControl,
    this.onBack,
  });
  final List<SettingsDevice> devices;
  final ValueChanged<String> onSelectDevice, onRemoveDevice;
  final VoidCallback onAddTv;
  final bool hapticsEnabled, volumeKeysEnabled;
  final ValueChanged<bool> onHapticsChanged, onVolumeKeysChanged;
  final double swipeSensitivity;
  final ValueChanged<double> onSwipeSensitivityChanged;
  final String micButtonLabel, speechLanguageLabel, themeLabel, appVersion;
  final VoidCallback onMicButtonTap,
      onSpeechLanguageTap,
      onNetworkDebuggingTap,
      onThemeTap,
      onAboutTap;
  final VoidCallback? onTurnOffFullControl;
  final VoidCallback? onBack;
  final bool adbConnected;

  String get _sensitivityLabel => swipeSensitivity < 1 / 3
      ? 'Low'
      : swipeSensitivity < 2 / 3
      ? 'Medium'
      : 'High';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget row(
      IconData icon,
      String title,
      String? subtitle, {
      VoidCallback? tap,
      VoidCallback? longPress,
      Widget? trailing,
      Widget? bottom,
      bool mergeSemantics = false,
    }) => _Row(
      icon: icon,
      title: title,
      subtitle: subtitle,
      tap: tap,
      longPress: longPress,
      trailing: trailing,
      bottom: bottom,
      mergeSemantics: mergeSemantics,
    );
    Widget toggle(bool value, ValueChanged<bool> changed) =>
        Switch(value: value, onChanged: changed, activeTrackColor: c.primary);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                if (onBack != null) ...[
                  IconButton(
                    onPressed: onBack,
                    icon: Icon(Icons.arrow_back, color: c.onSurfaceStrong),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  'Settings',
                  style: context.appTextTheme.headlineSmall!.copyWith(
                    color: c.onSurfaceStrong,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Section(
              label: 'Devices',
              children: [
                for (final device in devices)
                  row(
                    Icons.tv_outlined,
                    device.name,
                    device.isActive ? 'Connected' : device.subtitle,
                    tap: () => onSelectDevice(device.id),
                    longPress: () => onRemoveDevice(device.id),
                    trailing: IconButton(
                      onPressed: () => onRemoveDevice(device.id),
                      icon: Icon(
                        Icons.delete_outline,
                        color: c.onSurfaceVariant,
                      ),
                      tooltip: 'Remove ${device.name}',
                    ),
                  ),
                row(Icons.add, 'Add a TV', null, tap: onAddTv),
              ],
            ),
            _Section(
              label: 'Control',
              children: [
                row(
                  Icons.touch_app_outlined,
                  'Haptic feedback',
                  'Vibrate on key presses',
                  tap: () => onHapticsChanged(!hapticsEnabled),
                  trailing: toggle(hapticsEnabled, onHapticsChanged),
                  mergeSemantics: true,
                ),
                if (defaultTargetPlatform != TargetPlatform.iOS)
                  row(
                    Icons.volume_up_outlined,
                    'Volume keys control TV',
                    "Use your phone's volume buttons",
                    tap: () => onVolumeKeysChanged(!volumeKeysEnabled),
                    trailing: toggle(volumeKeysEnabled, onVolumeKeysChanged),
                    mergeSemantics: true,
                  ),
                row(
                  Icons.swap_horiz,
                  'Swipe sensitivity',
                  'Adjust how sensitive swipe gestures are',
                  bottom: Row(
                    children: [
                      Expanded(
                        child: MergeSemantics(
                          child: Semantics(
                            label: 'Swipe sensitivity',
                            value: _sensitivityLabel,
                            child: Slider(
                              value: swipeSensitivity.clamp(0.0, 1.0),
                              onChanged: onSwipeSensitivityChanged,
                              semanticFormatterCallback: (_) =>
                                  _sensitivityLabel,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        _sensitivityLabel,
                        style: context.appTextTheme.labelSmall!.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _Section(
              label: 'Voice',
              children: [
                row(
                  Icons.mic_none,
                  'Mic button',
                  micButtonLabel,
                  tap: onMicButtonTap,
                ),
                row(
                  Icons.translate,
                  'Speech language',
                  speechLanguageLabel,
                  tap: onSpeechLanguageTap,
                ),
              ],
            ),
            _Section(
              label: 'Connection',
              children: [
                row(
                  Icons.terminal,
                  'Full control',
                  adbConnected ? 'Connected' : 'Off · Tap to set up',
                  tap: onNetworkDebuggingTap,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (adbConnected)
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: c.connected.withValues(alpha: .12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 16,
                            color: c.connected,
                          ),
                        ),
                      Icon(Icons.chevron_right, color: c.onSurfaceStrong),
                    ],
                  ),
                ),
                if (adbConnected && onTurnOffFullControl != null)
                  row(
                    Icons.link_off,
                    'Turn off Full control',
                    'Stop controlling this TV over the network',
                    tap: onTurnOffFullControl,
                  ),
              ],
            ),
            _Section(
              label: 'Appearance',
              children: [
                row(
                  Icons.palette_outlined,
                  'Theme',
                  themeLabel,
                  tap: onThemeTap,
                ),
              ],
            ),
            _Section(
              label: 'About',
              children: [
                row(
                  Icons.info_outline,
                  'About',
                  'App version $appVersion',
                  tap: onAboutTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});
  final String label;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 3, bottom: 5),
            child: Text(
              label,
              style: context.appTextTheme.labelMedium!.copyWith(
                color: c.onSurfaceVariant,

                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: c.appTile,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.subtleOutline),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(height: 1, color: c.subtleOutline),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.tap,
    this.longPress,
    this.trailing,
    this.bottom,
    this.mergeSemantics = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? tap, longPress;
  final Widget? trailing, bottom;
  final bool mergeSemantics;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = InkWell(
      onTap: tap,
      onLongPress: longPress,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 21, color: c.onSurfaceStrong),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.appTextTheme.labelLarge!.copyWith(
                      color: c.onSurfaceStrong,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: context.appTextTheme.labelSmall!.copyWith(
                        color: c.muted,
                      ),
                    ),
                  ?bottom,
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (tap != null)
              Icon(Icons.chevron_right, color: c.onSurfaceStrong),
          ],
        ),
      ),
    );
    return mergeSemantics ? MergeSemantics(child: content) : content;
  }
}
