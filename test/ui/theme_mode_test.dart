/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/storage/paired_tv_store.dart';
import 'package:xiaomi_remote/ui/theme/app_colors.dart';
import 'package:xiaomi_remote/ui/theme/app_theme.dart';
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

void main() {
  test('theme choice persists and reloads', () async {
    final store = _MemoryStore();
    final first = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    await first.read(themeModeProvider.notifier).select(ThemeMode.dark);
    first.dispose();

    final second = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    second.read(themeModeProvider);
    await Future<void>.delayed(Duration.zero);
    expect(second.read(themeModeProvider), ThemeMode.dark);
    second.dispose();
  });

  test('dark theme carries the dark palette', () {
    final theme = AppTheme.dark;
    expect(theme.brightness, Brightness.dark);
    expect(theme.extension<AppColors>(), same(AppColors.dark));
    expect(theme.scaffoldBackgroundColor, AppColors.dark.background);
  });
}
