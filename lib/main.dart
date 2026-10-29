/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/session/providers.dart';
import 'ui/onboarding/onboarding_flow.dart';
import 'ui/onboarding/unlock_page.dart';
import 'ui/remote/remote_home.dart';
import 'ui/settings/preferences_sync.dart';
import 'ui/settings/settings_screen.dart';
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
class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  void _openAddTv(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (routeContext) => Consumer(
        builder: (_, ref, child) {
          ref.listen(activeTvProvider, (previous, next) {
            if (next != null && next.id != previous?.id) {
              Navigator.of(routeContext).popUntil((route) => route.isFirst);
            }
          });
          return child!;
        },
        child: const OnboardingFlow(),
      ),
    ),
  );

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
  Widget build(BuildContext context, WidgetRef ref) {
    final paired = ref.watch(pairedTvsProvider);
    if (paired.isLoading && !paired.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (ref.watch(activeTvProvider) == null) return const OnboardingFlow();
    return RemoteHome(
      onAddTv: () => _openSettings(context),
      onAppSettings: () => _openSettings(context),
    );
  }
}
