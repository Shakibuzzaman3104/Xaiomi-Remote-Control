/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bluetooth/bluetooth_remote.dart';
import '../../sheets/bluetooth_remote_sheet.dart';
import '../../physics.dart';

import '../../haptics.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

class DisconnectedBanner extends ConsumerWidget {
  const DisconnectedBanner({
    super.key,
    required this.onRetry,
    this.onPairAgain,
  });
  final VoidCallback onRetry;
  final VoidCallback? onPairAgain;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final pairAgain = onPairAgain;
    final bluetooth = ref.watch(bluetoothRemoteProvider);
    if (bluetooth.supported) {
      return SpringIn(
        rise: -16,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.warning_amber_outlined, color: c.danger),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  pairAgain != null
                      ? "The TV doesn't recognise this phone any more. Pair it again."
                      : 'TV is asleep or off Wi-Fi. Wake it with the physical remote.',
                  style: context.appTextTheme.labelMedium!.copyWith(color: c.onSurface),
                )),
              ]),
              Wrap(children: [
                TextButton(
                  onPressed: () { AppHaptics.selection(); (pairAgain ?? onRetry)(); },
                  style: TextButton.styleFrom(foregroundColor: c.primaryText),
                  child: Text(pairAgain != null ? 'Pair again' : 'Retry'),
                ),
                TextButton(
                  onPressed: bluetooth.busy ? null : () {
                    AppHaptics.selection();
                    if (bluetooth.hostAddress != null) {
                      ref.read(bluetoothRemoteProvider.notifier).wake();
                    } else {
                      showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => const BluetoothRemoteSheet());
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: c.primaryText),
                  child: Text(bluetooth.hostAddress != null ? 'Wake with Bluetooth' : 'Use Bluetooth'),
                ),
              ]),
              if (bluetooth.error != null)
                Text(bluetooth.error!, style: context.appTextTheme.labelSmall!.copyWith(color: c.danger)),
            ],
          ),
        ),
      );
    }
    return SpringIn(
      rise: -16,
      child: Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: c.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                pairAgain != null
                    ? "The TV doesn't recognise this phone any more. Pair it again."
                    : 'TV is asleep or off Wi-Fi. Wake it with the physical remote.',
                style: context.appTextTheme.labelMedium!.copyWith(
                  color: c.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                AppHaptics.selection();
                (pairAgain ?? onRetry)();
              },
              style: TextButton.styleFrom(foregroundColor: c.primaryText),
              child: Text(pairAgain != null ? 'Pair again' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
