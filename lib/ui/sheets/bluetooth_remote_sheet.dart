/**
 * @author Shakib
 * @since 30/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bluetooth/bluetooth_remote.dart';
import '../haptics.dart';
import '../physics.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class BluetoothRemoteSheet extends ConsumerWidget {
  const BluetoothRemoteSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final remote = ref.watch(bluetoothRemoteProvider);
    final controller = ref.read(bluetoothRemoteProvider.notifier);
    void key(String name) {
      AppHaptics.selection();
      controller.sendKey(name);
    }
    Widget button(IconData icon, String label, String name) => IconButton(
      tooltip: label,
      onPressed: remote.busy || !remote.connected ? null : () => key(name),
      icon: Icon(icon),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SpringIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Bluetooth remote', style: context.appTextTheme.headlineMedium!.copyWith(color: c.onSurfaceStrong)),
              const SizedBox(height: 8),
              Text(
                remote.connected ? 'Connected' : remote.hostAddress == null ? 'Not set up' : 'Paired with ${remote.hostName ?? 'TV'}',
                style: context.appTextTheme.labelMedium!.copyWith(color: c.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (remote.hostAddress == null) ...[
                const Text('1. Tap “Make phone visible”.\n\n2. On the TV open Settings → Remotes & accessories → Add accessory.\n\n3. Pick this phone.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: remote.busy ? null : () { AppHaptics.selection(); controller.startPairing(); },
                  child: const Text('Make phone visible'),
                ),
              ] else ...[
                FilledButton(
                  onPressed: remote.busy ? null : () { AppHaptics.selection(); controller.wake(); },
                  child: const Text('Wake TV'),
                ),
                Center(child: button(Icons.keyboard_arrow_up, 'Up', 'up')),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  button(Icons.keyboard_arrow_left, 'Left', 'left'),
                  TextButton(onPressed: remote.busy || !remote.connected ? null : () => key('ok'), child: const Text('OK')),
                  button(Icons.keyboard_arrow_right, 'Right', 'right'),
                ]),
                Center(child: button(Icons.keyboard_arrow_down, 'Down', 'down')),
                Wrap(alignment: WrapAlignment.center, children: [
                  button(Icons.arrow_back, 'Back', 'back'),
                  button(Icons.home_outlined, 'Home', 'home'),
                  button(Icons.play_arrow, 'Play-pause', 'playPause'),
                  button(Icons.volume_down_outlined, 'Vol-', 'volumeDown'),
                  button(Icons.volume_up_outlined, 'Vol+', 'volumeUp'),
                ]),
                TextButton(onPressed: remote.busy ? null : () { AppHaptics.selection(); controller.forget(); }, child: const Text('Forget TV')),
              ],
              if (remote.error != null) ...[
                const SizedBox(height: 8),
                Text(remote.error!, style: context.appTextTheme.labelMedium!.copyWith(color: c.danger)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
