/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/theme/theme_mode_provider.dart';
import '../session/providers.dart';
import '../storage/paired_tv_store.dart';
import 'adb_client.dart';
import 'adb_commands.dart';
import 'adb_key.dart';

enum FullControlStatus {
  off,
  connecting,
  waitingForApproval,
  connected,
  failed,
}

@immutable
class TvApp {
  const TvApp({
    required this.package,
    required this.label,
    required this.isTvApp,
    this.iconPng,
  });
  final String package;
  final String label;
  final bool isTvApp;
  final Uint8List? iconPng;
}

@immutable
class FullControlState {
  const FullControlState({
    this.status = FullControlStatus.off,
    this.error,
    this.apps = const [],
    this.appsLoading = false,
  });
  final FullControlStatus status;
  final String? error;
  final List<TvApp> apps;
  final bool appsLoading;

  FullControlState copyWith({
    FullControlStatus? status,
    String? error,
    List<TvApp>? apps,
    bool? appsLoading,
  }) => FullControlState(
    status: status ?? this.status,
    error: error,
    apps: apps ?? this.apps,
    appsLoading: appsLoading ?? this.appsLoading,
  );
}

List<TvApp> parseHelperApps(String output) {
  final apps = <String, TvApp>{};
  for (final line in const LineSplitter().convert(output)) {
    final fields = line.split('\t');
    if (fields.length != 4 ||
        fields[0].trim().isEmpty ||
        fields[1].trim().isEmpty ||
        (fields[2] != 'tv' && fields[2] != 'phone')) {
      continue;
    }
    Uint8List? icon;
    try {
      if (fields[3].isNotEmpty) icon = base64Decode(fields[3]);
    } on FormatException {
      continue;
    }
    final app = TvApp(
      package: fields[0].trim(),
      label: fields[1].trim(),
      isTvApp: fields[2] == 'tv',
      iconPng: icon,
    );
    final previous = apps[app.package];
    if (previous == null || (!previous.isTvApp && app.isTvApp)) {
      apps[app.package] = app;
    }
  }
  final result = apps.values.toList()
    ..sort((a, b) {
      if (a.isTvApp != b.isTvApp) return a.isTvApp ? -1 : 1;
      final comparison = a.label.toLowerCase().compareTo(b.label.toLowerCase());
      return comparison != 0 ? comparison : a.package.compareTo(b.package);
    });
  return List.unmodifiable(result);
}

final fullControlProvider = NotifierProvider<FullControl, FullControlState>(
  FullControl.new,
);

class FullControl extends Notifier<FullControlState> {
  static final _keyLoads = <KeyValueStore, Future<AdbKey>>{};
  AdbClient? _client;
  StreamSubscription<AdbConnectionState>? _subscription;
  int _generation = 0;
  PairedTv? _tv;
  KeyValueStore? _store;
  bool _waitingForApproval = false;

  @override
  FullControlState build() {
    final tv = ref.watch(activeTvProvider);
    final store = ref.watch(keyValueStoreProvider);
    _tv = tv;
    _store = store;
    var alive = true;
    final generation = ++_generation;
    ref.onDispose(() {
      alive = false;
      ++_generation;
      final subscription = _subscription;
      final client = _client;
      _subscription = null;
      _client = null;
      if (subscription != null) unawaited(subscription.cancel());
      if (client != null) unawaited(client.disconnect());
    });
    if (tv != null) {
      unawaited(() async {
        try {
          final enabled = await store.read('adb_enabled_${tv.id}');
          if (alive &&
              generation == _generation &&
              enabled == '1' &&
              state.status == FullControlStatus.off) {
            await connect();
          }
        } catch (_) {}
      }());
    }
    return const FullControlState();
  }

  Future<AdbKey> _loadKey(KeyValueStore store) {
    final pending = _keyLoads[store];
    if (pending != null) return pending;
    final load = _readOrCreateKey(store);
    _keyLoads[store] = load;
    return load.whenComplete(() => _keyLoads.remove(store));
  }

  Future<AdbKey> _readOrCreateKey(KeyValueStore store) async {
    final privateKey = await store.read('adb_private_key');
    final publicKey = await store.read('adb_public_key');
    if (privateKey != null &&
        publicKey != null &&
        privateKey.isNotEmpty &&
        publicKey.isNotEmpty) {
      return AdbKey(privateKeyPem: privateKey, publicKeyPem: publicKey);
    }
    final key = await Isolate.run(AdbKey.generate);
    await store.write('adb_private_key', key.privateKeyPem);
    await store.write('adb_public_key', key.publicKeyPem);
    return key;
  }

