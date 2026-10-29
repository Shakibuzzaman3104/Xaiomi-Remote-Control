/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/main.dart';
import 'package:xiaomi_remote/ui/remote/remote_models.dart';
import 'package:xiaomi_remote/ui/remote/remote_screen.dart';
import 'package:xiaomi_remote/ui/remote/widgets/dpad.dart';
import 'package:xiaomi_remote/ui/theme/app_theme.dart';

void main() {
  testWidgets('demo renders at phone size and larger text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final scale in [1.0, 1.3]) {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 780),
            textScaler: TextScaler.linear(scale),
          ),
          child: const XiaomiRemoteApp(),
        ),
      );
      await tester.pump();
      expect(find.text('Living Room · Mi Box S'), findsOneWidget);
      expect(find.text('Me at the zoo'), findsOneWidget);
      expect(find.text('Favourite apps'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
          favourites: const [],
        ),
        onButton: buttons.add,
        onSwitchDevice: () {},
        onOpenNowPlaying: () {},
        onOpenApp: (_) {},
        onEditFavourites: () {},
        onKeyboard: () {},
        onVoice: () {
          voices++;
        },
        onRetry: () {},
        onMenu: () {},
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
    await tester.ensureVisible(find.byIcon(Icons.mic_none));
    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.pump();
    expect(voices, 1);
    await tester.ensureVisible(find.text('Numpad'));
    await tester.tap(find.text('Numpad'));
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
