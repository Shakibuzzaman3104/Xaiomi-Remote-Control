/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/ui/apps/app_actions_sheet.dart';
import 'package:xiaomi_remote/ui/apps/apps_screen.dart';
import 'package:xiaomi_remote/ui/settings/settings_view.dart';
import 'package:xiaomi_remote/ui/theme/app_theme.dart';

void main() {
  const apps = [
    TvAppItem(
      package: 'one',
      label: 'YouTube',
      icon: Icon(Icons.tv),
      isFavourite: true,
    ),
    TvAppItem(
      package: 'two',
      label: 'Netflix',
      icon: Icon(Icons.tv),
      isFavourite: false,
    ),
  ];
  void noop() {}
  Widget settings(ValueChanged<bool> changed) => SettingsView(
    devices: const [
      SettingsDevice(
        id: '1',
        name: 'Living Room',
        subtitle: 'host',
        isActive: true,
      ),
    ],
    onSelectDevice: (_) {},
    onRemoveDevice: (_) {},
    onAddTv: noop,
    hapticsEnabled: false,
    onHapticsChanged: changed,
    volumeKeysEnabled: false,
    onVolumeKeysChanged: changed,
    swipeSensitivity: .5,
    onSwipeSensitivityChanged: (_) {},
    micButtonLabel: 'Search YouTube',
    onMicButtonTap: noop,
    speechLanguageLabel: 'English',
    onSpeechLanguageTap: noop,
    adbConnected: true,
    onNetworkDebuggingTap: noop,
    companionInstalled: false,
    onCompanionTap: noop,
    themeLabel: 'System',
    onThemeTap: noop,
    appVersion: '1.0.0',
    onAboutTap: noop,
  );
  Widget appScreen(ValueChanged<TvAppItem> actions) => AppsScreen(
    deviceName: 'Living Room',
    connected: true,
    onSwitchDevice: noop,
    onTvSettings: noop,
    onAppSettings: noop,
    onBack: noop,
    apps: apps,
    onOpen: (_) {},
    onShowActions: actions,
  );

  for (final size in [const Size(360, 780), const Size(412, 915)]) {
    for (final scale in [1.0, 1.3]) {
      for (final dark in [false, true]) {
        testWidgets('presentation $size scale $scale dark $dark', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final theme = dark ? AppTheme.dark : AppTheme.light;
          Widget wrap(Widget child) => MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: child,
          );
          var changed = false;
          await tester.pumpWidget(wrap(settings((value) => changed = value)));
          await tester.tap(find.byType(Switch).first);
          expect(changed, isTrue);
          changed = false;
          await tester.tap(find.byType(Switch).last);
          expect(changed, isTrue);
          await tester.drag(find.byType(ListView), const Offset(0, -1000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(wrap(appScreen((_) {})));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(
            wrap(
              Scaffold(
                body: AppActionsSheet(
                  app: apps.first,
                  onOpen: noop,
                  onToggleFavourite: noop,
                  onForceStop: noop,
                  onClearCache: noop,
                  onAppInfo: noop,
                  onUninstall: noop,
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets('search, favourites and long press', (tester) async {
    TvAppItem? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: appScreen((app) => selected = app),
      ),
    );
    await tester.enterText(find.byType(TextField), 'NET');
    await tester.pump();
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('YouTube'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.text('Favourites'));
    await tester.pump();
    expect(find.text('Netflix'), findsNothing);
    await tester.longPress(find.text('YouTube'));
    expect(selected, same(apps.first));
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    expect(find.text('No apps match "missing"'), findsOneWidget);
  });
  testWidgets('empty favourites shows its own message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppsScreen(
          deviceName: 'Living Room',
          connected: true,
          onSwitchDevice: noop,
          onTvSettings: noop,
          onAppSettings: noop,
          onBack: noop,
          apps: const [
            TvAppItem(
              package: 'two',
              label: 'Netflix',
              icon: Icon(Icons.tv),
              isFavourite: false,
            ),
          ],
          onOpen: (_) {},
          onShowActions: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('Favourites'));
    await tester.pump();
    expect(find.text('No favourites yet'), findsOneWidget);
    expect(find.text('Long-press an app to add it here.'), findsOneWidget);
    expect(find.text('No apps match ""'), findsNothing);
  });
  testWidgets('full control actions are disabled', (tester) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppActionsSheet(
            app: apps.first,
            fullControl: false,
            onOpen: noop,
            onToggleFavourite: noop,
            onForceStop: () => called = true,
            onClearCache: noop,
            onAppInfo: noop,
            onUninstall: noop,
          ),
        ),
      ),
    );
    expect(find.text('Needs full control'), findsNWidgets(4));
    await tester.tap(find.text('Force stop'));
    expect(called, isFalse);
  });
}
