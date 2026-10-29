/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/ui/theme/app_theme.dart';
import 'package:xiaomi_remote/ui/remote/widgets/volume_pill.dart';

void main() {
  testWidgets('exact volume slider reports drag end', (tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: VolumePill(
            level: 50,
            muted: false,
            onButton: (_) {},
            exactIndex: 5,
            exactMax: 10,
            onExactVolumeChanged: (value) => selected = value,
          ),
        ),
      ),
    );
    expect(find.byType(Slider), findsOneWidget);
    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(selected, isNotNull);
    expect(selected!, greaterThan(5));
  });

  testWidgets('volume pill retains label mode without exact volume', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: VolumePill(level: 50, muted: false, onButton: (_) {}),
        ),
      ),
    );
    expect(find.byType(Slider), findsNothing);
    expect(find.text('Volume 50%'), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
