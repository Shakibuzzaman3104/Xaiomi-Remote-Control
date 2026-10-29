/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/ui/apps/apps_screen.dart';
import 'package:xiaomi_remote/ui/onboarding/discover_screen.dart';
import 'package:xiaomi_remote/ui/onboarding/pair_screen.dart';
import 'package:xiaomi_remote/ui/remote/remote_models.dart';
import 'package:xiaomi_remote/ui/remote/remote_screen.dart';
import 'package:xiaomi_remote/ui/remote/widgets/device_header.dart';
import 'package:xiaomi_remote/ui/theme/app_theme.dart';

Widget _app(Widget home, {bool reduced = false}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: child!,
  ),
  home: home,
);

Widget _header(bool connected) => Scaffold(
  body: DeviceHeader(
    name: 'TV',
    connected: connected,
    onSwitchDevice: () {},
    onTvSettings: () {},
    onAppSettings: () {},
  ),
);

Widget _discover({bool timedOut = false}) => Scaffold(
  body: DiscoverScreen(
    devices: const [],
    searching: true,
    timedOut: timedOut,
    onSelect: (_) {},
    onEnterIp: () {},
  ),
);

TvAppItem _item(String label, {bool favourite = false}) => TvAppItem(
  package: label,
  label: label,
  icon: const Icon(Icons.tv),
  isFavourite: favourite,
);

Widget _apps(List<TvAppItem> items) => AppsScreen(
  onBack: () {},
  apps: items,
  onOpen: (_) {},
  onShowActions: (_) {},
);

void main() {
  testWidgets('connecting pulse runs only while reconnecting', (tester) async {
    await tester.pumpWidget(_app(_header(false)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(_app(_header(true)));
    await tester.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('connecting pulse is static under Reduce Motion', (tester) async {
    await tester.pumpWidget(_app(_header(false), reduced: true));
    await tester.pumpAndSettle();
    expect(find.text('Reconnecting…'), findsOneWidget);
  });

  testWidgets('radar pulses while searching and stops afterwards', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_discover()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(_app(_discover(timedOut: true)));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('switching pad modes ignores the outgoing pad', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final buttons = <RemoteButton>[];
    await tester.pumpWidget(
      _app(
        RemoteScreen(
          state: const RemoteViewState(
            deviceName: 'TV',
            connected: true,
            reconnecting: false,
            muted: false,
          ),
          onButton: buttons.add,
          onSwitchDevice: () {},
          onOpenNowPlaying: () {},
          onApps: () {},
          onKeyboard: () {},
          onVoice: () {},
          onRetry: () {},
          onAppSettings: () {},
          onPointerMove: (_) {},
          onScroll: (_) {},
          onClick: (_) {},
          onAirMouseChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.byTooltip('Numpad'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('5'));
    await tester.pump();
    expect(buttons, [RemoteButton.digit5]);
    await tester.pumpAndSettle();
  });

  testWidgets('wrong code shakes once and settles', (tester) async {
    await tester.pumpWidget(
      _app(
        PairScreen(
          deviceName: 'TV',
          onSubmit: (_) async => 'Wrong code',
          onBack: () {},
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Wrong code'), findsOneWidget);
  });

  testWidgets('pair success shows the check', (tester) async {
    await tester.pumpWidget(
      _app(
        PairScreen(
          deviceName: 'TV',
          onSubmit: (_) async => null,
          onBack: () {},
          success: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Paired'), findsOneWidget);
    expect(find.text('Pair'), findsNothing);
  });

  testWidgets('apps entrance plays once and favourite star pops on change', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_apps([_item('A'), _item('B')])));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(_apps([_item('A'), _item('B')])));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(
      _app(_apps([_item('A', favourite: true), _item('B')])),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('apps skeleton pulses while loading and respects Reduce Motion', (
    tester,
  ) async {
    Widget loading() => AppsScreen(
      onBack: () {},
      apps: const [],
      onOpen: (_) {},
      onShowActions: (_) {},
      loading: true,
    );
    await tester.pumpWidget(_app(loading()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(_app(loading(), reduced: true));
    await tester.pumpAndSettle();
  });
}
