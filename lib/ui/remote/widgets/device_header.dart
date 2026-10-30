/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../../fade_switcher.dart';
import '../../haptics.dart';
import '../../motion.dart';
import '../../physics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'pulse_dot.dart';

class DeviceHeader extends StatelessWidget {
  const DeviceHeader({
    super.key,
    required this.name,
    required this.connected,
    required this.onSwitchDevice,
    required this.onTvSettings,
    required this.onAppSettings,
    this.onTransfer,
    this.onPower,
    this.offlineLabel = 'Reconnecting…',
    this.retrying = true,
    this.tvOn,
  });
  final String name, offlineLabel;
  final bool? tvOn;
  final bool connected, retrying;
  final VoidCallback onSwitchDevice, onTvSettings, onAppSettings;
  final VoidCallback? onPower, onTransfer;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final screenOff = connected && tvOn == false;
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
                          child: ExcludeSemantics(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.appTextTheme.titleSmall!.copyWith(
                                color: c.onSurfaceStrong,
                              ),
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
                    SpringValue(
                      value: connected ? 1 : 0,
                      spring: AppSprings.settle,
                      builder: (context, value, child) => Opacity(
                        opacity:
                            0.75 + 0.25 * (2 * value.clamp(0.0, 1.0) - 1).abs(),
                        child: child,
                      ),
                      child: FadeSwitcher(
                        scale: 1,
                        alignment: Alignment.centerLeft,
                        duration: AppMotion.quick,
                        child: Row(
                          key: ValueKey((connected, screenOff, offlineLabel)),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox.square(
                              dimension: 15,
                              child: Center(
                                child: screenOff
                                    ? Icon(
                                        Icons.bedtime_outlined,
                                        size: 15,
                                        color: c.muted,
                                      )
                                    : connected
                                    ? Icon(Icons.wifi, size: 15, color: c.muted)
                                    : retrying
                                    ? const PulseDot()
                                    : Icon(
                                        Icons.link_off,
                                        size: 15,
                                        color: c.muted,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              screenOff
                                  ? 'Screen off'
                                  : connected
                                  ? 'Connected'
                                  : offlineLabel,
                              style: context.appTextTheme.labelMedium!.copyWith(
                                color: c.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: screenOff ? 'Turn on' : 'Power',
          onPressed: onPower == null
              ? null
              : () {
                  AppHaptics.medium();
                  onPower!();
                },
          icon: Icon(
            Icons.power_settings_new,
            color: screenOff ? c.primaryText : c.onSurface,
          ),
        ),
        PopupMenuButton<VoidCallback>(
          tooltip: 'Menu',
          icon: Icon(Icons.more_vert, color: c.onSurface),
          color: c.surfaceContainer,
          onSelected: (action) => action(),
          itemBuilder: (_) => [
            if (connected && onTransfer != null)
              PopupMenuItem(value: onTransfer, child: const Text('Transfer files')),
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
