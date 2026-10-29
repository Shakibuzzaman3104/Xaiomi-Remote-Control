/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/providers.dart';
import '../../core/settings/app_preferences.dart';
import '../../core/session/tv_session.dart';
import '../apps/apps_page.dart';
import 'remote_models.dart';
import 'remote_screen.dart';

/// The Remote screen driven by the active TV session.
class ConnectedRemotePage extends ConsumerStatefulWidget {
  const ConnectedRemotePage({
    super.key,
    required this.onSwitchDevice,
    required this.onAppSettings,
    required this.onKeyboard,
    required this.onVoice,
  });
  final VoidCallback onSwitchDevice, onAppSettings, onKeyboard, onVoice;

  @override
  ConsumerState<ConnectedRemotePage> createState() =>
      _ConnectedRemotePageState();
}

class _ConnectedRemotePageState extends ConsumerState<ConnectedRemotePage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(tvSessionProvider)?.retryNow();
    }
  }

  void _showApps() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppsPage(
          onAppSettings: widget.onAppSettings,
          onSwitchDevice: widget.onSwitchDevice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tv = ref.watch(activeTvProvider);
    final session = ref.watch(tvSessionProvider);
    final sessionState =
        ref.watch(tvSessionStateProvider).asData?.value ??
        const TvSessionState(status: SessionStatus.connecting);
    final atv = sessionState.atv;
    final status = sessionState.status;

    return RemoteScreen(
      swipeSensitivity: ref.watch(appPreferencesProvider).swipeSensitivity,
      state: RemoteViewState(
        deviceName: tv?.name ?? 'No TV',
        connected: status == SessionStatus.connected,
        reconnecting:
            status == SessionStatus.connecting ||
            status == SessionStatus.reconnecting,
        volumeLevel: atv.volumeMax > 0
            ? (atv.volumeLevel * 100 / atv.volumeMax).round()
            : null,
        muted: atv.muted,
      ),
      onButton: (button) => session?.press(button),
      onSwitchDevice: widget.onSwitchDevice,
      onOpenNowPlaying: () {},
      onApps: _showApps,
      onKeyboard: widget.onKeyboard,
      onVoice: widget.onVoice,
      onRetry: () => session?.retryNow(),
      onAppSettings: widget.onAppSettings,
      onPointerMove: (_) {},
      onScroll: (_) {},
      onClick: (_) {},
      onAirMouseChanged: (_) {},
      mouseAvailable: false,
    );
  }
}
