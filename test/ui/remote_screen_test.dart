/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/ui/remote/remote_models.dart';
import 'package:xiaomi_remote/ui/remote/remote_screen.dart';
import 'package:xiaomi_remote/ui/remote/widgets/dpad.dart';
import 'package:xiaomi_remote/ui/theme/app_theme.dart';

void main() {
  testWidgets('overlapping dpad pointers do not leak repeats', (tester) async {
    final buttons = <RemoteButton>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Center(
          child: SizedBox(width: 200, child: Dpad(onButton: buttons.add)),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(Dpad));
    final first = await tester.startGesture(
      center + const Offset(0, -70),
      pointer: 1,
    );
    await tester.pump(const Duration(milliseconds: 400));
    final second = await tester.startGesture(
      center + const Offset(70, 0),
      pointer: 2,
    );
    await second.up();
    await tester.pump(const Duration(milliseconds: 250));
    expect(buttons.every((button) => button == RemoteButton.up), isTrue);
    expect(buttons.length, greaterThan(2));
    await first.up();
    final count = buttons.length;
    await tester.pump(const Duration(seconds: 1));
    expect(buttons.length, count);
  });
  testWidgets('renders at phone size, larger text and both themes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      for (final scale in [1.0, 1.3]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 780),
                textScaler: TextScaler.linear(scale),
              ),
              child: RemoteScreen(
                state: RemoteViewState(
                  deviceName: 'Living Room · Mi Box S',
                  connected: true,
                  reconnecting: false,
                  nowPlaying: const NowPlaying(
                    title: 'Me at the zoo',
                    position: Duration(seconds: 12),
                    duration: Duration(seconds: 19),
                    playing: true,
                  ),
                  volumeLevel: 12,
                  muted: false,
                ),
                onButton: (_) {},
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
          ),
        );
        await tester.pump();
        expect(find.text('Living Room · Mi Box S'), findsOneWidget);
        expect(find.text('Me at the zoo'), findsOneWidget);
        expect(find.text('Play'), findsNothing);
        expect(find.text('Pause'), findsOneWidget);
        expect(find.text('Favourite apps'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets('buttons, repeats, numpad and disconnected state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final buttons = <RemoteButton>[];
    var voices = 0;
    Widget screen(bool connected) => MaterialApp(
      theme: AppTheme.light,
      home: RemoteScreen(
        key: ValueKey(connected),
        state: RemoteViewState(
          deviceName: 'TV',
          connected: connected,
          reconnecting: !connected,
          muted: false,
        ),
        onButton: buttons.add,
        onSwitchDevice: () {},
        onOpenNowPlaying: () {},
        onApps: () {},
        onKeyboard: () {},
        onVoice: () {
          voices++;
        },
        onRetry: () {},
        onAppSettings: () {},
        onPointerMove: (_) {},
        onScroll: (_) {},
        onClick: (_) {},
        onAirMouseChanged: (_) {},
      ),
    );
    await tester.pumpWidget(screen(true));
    final rect = tester.getRect(find.byType(Dpad));
    final center = rect.center;
    final r = rect.width * .35;
    for (final pair in [
      (center, RemoteButton.ok),
      (center + Offset(0, -r), RemoteButton.up),
      (center + Offset(0, r), RemoteButton.down),
      (center + Offset(-r, 0), RemoteButton.left),
      (center + Offset(r, 0), RemoteButton.right),
    ]) {
      await tester.tapAt(pair.$1);
      await tester.pump();
      expect(buttons.last, pair.$2);
    }
    final count = buttons.where((b) => b == RemoteButton.up).length;
    final gesture = await tester.startGesture(center + Offset(0, -r));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pump();
    expect(
      buttons.where((b) => b == RemoteButton.up).length,
      greaterThan(count + 1),
    );
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(buttons.last, RemoteButton.back);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(buttons.last, RemoteButton.volumeUp);
    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(buttons.last, RemoteButton.playPause);
    await tester.tap(find.byTooltip('Power'));
    await tester.pump();
    expect(buttons.last, RemoteButton.power);
    await tester.ensureVisible(find.byIcon(Icons.mic_none));
    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.pump();
    expect(voices, 1);
    await tester.ensureVisible(find.byTooltip('Numpad'));
    await tester.tap(find.byTooltip('Numpad'));
    await tester.pump();
    await tester.tap(find.text('5'));
    await tester.pump();
    expect(buttons.last, RemoteButton.digit5);
    await tester.pumpWidget(screen(false));
    await tester.pump();
    expect(find.textContaining('TV is asleep'), findsOneWidget);
    final before = buttons.length;
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(buttons.length, before);
  });
}
