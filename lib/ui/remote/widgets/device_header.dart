/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../../haptics.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

class DeviceHeader extends StatelessWidget {
  const DeviceHeader({
    super.key,
    required this.name,
    required this.connected,
    required this.onSwitchDevice,
    required this.onTvSettings,
    required this.onAppSettings,
    this.onPower,
  });
  final String name;
  final bool connected;
  final VoidCallback onSwitchDevice, onTvSettings, onAppSettings;
  final VoidCallback? onPower;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(Icons.tv_outlined, color: c.onSurface, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Semantics(
            button: true,
            label: 'Switch device, $name',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                AppHaptics.selection();
                onSwitchDevice();
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.appTextTheme.titleSmall!.copyWith(
                              color: c.onSurfaceStrong,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: c.onSurface,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (connected)
                          Icon(Icons.wifi, size: 15, color: c.muted)
                        else
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.primary,
                            ),
                          ),
                        const SizedBox(width: 5),
                        Text(
                          connected ? 'Connected' : 'Reconnecting…',
                          style: context.appTextTheme.labelMedium!.copyWith(
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Power',
          onPressed: onPower == null
              ? null
              : () {
                  AppHaptics.medium();
                  onPower!();
                },
          icon: Icon(Icons.power_settings_new, color: c.onSurface),
        ),
        PopupMenuButton<VoidCallback>(
          tooltip: 'Menu',
          icon: Icon(Icons.more_vert, color: c.onSurface),
          color: c.surfaceContainer,
          onSelected: (action) => action(),
          itemBuilder: (_) => [
            if (connected)
              PopupMenuItem(
                value: onTvSettings,
                child: const Text('TV settings'),
              ),
            PopupMenuItem(
              value: onAppSettings,
              child: const Text('App settings'),
            ),
          ],
        ),
      ],
    );
  }
}
