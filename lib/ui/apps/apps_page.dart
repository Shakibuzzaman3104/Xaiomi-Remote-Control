/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adb/full_control.dart';
import '../../core/session/app_links.dart';
import '../../core/session/providers.dart';
import '../../core/settings/favourites.dart';
import '../haptics.dart';
import '../motion.dart';
import '../onboarding/unlock_page.dart';
import 'app_actions_sheet.dart';
import 'apps_screen.dart';

class AppsPage extends ConsumerStatefulWidget {
  const AppsPage({super.key});

  @override
  ConsumerState<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends ConsumerState<AppsPage> {
  void _toast(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  void _openFullControlSetup() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const UnlockPage()));
  }

  Future<void> _showError(
    Object error, {
    TvAppItem? app,
    _AppAction action = _AppAction.other,
  }) async {
    final raw = error.toString().toLowerCase();
    if (action == _AppAction.uninstall &&
        (raw.contains('delete_failed') || raw.contains('system app'))) {
      _toast(
        "Can't uninstall ${app?.label ?? 'this app'}. It came with the TV.",
      );
      return;
    }
    if (action == _AppAction.clearCache && app != null) {
      _toast(
        "Couldn't clear the cache. Opening ${app.label} info on the TV instead.",
      );
      try {
        await ref.read(fullControlProvider.notifier).openAppInfo(app.package);
      } catch (_) {}
      return;
    }
    _toast("That didn't work. Try again.");
  }

  Future<void> _run(
    Future<void> Function() action, {
    TvAppItem? app,
    _AppAction kind = _AppAction.other,
    String? done,
  }) async {
    try {
      await action();
      if (done != null) _toast(done);
    } catch (error) {
      await _showError(error, app: app, action: kind);
    }
  }

  Future<void> _open(TvAppItem app) async {
    if (ref.read(fullControlProvider).status == FullControlStatus.connected) {
      _toast('Opening ${app.label}…');
      try {
        await ref.read(fullControlProvider.notifier).launch(app.package);
        if (mounted) Navigator.of(context).pop();
      } catch (error) {
        await _showError(error);
      }
      return;
    }
    final known = knownApps
        .where((item) => item.package == app.package)
        .firstOrNull;
    final link = known?.webLink;
    if (link == null) {
      _toast(
        'Turn on Full control to open ${app.label}',
        action: SnackBarAction(
          label: 'Set up',
          onPressed: _openFullControlSetup,
        ),
      );
      return;
    }
    final session = ref.read(tvSessionProvider);
    if (session == null || !session.isConnected) {
      _toast('The TV is not connected');
      return;
    }
    session.launchLink(link);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _toggle(String package) {
    AppHaptics.selection();
    return _run(() => ref.read(favouritesProvider.notifier).toggle(package));
  }

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
        app: app,
        kind: _AppAction.uninstall,
        done: 'Uninstalled ${app.label}',
      );
    }
  }

  void _showActions(TvAppItem app) {
    final connected =
        ref.read(fullControlProvider).status == FullControlStatus.connected;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: sheetAnimation(context),
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
          onNeedFullControl: () => closeAndRun(_openFullControlSetup),
          onForceStop: () => closeAndRun(
            () => _run(
              () =>
                  ref.read(fullControlProvider.notifier).forceStop(app.package),
              app: app,
              done: 'Stopped ${app.label}',
            ),
          ),
          onClearCache: () => closeAndRun(
            () => _run(
              () => ref
                  .read(fullControlProvider.notifier)
                  .clearCache(app.package),
              app: app,
              kind: _AppAction.clearCache,
              done: 'Cleared cache for ${app.label}',
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
      onBack: () => Navigator.of(context).pop(),
      apps: apps,
      onOpen: _open,
      onShowActions: _showActions,
      onToggleFavourite: (app) => _toggle(app.package),
      onNoticeTap: connected ? null : _openFullControlSetup,
      notice: !connected
          ? 'Turn on Full control to see every app on your TV.'
          : null,
      loading: control.appsLoading,
      errorText: connected ? control.error : null,
      onRetry: () => ref.read(fullControlProvider.notifier).loadApps(),
      onRefresh: connected
          ? () => ref.read(fullControlProvider.notifier).loadApps()
          : null,
    );
  }
}

enum _AppAction { other, clearCache, uninstall }
