/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/paired_tv_store.dart';

final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => SecureKeyValueStore(),
);

/// The user's theme choice, persisted across launches.
class ThemeModeSetting extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final saved = await ref.read(keyValueStoreProvider).read(_key);
    final mode = ThemeMode.values.where((m) => m.name == saved).firstOrNull;
    if (mode != null) state = mode;
  }

  Future<void> select(ThemeMode mode) async {
    state = mode;
    await ref.read(keyValueStoreProvider).write(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeSetting, ThemeMode>(
  ThemeModeSetting.new,
);
