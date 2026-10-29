/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/app_links.dart';
import '../../core/session/providers.dart';
import '../../core/session/tv_session.dart';
import '../sheets/apps_sheet.dart';
import '../theme/app_colors.dart';
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

  void _openApp(FavouriteApp app) {
    final known = knownApps.firstWhere((a) => a.package == app.id);
    final link = known.webLink;
    Navigator.of(context).pop();
    if (link != null) {
      ref.read(tvSessionProvider)?.launchLink(link);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening ${known.label} needs full control')),
    );
  }

  Future<void> _showApps() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AppsSheet(
      favourites: [
        for (final app in knownApps.take(8))
          FavouriteApp(
            id: app.package,
            label: app.label,
            icon: _AppLetter(label: app.label),
          ),
      ],
      onOpen: _openApp,
      note: 'Turn on full control to see and open every app on the TV.',
    ),
  );

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
      state: RemoteViewState(
        deviceName: tv?.name ?? 'No TV',
        connected: status == SessionStatus.connected,
        reconnecting:
            status == SessionStatus.connecting ||
            status == SessionStatus.reconnecting,
        volumeLevel: atv.volumeMax > 0 ? atv.volumeLevel : null,
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
    );
  }
}

class _AppLetter extends StatelessWidget {
  const _AppLetter({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CircleAvatar(
      radius: 16,
      backgroundColor: colors.okButton,
      child: Text(
        label[0],
        style: TextStyle(
          color: colors.primaryText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
