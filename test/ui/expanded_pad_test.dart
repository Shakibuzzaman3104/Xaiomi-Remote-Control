/**
 * @author Shakib
 * @since 30/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/ui/remote/expanded_pad_page.dart';
import 'package:xiaomi_remote/ui/remote/remote_models.dart';
import 'package:xiaomi_remote/ui/remote/remote_screen.dart';
import 'package:xiaomi_remote/ui/remote/widgets/swipe_pad.dart';
import 'package:xiaomi_remote/ui/theme/app_theme.dart';

void main() {
  testWidgets('expands swipe pad, sends direction and closes', (tester) async {
    final buttons = <RemoteButton>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RemoteScreen(
          initialMode: RemoteMode.swipe,
          state: RemoteViewState(
            deviceName: 'TV',
            connected: true,
            reconnecting: false,
            muted: false,
          ),
          onButton: buttons.add,
          onSwitchDevice: () {},
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
    await tester.tap(find.byTooltip('Expand pad'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpandedPadPage), findsOneWidget);
    final pad = find.descendant(
      of: find.byType(ExpandedPadPage),
      matching: find.byType(SwipePad),
    );
    await tester.drag(pad, const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(buttons, contains(RemoteButton.right));
    await tester.tap(find.byTooltip('Collapse pad'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpandedPadPage), findsNothing);
    expect(find.byTooltip('Expand pad'), findsOneWidget);
  });

  testWidgets('mouse expands in landscape with scroll and click controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(780, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final clicks = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RemoteScreen(
          initialMode: RemoteMode.mouse,
          state: RemoteViewState(
            deviceName: 'TV',
            connected: true,
            reconnecting: false,
            muted: false,
          ),
          onButton: (_) {},
          onSwitchDevice: () {},
          onApps: () {},
          onKeyboard: () {},
          onVoice: () {},
          onRetry: () {},
          onAppSettings: () {},
          onPointerMove: (_) {},
          onScroll: (_) {},
          onClick: clicks.add,
          onAirMouseChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.byTooltip('Expand pad'));
    await tester.pumpAndSettle();
    final page = find.byType(ExpandedPadPage);
    expect(
      find.descendant(of: page, matching: find.bySemanticsLabel('Scroll')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: page, matching: find.bySemanticsLabel('Air mouse')),
      findsNothing,
    );
    await tester.tap(
      find.descendant(of: page, matching: find.bySemanticsLabel('Click')),
    );
    expect(clicks, [false]);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(page, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
