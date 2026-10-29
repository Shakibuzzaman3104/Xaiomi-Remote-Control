/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adb/full_control.dart';
import '../../core/session/app_links.dart';
import '../../core/session/providers.dart';
import '../../core/session/remote_button.dart';
import '../../core/session/tv_session.dart';
import '../../core/settings/favourites.dart';
import '../onboarding/unlock_page.dart';
import 'app_actions_sheet.dart';
import 'apps_screen.dart';

class AppsPage extends ConsumerStatefulWidget {
  const AppsPage({
    super.key,
    required this.onAppSettings,
    required this.onSwitchDevice,
  });
  final VoidCallback onAppSettings;
  final VoidCallback onSwitchDevice;

  @override
  ConsumerState<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends ConsumerState<AppsPage> {
  void _showError(Object error) {
    if (!mounted) return;
    final message = error.toString().replaceFirst('AdbException: ', '');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _open(TvAppItem app) async {
    if (ref.read(fullControlProvider).status == FullControlStatus.connected) {
      try {
        await ref.read(fullControlProvider.notifier).launch(app.package);
        if (mounted) Navigator.of(context).pop();
      } catch (error) {
        _showError(error);
      }
      return;
    }
    final known = knownApps
        .where((item) => item.package == app.package)
        .firstOrNull;
    final link = known?.webLink;
    if (link == null) {
      _showError('Turn on full control to open ${app.label}');
      return;
    }
    final session = ref.read(tvSessionProvider);
    if (session == null || !session.isConnected) {
      _showError('The TV is not connected');
      return;
    }
    session.launchLink(link);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _toggle(String package) =>
      _run(() => ref.read(favouritesProvider.notifier).toggle(package));

  Future<void> _uninstall(TvAppItem app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Uninstall ${app.label}?'),
        content: const Text('This will remove the app from your TV.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(
        () => ref.read(fullControlProvider.notifier).uninstall(app.package),
      );
    }
  }

  void _showActions(TvAppItem app) {
    final connected =
        ref.read(fullControlProvider).status == FullControlStatus.connected;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        void closeAndRun(VoidCallback callback) {
          Navigator.of(sheetContext).pop();
          callback();
        }

        return AppActionsSheet(
          app: app,
          fullControl: connected,
          onOpen: () => closeAndRun(() => _open(app)),
          onToggleFavourite: () => closeAndRun(() => _toggle(app.package)),
          onForceStop: () => closeAndRun(
            () => _run(
              () =>
                  ref.read(fullControlProvider.notifier).forceStop(app.package),
            ),
          ),
          onClearCache: () => closeAndRun(
            () => _run(
              () => ref
                  .read(fullControlProvider.notifier)
                  .clearCache(app.package),
            ),
          ),
          onAppInfo: () => closeAndRun(
            () => _run(
              () => ref
                  .read(fullControlProvider.notifier)
                  .openAppInfo(app.package),
            ),
          ),
          onUninstall: () => closeAndRun(() => _uninstall(app)),
        );
      },
    );
  }

  Widget _icon(BuildContext context, String label, TvApp? app) {
    final bytes = app?.iconPng;
    final fallback = CircleAvatar(
      child: Text(label.isEmpty ? '?' : label.characters.first.toUpperCase()),
    );
    final cacheSize = (56 * MediaQuery.devicePixelRatioOf(context)).round();
    return bytes == null
        ? fallback
        : Image.memory(
            bytes,
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => fallback,
          );
  }

  @override
  Widget build(BuildContext context) {
    final control = ref.watch(fullControlProvider);
    final favourites = ref.watch(favouritesProvider);
    final connected = control.status == FullControlStatus.connected;
    final session = ref.watch(tvSessionProvider);
    final sessionStatus = ref
        .watch(tvSessionStateProvider)
        .asData
        ?.value
        .status;
    final apps = connected
        ? [
            for (final app in control.apps)
              TvAppItem(
                package: app.package,
                label: app.label,
                icon: _icon(context, app.label, app),
                isFavourite: favourites.contains(app.package),
              ),
          ]
        : [
            for (final app in [
              ...knownApps.where((app) => app.webLink != null),
              ...knownApps.where((app) => app.webLink == null),
            ])
              TvAppItem(
                package: app.package,
                label: app.label,
                icon: _icon(context, app.label, null),
                isFavourite: favourites.contains(app.package),
                dimmed: app.webLink == null,
              ),
          ];
    return AppsScreen(
      deviceName: ref.watch(activeTvProvider)?.name ?? 'No TV',
      connected: sessionStatus == SessionStatus.connected,
      onSwitchDevice: widget.onSwitchDevice,
      onAppSettings: widget.onAppSettings,
      onPower: () => session?.press(RemoteButton.power),
      onTvSettings: () => session?.press(RemoteButton.settings),
      onBack: () => Navigator.of(context).pop(),
      apps: apps,
      onOpen: _open,
      onShowActions: _showActions,
      onToggleFavourite: (app) => _toggle(app.package),
      onNoticeTap: connected
          ? null
          : () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const UnlockPage())),
      notice: !connected
          ? 'Turn on full control to see every app on your TV.'
          : null,
      loading: control.appsLoading,
      errorText: connected ? control.error : null,
      onRetry: () => ref.read(fullControlProvider.notifier).loadApps(),
    );
  }
}
