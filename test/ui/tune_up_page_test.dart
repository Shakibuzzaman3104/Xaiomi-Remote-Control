/**
 * @author Shakib
 * @since 30/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/adb/adb_client.dart';
import 'package:xiaomi_remote/core/adb/adb_key.dart';
import 'package:xiaomi_remote/core/adb/tv_tuneup.dart';
import 'package:xiaomi_remote/core/session/providers.dart';
import 'package:xiaomi_remote/ui/theme/app_theme.dart';
import 'package:xiaomi_remote/ui/tuneup/tune_up_page.dart';

class _FakeTuneUp extends TvTuneUp {
  _FakeTuneUp()
    : super(AdbClient(host: '127.0.0.1', port: 1, key: AdbKey.generate()));
  int scans = 0;
  int memoryCalls = 0;
  int restartCalls = 0;
  final removed = <String>[];
  final restored = <String>[];
  final scales = <double>[];
  @override
  Future<TvTuneUpReport> scan() async {
    scans++;
    return TvTuneUpReport(
      health: const TvHealth(
        memoryFree: 1073741824,
        memoryTotal: 2040109466,
        storageFree: 1073741824,
        storageTotal: 2147483648,
      ),
      animationScale: 0.5,
      removable: [
        bloatCatalog[0],
        bloatCatalog[2],
        bloatCatalog[10],
        bloatCatalog[19],
      ],
      removed: const ['com.mitv.videoplayer'],
    );
  }

  @override
  Future<void> remove(String package) async {
    removed.add(package);
  }

  @override
  Future<void> restore(String package) async {
    restored.add(package);
  }

  @override
  Future<void> setAnimationScale(double scale) async {
    scales.add(scale);
  }

  @override
  Future<int> freeMemory() async {
    memoryCalls++;
    return 0;
  }

  @override
  Future<void> restart() async {
    restartCalls++;
  }
}

Widget _page(TvTuneUp? tv) => ProviderScope(
  overrides: [
    tvTuneUpProvider.overrideWithValue(tv),
    activeTvProvider.overrideWith((ref) => null),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const TuneUpPage()),
);

void _largeScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('shows health and grouped selections', (tester) async {
    _largeScreen(tester);
    final tv = _FakeTuneUp();
    await tester.pumpWidget(_page(tv));
    await tester.pump();
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('1.0 GB free of 1.9 GB'), findsOneWidget);
    expect(find.text('Ads & tracking'), findsOneWidget);
    expect(find.text('Xiaomi extras'), findsOneWidget);
    expect(find.text('Google extras'), findsOneWidget);
    expect(find.text('Streaming apps'), findsOneWidget);
    final tiles = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(tiles.map((tile) => tile.value), [true, true, true, false]);
  });

  testWidgets('removes selected apps and scans again', (tester) async {
    _largeScreen(tester);
    final tv = _FakeTuneUp();
    await tester.pumpWidget(_page(tv));
    await tester.pump();
    await tester.ensureVisible(find.text('Remove 3 apps'));
    await tester.tap(find.text('Remove 3 apps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(tv.removed, [
      bloatCatalog[0].package,
      bloatCatalog[2].package,
      bloatCatalog[10].package,
    ]);
    expect(tv.scans, 2);
  });

  testWidgets('restores an app', (tester) async {
    _largeScreen(tester);
    final tv = _FakeTuneUp();
    await tester.pumpWidget(_page(tv));
    await tester.pump();
    await tester.ensureVisible(find.text('Restore'));
    await tester.tap(find.text('Restore'));
    await tester.pump();
    expect(tv.restored, ['com.mitv.videoplayer']);
  });

  testWidgets('sets animation scale', (tester) async {
    _largeScreen(tester);
    final tv = _FakeTuneUp();
    await tester.pumpWidget(_page(tv));
    await tester.pump();
    await tester.ensureVisible(find.text('Normal'));
    await tester.tap(find.text('Normal'));
    await tester.pump();
    expect(tv.scales, [1]);
  });

  testWidgets('shows disconnected prompt', (tester) async {
    await tester.pumpWidget(_page(null));
    expect(find.text('Tune up needs Full control'), findsOneWidget);
    expect(find.text('Set up Full control'), findsOneWidget);
  });
}
