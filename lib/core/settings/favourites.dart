/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/theme/theme_mode_provider.dart';

final favouritesProvider = NotifierProvider<Favourites, Set<String>>(
  Favourites.new,
);

class Favourites extends Notifier<Set<String>> {
  static const _key = 'favourite_apps';
  static const _defaults = {
    'com.google.android.youtube.tv',
    'com.netflix.ninja',
  };
  Future<void>? _loading;
  Future<void> _writes = Future.value();

  @override
  Set<String> build() {
    final store = ref.watch(keyValueStoreProvider);
    var alive = true;
    ref.onDispose(() => alive = false);
    _loading = () async {
      try {
        final raw = await store.read(_key);
        if (!alive || raw == null) return;
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.every((item) => item is String)) {
          state = Set.unmodifiable(decoded.cast<String>());
        }
      } catch (_) {}
    }();
    return Set.unmodifiable(_defaults);
  }

  bool contains(String package) => state.contains(package);

  Future<void> toggle(String package) async {
    await _loading;
    final updated = {...state};
    if (!updated.add(package)) updated.remove(package);
    state = Set.unmodifiable(updated);
    final store = ref.read(keyValueStoreProvider);
    final encoded = jsonEncode(updated.toList());
    final write = _writes
        .catchError((Object _) {})
        .then((_) => store.write(_key, encoded));
    _writes = write;
    await write;
  }
}
