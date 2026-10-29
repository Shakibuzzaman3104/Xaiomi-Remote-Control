/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/discovery/tv_discovery.dart';
import 'package:xiaomi_remote/core/remote/atv_remote.dart';
import 'package:xiaomi_remote/core/session/providers.dart';
import 'package:xiaomi_remote/core/session/tv_session.dart';
import 'package:xiaomi_remote/core/storage/paired_tv_store.dart';
import 'package:xiaomi_remote/main.dart';
import 'package:xiaomi_remote/ui/theme/theme_mode_provider.dart';

class _MemoryStore implements KeyValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

Future<void> _pumpApp(WidgetTester tester, PairedTvStore store) async {
  await tester.binding.setSurfaceSize(const Size(360, 780));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(_MemoryStore()),
        pairedTvStoreProvider.overrideWithValue(store),
        discoveredTvsProvider.overrideWith(
          (ref) => Stream.value(const [
            DiscoveredTv(name: 'Android TV', host: '192.168.0.103'),
          ]),
        ),
        tvSessionProvider.overrideWithValue(null),
        tvSessionStateProvider.overrideWith(
          (ref) => Stream.value(
            const TvSessionState(
              status: SessionStatus.connected,
              atv: AtvState(connected: true),
            ),
          ),
        ),
      ],
      child: const XiaomiRemoteApp(),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('shows onboarding when no TV is paired', (tester) async {
    await _pumpApp(tester, PairedTvStore(_MemoryStore()));
    expect(find.text('Find your TV'), findsOneWidget);
    expect(find.textContaining('192.168.0.103'), findsOneWidget);
  });

  testWidgets('shows the remote for the last used TV', (tester) async {
    final store = PairedTvStore(_MemoryStore());
    await store.save(
      PairedTv(
        id: '192.168.0.103',
        name: 'Living Room',
        host: '192.168.0.103',
        certPem: '',
        privateKeyPem: '',
        pairedAt: DateTime(2026, 10, 29),
      ),
    );
    await store.saveLastUsedId('192.168.0.103');
    await _pumpApp(tester, store);
    expect(find.text('Living Room'), findsOneWidget);
    expect(find.text('Apps'), findsOneWidget);
  });
}
