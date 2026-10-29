/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/adb/full_control.dart';
import 'package:xiaomi_remote/core/settings/favourites.dart';
import 'package:xiaomi_remote/core/session/providers.dart';
import 'package:xiaomi_remote/core/storage/paired_tv_store.dart';
import 'package:xiaomi_remote/ui/apps/app_actions_sheet.dart';
import 'package:xiaomi_remote/ui/apps/apps_page.dart';
import 'package:xiaomi_remote/ui/apps/apps_screen.dart';
import 'package:xiaomi_remote/ui/settings/settings_screen.dart';
import 'package:xiaomi_remote/ui/settings/settings_view.dart';
import 'package:xiaomi_remote/ui/theme/app_theme.dart';
import 'package:xiaomi_remote/ui/theme/theme_mode_provider.dart';

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
    themeLabel: 'System',
    onThemeTap: noop,
    appVersion: '1.0.0',
    onAboutTap: noop,
  );
  Widget appScreen(ValueChanged<TvAppItem> actions) => AppsScreen(
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
    await tester.pumpAndSettle();
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('YouTube'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favourites'));
    await tester.pumpAndSettle();
    expect(find.text('Netflix'), findsNothing);
    await tester.longPress(find.text('YouTube'));
    await tester.pumpAndSettle();
    expect(selected, same(apps.first));
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No apps match "missing"'), findsOneWidget);
  });
  testWidgets('empty favourites shows its own message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppsScreen(
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
  testWidgets('full control actions ask for setup when off', (tester) async {
    var called = false;
    var needsControl = false;
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
            onNeedFullControl: () => needsControl = true,
          ),
        ),
      ),
    );
    expect(find.text('Needs Full control'), findsNWidgets(4));
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(4));
    await tester.tap(find.text('Force stop'));
    expect(called, isFalse);
    expect(needsControl, isTrue);
  });
  testWidgets('paired TV row exposes a remove action', (tester) async {
    String? removed;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsView(
          devices: const [
            SettingsDevice(
              id: '1',
              name: 'Living Room',
              subtitle: 'host',
              isActive: true,
            ),
          ],
          onSelectDevice: (_) {},
          onRemoveDevice: (id) => removed = id,
          onAddTv: noop,
          hapticsEnabled: false,
          onHapticsChanged: (_) {},
          volumeKeysEnabled: false,
          onVolumeKeysChanged: (_) {},
          swipeSensitivity: .5,
          onSwipeSensitivityChanged: (_) {},
          micButtonLabel: 'Search YouTube',
          onMicButtonTap: noop,
          speechLanguageLabel: 'English',
          onSpeechLanguageTap: noop,
          adbConnected: false,
          onNetworkDebuggingTap: noop,
          themeLabel: 'System',
          onThemeTap: noop,
          appVersion: '1.0.0',
          onAboutTap: noop,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Remove Living Room'));
    expect(removed, '1');
  });
  testWidgets('force stop confirms with a snack bar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fullControlProvider.overrideWith(_FakeControl.new),
          favouritesProvider.overrideWith(_FakeFavourites.new),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const AppsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('YouTube'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Force stop'));
    await tester.pumpAndSettle();
    expect(find.text('Stopped YouTube'), findsOneWidget);
  });
  testWidgets('removing a TV asks for confirmation first', (tester) async {
    final store = _MemoryStore();
    final saved = PairedTvStore(store);
    for (final (id, name) in [('1', 'Living Room'), ('2', 'Bedroom')]) {
      await saved.save(
        PairedTv(
          id: id,
          name: name,
          host: 'host-$id',
          certPem: 'cert',
          privateKeyPem: 'key',
          pairedAt: DateTime(2026),
        ),
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pairedTvStoreProvider.overrideWithValue(saved),
          keyValueStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: SettingsScreen(
            onAddTv: noop,
            onOpenFullControl: noop,
            onBack: noop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Living Room'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Living Room?'), findsOneWidget);
    expect(
      find.text("You'll need to pair it again to use it."),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Living Room'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove Living Room'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Living Room'), findsNothing);
    expect(find.text('Bedroom'), findsOneWidget);
  });
  testWidgets('settings names Full control and offers to turn it off', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsView(
          devices: const [],
          onSelectDevice: (_) {},
          onRemoveDevice: (_) {},
          onAddTv: noop,
          hapticsEnabled: true,
          onHapticsChanged: (_) {},
          volumeKeysEnabled: true,
          onVolumeKeysChanged: (_) {},
          swipeSensitivity: .5,
          onSwipeSensitivityChanged: (_) {},
          micButtonLabel: 'Search YouTube',
          onMicButtonTap: noop,
          speechLanguageLabel: 'English',
          onSpeechLanguageTap: noop,
          adbConnected: true,
          onNetworkDebuggingTap: noop,
          onTurnOffFullControl: noop,
          themeLabel: 'System',
          onThemeTap: noop,
          appVersion: '1.0.0',
          onAboutTap: noop,
        ),
      ),
    );
    expect(find.text('Full control'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Turn off Full control'), findsOneWidget);
  });
}

class _MemoryStore implements KeyValueStore {
  final _values = <String, String>{};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
  @override
  Future<void> delete(String key) async => _values.remove(key);
}

class _FakeFavourites extends Favourites {
  @override
  Set<String> build() => const {};
}

class _FakeControl extends FullControl {
  @override
  FullControlState build() => const FullControlState(
    status: FullControlStatus.connected,
    apps: [TvApp(package: 'one', label: 'YouTube', isTvApp: true)],
  );

  @override
  Future<void> forceStop(String package) async {}
}
