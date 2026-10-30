/**
 * @author Shakib
 * @since 30/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/ui/remote/remote_models.dart';
import 'package:xiaomi_remote/ui/remote/widgets/seek_bar.dart';
import 'package:xiaomi_remote/ui/theme/app_theme.dart';

void main() {
  testWidgets('seeking sends one target on release', (tester) async {
    final targets = <Duration>[];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: SizedBox(width: 300, child: SeekBar(
        playing: const NowPlaying(title: 'Video', position: Duration(seconds: 20), duration: Duration(seconds: 100), playing: true, canSeek: true),
        position: const Duration(seconds: 20),
        onSeekTo: targets.add,
      )))),
    ));
    final slider = find.byType(Slider);
    final rect = tester.getRect(slider);
    final gesture = await tester.startGesture(Offset(rect.left + rect.width * .25, rect.center.dy));
    await gesture.moveTo(Offset(rect.left + rect.width * .7, rect.center.dy));
    await tester.pump();
    expect(targets, isEmpty);
    await gesture.up();
    await tester.pump();
    expect(targets, hasLength(1));
    expect(targets.single.inSeconds, inInclusiveRange(60, 80));
  });
}