  Future<void> connect() async {
    final tv = _tv;
    final store = _store;
    if (tv == null || store == null) {
      state = state.copyWith(
        status: FullControlStatus.failed,
        error: 'No TV selected',
      );
      return;
    }
    if (state.status == FullControlStatus.connecting ||
        state.status == FullControlStatus.waitingForApproval ||
        state.status == FullControlStatus.connected) {
      return;
    }
    final generation = ++_generation;
    _waitingForApproval = false;
    state = const FullControlState(status: FullControlStatus.connecting);
    try {
      final key = await _loadKey(store);
      if (generation != _generation) return;
      final oldSubscription = _subscription;
      final oldClient = _client;
      _subscription = null;
      _client = null;
      if (oldSubscription != null) await oldSubscription.cancel();
      if (oldClient != null) await oldClient.disconnect();
      if (generation != _generation) return;
      final client = AdbClient(host: tv.host, key: key);
      _client = client;
      _subscription = client.states.listen((event) {
        if (generation != _generation) return;
        switch (event) {
          case AdbConnectionState.connecting:
            state = state.copyWith(status: FullControlStatus.connecting);
          case AdbConnectionState.waitingForApproval:
            _waitingForApproval = true;
            state = state.copyWith(
              status: FullControlStatus.waitingForApproval,
            );
          case AdbConnectionState.connected:
            state = state.copyWith(status: FullControlStatus.connected);
          case AdbConnectionState.disconnected:
            state = const FullControlState();
          case AdbConnectionState.failed:
            if (state.status != FullControlStatus.failed) {
              state = state.copyWith(
                status: FullControlStatus.failed,
                error: 'Full control connection failed',
                appsLoading: false,
              );
            }
        }
      });
      await client.connect(authTimeout: const Duration(seconds: 60));
      if (generation != _generation) {
        await client.disconnect();
        return;
      }
      state = state.copyWith(status: FullControlStatus.connected);
      await store.write('adb_enabled_${tv.id}', '1');
      if (generation != _generation) return;
      try {
        await loadApps();
      } catch (error) {
        if (generation == _generation) {
          state = state.copyWith(error: 'Could not load apps: $error');
        }
      }
    } catch (error) {
      if (generation != _generation) return;
      final message = error.toString().toLowerCase();
      final String readable;
      if (_waitingForApproval &&
          (error is TimeoutException ||
              message.contains('timed out') ||
              message.contains('timeout'))) {
        readable = 'No answer on the TV. Choose Allow on the TV and try again.';
      } else if (error is SocketException ||
          message.contains('socketexception') ||
          message.contains('connection refused')) {
        readable = 'Network debugging is off on the TV';
      } else {
        readable = error is AdbException ? error.message : error.toString();
      }
      state = state.copyWith(
        status: FullControlStatus.failed,
        error: readable,
        appsLoading: false,
      );
    }
  }

  Future<void> loadApps() async {
    final client = _connectedClient();
    final generation = _generation;
    state = state.copyWith(appsLoading: true);
    try {
      final data = await rootBundle.load('assets/tv_helper.jar');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      const path = '/data/local/tmp/xr_helper.jar';
      final listing = await client.shell('ls -l $path');
      final size = RegExp(r'^\S+\s+\d+\s+\S+\s+\S+\s+(\d+)\s')
          .firstMatch(listing.trim())
          ?.group(1);
      if (int.tryParse(size ?? '') != bytes.length) {
        await client.push(bytes, path);
      }
      final output = await client.shell(
        'CLASSPATH=$path app_process / com.diatomicsoft.xiaomiremote.helper.Main apps 96',
        timeout: const Duration(seconds: 30),
      );
      if (generation == _generation) {
        state = state.copyWith(
          apps: parseHelperApps(output),
          appsLoading: false,
        );
      }
    } catch (_) {
      if (generation == _generation) state = state.copyWith(appsLoading: false);
      rethrow;
    }
  }

  AdbClient _connectedClient() {
    final client = _client;
    if (client == null || state.status != FullControlStatus.connected) {
      throw AdbException('Full control is not connected');
    }
    return client;
  }

  Future<void> launch(String package) =>
      AdbCommands(_connectedClient()).launchApp(package);
  Future<void> forceStop(String package) =>
      AdbCommands(_connectedClient()).forceStop(package);
  Future<void> clearCache(String package) =>
      AdbCommands(_connectedClient()).clearCache(package);
  Future<void> openAppInfo(String package) =>
      AdbCommands(_connectedClient()).openAppInfo(package);
  Future<void> globalSearch(String query) =>
      AdbCommands(_connectedClient()).globalSearch(query);

  Future<void> uninstall(String package) async {
    await AdbCommands(_connectedClient()).uninstall(package);
    await loadApps();
  }

  Future<void> disconnect() async {
    ++_generation;
    final tv = _tv;
    final store = _store;
    final client = _client;
    final subscription = _subscription;
    _client = null;
    _subscription = null;
    state = const FullControlState();
    if (subscription != null) await subscription.cancel();
    if (client != null) await client.disconnect();
    if (tv != null && store != null) await store.delete('adb_enabled_${tv.id}');
  }
}
