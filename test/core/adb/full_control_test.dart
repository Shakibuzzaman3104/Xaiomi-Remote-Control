/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/adb/adb_client.dart';
import 'package:xiaomi_remote/core/adb/adb_key.dart';
import 'package:xiaomi_remote/core/adb/full_control.dart';
import 'package:xiaomi_remote/core/session/providers.dart';
import 'package:xiaomi_remote/core/settings/favourites.dart';
import 'package:xiaomi_remote/core/storage/paired_tv_store.dart';
import 'package:xiaomi_remote/ui/theme/theme_mode_provider.dart';

class MemoryStore implements KeyValueStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class FailingClient extends AdbClient {
  FailingClient(AdbKey key) : super(host: 'test', key: key);

  final events = StreamController<AdbConnectionState>.broadcast();

  @override
  Stream<AdbConnectionState> get states => events.stream;

  @override
  Future<void> connect({
    Duration authTimeout = const Duration(seconds: 60),
    bool offerPublicKey = true,
  }) async {
    events.add(AdbConnectionState.failed);
    throw AdbException('offline');
  }

  @override
  Future<void> disconnect() async {
    await events.close();
  }
}

void main() {
  test('disconnect cancels scheduled full control reconnect', () async {
    final store = MemoryStore();
    store.values.addAll({
      'adb_enabled_tv': '1',
      'adb_private_key': 'private',
      'adb_public_key': 'public',
    });
    final tv = PairedTv(
      id: 'tv',
      name: 'TV',
      host: 'test',
      certPem: '',
      privateKeyPem: '',
      pairedAt: DateTime(2026),
    );
    var attempts = 0;
    final container = ProviderContainer(
      overrides: [
        activeTvProvider.overrideWithValue(tv),
        keyValueStoreProvider.overrideWithValue(store),
        fullControlProvider.overrideWith(
          () => FullControl(
            clientFactory: (_, AdbKey key) {
              attempts++;
              return FailingClient(key);
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(fullControlProvider);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(attempts, 1);
    expect(
      container.read(fullControlProvider).status,
      FullControlStatus.failed,
    );
    await container.read(fullControlProvider.notifier).disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    await container.read(fullControlProvider.notifier).reconnectIfEnabled();
    expect(attempts, 1);
    expect(container.read(fullControlProvider).status, FullControlStatus.off);
  });

  test('parses icons, skips malformed lines, prefers TV entries and sorts', () {
    final apps = parseHelperApps(
      'phone.z\tAlpha\tphone\tAQI=\n'
      'same.pkg\tPhone version\tphone\t\n'
      'tv.z\tZulu\ttv\t\n'
      'same.pkg\tBeta\ttv\tAw==\n'
      'tv.a\talpha\ttv\t\n'
      'same.pkg\tLater phone\tphone\t\n'
      'bad line\n'
      'bad.pkg\tBroken\ttv\t%%%\n'
      'bad.pkg\tBroken\tother\t\n'
      '\tNo package\ttv\t\n',
    );
    expect(apps.map((app) => app.package), [
      'tv.a',
      'same.pkg',
      'tv.z',
      'phone.z',
    ]);
    expect(apps[1].label, 'Beta');
    expect(apps[1].isTvApp, isTrue);
    expect(apps[1].iconPng, [3]);
    expect(apps.last.iconPng, [1, 2]);
  });

  test('favourites load, toggle and persist across containers', () async {
    final store = MemoryStore();
    final first = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(first.dispose);
    expect(first.read(favouritesProvider), {
      'com.google.android.youtube.tv',
      'com.netflix.ninja',
    });
    final favourites = first.read(favouritesProvider.notifier);
    await favourites.toggle('com.netflix.ninja');
    await favourites.toggle('example.app');
    expect(favourites.contains('example.app'), isTrue);
    expect(
      jsonDecode(store.values['favourite_apps']!),
      containsAll(['com.google.android.youtube.tv', 'example.app']),
    );
    expect(
      jsonDecode(store.values['favourite_apps']!),
      isNot(contains('com.netflix.ninja')),
    );

    final second = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(second.dispose);
    second.read(favouritesProvider);
    await Future<void>.delayed(Duration.zero);
    expect(second.read(favouritesProvider), {
      'com.google.android.youtube.tv',
      'example.app',
    });
  });
}
