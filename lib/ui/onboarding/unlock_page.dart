/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adb/full_control.dart';
import '../../core/session/providers.dart';
import 'unlock_screen.dart';

class UnlockPage extends ConsumerWidget {
  const UnlockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final control = ref.watch(fullControlProvider);
    final status = control.status;
    final connected = status == FullControlStatus.connected;
    final statusText = switch (status) {
      FullControlStatus.off => 'Full control: not connected',
      FullControlStatus.connecting => 'Connecting…',
      FullControlStatus.waitingForApproval => 'Choose Allow on the TV',
      FullControlStatus.connected => 'Full control: connected',
      FullControlStatus.failed =>
        control.error ?? 'Full control connection failed',
    };
    return UnlockScreen(
      statusText: statusText,
      connecting:
          status == FullControlStatus.connecting ||
          status == FullControlStatus.waitingForApproval,
      connected: connected,
      deviceName: ref.watch(activeTvProvider)?.name,
      onConnect: () {
        if (connected) {
          Navigator.of(context).pop();
        } else {
          ref.read(fullControlProvider.notifier).connect();
        }
      },
      onSkip: () => Navigator.of(context).pop(),
      onBack: () => Navigator.of(context).pop(),
    );
  }
}
