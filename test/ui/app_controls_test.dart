/**
 * @author Shakib
 * @since 30/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/ui/remote/remote_models.dart';
import 'package:xiaomi_remote/ui/remote/widgets/app_controls.dart';
import 'package:xiaomi_remote/ui/theme/app_theme.dart';

void main() {
  testWidgets('YouTube controls appear and send chip actions', (tester) async {
    final buttons = <RemoteButton>[];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: AppControls(
        data: const AppControlData(package: 'com.google.android.youtube.tv', label: 'YouTube'),
        onSeekBy: (_) {}, onButton: buttons.add, onSearch: () {},
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('YouTube'), findsOneWidget);
    await tester.tap(find.text('Captions'));
    expect(buttons, [RemoteButton.captions]);
  });

  testWidgets('other apps have no controls', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: AppControls(
        data: const AppControlData(package: 'other.app', label: 'Other'),
        onSeekBy: (_) {}, onButton: (_) {}, onSearch: () {},
      )),
    ));
    expect(find.byType(ActionChip), findsNothing);
  });
}
