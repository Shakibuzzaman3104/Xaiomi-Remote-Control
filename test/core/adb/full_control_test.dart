/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/adb/full_control.dart';
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

void main() {
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
