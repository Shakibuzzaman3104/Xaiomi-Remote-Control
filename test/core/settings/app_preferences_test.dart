/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/settings/app_preferences.dart';
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
  test('preferences survive a JSON round trip', () {
    const original = AppPreferences(
      haptics: false,
      volumeKeysControlTv: false,
      swipeSensitivity: 0.8,
      micButton: VoiceTargetPreference.typeIntoField,
      speechLocale: 'bn_BD',
    );
    final restored = AppPreferences.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    expect(restored.toJson(), original.toJson());
  });

  test('preferences persist between provider containers', () async {
    final store = MemoryStore();
    final first = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    first.read(appPreferencesProvider);
    final notifier = first.read(appPreferencesProvider.notifier);
    await notifier.setHaptics(false);
    await notifier.setVolumeKeysControlTv(false);
    await notifier.setSwipeSensitivity(0.75);
    await notifier.setMicButton(VoiceTargetPreference.typeIntoField);
    await notifier.setSpeechLocale('bn_BD');
    first.dispose();

    final second = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(second.dispose);
    second.read(appPreferencesProvider);
    await Future<void>.delayed(Duration.zero);
    expect(second.read(appPreferencesProvider).toJson(), {
      'haptics': false,
      'volumeKeysControlTv': false,
      'swipeSensitivity': 0.75,
      'micButton': 'typeIntoField',
      'speechLocale': 'bn_BD',
      'remoteMode': 'dpad',
    });
  });
}
