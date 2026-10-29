/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../haptics.dart';

import '../theme/app_colors.dart';
import 'step_dots.dart';
import '../theme/app_theme.dart';

class DiscoverItem {
  const DiscoverItem({
    required this.id,
    required this.title,
    required this.subtitle,
  });
  final String id;
  final String title;
  final String subtitle;
}

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({
    super.key,
    required this.devices,
    required this.searching,
    required this.onSelect,
    required this.onEnterIp,
  });
  final List<DiscoverItem> devices;
  final bool searching;
  final ValueChanged<DiscoverItem> onSelect;
  final VoidCallback onEnterIp;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Center(child: StepDots(current: 1)),
              const SizedBox(height: 48),
              Text(
                'Find your TV',
                textAlign: TextAlign.center,
                style: context.appTextTheme.headlineMedium!.copyWith(
                  color: c.onSurfaceStrong,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 35),
                child: Text(
                  'Make sure your phone and TV are on the same Wi-Fi.',
                  textAlign: TextAlign.center,
                  style: context.appTextTheme.bodyLarge!.copyWith(
                    height: 1.3,
                    color: c.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 38),
              Center(
                child: Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/illustrations/discover_dark.png'
                      : 'assets/illustrations/discover.png',
                  width: 280,
                  height: 201,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const SizedBox(width: 280, height: 201),
                ),
              ),
              const SizedBox(height: 34),
              Text(
                'Available devices',
                style: context.appTextTheme.displaySmall!.copyWith(
                  color: c.onSurfaceStrong,
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < devices.length; i++) ...[
                _DeviceTile(
                  item: devices[i],
                  highlighted: i == 0,
                  onTap: () {
                    AppHaptics.selection();
                    onSelect(devices[i]);
                  },
                ),
                const SizedBox(height: 10),
              ],
              if (searching)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (devices.isEmpty)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.primary,
                            backgroundColor: c.okButton,
                          ),
                        )
                      else
                        Icon(Icons.wifi_find, size: 20, color: c.muted),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Text(
                          devices.isEmpty
                              ? 'Searching…'
                              : 'Still looking for more TVs…',
                          style: context.appTextTheme.bodySmall!.copyWith(
                            color: c.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 68),
              Center(
                child: TextButton(
                  onPressed: () {
                    AppHaptics.selection();
                    onEnterIp();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: c.primaryText,
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(
                    'Enter IP address manually',
                    style: context.appTextTheme.labelLarge!,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.item,
    required this.highlighted,
    required this.onTap,
  });
  final DiscoverItem item;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: '${item.title}, ${item.subtitle}',
      child: Material(
        color: highlighted ? c.surfaceContainer : c.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(
            color: highlighted ? c.surfaceContainer : c.subtleOutline,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.tv_outlined, size: 29, color: c.onSurfaceStrong),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.appTextTheme.displaySmall!.copyWith(
                          color: c.onSurfaceStrong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.appTextTheme.bodySmall!.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: c.onSurfaceStrong, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
