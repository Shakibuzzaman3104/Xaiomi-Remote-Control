/**
 * @author Shakib
 * @since 30/10/26
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/adb/adb_client.dart';
import 'package:xiaomi_remote/core/adb/full_control.dart';
import 'package:xiaomi_remote/core/adb/tv_files.dart';
import 'package:xiaomi_remote/core/session/providers.dart';
import 'package:xiaomi_remote/core/transfer/transfer_queue.dart';
import 'package:xiaomi_remote/ui/theme/app_theme.dart';
import 'package:xiaomi_remote/ui/transfer/transfer_page.dart';

class _Connected extends FullControl {
  @override
  FullControlState build() =>
      const FullControlState(status: FullControlStatus.connected);
}

class _Disconnected extends FullControl {
  @override
  FullControlState build() => const FullControlState();
}

class _Files implements TvFiles {
  AdbFileEntry entry(String name, {bool folder = false}) => AdbFileEntry(
    name: name,
    mode: folder ? 0x4000 : 0x8000,
    size: 1200,
    modified: DateTime(2026),
  );
  @override
  Future<List<AdbFileEntry>> listFolder(String path) async => path == '/sdcard'
      ? [entry('image.png'), entry('Folder', folder: true), entry('app.apk')]
      : [entry('child.txt')];
  @override
  Future<({int free, int total})> storage() async => (free: 4, total: 8);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingFiles extends _Files {
  final pending = Completer<String>();

  @override
  Future<String> sendFile(
    String name,
    Stream<List<int>> data,
    int length, {
    void Function(int, int)? onProgress,
    CancelToken? cancel,
  }) => cancel!.guard(pending.future);
}

Widget _page({bool connected = true}) => ProviderScope(
  overrides: [
    fullControlProvider.overrideWith(
      connected ? _Connected.new : _Disconnected.new,
    ),
    tvFilesProvider.overrideWithValue(_Files()),
    activeTvProvider.overrideWith((ref) => null),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const TransferPage()),
);

void main() {
  test('disposing the queue cancels running and queued transfers', () async {
    final files = _PendingFiles();
    final container = ProviderContainer(
      overrides: [
        fullControlProvider.overrideWith(_Connected.new),
        tvFilesProvider.overrideWithValue(files),
      ],
    );
    container.read(transferQueueProvider.notifier).sendFiles([
      PickedFile(name: 'one.txt', size: 1, openRead: () => Stream.empty()),
      PickedFile(name: 'two.txt', size: 1, openRead: () => Stream.empty()),
    ]);
    final jobs = container.read(transferQueueProvider);
    expect(jobs.map((job) => job.status), [
      TransferStatus.running,
      TransferStatus.queued,
    ]);

    container.dispose();
    expect(jobs.every((job) => job.cancelToken.isCancelled), isTrue);
    await Future<void>.delayed(Duration.zero);
  });

  testWidgets('switches tabs and navigates folders first', (tester) async {
    await tester.pumpWidget(_page());
    expect(find.text('Choose files'), findsOneWidget);
    await tester.tap(find.text('TV files'));
    await tester.pumpAndSettle();
    expect(find.text('Internal storage'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Folder')).dy,
      lessThan(tester.getTopLeft(find.text('app.apk')).dy),
    );
    await tester.tap(find.text('Folder'));
    await tester.pumpAndSettle();
    expect(find.text('child.txt'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Folder'), findsOneWidget);
    expect(find.text('child.txt'), findsNothing);
  });
  testWidgets('install is offered only for APK files', (tester) async {
    await tester.pumpWidget(_page());
    await tester.tap(find.text('TV files'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('app.apk'));
    await tester.pumpAndSettle();
    expect(find.text('Install'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Install'), findsNothing);
    await tester.ensureVisible(find.text('image.png'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('image.png'));
    await tester.pumpAndSettle();
    expect(find.text('Install'), findsNothing);
    expect(find.text('Save to phone'), findsOneWidget);
    expect(find.text('Open on TV'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
  testWidgets('file actions remain usable on a short screen', (tester) async {
    await tester.pumpWidget(_page());
    await tester.tap(find.text('TV files'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('app.apk'));
    await tester.pumpAndSettle();

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 300);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete app.apk?'), findsOneWidget);
    expect(
      find.text('This will remove the file from your TV.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
  testWidgets('shows Full control prompt when disconnected', (tester) async {
    await tester.pumpWidget(_page(connected: false));
    expect(find.text('Transfer needs Full control'), findsOneWidget);
    expect(find.text('Set up Full control'), findsOneWidget);
  });
}
