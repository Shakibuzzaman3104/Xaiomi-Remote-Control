/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/session/providers.dart';
import 'core/discovery/tv_discovery.dart';
import 'ui/fade_switcher.dart';
import 'ui/onboarding/onboarding_flow.dart';
import 'ui/onboarding/unlock_page.dart';
import 'ui/remote/remote_home.dart';
import 'ui/settings/preferences_sync.dart';
import 'ui/settings/settings_screen.dart';
import 'ui/sheets/tv_switcher_sheet.dart';
import 'ui/theme/app_colors.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/theme_mode_provider.dart';

void main() => runApp(
  const ProviderScope(child: PreferencesSync(child: XiaomiRemoteApp())),
);

class XiaomiRemoteApp extends ConsumerWidget {
  const XiaomiRemoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'Xiaomi Remote',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ref.watch(themeModeProvider),
    home: const AppRoot(),
  );
}

/// Shows onboarding until a TV is paired, then the Remote.
class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  bool _firstRunInProgress = false;

  void _openAddTv(BuildContext context, {DiscoveredTv? initialTv}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (routeContext) => OnboardingFlow(
            initialTv: initialTv,
            onCancel: () => Navigator.of(routeContext).pop(),
            onFinished: () =>
                Navigator.of(routeContext).popUntil((route) => route.isFirst),
          ),
        ),
      );

  void _openSwitcher(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.colors.surfaceContainer,
      builder: (sheetContext) => TvSwitcherSheet(
        onAddTv: () {
          Navigator.of(sheetContext).pop();
          _openAddTv(context);
        },
        onSettings: () {
          Navigator.of(sheetContext).pop();
          _openSettings(context);
        },
      ),
    );
  }

  void _openSettings(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (routeContext) => SettingsScreen(
        onAddTv: () => _openAddTv(context),
        onOpenFullControl: () => Navigator.of(routeContext)
            .push(MaterialPageRoute<void>(builder: (_) => const UnlockPage())),
        onBack: () => Navigator.of(routeContext).pop(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final paired = ref.watch(pairedTvsProvider);
    final Widget screen;
    if (paired.isLoading && !paired.hasValue) {
      screen = const Scaffold(
        key: ValueKey('loading'),
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (ref.watch(activeTvProvider) == null || _firstRunInProgress) {
      _firstRunInProgress = true;
      screen = OnboardingFlow(
        key: const ValueKey('onboarding'),
        onFinished: () => setState(() => _firstRunInProgress = false),
      );
    } else {
      screen = RemoteHome(
        key: const ValueKey('remote'),
        onAddTv: () => _openSwitcher(context),
        onAppSettings: () => _openSettings(context),
        onPairAgain: () {
          final tv = ref.read(activeTvProvider);
          if (tv != null) {
            _openAddTv(
              context,
              initialTv: DiscoveredTv(
                name: tv.name,
                host: tv.host,
                model: tv.model,
              ),
            );
          }
        },
      );
    }
    return FadeSwitcher(scale: 1, expand: true, child: screen);
  }
}
